package com.credtrack.backend.dto;

import lombok.*;
import java.util.List;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class StatementExtractionResult {

    /** AWAITING_CONFIRMATION | WRONG_STATEMENT | FAILED */
    private String status;
    private List<String> validationIssues;
    private String failureReason;

    // Extracted statement header
    private String bank;
    private String cardLastFour;
    private String statementDate;        // YYYY-MM-DD
    private String billingPeriodStart;   // YYYY-MM-DD
    private String billingPeriodEnd;     // YYYY-MM-DD
    private Double statementBalance;
    private Double minimumDue;
    private String dueDate;              // YYYY-MM-DD

    private List<ExtractedTransaction> transactions;

    @Data @Builder @NoArgsConstructor @AllArgsConstructor
    public static class ExtractedTransaction {
        private String date;            // YYYY-MM-DD
        private String merchantName;
        private Double amount;
        private String type;            // PURCHASE | PAYMENT | CREDIT
    }
}
