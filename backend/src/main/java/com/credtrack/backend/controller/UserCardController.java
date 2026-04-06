package com.credtrack.backend.controller;

import com.credtrack.backend.dto.UserCardRequest;
import com.credtrack.backend.dto.UserCardResponse;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.UserCardService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/user-cards")
public class UserCardController {

    private final UserCardService  service;
    private final FirebaseService  firebaseService;

    public UserCardController(UserCardService service, FirebaseService firebaseService) {
        this.service         = service;
        this.firebaseService = firebaseService;
    }

    // Verifies the Bearer token and returns the Firebase UID.
    private String resolveUid(String authHeader) {
        String token = authHeader.replace("Bearer ", "");
        return firebaseService.verifyToken(token).getUid();
    }

    /**
     * GET /user-cards
     * GET /user-cards?includeInactive=true
     */
    @GetMapping
    public ResponseEntity<List<UserCardResponse>> list(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        String uid = resolveUid(authHeader);
        return ResponseEntity.ok(service.getCardsForUser(uid, includeInactive));
    }

    /**
     * GET /user-cards/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<UserCardResponse> get(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id) {
        String uid = resolveUid(authHeader);
        return ResponseEntity.ok(service.getCard(id, uid));
    }

    /**
     * POST /user-cards
     * Body: { cardProductId, lastFour, cardHolderName, creditLimit, ... }
     * userId is taken from the verified token — not from the client.
     */
    @PostMapping
    public ResponseEntity<UserCardResponse> add(
            @RequestHeader("Authorization") String authHeader,
            @RequestBody UserCardRequest req) {
        String uid = resolveUid(authHeader);
        return ResponseEntity.status(HttpStatus.CREATED).body(service.addCard(uid, req));
    }

    /**
     * PATCH /user-cards/{id}
     * Partial update — only fields present in the body are changed.
     */
    @PatchMapping("/{id}")
    public ResponseEntity<UserCardResponse> update(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id,
            @RequestBody UserCardRequest req) {
        String uid = resolveUid(authHeader);
        return ResponseEntity.ok(service.updateCard(id, uid, req));
    }

    /**
     * DELETE /user-cards/{id}
     * Soft-deletes the card (sets is_active = false).
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> remove(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id) {
        String uid = resolveUid(authHeader);
        service.removeCard(id, uid);
        return ResponseEntity.noContent().build();
    }
}
