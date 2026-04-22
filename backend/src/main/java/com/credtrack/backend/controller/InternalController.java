package com.credtrack.backend.controller;

import com.credtrack.backend.dto.CardStatementResponse;
import com.credtrack.backend.dto.GmailCredentialRequest;
import com.credtrack.backend.dto.PaymentCreateRequest;
import com.credtrack.backend.dto.StatementCreateRequest;
import com.credtrack.backend.dto.TransactionCreateRequest;
import com.credtrack.backend.dto.TransactionResponse;
import com.credtrack.backend.dto.UserCardResponse;
import com.credtrack.backend.dto.UtilityBillCreateRequest;
import com.credtrack.backend.dto.UtilityBillResponse;
import com.credtrack.backend.dto.UtilityPaymentCreateRequest;
import com.credtrack.backend.entity.GmailCredential;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.entity.UserUtilityAccount;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.GmailCredentialRepository;
import com.credtrack.backend.repository.UserCardRepository;
import com.credtrack.backend.repository.UserUtilityAccountRepository;
import com.credtrack.backend.repository.UtilityBillRepository;
import com.credtrack.backend.repository.UtilityPaymentRepository;
import com.credtrack.backend.service.GmailOAuthService;
import com.credtrack.backend.service.UtilityBillInternalService;
import com.credtrack.backend.service.UtilityPaymentInternalService;
import com.credtrack.backend.service.PaymentInternalService;
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

    private final TransactionInternalService   internalService;
    private final StatementInternalService     statementService;
    private final PaymentInternalService       paymentService;
    private final UserCardService              userCardService;
    private final GmailCredentialRepository    gmailCredentialRepo;
    private final UserCardRepository           userCardRepo;
    private final GmailOAuthService            gmailOAuthService;
    private final CardStatementRepository      statementRepo;
    private final UtilityBillInternalService    utilityBillService;
    private final UtilityPaymentInternalService utilityPaymentService;
    private final UserUtilityAccountRepository  utilityAccountRepo;
    private final UtilityBillRepository         utilityBillRepo;
    private final UtilityPaymentRepository      utilityPaymentRepo;

    public InternalController(TransactionInternalService internalService,
                              StatementInternalService statementService,
                              PaymentInternalService paymentService,
                              UserCardService userCardService,
                              GmailCredentialRepository gmailCredentialRepo,
                              UserCardRepository userCardRepo,
                              GmailOAuthService gmailOAuthService,
                              CardStatementRepository statementRepo,
                              UtilityBillInternalService utilityBillService,
                              UtilityPaymentInternalService utilityPaymentService,
                              UserUtilityAccountRepository utilityAccountRepo,
                              UtilityBillRepository utilityBillRepo,
                              UtilityPaymentRepository utilityPaymentRepo) {
        this.internalService       = internalService;
        this.statementService      = statementService;
        this.paymentService        = paymentService;
        this.userCardService       = userCardService;
        this.gmailCredentialRepo   = gmailCredentialRepo;
        this.userCardRepo          = userCardRepo;
        this.gmailOAuthService     = gmailOAuthService;
        this.statementRepo         = statementRepo;
        this.utilityBillService    = utilityBillService;
        this.utilityPaymentService = utilityPaymentService;
        this.utilityAccountRepo    = utilityAccountRepo;
        this.utilityBillRepo       = utilityBillRepo;
        this.utilityPaymentRepo    = utilityPaymentRepo;
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
                                        card.put("lastTransactionScanAt",
                                                uc.getLastTransactionScanAt() != null
                                                        ? uc.getLastTransactionScanAt().toString() : null);
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
     * POST /internal/payments
     * AI agent writes an extracted Chase payment confirmation.
     * Marks the oldest unpaid statement for the card as paid.
     * Returns 204 on success, 409 if gmailMessageId already processed.
     */
    @PostMapping("/payments")
    public ResponseEntity<Void> createPayment(@RequestBody PaymentCreateRequest req) {
        paymentService.create(req);
        return ResponseEntity.noContent().build();
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
     * POST /internal/cards/{cardId}/init-complete
     * AI agent calls this after the one-time historical init scan for a card succeeds.
     * Sets gmailScanComplete=true so the coordinator switches the card to normal
     * incremental polling on subsequent poll cycles.
     */
    @PostMapping("/cards/{cardId}/init-complete")
    @Transactional
    public ResponseEntity<Void> markInitComplete(@PathVariable Long cardId) {
        UserCard card = userCardRepo.findById(cardId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Card not found: " + cardId));
        card.setGmailScanComplete(true);
        userCardRepo.save(card);
        log.info("Init scan marked complete for card {}", cardId);
        return ResponseEntity.ok().build();
    }

    /**
     * PATCH /internal/cards/{cardId}/transaction-scan
     * AI agent calls this after completing a transaction email scan for a card.
     * Sets lastTransactionScanAt = now so the coordinator knows when the last scan ran.
     * The scan interval (default 24h, configurable via env) determines when to run next.
     */
    @PatchMapping("/cards/{cardId}/transaction-scan")
    @Transactional
    public ResponseEntity<Void> markTransactionScan(@PathVariable Long cardId) {
        UserCard card = userCardRepo.findById(cardId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Card not found: " + cardId));
        card.setLastTransactionScanAt(LocalDateTime.now());
        userCardRepo.save(card);
        log.info("Transaction scan timestamp updated for card {}", cardId);
        return ResponseEntity.ok().build();
    }

    // ── Utility bills ─────────────────────────────────────────────────────────

    /**
     * GET /internal/utility-accounts
     * AI agent calls this to get all registered utility accounts across all users
     * so it knows which Gmail mailboxes to search for utility bill emails.
     */
    @GetMapping("/utility-accounts")
    @Transactional(readOnly = true)
    public ResponseEntity<List<Map<String, Object>>> getAllUtilityAccounts() {
        List<Map<String, Object>> result = utilityAccountRepo.findAll().stream()
                .map(a -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("id",                   a.getId());
                    m.put("userId",               a.getUser().getId());
                    m.put("billerName",           a.getBillerName());
                    m.put("accountLastFour",      a.getAccountLastFour());
                    m.put("utilityInitComplete",  a.isUtilityInitComplete());
                    return m;
                })
                .toList();
        return ResponseEntity.ok(result);
    }

    /**
     * POST /internal/utility-accounts/{accountId}/init-complete
     * AI agent calls this after the one-time historical init scan completes for a
     * utility account. Sets utilityInitComplete=true so the coordinator switches
     * to the normal incremental poll path on subsequent poll cycles.
     */
    @PostMapping("/utility-accounts/{accountId}/init-complete")
    @Transactional
    public ResponseEntity<Void> markUtilityAccountInitComplete(@PathVariable Long accountId) {
        UserUtilityAccount account = utilityAccountRepo.findById(accountId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Utility account not found: " + accountId));
        account.setUtilityInitComplete(true);
        utilityAccountRepo.save(account);
        log.info("Utility account {} init-complete marked", accountId);
        return ResponseEntity.ok().build();
    }

    /**
     * POST /internal/utility-bills
     * AI agent writes an extracted utility bill.
     * Returns 201 on success, 409 if gmailMessageId already exists.
     */
    @PostMapping("/utility-bills")
    public ResponseEntity<UtilityBillResponse> createUtilityBill(
            @RequestBody UtilityBillCreateRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(utilityBillService.create(req));
    }

    /**
     * POST /internal/utility-payments
     * AI agent writes an extracted utility payment.
     * Returns 204 on success, 409 if gmailMessageId already processed.
     */
    @PostMapping("/utility-payments")
    public ResponseEntity<Void> createUtilityPayment(
            @RequestBody UtilityPaymentCreateRequest req) {
        utilityPaymentService.create(req);
        return ResponseEntity.noContent().build();
    }

    /**
     * POST /internal/utility-accounts/{accountId}/reset
     * Deletes all utility bills and payments for the account, then resets
     * utilityInitComplete=false so the AI agent re-runs the full historical init
     * on the next poll cycle. Use this to fix bad payment-matching data.
     */
    @PostMapping("/utility-accounts/{accountId}/reset")
    @Transactional
    public ResponseEntity<Void> resetUtilityAccount(@PathVariable Long accountId) {
        UserUtilityAccount account = utilityAccountRepo.findById(accountId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Utility account not found: " + accountId));

        String userId      = account.getUser().getId();
        String billerName  = account.getBillerName();
        String lastFour    = account.getAccountLastFour();

        // Delete payments first (FK to bills)
        int payments = utilityPaymentRepo.deleteByUser_IdAndBillerNameAndAccountLastFour(
                userId, billerName, lastFour);
        // Delete bills
        int bills = utilityBillRepo.deleteByUser_IdAndBillerNameAndAccountLastFour(
                userId, billerName, lastFour);

        // Reset init flag so the coordinator rescans on the next poll cycle
        account.setUtilityInitComplete(false);
        utilityAccountRepo.save(account);

        log.info("Utility account {} reset — deleted {} bill(s) and {} payment(s), init flag cleared",
                accountId, bills, payments);
        return ResponseEntity.ok().build();
    }
}
