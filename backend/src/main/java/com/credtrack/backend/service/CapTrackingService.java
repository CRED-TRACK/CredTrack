package com.credtrack.backend.service;

import com.credtrack.backend.entity.CapPeriod;
import com.credtrack.backend.entity.CardRewardRule;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.Builder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Computes spent-in-period vs cap for a (userCardId, ruleSet) bucket.
 * Cap groups share the same period total across multiple rules.
 */
@Service
public class CapTrackingService {

    @PersistenceContext
    private EntityManager em;

    private final ZoneId zone;

    public CapTrackingService(@Value("${app.advisor.timezone:America/New_York}") String tz) {
        this.zone = ZoneId.of(tz);
    }

    @lombok.Value
    @Builder
    public static class CapStatus {
        LocalDate periodStart;
        LocalDate periodEnd;
        BigDecimal spentInPeriod;
        BigDecimal capAmount;
        BigDecimal capRemaining;
        boolean capExhausted;
        String capPeriodLabel;
    }

    public LocalDate today() {
        return ZonedDateTime.now(zone).toLocalDate();
    }

    /**
     * For one user card, compute CapStatus per rule. Rules sharing a non-null cap_group_key
     * share one period sum (computed once and assigned to every member rule).
     */
    public Map<Long, CapStatus> computeStatusesForCard(Long userCardId,
                                                       List<CardRewardRule> rules,
                                                       LocalDate asOf) {
        Map<Long, CapStatus> out = new HashMap<>();
        Map<String, BigDecimal> groupSums = new HashMap<>();

        for (CardRewardRule rule : rules) {
            if (rule.getCapAmount() == null || rule.getCapPeriod() == null
                || rule.getCapPeriod() == CapPeriod.NONE) {
                out.put(rule.getId(), CapStatus.builder()
                    .periodStart(null).periodEnd(null)
                    .spentInPeriod(null)
                    .capAmount(null).capRemaining(null).capExhausted(false)
                    .capPeriodLabel(null)
                    .build());
                continue;
            }

            PeriodWindow win = computeWindow(rule.getCapPeriod(), asOf);
            BigDecimal spent;
            if (rule.getCapGroupKey() != null) {
                spent = groupSums.computeIfAbsent(rule.getCapGroupKey(), k ->
                    sumGroupSpend(userCardId, rules, rule.getCapGroupKey(), win));
            } else {
                spent = sumCategorySpend(userCardId,
                    List.of(rule.getCanonicalCategory()), win);
            }
            BigDecimal remaining = rule.getCapAmount().subtract(spent).max(BigDecimal.ZERO);
            boolean exhausted = spent.compareTo(rule.getCapAmount()) >= 0;
            out.put(rule.getId(), CapStatus.builder()
                .periodStart(win.start).periodEnd(win.end)
                .spentInPeriod(spent)
                .capAmount(rule.getCapAmount())
                .capRemaining(remaining)
                .capExhausted(exhausted)
                .capPeriodLabel(label(rule.getCapPeriod()))
                .build());
        }
        return out;
    }

    private BigDecimal sumGroupSpend(Long userCardId, List<CardRewardRule> rules,
                                     String groupKey, PeriodWindow win) {
        List<String> categories = rules.stream()
            .filter(r -> groupKey.equals(r.getCapGroupKey()))
            .map(CardRewardRule::getCanonicalCategory)
            .distinct()
            .toList();
        return sumCategorySpend(userCardId, categories, win);
    }

    private BigDecimal sumCategorySpend(Long userCardId, Collection<String> categories,
                                        PeriodWindow win) {
        if (categories.isEmpty()) return BigDecimal.ZERO;
        Object result = em.createQuery("""
                SELECT COALESCE(SUM(t.amount), 0)
                FROM Transaction t
                WHERE t.userCard.id = :uc
                  AND t.transactionType = 'PURCHASE'
                  AND t.transactionDate >= :from
                  AND t.transactionDate <= :to
                  AND t.canonicalCategory IN :cats
            """)
            .setParameter("uc", userCardId)
            .setParameter("from", win.start)
            .setParameter("to", win.end)
            .setParameter("cats", categories)
            .getSingleResult();
        return result instanceof BigDecimal bd ? bd : new BigDecimal(result.toString());
    }

    private PeriodWindow computeWindow(CapPeriod period, LocalDate asOf) {
        return switch (period) {
            case CALENDAR_YEAR -> new PeriodWindow(
                asOf.withDayOfYear(1),
                asOf.withMonth(12).withDayOfMonth(31));
            case QUARTER -> {
                int q = (asOf.getMonthValue() - 1) / 3;
                int startMonth = q * 3 + 1;
                LocalDate start = asOf.withMonth(startMonth).withDayOfMonth(1);
                LocalDate end = start.plusMonths(3).minusDays(1);
                yield new PeriodWindow(start, end);
            }
            case ANNIVERSARY_YEAR, BILLING_CYCLE, NONE ->
                // v1 fallback: treat as calendar year. ANNIVERSARY_YEAR/BILLING_CYCLE land in Phase 2 when needed.
                new PeriodWindow(asOf.withDayOfYear(1),
                                 asOf.withMonth(12).withDayOfMonth(31));
        };
    }

    private String label(CapPeriod period) {
        return switch (period) {
            case CALENDAR_YEAR -> "this year";
            case QUARTER -> "this quarter";
            case ANNIVERSARY_YEAR -> "this anniversary year";
            case BILLING_CYCLE -> "this billing cycle";
            case NONE -> null;
        };
    }

    private record PeriodWindow(LocalDate start, LocalDate end) {}
}
