package com.credtrack.backend.controller;

import com.credtrack.backend.dto.CardStatementResponse;
import com.credtrack.backend.dto.MarkPaidRequest;
import com.credtrack.backend.entity.CardStatement;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.UserCardRepository;
import com.credtrack.backend.service.FirebaseService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;

/**
 * iOS-facing statement endpoints — Firebase JWT required.
 */
@RestController
@RequestMapping("/statements")
public class StatementController {

    private final CardStatementRepository statementRepo;
    private final UserCardRepository      userCardRepo;
    private final FirebaseService         firebaseService;

    public StatementController(CardStatementRepository statementRepo,
                               UserCardRepository userCardRepo,
                               FirebaseService firebaseService) {
        this.statementRepo  = statementRepo;
        this.userCardRepo   = userCardRepo;
        this.firebaseService = firebaseService;
    }

    private String resolveUid(String authHeader) {
        return firebaseService.verifyToken(authHeader.replace("Bearer ", "")).getUid();
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
}
