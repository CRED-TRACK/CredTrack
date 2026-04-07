package com.credtrack.backend.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter @Setter @NoArgsConstructor
public class TransactionUpdateRequest {
    private String merchantName;
    private String merchantCategory;
    private Long   userCardId;
    private String status;
}
