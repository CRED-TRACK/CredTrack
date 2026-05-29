package com.credtrack.backend.service;

import com.credtrack.backend.dto.DashboardCardSection;
import com.credtrack.backend.dto.DashboardResponse;
import com.credtrack.backend.dto.RewardRuleDTO;
import com.credtrack.backend.dto.WarningDTO;
import com.credtrack.backend.entity.CanonicalCategory;
import com.credtrack.backend.entity.CardRewardRule;
import com.credtrack.backend.entity.RuleSource;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.entity.UserCardCategoryChoice;
import com.credtrack.backend.repository.UserCardRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class AdvisorDashboardService {

    private final UserCardRepository userCardRepository;
    private final RewardRulesService rewardRulesService;
    private final CapTrackingService capTrackingService;
    private final UserCardCategoryChoiceService choiceService;

    public AdvisorDashboardService(UserCardRepository userCardRepository,
                                   RewardRulesService rewardRulesService,
                                   CapTrackingService capTrackingService,
                                   UserCardCategoryChoiceService choiceService) {
        this.userCardRepository = userCardRepository;
        this.rewardRulesService = rewardRulesService;
        this.capTrackingService = capTrackingService;
        this.choiceService = choiceService;
    }

    public DashboardResponse buildFor(String userId) {
        LocalDate asOf = capTrackingService.today();

        List<UserCard> cards = userCardRepository.findByUser_IdAndIsActiveTrueOrderByAddedAtDesc(userId);
        if (cards.isEmpty()) {
            return DashboardResponse.builder()
                .asOf(asOf)
                .fiscalYearStart(asOf.withDayOfYear(1))
                .currentQuarter(currentQuarterLabel(asOf))
                .categoriesActive(List.of())
                .categoryRankings(List.of())
                .cards(List.of())
                .build();
        }

        List<Long> cardProductIds = cards.stream()
            .map(c -> c.getCardProduct().getId())
            .distinct()
            .toList();
        List<CardRewardRule> allRules = rewardRulesService.findActiveForCardProducts(cardProductIds, asOf);

        Map<Long, List<CardRewardRule>> rulesByProduct = allRules.stream()
            .collect(Collectors.groupingBy(r -> r.getCardProduct().getId()));

        Map<Long, UserCardCategoryChoice> bofaChoiceByCard = choiceService
            .findActiveBofaChoices(cards.stream().map(UserCard::getId).toList(), asOf);

        List<DashboardCardSection> sections = new ArrayList<>();
        Map<String, BestEntry> bestPerCategory = new HashMap<>();

        for (UserCard card : cards) {
            List<CardRewardRule> rules = rulesByProduct.getOrDefault(card.getCardProduct().getId(), List.of());
            Map<Long, CapTrackingService.CapStatus> caps =
                capTrackingService.computeStatusesForCard(card.getId(), rules, asOf);

            UserCardCategoryChoice choice = bofaChoiceByCard.get(card.getId());
            List<RewardRuleDTO> dtos = new ArrayList<>();
            for (CardRewardRule rule : rules) {
                CapTrackingService.CapStatus cap = caps.get(rule.getId());

                int effectiveRate = rule.getRateBps();
                boolean choiceActive = true;
                String userChoiceActive = null;
                if (Boolean.TRUE.equals(rule.getRequiresUserChoice())) {
                    if (choice == null) {
                        // No choice set — this rule's 3% does not apply yet.
                        choiceActive = false;
                    } else {
                        userChoiceActive = choice.getCanonicalCategory();
                        choiceActive = choice.getCanonicalCategory().equals(rule.getCanonicalCategory());
                    }
                }

                if (cap != null && cap.isCapExhausted()) {
                    effectiveRate = rule.getBaseRateBps() != null ? rule.getBaseRateBps() : 0;
                }
                if (!choiceActive) {
                    effectiveRate = rule.getBaseRateBps() != null ? rule.getBaseRateBps() : 0;
                }

                CanonicalCategory cat = CanonicalCategory.fromCode(rule.getCanonicalCategory())
                    .orElse(CanonicalCategory.OTHER);

                RewardRuleDTO dto = RewardRuleDTO.builder()
                    .canonicalCategory(rule.getCanonicalCategory())
                    .displayName(cat.displayName())
                    .iconHint(cat.iconHint())
                    .rateBps(rule.getRateBps())
                    .effectiveRateBps(effectiveRate)
                    .baseRateBps(rule.getBaseRateBps())
                    .capAmount(rule.getCapAmount())
                    .capPeriod(rule.getCapPeriod() != null ? rule.getCapPeriod().name() : null)
                    .capPeriodLabel(cap != null ? cap.getCapPeriodLabel() : null)
                    .capGroupKey(rule.getCapGroupKey())
                    .spentInPeriod(cap != null ? cap.getSpentInPeriod() : null)
                    .capRemaining(cap != null ? cap.getCapRemaining() : null)
                    .capExhausted(cap != null && cap.isCapExhausted())
                    .requiresUserChoice(Boolean.TRUE.equals(rule.getRequiresUserChoice()))
                    .userChoiceActive(userChoiceActive)
                    .channelRestriction(rule.getChannelRestriction())
                    .exclusions(rule.getExclusions() != null ? List.of(rule.getExclusions()) : List.of())
                    .notes(rule.getNotes())
                    .source(rule.getSource() != null ? rule.getSource().name() : RuleSource.SEED.name())
                    .sourceConfidence(rule.getSourceConfidence() != null
                        ? BigDecimal.valueOf(rule.getSourceConfidence()) : null)
                    .sourceDocumentId(rule.getSourceDocumentId())
                    .effectiveFrom(rule.getEffectiveFrom())
                    .effectiveTo(rule.getEffectiveTo())
                    .build();
                dtos.add(dto);

                if (choiceActive && effectiveRate > 0) {
                    bestPerCategory.merge(rule.getCanonicalCategory(),
                        new BestEntry(card.getId(), effectiveRate,
                            cap != null ? cap.getCapRemaining() : null,
                            cap != null ? cap.getCapPeriodLabel() : null),
                        BestEntry::better);
                }
            }

            List<WarningDTO> warnings = new ArrayList<>();
            String bank = card.getCardProduct().getBankKey();
            String prod = card.getCardProduct().getProductName();
            boolean isBofaCustomized = "BOA".equalsIgnoreCase(bank)
                && prod != null && prod.toLowerCase().contains("customized");
            if (isBofaCustomized && choice == null) {
                warnings.add(WarningDTO.builder()
                    .code("BOA_3PCT_CHOICE_MISSING")
                    .message("Pick your 3% category to unlock BofA bonus.")
                    .build());
            }

            sections.add(DashboardCardSection.builder()
                .userCardId(card.getId())
                .productName(card.getCardProduct().getProductName())
                .issuerName(card.getCardProduct().getIssuerName())
                .bankKey(card.getCardProduct().getBankKey())
                .faceColor(card.getCardProduct().getFaceColor())
                .gradientEnd(card.getCardProduct().getGradientEnd())
                .textColor(card.getCardProduct().getTextColor())
                .lastFour(card.getLastFour())
                .nickname(card.getNickname())
                .rewards(dtos)
                .warnings(warnings)
                .build());
        }

        List<DashboardResponse.CategoryRanking> rankings = bestPerCategory.entrySet().stream()
            .map(e -> DashboardResponse.CategoryRanking.builder()
                .category(e.getKey())
                .displayName(CanonicalCategory.fromCode(e.getKey())
                    .orElse(CanonicalCategory.OTHER).displayName())
                .bestUserCardId(e.getValue().cardId)
                .bestRateBps(e.getValue().rateBps)
                .capRemaining(e.getValue().capRemaining)
                .capPeriodLabel(e.getValue().capPeriodLabel)
                .build())
            .sorted(Comparator.comparing(DashboardResponse.CategoryRanking::getCategory))
            .toList();

        List<String> categoriesActive = bestPerCategory.keySet().stream().sorted().toList();

        return DashboardResponse.builder()
            .asOf(asOf)
            .fiscalYearStart(asOf.withDayOfYear(1))
            .currentQuarter(currentQuarterLabel(asOf))
            .categoriesActive(categoriesActive)
            .categoryRankings(rankings)
            .cards(sections)
            .build();
    }

    private String currentQuarterLabel(LocalDate asOf) {
        int q = (asOf.getMonthValue() - 1) / 3 + 1;
        return asOf.getYear() + "-Q" + q;
    }

    private static class BestEntry {
        final Long cardId;
        final int rateBps;
        final BigDecimal capRemaining;
        final String capPeriodLabel;

        BestEntry(Long cardId, int rateBps, BigDecimal capRemaining, String capPeriodLabel) {
            this.cardId = cardId;
            this.rateBps = rateBps;
            this.capRemaining = capRemaining;
            this.capPeriodLabel = capPeriodLabel;
        }

        BestEntry better(BestEntry other) {
            if (other.rateBps > this.rateBps) return other;
            return this;
        }
    }
}
