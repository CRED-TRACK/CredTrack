package com.credtrack.backend.controller;

import com.credtrack.backend.dto.UserUtilityAccountRequest;
import com.credtrack.backend.dto.UserUtilityAccountResponse;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.UserUtilityAccountService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/utility-accounts")
public class UserUtilityAccountController {

    private final UserUtilityAccountService service;
    private final FirebaseService           firebaseService;

    public UserUtilityAccountController(UserUtilityAccountService service,
                                        FirebaseService firebaseService) {
        this.service         = service;
        this.firebaseService = firebaseService;
    }

    private String resolveUid(String authHeader) {
        return firebaseService.verifyToken(authHeader.replace("Bearer ", "")).getUid();
    }

    @GetMapping
    public ResponseEntity<List<UserUtilityAccountResponse>> list(
            @RequestHeader("Authorization") String authHeader) {
        String userId = resolveUid(authHeader);
        return ResponseEntity.ok(service.getAccounts(userId));
    }

    @PostMapping
    public ResponseEntity<UserUtilityAccountResponse> add(
            @RequestHeader("Authorization") String authHeader,
            @RequestBody UserUtilityAccountRequest req) {
        String userId = resolveUid(authHeader);
        return ResponseEntity.status(HttpStatus.CREATED).body(service.addAccount(userId, req));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> remove(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long id) {
        String userId = resolveUid(authHeader);
        service.removeAccount(userId, id);
        return ResponseEntity.noContent().build();
    }
}
