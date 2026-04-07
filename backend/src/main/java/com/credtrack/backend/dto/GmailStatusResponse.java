package com.credtrack.backend.dto;

import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter @Builder
public class GmailStatusResponse {
    private boolean       connected;
    private String        gmailAddress;
    private LocalDateTime lastSyncedAt;
}
