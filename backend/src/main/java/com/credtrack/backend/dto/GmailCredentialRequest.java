package com.credtrack.backend.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter @Setter @NoArgsConstructor
public class GmailCredentialRequest {

    private String        userId;
    private String        encryptedRefreshToken;
    private String        accessToken;
    private LocalDateTime tokenExpiryUtc;
    private String        gmailAddress;
    private String        historyId;
    private LocalDateTime lastSyncedAt;
}
