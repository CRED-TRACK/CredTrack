package com.credtrack.backend.dto;

import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.util.List;

@Getter @Builder
public class TransactionSummaryResponse {

    private String     month;
    private BigDecimal totalSpent;
    private long       transactionCount;

    private List<CategorySummary> byCategory;
    private List<CardSummary>     byCard;

    @Getter @Builder
    public static class CategorySummary {
        private String     category;
        private BigDecimal totalSpent;
        private long       count;
    }

    @Getter @Builder
    public static class CardSummary {
        private Long       userCardId;
        private BigDecimal totalSpent;
        private long       count;
    }
}
