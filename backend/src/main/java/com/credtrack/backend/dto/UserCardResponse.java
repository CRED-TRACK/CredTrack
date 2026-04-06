package com.credtrack.backend.dto;

import com.credtrack.backend.entity.UserCard;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Getter @Builder
public class UserCardResponse {

    private Long   id;
    private String userId;

    // Card product snapshot (so the app doesn't need a second request)
    private Long   cardProductId;
    private String productName;
    private String issuerName;
    private String bankKey;
    private String brand;
    private String faceColor;
    private String gradientEnd;
    private String textColor;

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
    private LocalDate  paymentDueDate;
    private LocalDate  lastPaymentDate;
    private BigDecimal lastPaymentAmount;

    // Meta
    private Boolean       isActive;
    private LocalDateTime addedAt;
    private LocalDateTime updatedAt;

    public static UserCardResponse from(UserCard uc) {
        var cp = uc.getCardProduct();
        return UserCardResponse.builder()
                .id(uc.getId())
                .userId(uc.getUser().getId())
                .cardProductId(cp != null ? cp.getId() : null)
                .productName(cp != null ? cp.getProductName() : null)
                .issuerName(cp != null ? cp.getIssuerName() : null)
                .bankKey(cp != null ? cp.getBankKey() : null)
                .brand(cp != null ? cp.getBrand() : null)
                .faceColor(cp != null ? cp.getFaceColor() : null)
                .gradientEnd(cp != null ? cp.getGradientEnd() : null)
                .textColor(cp != null ? cp.getTextColor() : null)
                .nickname(uc.getNickname())
                .lastFour(uc.getLastFour())
                .cardHolderName(uc.getCardHolderName())
                .creditLimit(uc.getCreditLimit())
                .currentBalance(uc.getCurrentBalance())
                .statementBalance(uc.getStatementBalance())
                .minimumDue(uc.getMinimumDue())
                .paymentDueDate(uc.getPaymentDueDate())
                .lastPaymentDate(uc.getLastPaymentDate())
                .lastPaymentAmount(uc.getLastPaymentAmount())
                .isActive(uc.getIsActive())
                .addedAt(uc.getAddedAt())
                .updatedAt(uc.getUpdatedAt())
                .build();
    }
}
