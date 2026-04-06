package com.credtrack.backend.controller;

import com.credtrack.backend.dto.UserCardRequest;
import com.credtrack.backend.dto.UserCardResponse;
import com.credtrack.backend.service.UserCardService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/user-cards")
public class UserCardController {

    private final UserCardService service;

    public UserCardController(UserCardService service) {
        this.service = service;
    }

    /**
     * GET /user-cards?userId={uid}
     * GET /user-cards?userId={uid}&includeInactive=true
     *
     * Returns all active cards for the user (newest first).
     * Pass includeInactive=true to also see closed/removed cards.
     */
    @GetMapping
    public ResponseEntity<List<UserCardResponse>> list(
            @RequestParam String userId,
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return ResponseEntity.ok(service.getCardsForUser(userId, includeInactive));
    }

    /**
     * GET /user-cards/{id}?userId={uid}
     *
     * Returns a single user card. userId is verified to prevent cross-user access.
     */
    @GetMapping("/{id}")
    public ResponseEntity<UserCardResponse> get(
            @PathVariable Long id,
            @RequestParam String userId) {
        return ResponseEntity.ok(service.getCard(id, userId));
    }

    /**
     * POST /user-cards
     *
     * Body: { userId, cardProductId, lastFour, ... }
     * Adds a card to the user's wallet.
     */
    @PostMapping
    public ResponseEntity<UserCardResponse> add(@RequestBody UserCardRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.addCard(req));
    }

    /**
     * PATCH /user-cards/{id}?userId={uid}
     *
     * Partial update — only fields present in the body are changed.
     * Use this to update balances, statement dates, autopay, etc.
     */
    @PatchMapping("/{id}")
    public ResponseEntity<UserCardResponse> update(
            @PathVariable Long id,
            @RequestParam String userId,
            @RequestBody UserCardRequest req) {
        return ResponseEntity.ok(service.updateCard(id, userId, req));
    }

    /**
     * DELETE /user-cards/{id}?userId={uid}
     *
     * Soft-deletes the card (sets is_active = false).
     * The card remains in the DB for history.
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> remove(
            @PathVariable Long id,
            @RequestParam String userId) {
        service.removeCard(id, userId);
        return ResponseEntity.noContent().build();
    }
}
