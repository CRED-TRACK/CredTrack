package com.credtrack.backend.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Payload sent by the AI agent to POST /internal/payments.
 * Parsed from a Chase "Your credit card payment is scheduled" email.
 */
@Data
public class PaymentCreateRequest {
    private String     userId;
    private String     gmailMessageId;  // payment email's message ID — dedup key
    private String     cardLastFour;
    private String     bank;            // e.g. "CHASE"
    private BigDecimal amount;
    private LocalDate  paymentDate;     // "Payment authorized on" date from email
    private LocalDate  effectiveDate;   // "Effective date" from email
}
