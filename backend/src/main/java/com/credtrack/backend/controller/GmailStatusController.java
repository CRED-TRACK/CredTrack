package com.credtrack.backend.controller;

import com.credtrack.backend.dto.GmailStatusResponse;
import com.credtrack.backend.entity.GmailCredential;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.repository.GmailCredentialRepository;
import com.credtrack.backend.repository.UserRepository;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.GmailOAuthService;
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

    // ── Status ────────────────────────────────────────────────────────────────

    /**
     * GET /gmail/status
     * Returns whether the authenticated user has connected their Gmail.
     */
    @GetMapping("/status")
    public ResponseEntity<GmailStatusResponse> status(
            @RequestHeader("Authorization") String authHeader) {
        String uid = resolveUid(authHeader);
        Optional<GmailCredential> cred = credRepo.findByUser_Id(uid);
        return ResponseEntity.ok(GmailStatusResponse.builder()
                .connected(cred.isPresent())
                .gmailAddress(cred.map(GmailCredential::getGmailAddress).orElse(null))
                .lastSyncedAt(cred.map(GmailCredential::getLastSyncedAt).orElse(null))
                .build());
    }

    // ── OAuth ─────────────────────────────────────────────────────────────────

    /**
     * GET /gmail/oauth/authorize
     * Returns the Google OAuth consent URL. iOS opens this in ASWebAuthenticationSession.
     */
    @GetMapping("/oauth/authorize")
    public ResponseEntity<Map<String, String>> authorize(
            @RequestHeader("Authorization") String authHeader) {
        String uid     = resolveUid(authHeader);
        String authUrl = oauthService.buildAuthUrl(uid);
        return ResponseEntity.ok(Map.of("auth_url", authUrl));
    }

    /**
     * GET /gmail/oauth/callback?code=...&state=...
     * Google redirects here after user grants (or denies) consent.
     * NOT Firebase-protected — Google calls this directly.
     * On success: stores encrypted tokens, redirects to credtrack://gmail/connected
     * On error:   redirects to credtrack://gmail/error
     */
    @GetMapping("/oauth/callback")
    public ResponseEntity<Void> callback(
            @RequestParam(required = false) String code,
            @RequestParam(required = false) String state,
            @RequestParam(required = false) String error) {

        // User denied consent
        if (error != null || code == null || state == null) {
            return ResponseEntity.status(HttpStatus.FOUND)
                    .location(URI.create("credtrack://gmail/error"))
                    .build();
        }

        try {
            // Verify HMAC-signed state → extract uid
            String uid = oauthService.verifyState(state);

            // Exchange code for tokens
            GmailOAuthService.TokenResponse tokens = oauthService.exchangeCode(code);

            // Load user
            User user = userRepo.findById(uid)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

            // Upsert GmailCredential
            GmailCredential cred = credRepo.findByUser_Id(uid)
                    .orElseGet(() -> GmailCredential.builder().user(user).build());

            cred.setEncryptedRefreshToken(oauthService.encrypt(tokens.refreshToken()));
            cred.setAccessToken(tokens.accessToken());
            cred.setTokenExpiryUtc(tokens.expiryUtc());
            credRepo.save(cred);

            return ResponseEntity.status(HttpStatus.FOUND)
                    .location(URI.create(gmailConnectedDeepLink))
                    .build();

        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.FOUND)
                    .location(URI.create("credtrack://gmail/error"))
                    .build();
        }
    }

    /**
     * DELETE /gmail/disconnect
     * Removes the stored Gmail credential for the authenticated user.
     */
    @DeleteMapping("/disconnect")
    public ResponseEntity<Void> disconnect(
            @RequestHeader("Authorization") String authHeader) {
        String uid = resolveUid(authHeader);
        credRepo.findByUser_Id(uid).ifPresent(credRepo::delete);
        return ResponseEntity.noContent().build();
    }
}
