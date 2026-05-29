package com.credtrack.backend.dto;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter @Builder
public class DashboardCardSection {
    private Long userCardId;
    private String productName;
    private String issuerName;
    private String bankKey;
    private String faceColor;
    private String gradientEnd;
    private String textColor;
    private String lastFour;
    private String nickname;

    private List<RewardRuleDTO> rewards;
    private List<WarningDTO> warnings;
}
