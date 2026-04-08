package com.credtrack.backend.dto;

import com.credtrack.backend.entity.CardStatement;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Builder
public class CardStatementResponse {

    private Long      id;
    private Long      userCardId;
    private String    cardLastFour;
    private String    bank;
    private LocalDate statementDate;
    private BigDecimal statementBalance;
    private BigDecimal minimumDue;
    private LocalDate dueDate;
    private String    viewStatementUrl;
    private String    makePaymentUrl;
    private LocalDateTime createdAt;

    public static CardStatementResponse from(CardStatement s) {
        return CardStatementResponse.builder()
                .id(s.getId())
                .userCardId(s.getUserCard() != null ? s.getUserCard().getId() : null)
                .cardLastFour(s.getCardLastFour())
                .bank(s.getBank())
                .statementDate(s.getStatementDate())
                .statementBalance(s.getStatementBalance())
                .minimumDue(s.getMinimumDue())
                .dueDate(s.getDueDate())
                .viewStatementUrl(s.getViewStatementUrl())
                .makePaymentUrl(s.getMakePaymentUrl())
                .createdAt(s.getCreatedAt())
                .build();
    }
}
