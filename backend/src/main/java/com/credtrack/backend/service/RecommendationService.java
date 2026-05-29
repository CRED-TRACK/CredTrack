package com.credtrack.backend.service;

import com.credtrack.backend.entity.CardRewardRule;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.entity.UserCardCategoryChoice;
import lombok.Builder;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

/**
 * Pure computation: given a user's cards, their active rules + caps + choices,
 * rank cards for one category (or compute the best card per category).
 */
public class RecommendationService {

    public static final String BLOCKED_TRAVEL_PORTAL = "TRAVEL_PORTAL_ONLY";
    public static final String BLOCKED_REQUIRES_CHOICE = "REQUIRES_USER_CHOICE_MISMATCH";

    @lombok.Value
    @Builder
    public static class Ranked {
        Long userCardId;
        int rank;
        int effectiveRateBps;
        String rateLabel;
        BigDecimal projectedCashback;
        BigDecimal capRemaining;
        String capPeriodLabel;
        boolean capExhausted;
        String blockedReason;
        String notes;
    }

    /**
     * Build effective rate for a single (card, category) considering caps, choices, channel.
     * Returns null if this card has no rule for the category.
     */
    public static Ranked evaluate(UserCard card,
                                  CardRewardRule rule,
                                  CapTrackingService.CapStatus capStatus,
                                  UserCardCategoryChoice choiceIfAny,
                                  BigDecimal amount,
                                  String requestedCategory) {
        if (rule == null) return null;

        int rate = rule.getRateBps();
        int base = rule.getBaseRateBps() != null ? rule.getBaseRateBps() : 0;
        String blocked = null;

        if (rule.getRequiresUserChoice() != null && rule.getRequiresUserChoice()) {
            String chosen = choiceIfAny != null ? choiceIfAny.getCanonicalCategory() : null;
            if (chosen == null || !chosen.equals(rule.getCanonicalCategory())) {
                blocked = BLOCKED_REQUIRES_CHOICE;
                rate = base;
            }
        }

        if (rule.getChannelRestriction() != null
            && "TRAVEL_PORTAL_ONLY".equals(rule.getChannelRestriction())) {
            // Surface the restriction. Caller decides whether to drop or include.
            blocked = blocked == null ? BLOCKED_TRAVEL_PORTAL : blocked;
        }

        boolean exhausted = capStatus != null && capStatus.isCapExhausted();
        if (exhausted) rate = base;

        BigDecimal projected = null;
        if (amount != null && amount.signum() > 0) {
            BigDecimal effective = BigDecimal.valueOf(rate).movePointLeft(4);
            BigDecimal baseRate = BigDecimal.valueOf(base).movePointLeft(4);
            if (capStatus != null && capStatus.getCapRemaining() != null && capStatus.getCapAmount() != null) {
                BigDecimal eligible = amount.min(capStatus.getCapRemaining());
                BigDecimal overflow = amount.subtract(eligible).max(BigDecimal.ZERO);
                projected = eligible.multiply(effective).add(overflow.multiply(baseRate));
            } else {
                projected = amount.multiply(effective);
            }
            projected = projected.setScale(2, RoundingMode.HALF_UP);
        }

        return Ranked.builder()
            .userCardId(card.getId())
            .effectiveRateBps(rate)
            .rateLabel(formatRate(rate))
            .projectedCashback(projected)
            .capRemaining(capStatus != null ? capStatus.getCapRemaining() : null)
            .capPeriodLabel(capStatus != null ? capStatus.getCapPeriodLabel() : null)
            .capExhausted(exhausted)
            .blockedReason(blocked)
            .notes(rule.getNotes())
            .build();
    }

    public static String formatRate(int rateBps) {
        BigDecimal pct = BigDecimal.valueOf(rateBps).movePointLeft(2);
        return pct.stripTrailingZeros().toPlainString() + "%";
    }

    /**
     * Rank a flat list of Ranked entries: descending by rate, tiebreak by capRemaining desc.
     * Mutates rank field in the input list.
     */
    public static List<Ranked> assignRanks(List<Ranked> entries) {
        List<Ranked> sorted = entries.stream()
            .sorted((a, b) -> {
                int byRate = Integer.compare(b.getEffectiveRateBps(), a.getEffectiveRateBps());
                if (byRate != 0) return byRate;
                BigDecimal ar = a.getCapRemaining() != null ? a.getCapRemaining() : BigDecimal.ZERO;
                BigDecimal br = b.getCapRemaining() != null ? b.getCapRemaining() : BigDecimal.ZERO;
                return br.compareTo(ar);
            })
            .toList();
        List<Ranked> out = new java.util.ArrayList<>(sorted.size());
        for (int i = 0; i < sorted.size(); i++) {
            Ranked r = sorted.get(i);
            out.add(Ranked.builder()
                .userCardId(r.getUserCardId())
                .rank(i + 1)
                .effectiveRateBps(r.getEffectiveRateBps())
                .rateLabel(r.getRateLabel())
                .projectedCashback(r.getProjectedCashback())
                .capRemaining(r.getCapRemaining())
                .capPeriodLabel(r.getCapPeriodLabel())
                .capExhausted(r.isCapExhausted())
                .blockedReason(r.getBlockedReason())
                .notes(r.getNotes())
                .build());
        }
        return out;
    }
}
