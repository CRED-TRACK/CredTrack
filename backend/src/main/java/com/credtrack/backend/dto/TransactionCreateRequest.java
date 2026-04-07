package com.credtrack.backend.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter @NoArgsConstructor
public class TransactionCreateRequest {

    private String     userId;
    private String     gmailMessageId;
    private String     merchantName;
    private String     merchantCategory;
    private BigDecimal amount;
    private String     currency;
    private LocalDate  transactionDate;
    private LocalDate  postedDate;
    private String     cardLastFour;
    private String     transactionType;
    private String     status;
    private String     description;
    private String     llmConfidence;
    private String     extractionModel;
    private String     bankKey;
}
