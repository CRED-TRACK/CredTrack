package com.credtrack.backend.controller;

import com.credtrack.backend.dto.CardStatementResponse;
import com.credtrack.backend.dto.MarkPaidRequest;
import com.credtrack.backend.dto.StatementExtractionResult;
import com.credtrack.backend.dto.StatementExtractionResult.ExtractedTransaction;
import com.credtrack.backend.dto.UnbilledSpendResponse;
import com.credtrack.backend.entity.CardStatement;
import com.credtrack.backend.entity.Transaction;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.TransactionRepository;
import com.credtrack.backend.repository.UserCardRepository;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.FirebaseStorageService;
import com.credtrack.backend.service.PdfExtractionService;
import com.credtrack.backend.service.UnbilledSpendService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * iOS-facing statement endpoints — Firebase JWT required.
 */
@RestController
@RequestMapping("/statements")
public class StatementController {

    private final CardStatementRepository statementRepo;
    private final UserCardRepository      userCardRepo;
    private final TransactionRepository   transactionRepo;
    private final FirebaseService         firebaseService;
    private final FirebaseStorageService  storageService;
    private final UnbilledSpendService    unbilledSpendService;
    private final PdfExtractionService    extractionService;

    public StatementController(CardStatementRepository statementRepo,
                               UserCardRepository userCardRepo,
                               TransactionRepository transactionRepo,
                               FirebaseService firebaseService,
                               FirebaseStorageService storageService,
                               UnbilledSpendService unbilledSpendService,
                               PdfExtractionService extractionService) {
        this.statementRepo        = statementRepo;
        this.userCardRepo         = userCardRepo;
        this.transactionRepo      = transactionRepo;
        this.firebaseService      = firebaseService;
        this.storageService       = storageService;
        this.unbilledSpendService = unbilledSpendService;
        this.extractionService    = extractionService;
    }

    private String resolveUid(String authHeader) {
        return firebaseService.verifyToken(authHeader.replace("Bearer ", "")).getUid();
    }

    /**
     * GET /statements/unbilled?cardId={id}
     * Returns all transactions since the last statement closing date (open billing period).
     * unbilledTotal is the running spend not yet captured in a statement.
     */
    @GetMapping("/unbilled")
    public ResponseEntity<UnbilledSpendResponse> unbilled(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam Long cardId) {

        String uid = resolveUid(authHeader);
        return ResponseEntity.ok(unbilledSpendService.computeUnbilled(uid, cardId));
    }

