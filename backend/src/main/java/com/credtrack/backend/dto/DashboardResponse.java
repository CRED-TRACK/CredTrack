package com.credtrack.backend.dto;

import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter @Builder
public class DashboardResponse {

    private LocalDate asOf;
    private LocalDate fiscalYearStart;
    private String currentQuarter;
    private List<String> categoriesActive;
    private List<CategoryRanking> categoryRankings;
    private List<DashboardCardSection> cards;

    @Getter @Builder
    public static class CategoryRanking {
        private String category;
        private String displayName;
        private Long bestUserCardId;
        private Integer bestRateBps;
        private BigDecimal capRemaining;
        private String capPeriodLabel;
    }
}
