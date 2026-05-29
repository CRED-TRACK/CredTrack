package com.credtrack.backend.dto;

import com.credtrack.backend.entity.CanonicalCategory;
import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter @Builder
public class CategoryDTO {
    private String code;
    private String displayName;
    private String iconHint;
    private List<String> commonMerchants;

    public static CategoryDTO from(CanonicalCategory cat) {
        return CategoryDTO.builder()
            .code(cat.code())
            .displayName(cat.displayName())
            .iconHint(cat.iconHint())
            .commonMerchants(cat.commonMerchants())
            .build();
    }
}