    /**
     * GET /statements?cardId=&page=&size=
     * Returns paginated statement history.
     * If cardId is provided, filters to that card only.
     */
    @GetMapping
    public ResponseEntity<Page<CardStatementResponse>> list(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam(required = false) Long cardId,
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "20") int size) {

        String uid = resolveUid(authHeader);
        Pageable pageable = PageRequest.of(page, size);

        Page<CardStatementResponse> result = cardId != null
                ? statementRepo.findByUserCard_IdAndUser_IdOrderByStatementDateDesc(cardId, uid, pageable)
                               .map(CardStatementResponse::from)
                : statementRepo.findByUser_IdOrderByStatementDateDesc(uid, pageable)
                               .map(CardStatementResponse::from);

        return ResponseEntity.ok(result);
    }

    /**
     * GET /statements/{id}
     * Returns a single statement. 404 if not found or not owned by caller.
     */
    @GetMapping("/{id}")
    public ResponseEntity<CardStatementResponse> get(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id) {

        String uid = resolveUid(authHeader);
        CardStatementResponse response = statementRepo.findByIdAndUser_Id(id, uid)
                .map(CardStatementResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Statement not found"));

        return ResponseEntity.ok(response);
    }

    /**
     * POST /statements/{id}/mark-paid
     * Manually marks a statement as paid.
     * Body: { "paymentDate": "2026-04-14" }  — paymentDate is optional, defaults to today.
     * Returns the updated statement.
     */
    @PostMapping("/{id}/mark-paid")
    @Transactional
    public ResponseEntity<CardStatementResponse> markPaid(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id,
            @RequestBody(required = false) MarkPaidRequest req) {

        String uid = resolveUid(authHeader);

        CardStatement stmt = statementRepo.findByIdAndUser_Id(id, uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Statement not found"));

        LocalDate paymentDate = (req != null && req.getPaymentDate() != null)
                ? req.getPaymentDate()
                : LocalDate.now();

        stmt.setIsPaid(true);
        stmt.setPaymentDate(paymentDate);
        if (req != null && req.getPaidAmount() != null) {
            stmt.setPaidAmount(req.getPaidAmount());
        }
        statementRepo.save(stmt);

        // Keep UserCard.lastPaymentDate in sync if this card is registered
        if (stmt.getUserCard() != null) {
            UserCard card = stmt.getUserCard();
            if (paymentDate.isAfter(card.getLastPaymentDate() == null ? LocalDate.MIN : card.getLastPaymentDate())) {
                card.setLastPaymentDate(paymentDate);
                userCardRepo.save(card);
            }
        }

        return ResponseEntity.ok(CardStatementResponse.from(stmt));
    }

    /**
     * POST /statements/{id}/upload-pdf
     * Attaches a PDF to an existing statement. Uploads to Firebase Storage and
     * sets pdfStatus=PENDING on the existing row — no new row is created.
     * The AI agent will later extract the text and update the row.
     */
    @PostMapping("/{id}/upload-pdf")
    @Transactional
    public ResponseEntity<CardStatementResponse> uploadPdf(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file) {

        String uid = resolveUid(authHeader);

        CardStatement stmt = statementRepo.findByIdAndUser_Id(id, uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Statement not found"));

        if (file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "File is empty");
        }

        Long cardId = stmt.getUserCard() != null ? stmt.getUserCard().getId() : 0L;
        String uuid     = UUID.randomUUID().toString();
        String filename = uuid + ".pdf";

        try {
            String firebasePath = storageService.uploadStatementPdf(uid, cardId, filename, file.getBytes());
            stmt.setFirebasePath(firebasePath);
            stmt.setPdfStatus("PENDING");
            return ResponseEntity.ok(CardStatementResponse.from(statementRepo.save(stmt)));
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Upload failed: " + e.getMessage());
        }
    }

    /**
     * GET /statements/{id}/pdf
     * Proxies the statement PDF through the backend so the iOS client can download it
     * without needing direct Firebase Storage access.
     */
    @GetMapping("/{id}/pdf")
    public ResponseEntity<byte[]> downloadPdf(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id) {

        String uid = resolveUid(authHeader);

        CardStatement stmt = statementRepo.findByIdAndUser_Id(id, uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Statement not found"));

        if (stmt.getFirebasePath() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No PDF attached to this statement");
        }

        byte[] bytes = storageService.downloadPdf(stmt.getFirebasePath());
        if (bytes == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "PDF not found in storage");
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_PDF);
        headers.setContentDispositionFormData("inline", "statement.pdf");
        return new ResponseEntity<>(bytes, headers, HttpStatus.OK);
    }

    /**
     * GET /statements/{id}/extraction-preview
     * Returns extraction result once pdfStatus leaves PENDING/EXTRACTING.
     * Returns 202 Accepted while still processing.
     */
    @GetMapping("/{id}/extraction-preview")
    public ResponseEntity<StatementExtractionResult> extractionPreview(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id) {

        String uid = resolveUid(authHeader);
        CardStatement stmt = statementRepo.findByIdAndUser_Id(id, uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Statement not found"));

        String status = stmt.getPdfStatus();
        if (status == null || "PENDING".equals(status) || "EXTRACTING".equals(status)) {
            return ResponseEntity.accepted()
                    .body(StatementExtractionResult.builder().status(status).build());
        }

        if (stmt.getExtractedData() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No extraction data available");
        }

        StatementExtractionResult result = extractionService.parseStatementResult(stmt.getExtractedData());
        if (result == null) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Extraction data is corrupted");
        }
        return ResponseEntity.ok(result);
    }

    /**
     * POST /statements/{id}/apply-extraction
     * User confirms the extracted data. Deletes Gmail transactions in the billing period,
     * inserts PDF transactions, updates statement header, sets pdfStatus=EXTRACTED.
     * Body (optional): { "force": true } — apply even if WRONG_STATEMENT.
     */
    @PostMapping("/{id}/apply-extraction")
    @Transactional
    public ResponseEntity<CardStatementResponse> applyExtraction(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id,
            @RequestBody(required = false) Map<String, Object> body) {

        String uid = resolveUid(authHeader);
        CardStatement stmt = statementRepo.findByIdAndUser_Id(id, uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Statement not found"));

        String status = stmt.getPdfStatus();
        boolean force = body != null && Boolean.TRUE.equals(body.get("force"));

        if ("WRONG_STATEMENT".equals(status) && !force) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Extraction detected a potential wrong statement. Send { \"force\": true } to apply anyway.");
        }
        if (!"AWAITING_CONFIRMATION".equals(status) && !"WRONG_STATEMENT".equals(status)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Statement is not ready for confirmation (pdfStatus=" + status + ").");
        }
        if (stmt.getExtractedData() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No extraction data to apply");
        }

        StatementExtractionResult result = extractionService.parseStatementResult(stmt.getExtractedData());
        if (result == null) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Extraction data corrupted");
        }

        if (result.getStatementBalance() != null) stmt.setStatementBalance(BigDecimal.valueOf(result.getStatementBalance()));
        if (result.getMinimumDue() != null) stmt.setMinimumDue(BigDecimal.valueOf(result.getMinimumDue()));
        if (result.getDueDate() != null) try { stmt.setDueDate(LocalDate.parse(result.getDueDate())); } catch (Exception ignored) {}
        if (result.getStatementDate() != null) try { stmt.setStatementDate(LocalDate.parse(result.getStatementDate())); } catch (Exception ignored) {}

        UserCard card = stmt.getUserCard();
        if (card != null && result.getTransactions() != null && !result.getTransactions().isEmpty()) {
            LocalDate periodStart = parseDateSafe(result.getBillingPeriodStart());
            LocalDate periodEnd   = parseDateSafe(result.getBillingPeriodEnd());
            if (periodStart == null && stmt.getStatementDate() != null) periodStart = stmt.getStatementDate().minusDays(30);
            if (periodEnd == null && stmt.getStatementDate() != null) periodEnd = stmt.getStatementDate();

            if (periodStart != null && periodEnd != null) {
                transactionRepo.deleteByUserCard_IdAndTransactionDateBetween(card.getId(), periodStart, periodEnd);

                String bankKey = card.getCardProduct() != null ? card.getCardProduct().getBankKey() : null;
                int idx = 0;
                for (ExtractedTransaction txn : result.getTransactions()) {
                    LocalDate txnDate = parseDateSafe(txn.getDate());
                    if (txnDate == null) continue;
                    String syntheticId = "PDF-" + stmt.getId() + "-" + (idx++);
                    if (transactionRepo.existsByGmailMessageId(syntheticId)) continue;
                    Transaction t = Transaction.builder()
                            .user(stmt.getUser())
                            .userCard(card)
                            .gmailMessageId(syntheticId)
                            .merchantName(txn.getMerchantName())
                            .amount(BigDecimal.valueOf(txn.getAmount()))
                            .transactionDate(txnDate)
                            .cardLastFour(card.getLastFour())
                            .transactionType(txn.getType() != null ? txn.getType() : "PURCHASE")
                            .status("CONFIRMED")
                            .bankKey(bankKey)
                            .build();
                    transactionRepo.save(t);
                }
            }
        }

        stmt.setPdfStatus("EXTRACTED");
        return ResponseEntity.ok(CardStatementResponse.from(statementRepo.save(stmt)));
    }

    private LocalDate parseDateSafe(String iso) {
        if (iso == null) return null;
        try { return LocalDate.parse(iso); } catch (Exception e) { return null; }
    }
}
