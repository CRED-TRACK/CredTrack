package com.credtrack.backend.dto;

import lombok.*;
import java.util.List;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class CardSpendingResponse {

    private double totalSpend;
    private int    totalTransactions;
    private int    months;
    private List<CardSummary>      cards;
    private List<CategoryCluster>  categories;
    private List<MonthlyBreakdown> monthlyBreakdown;

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class CardSummary {
        private Long   cardId;
        private String bankKey;
        private String lastFour;
        private double totalSpend;
        private int    transactionCount;
    }

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class CategoryCluster {
        private String cluster;
        private double amount;
        private double percentage;
        private int    transactionCount;
    }

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class MonthlyBreakdown {
        private String          month;
        private double          totalSpend;
        private List<CardMonthData> cards;
    }

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class CardMonthData {
        private Long   cardId;
        private String bankKey;
        private String lastFour;
        private double amount;
    }
}
