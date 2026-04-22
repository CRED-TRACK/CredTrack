package com.credtrack.backend.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Sent by the AI agent to POST /internal/utility-bills. */
@Data
public class UtilityBillCreateRequest {
    private String     userId;
    private String     gmailMessageId;
    private String     billerName;        // EVERSOURCE or NATIONAL_GRID
    private String     accountLastFour;
    private LocalDate  billDate;
    private LocalDate  billingPeriodStart;
    private LocalDate  billingPeriodEnd;
    private BigDecimal amountDue;
    private LocalDate  dueDate;
}
