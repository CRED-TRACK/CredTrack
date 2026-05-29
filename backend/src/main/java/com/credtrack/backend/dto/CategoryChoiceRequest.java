package com.credtrack.backend.dto;

import lombok.Getter;
import lombok.Setter;

@Getter @Setter
public class CategoryChoiceRequest {
    private String choiceKind;
    private String canonicalCategory;
}
