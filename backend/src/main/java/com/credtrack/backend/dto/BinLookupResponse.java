package com.credtrack.backend.dto;

import com.credtrack.backend.entity.BinRecord;
import com.credtrack.backend.service.IssuerKeyResolver;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class BinLookupResponse {

    // BIN meta
    private Long    bin;
    private String  brand;       // VISA, MASTERCARD, AMEX, DISCOVER …
    private String  type;        // CREDIT, DEBIT, PREPAID
    private String  category;    // CLASSIC, GOLD, PLATINUM …

    // Issuer
    private String  issuerName;   // raw name from BIN data
    private String  bankKey;      // resolved key e.g. "CHASE" — use for /card-products?issuer= and logo
    private String  issuerPhone;
    private String  issuerUrl;
    private String  issuerColor;

    // Country
    private String  countryName;
    private String  isoCode2;
    private String  isoCode3;

    public static BinLookupResponse from(BinRecord record) {
        // Prefer the joined Issuer entity fields; fall back to the raw columns on BinRecord
        boolean hasIssuer = record.getIssuer() != null;

        return BinLookupResponse.builder()
                .bin(record.getBin())
                .brand(record.getBrand())
                .type(record.getType())
                .category(record.getCategory())
                .issuerName(hasIssuer ? record.getIssuer().getIssuerName() : null)
                .bankKey(IssuerKeyResolver.resolve(
                        hasIssuer ? record.getIssuer().getIssuerName() : null))
                .issuerPhone(hasIssuer ? record.getIssuer().getIssuerPhone() : record.getIssuerPhone())
                .issuerUrl(hasIssuer   ? record.getIssuer().getIssuerUrl()   : record.getIssuerUrl())
                .issuerColor(hasIssuer ? record.getIssuer().getColor()       : record.getColor())
                .countryName(record.getCountryName())
                .isoCode2(record.getIsoCode2())
                .isoCode3(record.getIsoCode3())
                .build();
    }
}
