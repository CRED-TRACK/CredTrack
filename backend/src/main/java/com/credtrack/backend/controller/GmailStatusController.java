package com.credtrack.backend.controller;

import com.credtrack.backend.dto.GmailStatusResponse;
import com.credtrack.backend.entity.GmailCredential;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.repository.GmailCredentialRepository;
import com.credtrack.backend.repository.UserRepository;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.GmailOAuthService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.net.URI;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/gmail")
public class GmailStatusController {

    private static final Logger log = LoggerFactory.getLogger(GmailStatusController.class);

    private final GmailCredentialRepository credRepo;
    private final UserRepository            userRepo;
    private final FirebaseService           firebaseService;
    private final GmailOAuthService         oauthService;

    @Value("${app.deep-link.gmail-connected:credtrack://gmail/connected}")
    private String gmailConnectedDeepLink;

    public GmailStatusController(GmailCredentialRepository credRepo,
                                 UserRepository userRepo,
                                 FirebaseService firebaseService,
                                 GmailOAuthService oauthService) {
        this.credRepo        = credRepo;
        this.userRepo        = userRepo;
        this.firebaseService = firebaseService;
        this.oauthService    = oauthService;
    }

    private String resolveUid(String authHeader) {
        return firebaseService.verifyToken(authHeader.replace("Bearer ", "")).getUid();
    }

    @GetMapping("/status")
    public ResponseEntity<GmailStatusResponse> status(
            @RequestHeader("Authorization") String authHeader) {
        String uid = resolveUid(authHeader);
        Optional<GmailCredential> cred = credRepo.findByUser_Id(uid);
        log.info("gmail_status event=checked uid={} connected={}", uid, cred.isPresent());
        return ResponseEntity.ok(GmailStatusResponse.builder()
                .connected(cred.isPresent())
                .gmailAddress(cred.map(GmailCredential::getGmailAddress).orElse(null))
                .lastSyncedAt(cred.map(GmailCredential::getLastSyncedAt).orElse(null))
                .build());
    }

    @GetMapping("/oauth/authorize")
    public ResponseEntity<Map<String, String>> authorize(
            @RequestHeader("Authorization") String authHeader) {
        String uid     = resolveUid(authHeader);
        String authUrl = oauthService.buildAuthUrl(uid);
        log.info("gmail_oauth event=authorize uid={}", uid);
        return ResponseEntity.ok(Map.of("auth_url", authUrl));
    }

    @GetMapping("/oauth/callback")
    public ResponseEntity<Void> callback(
            @RequestParam(required = false) String code,
            @RequestParam(required = false) String state,
            @RequestParam(required = false) String error) {

        if (error != null || code == null || state == null) {
            log.warn("gmail_oauth event=callback_rejected error={} code_present={} state_present={}",
                    error, code != null, state != null);
            return ResponseEntity.status(HttpStatus.FOUND)
                    .location(URI.create("credtrack://gmail/error"))
                    .build();
        }

        try {
            String uid = oauthService.verifyState(state);
            log.info("gmail_oauth event=callback_verified uid={}", uid);

            GmailOAuthService.TokenResponse tokens = oauthService.exchangeCode(code);
            log.info("gmail_oauth event=token_exchanged uid={} has_refresh_token={}",
                    uid, tokens.refreshToken() != null && !tokens.refreshToken().isBlank());

            User user = userRepo.findById(uid)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
            log.info("gmail_oauth event=user_found uid={} email={}", uid, user.getEmail());

            GmailCredential cred = credRepo.findByUser_Id(uid)
                    .orElseGet(() -> GmailCredential.builder().user(user).build());

            cred.setEncryptedRefreshToken(oauthService.encrypt(tokens.refreshToken()));
            cred.setAccessToken(tokens.accessToken());
            cred.setTokenExpiryUtc(tokens.expiryUtc());
            credRepo.save(cred);
            log.info("gmail_oauth event=credential_saved uid={} expiry_utc={}", uid, tokens.expiryUtc());

            return ResponseEntity.status(HttpStatus.FOUND)
                    .location(URI.create(gmailConnectedDeepLink))
                    .build();

        } catch (Exception e) {
            log.error("gmail_oauth event=callback_failed error={}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.FOUND)
                    .location(URI.create("credtrack://gmail/error"))
                    .build();
        }
    }

    @DeleteMapping("/disconnect")
    public ResponseEntity<Void> disconnect(
            @RequestHeader("Authorization") String authHeader) {
        String uid = resolveUid(authHeader);
        credRepo.findByUser_Id(uid).ifPresent(credRepo::delete);
        log.info("gmail_oauth event=disconnected uid={}", uid);
        return ResponseEntity.noContent().build();
    }
}
