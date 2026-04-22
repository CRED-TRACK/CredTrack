package com.credtrack.backend.dto;

import lombok.Data;

@Data
public class UserUtilityAccountRequest {
    private String billerName;       // EVERSOURCE or NATIONAL_GRID
    private String accountLastFour;  // last 4 digits of utility account number
}
