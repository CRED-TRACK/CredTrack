package com.credtrack.backend.dto;

import lombok.Builder;
import lombok.Getter;

@Getter @Builder
public class WarningDTO {
    private String code;
    private String message;
}
