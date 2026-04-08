package com.credtrack.backend.controller;

import com.credtrack.backend.dto.CardStatementResponse;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.service.FirebaseService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/**
 * iOS-facing statement endpoints — Firebase JWT required.
 */
@RestController
@RequestMapping("/statements")
public class StatementController {

    private final CardStatementRepository statementRepo;
    private final FirebaseService         firebaseService;

    public StatementController(CardStatementRepository statementRepo,
                               FirebaseService firebaseService) {
        this.statementRepo  = statementRepo;
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
}
