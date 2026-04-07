package com.credtrack.backend.controller;

import com.credtrack.backend.dto.TransactionResponse;
import com.credtrack.backend.dto.TransactionSummaryResponse;
import com.credtrack.backend.dto.TransactionUpdateRequest;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.TransactionInternalService;
import com.credtrack.backend.service.TransactionQueryService;
import org.springframework.data.domain.Page;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/transactions")
public class TransactionController {

    private final TransactionQueryService    queryService;
    private final TransactionInternalService internalService;
    private final FirebaseService            firebaseService;

    public TransactionController(TransactionQueryService queryService,
                                 TransactionInternalService internalService,
                                 FirebaseService firebaseService) {
        this.queryService    = queryService;
        this.internalService = internalService;
        this.firebaseService = firebaseService;
    }

    private String resolveUid(String authHeader) {
        return firebaseService.verifyToken(authHeader.replace("Bearer ", "")).getUid();
    }

    /**
     * GET /transactions
     * Optional query params: cardId, startDate, endDate, type, search, page, size
     */
    @GetMapping
    public ResponseEntity<Page<TransactionResponse>> list(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam(required = false) Long cardId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        String uid = resolveUid(authHeader);
        return ResponseEntity.ok(
                queryService.list(uid, cardId, startDate, endDate, type, search, page, size));
    }

    /**
     * GET /transactions/summary?month=2026-04
     */
    @GetMapping("/summary")
    public ResponseEntity<TransactionSummaryResponse> summary(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam(required = false) String month) {
        String uid = resolveUid(authHeader);
        return ResponseEntity.ok(queryService.summary(uid, month));
    }

    /**
     * GET /transactions/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<TransactionResponse> get(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id) {
        String uid = resolveUid(authHeader);
        return ResponseEntity.ok(queryService.get(id, uid));
    }

    /**
     * PATCH /transactions/{id}
     * Allows manual corrections: merchant_name, merchant_category, user_card_id, status
     */
    @PatchMapping("/{id}")
    public ResponseEntity<TransactionResponse> update(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id,
            @RequestBody TransactionUpdateRequest req) {
        String uid = resolveUid(authHeader);
        return ResponseEntity.ok(internalService.update(id, uid, req));
    }
}
