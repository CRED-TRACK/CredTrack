package com.credtrack.backend.controller;

import com.credtrack.backend.dto.CardStatementResponse;
import com.credtrack.backend.dto.GmailCredentialRequest;
import com.credtrack.backend.dto.StatementCreateRequest;
import com.credtrack.backend.dto.TransactionCreateRequest;
import com.credtrack.backend.dto.TransactionResponse;
import com.credtrack.backend.dto.UserCardResponse;
import com.credtrack.backend.entity.GmailCredential;
import com.credtrack.backend.repository.GmailCredentialRepository;
import com.credtrack.backend.service.StatementInternalService;
import com.credtrack.backend.service.TransactionInternalService;
import com.credtrack.backend.service.UserCardService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
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
    private final StatementInternalService   statementService;
    private final UserCardService            userCardService;
    private final GmailCredentialRepository  gmailCredentialRepo;

    public InternalController(TransactionInternalService internalService,
                              StatementInternalService statementService,
                              UserCardService userCardService,
                              GmailCredentialRepository gmailCredentialRepo) {
        this.internalService     = internalService;
        this.statementService    = statementService;
        this.userCardService     = userCardService;
        this.gmailCredentialRepo = gmailCredentialRepo;
    }

    /**
     * GET /internal/gmail-credentials
     * AI agent calls this to get all users with Gmail connected for polling.
     * Returns userId, accessToken, tokenExpiryUtc, gmailAddress, historyId.
     */
    @GetMapping("/gmail-credentials")
    public ResponseEntity<List<Map<String, Object>>> getAllGmailCredentials() {
        List<Map<String, Object>> result = gmailCredentialRepo.findAll().stream()
                .filter(c -> c.getAccessToken() != null)
                .map(c -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("userId",        c.getUser().getId());
                    m.put("accessToken",   c.getAccessToken());
                    m.put("tokenExpiryUtc", c.getTokenExpiryUtc() != null
                            ? c.getTokenExpiryUtc().toString() : null);
                    m.put("gmailAddress",  c.getGmailAddress());
                    m.put("historyId",     c.getHistoryId() != null
                            ? Long.parseLong(c.getHistoryId()) : null);
                    return m;
                })
                .toList();
        return ResponseEntity.ok(result);
    }

    /**
     * POST /internal/statements
     * AI agent writes an extracted statement.
     * Returns 201 on success, 409 if gmail_message_id already exists.
     */
    @PostMapping("/statements")
    public ResponseEntity<CardStatementResponse> createStatement(
            @RequestBody StatementCreateRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(statementService.create(req));
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
