package com.credtrack.backend.dto;

import com.credtrack.backend.entity.UserUtilityAccount;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class UserUtilityAccountResponse {
    private Long          id;
    private String        billerName;
    private String        accountLastFour;
    private LocalDateTime createdAt;

    public static UserUtilityAccountResponse from(UserUtilityAccount a) {
        return UserUtilityAccountResponse.builder()
                .id(a.getId())
                .billerName(a.getBillerName())
                .accountLastFour(a.getAccountLastFour())
                .createdAt(a.getCreatedAt())
                .build();
    }
}
