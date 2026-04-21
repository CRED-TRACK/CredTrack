package com.credtrack.backend.dto;

import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Getter @Builder
public class UnbilledSpendResponse {

    private Long              userCardId;
    private LocalDate         since;          // last statement closing date (null = no statements yet)
    private BigDecimal        unbilledTotal;
    private List<TransactionResponse> transactions;
}
