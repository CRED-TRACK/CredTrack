package com.credtrack.backend.dto;

import com.credtrack.backend.entity.Transaction;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Builder
public class TransactionResponse {

    private Long   id;
    private String userId;
    private Long   userCardId;

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

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static TransactionResponse from(Transaction t) {
        return TransactionResponse.builder()
                .id(t.getId())
                .userId(t.getUser().getId())
                .userCardId(t.getUserCard() != null ? t.getUserCard().getId() : null)
                .merchantName(t.getMerchantName())
                .merchantCategory(t.getMerchantCategory())
                .amount(t.getAmount())
                .currency(t.getCurrency())
                .transactionDate(t.getTransactionDate())
                .postedDate(t.getPostedDate())
                .cardLastFour(t.getCardLastFour())
                .transactionType(t.getTransactionType())
                .status(t.getStatus())
                .description(t.getDescription())
                .llmConfidence(t.getLlmConfidence())
                .extractionModel(t.getExtractionModel())
                .bankKey(t.getBankKey())
                .createdAt(t.getCreatedAt())
                .updatedAt(t.getUpdatedAt())
                .build();
    }
}
