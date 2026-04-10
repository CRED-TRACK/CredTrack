package com.credtrack.backend.controller;

import com.credtrack.backend.dto.CardStatementResponse;
import com.credtrack.backend.dto.GmailCredentialRequest;
import com.credtrack.backend.dto.StatementCreateRequest;
import com.credtrack.backend.dto.TransactionCreateRequest;
import com.credtrack.backend.dto.TransactionResponse;
import com.credtrack.backend.dto.UserCardResponse;
import com.credtrack.backend.entity.GmailCredential;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.GmailCredentialRepository;
import com.credtrack.backend.repository.UserCardRepository;
import com.credtrack.backend.service.GmailOAuthService;
import com.credtrack.backend.service.StatementInternalService;
import com.credtrack.backend.service.TransactionInternalService;
import com.credtrack.backend.service.UserCardService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
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

    private static final Logger log = LoggerFactory.getLogger(InternalController.class);

    private final TransactionInternalService internalService;
    private final StatementInternalService   statementService;
    private final UserCardService            userCardService;
    private final GmailCredentialRepository  gmailCredentialRepo;
    private final UserCardRepository         userCardRepo;
    private final GmailOAuthService          gmailOAuthService;
    private final CardStatementRepository    statementRepo;

    public InternalController(TransactionInternalService internalService,
                              StatementInternalService statementService,
                              UserCardService userCardService,
                              GmailCredentialRepository gmailCredentialRepo,
                              UserCardRepository userCardRepo,
                              GmailOAuthService gmailOAuthService,
                              CardStatementRepository statementRepo) {
        this.internalService     = internalService;
        this.statementService    = statementService;
        this.userCardService     = userCardService;
        this.gmailCredentialRepo = gmailCredentialRepo;
        this.userCardRepo        = userCardRepo;
        this.gmailOAuthService   = gmailOAuthService;
        this.statementRepo       = statementRepo;
    }

    /**
     * GET /internal/gmail-credentials
     * AI agent calls this at the start of every poll cycle.
     * Returns each connected user's OAuth tokens + their registered cards
     * (lastFour + bankKey) so the agent never needs to call the LLM for
     * bank/card identification — it already knows before reading the email.
     */
    @GetMapping("/gmail-credentials")
    @Transactional(readOnly = true)
    public ResponseEntity<List<Map<String, Object>>> getAllGmailCredentials() {
        List<Map<String, Object>> result = gmailCredentialRepo.findAll().stream()
                .filter(c -> c.getAccessToken() != null)
                .map(c -> {
                    String userId = c.getUser().getId();

                    // Registered active cards for this user
                    List<Map<String, Object>> cards =
                            userCardRepo.findByUser_IdAndIsActiveTrueOrderByAddedAtDesc(userId)
                                    .stream()
                                    .map(uc -> {
                                        // Latest statement date for this card (null if never scanned)
                                        var latestStatement = statementRepo
                                                .findTopByUserCard_IdOrderByStatementDateDesc(uc.getId());

                                        Map<String, Object> card = new HashMap<>();
                                        card.put("cardId",            uc.getId());
                                        card.put("lastFour",          uc.getLastFour());
                                        card.put("bankKey",           uc.getCardProduct().getBankKey());
                                        card.put("gmailScanComplete", Boolean.TRUE.equals(uc.getGmailScanComplete()));
                                        card.put("lastStatementDate", latestStatement
                                                .map(s -> s.getStatementDate() != null
                                                        ? s.getStatementDate().toString() : null)
                                                .orElse(null));
                                        return card;
                                    })
                                    .toList();

                    Map<String, Object> m = new HashMap<>();
                    m.put("userId",        userId);
                    m.put("accessToken",   c.getAccessToken());
                    m.put("tokenExpiryUtc", c.getTokenExpiryUtc() != null
                            ? c.getTokenExpiryUtc().toString() : null);
                    m.put("gmailAddress",  c.getGmailAddress());
                    m.put("historyId",     c.getHistoryId() != null
                            ? Long.parseLong(c.getHistoryId()) : null);
                    m.put("cards",         cards);
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

    /**
     * POST /internal/gmail-credentials/{userId}/refresh
     * AI project calls this when the stored access token has expired.
     * Backend decrypts the refresh token, calls Google, saves + returns the new access token.
     */
    @PostMapping("/gmail-credentials/{userId}/refresh")
    @Transactional
    public ResponseEntity<Map<String, Object>> refreshToken(@PathVariable String userId) {
        GmailCredential cred = gmailCredentialRepo.findByUser_Id(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "No Gmail credential for user " + userId));

        if (cred.getEncryptedRefreshToken() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No refresh token stored");
        }

        try {
            String refreshToken = gmailOAuthService.decrypt(cred.getEncryptedRefreshToken());
            GmailOAuthService.TokenResponse tokens = gmailOAuthService.refreshAccessToken(refreshToken);

            cred.setAccessToken(tokens.accessToken());
            cred.setTokenExpiryUtc(tokens.expiryUtc());
            gmailCredentialRepo.save(cred);

            log.info("Access token refreshed for user {}, expires {}", userId, tokens.expiryUtc());
            return ResponseEntity.ok(Map.of(
                    "access_token",    tokens.accessToken(),
                    "token_expiry_utc", tokens.expiryUtc().toString()
            ));
        } catch (Exception e) {
            log.error("Token refresh failed for user {}: {}", userId, e.getMessage());
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,
                    "Token refresh failed: " + e.getMessage());
        }
    }

    /**
     * PATCH /internal/cards/{cardId}/last-four
     * AI agent calls this when it discovers that a bank displays more digits than stored
     * (e.g. Amex shows 5 digits "51006" but the user registered "1006").
     * Updates the stored lastFour so future Gmail searches use the exact token.
     */
    @PatchMapping("/cards/{cardId}/last-four")
    @Transactional
    public ResponseEntity<Void> updateCardLastFour(@PathVariable Long cardId,
                                                   @RequestBody Map<String, String> body) {
        String lastFour = body.get("last_four");
        if (lastFour == null || lastFour.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "last_four is required");
        }
        UserCard card = userCardRepo.findById(cardId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Card not found: " + cardId));
        card.setLastFour(lastFour);
        userCardRepo.save(card);
        log.info("Card {} lastFour updated to {}", cardId, lastFour);
        return ResponseEntity.ok().build();
    }

    /**
     * POST /internal/cards/{cardId}/gmail-scan-complete
     * AI agent calls this after finishing the initial historical Gmail scan for a card.
     * Prevents re-scanning old emails on every poll cycle.
     */
    @PostMapping("/cards/{cardId}/gmail-scan-complete")
    @Transactional
    public ResponseEntity<Void> markGmailScanComplete(@PathVariable Long cardId) {
        UserCard card = userCardRepo.findById(cardId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Card not found: " + cardId));
        card.setGmailScanComplete(true);
        userCardRepo.save(card);
        log.info("Gmail scan marked complete for card {}", cardId);
        return ResponseEntity.ok().build();
    }
}
