package com.credtrack.backend.dto;

import lombok.*;
import java.util.List;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class BillExtractionResult {

    /** AWAITING_CONFIRMATION | WRONG_STATEMENT | FAILED */
    private String status;
    private List<String> validationIssues;
    private String failureReason;

    // Extracted bill data
    private String billerName;
    private String accountLastFour;
    private String billDate;             // YYYY-MM-DD
    private String billingPeriodStart;   // YYYY-MM-DD
    private String billingPeriodEnd;     // YYYY-MM-DD
    private Double amountDue;
    private String dueDate;              // YYYY-MM-DD
}
