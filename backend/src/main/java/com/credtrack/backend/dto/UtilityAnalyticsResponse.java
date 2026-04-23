package com.credtrack.backend.dto;

import lombok.*;
import java.util.List;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class UtilityAnalyticsResponse {

    private List<AccountSummary> accounts;

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class AccountSummary {
        private String billerName;
        private String accountLastFour;
        private List<BillPoint> bills;      // oldest-first for chart rendering
        private double   averageAmount;
        private Double   latestAmount;
        private Double   changePercent;     // vs prior bill; null when only one bill exists
    }

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class BillPoint {
        private String billDate;            // YYYY-MM-DD
        private double amountDue;
    }
}
