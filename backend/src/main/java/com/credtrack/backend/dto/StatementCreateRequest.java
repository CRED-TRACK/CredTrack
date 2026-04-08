package com.credtrack.backend.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Payload sent by the AI agent to POST /internal/statements.
 */
@Data
public class StatementCreateRequest {
    private String     userId;
    private String     gmailMessageId;
    private String     cardLastFour;       // last 4 digits extracted from email
    private String     bank;               // discover | chase | amex | bofa
    private LocalDate  statementDate;
    private BigDecimal statementBalance;
    private BigDecimal minimumPaymentDue;
    private LocalDate  dueDate;
    private String     viewStatementUrl;
    private String     makePaymentUrl;
    private Double     confidence;
}
