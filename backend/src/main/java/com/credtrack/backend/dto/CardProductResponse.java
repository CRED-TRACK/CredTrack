package com.credtrack.backend.dto;

import com.credtrack.backend.entity.CardProduct;
import lombok.Builder;
import lombok.Getter;

@Getter @Builder
public class CardProductResponse {

    private Long   id;
    private String issuerName;
    private String bankKey;       // stable key e.g. "CHASE" — app uses this for logo selection
    private String productName;
    private String officialName;
    private String brand;
    private String faceColor;
    private String gradientEnd;
    private String textColor;

    public static CardProductResponse from(CardProduct p) {
        return CardProductResponse.builder()
                .id(p.getId())
                .issuerName(p.getIssuerName())
                .bankKey(p.getBankKey())
                .productName(p.getProductName())
                .officialName(p.getOfficialName())
                .brand(p.getBrand())
                .faceColor(p.getFaceColor())
                .gradientEnd(p.getGradientEnd())
                .textColor(p.getTextColor())
                .build();
    }
}
