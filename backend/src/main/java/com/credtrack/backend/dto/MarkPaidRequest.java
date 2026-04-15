package com.credtrack.backend.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;

/**
 * Body for POST /statements/{id}/mark-paid.
 * paymentDate is optional — defaults to today (UTC) if omitted.
 */
@Getter @Setter @NoArgsConstructor
public class MarkPaidRequest {

    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate paymentDate;
}
