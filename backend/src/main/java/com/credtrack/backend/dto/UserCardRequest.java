package com.credtrack.backend.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter @NoArgsConstructor
public class UserCardRequest {

    // userId is resolved server-side from the Bearer token — never sent by the client
    private Long cardProductId;

    // Card identity
    private String nickname;
    private String lastFour;
    private String cardHolderName;

    // Financials
    private BigDecimal creditLimit;
    private BigDecimal currentBalance;
    private BigDecimal statementBalance;
    private BigDecimal minimumDue;

    // Key dates
    private LocalDate paymentDueDate;
    private LocalDate lastPaymentDate;
    private BigDecimal lastPaymentAmount;

    // Status
    private Boolean isActive;
}
