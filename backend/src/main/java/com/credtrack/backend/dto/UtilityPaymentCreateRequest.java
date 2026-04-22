package com.credtrack.backend.dto;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Sent by the AI agent to POST /internal/utility-payments. */
@Data
public class UtilityPaymentCreateRequest {
    private String     userId;
    private String     gmailMessageId;
    private String     billerName;       // EVERSOURCE or NATIONAL_GRID
    private String     accountLastFour;
    private BigDecimal paymentAmount;
    private LocalDate  paymentDate;
}
