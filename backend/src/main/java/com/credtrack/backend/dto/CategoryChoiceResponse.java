package com.credtrack.backend.dto;

import com.credtrack.backend.entity.UserCardCategoryChoice;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDate;

@Getter @Builder
public class CategoryChoiceResponse {
    private Long id;
    private Long userCardId;
    private String choiceKind;
    private String canonicalCategory;
    private LocalDate effectiveFrom;
    private LocalDate effectiveTo;

    public static CategoryChoiceResponse from(UserCardCategoryChoice c) {
        return CategoryChoiceResponse.builder()
            .id(c.getId())
            .userCardId(c.getUserCard().getId())
            .choiceKind(c.getChoiceKind())
            .canonicalCategory(c.getCanonicalCategory())
            .effectiveFrom(c.getEffectiveFrom())
            .effectiveTo(c.getEffectiveTo())
            .build();
    }
}
