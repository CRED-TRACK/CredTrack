package com.credtrack.backend.controller;

import com.credtrack.backend.dto.CardStatementResponse;
import com.credtrack.backend.dto.MarkPaidRequest;
import com.credtrack.backend.dto.UnbilledSpendResponse;
import com.credtrack.backend.entity.CardStatement;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.UserCardRepository;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.FirebaseStorageService;
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

import java.time.LocalDate;
import java.util.UUID;

/**
 * iOS-facing statement endpoints — Firebase JWT required.
 */
@RestController
@RequestMapping("/statements")
public class StatementController {

    private final CardStatementRepository statementRepo;
    private final UserCardRepository      userCardRepo;
    private final FirebaseService         firebaseService;
    private final FirebaseStorageService  storageService;
    private final UnbilledSpendService    unbilledSpendService;

    public StatementController(CardStatementRepository statementRepo,
                               UserCardRepository userCardRepo,
                               FirebaseService firebaseService,
                               FirebaseStorageService storageService,
                               UnbilledSpendService unbilledSpendService) {
        this.statementRepo       = statementRepo;
        this.userCardRepo        = userCardRepo;
        this.firebaseService     = firebaseService;
        this.storageService      = storageService;
        this.unbilledSpendService = unbilledSpendService;
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

        byte[] bytes = storageService.downloadStatementPdf(stmt.getFirebasePath());
        if (bytes == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "PDF not found in storage");
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_PDF);
        headers.setContentDispositionFormData("inline", "statement.pdf");
        return new ResponseEntity<>(bytes, headers, HttpStatus.OK);
    }
}
