package com.credtrack.backend.dto;

import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter @Builder
public class RewardRuleDTO {
    private String canonicalCategory;
    private String displayName;
    private String iconHint;

    /** Headline rate from the rule (e.g. 300 = 3.00%) — ignores caps/choice. */
    private Integer rateBps;

    /** Actual rate the user earns today (post cap + choice resolution). */
    private Integer effectiveRateBps;

    private Integer baseRateBps;
    private BigDecimal capAmount;
    private String capPeriod;
    private String capPeriodLabel;
    private String capGroupKey;

    private BigDecimal spentInPeriod;
    private BigDecimal capRemaining;
    private boolean capExhausted;

    private boolean requiresUserChoice;
    private String userChoiceActive;

    private String channelRestriction;
    private List<String> exclusions;
    private String notes;

    private String source;
    private BigDecimal sourceConfidence;
    private Long sourceDocumentId;

    private LocalDate effectiveFrom;
    private LocalDate effectiveTo;
}
