package com.credtrack.backend.controller;

import com.credtrack.backend.dto.GmailCredentialRequest;
import com.credtrack.backend.dto.TransactionCreateRequest;
import com.credtrack.backend.dto.TransactionResponse;
import com.credtrack.backend.dto.UserCardResponse;
import com.credtrack.backend.entity.GmailCredential;
import com.credtrack.backend.service.TransactionInternalService;
import com.credtrack.backend.service.UserCardService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * Internal REST API — called only by the AI agent project.
 * Protected by X-Service-Key header (validated by ServiceKeyInterceptor).
 * NOT Firebase-protected.
 */
@RestController
@RequestMapping("/internal")
public class InternalController {

    private final TransactionInternalService internalService;
    private final UserCardService            userCardService;

    public InternalController(TransactionInternalService internalService,
                              UserCardService userCardService) {
        this.internalService = internalService;
        this.userCardService = userCardService;
    }

    /**
     * POST /internal/transactions
     * AI project writes an extracted transaction.
     * Returns 201 on success, 409 if gmail_message_id already exists.
     */
    @PostMapping("/transactions")
    public ResponseEntity<TransactionResponse> createTransaction(
            @RequestBody TransactionCreateRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(internalService.create(req));
    }

    /**
     * GET /internal/users/{userId}/cards
     * AI project reads a user's registered cards to reconcile card_last_four.
     */
    @GetMapping("/users/{userId}/cards")
    public ResponseEntity<List<UserCardResponse>> getUserCards(
            @PathVariable String userId) {
        return ResponseEntity.ok(userCardService.getCardsForUser(userId, false));
    }

    /**
     * POST /internal/gmail-credentials
     * AI project upserts Gmail OAuth tokens after the OAuth callback.
     */
    @PostMapping("/gmail-credentials")
    public ResponseEntity<Map<String, Object>> upsertCredential(
            @RequestBody GmailCredentialRequest req) {
        GmailCredential cred = internalService.upsertCredential(req);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("id", cred.getId(), "userId", cred.getUser().getId()));
    }

    /**
     * PATCH /internal/gmail-credentials/{userId}
     * AI project updates historyId, accessToken, tokenExpiry, or lastSyncedAt
     * after each polling cycle or token refresh.
     */
    @PatchMapping("/gmail-credentials/{userId}")
    public ResponseEntity<Map<String, Object>> patchCredential(
            @PathVariable String userId,
            @RequestBody GmailCredentialRequest req) {
        req.setUserId(userId);
        GmailCredential cred = internalService.upsertCredential(req);
        return ResponseEntity.ok(Map.of("id", cred.getId(), "userId", cred.getUser().getId()));
    }
}
