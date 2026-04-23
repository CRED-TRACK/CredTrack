package com.credtrack.backend.controller;

import com.credtrack.backend.dto.CardSpendingResponse;
import com.credtrack.backend.dto.UtilityAnalyticsResponse;
import com.credtrack.backend.service.AiAgentClient;
import com.credtrack.backend.service.FirebaseService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Analytics endpoints — Firebase JWT required.
 * Delegates computation to the AI agent, which uses Akka Cluster Sharding
 * to compute and cache analytics per userId.
 */
@RestController
@RequestMapping("/analytics")
public class AnalyticsController {

    private final AiAgentClient   aiAgentClient;
    private final FirebaseService firebaseService;

    public AnalyticsController(AiAgentClient aiAgentClient, FirebaseService firebaseService) {
        this.aiAgentClient  = aiAgentClient;
        this.firebaseService = firebaseService;
    }

    private String resolveUid(String authHeader) {
        return firebaseService.verifyToken(authHeader.replace("Bearer ", "")).getUid();
    }

    /**
     * GET /analytics/cards?months=6
     * Returns per-card spend totals and category clusters for the past N months.
     */
    @GetMapping("/cards")
    public ResponseEntity<CardSpendingResponse> cardSpending(
            @RequestHeader("Authorization") String authHeader,
            @RequestParam(defaultValue = "6") int months) {
        if (months < 1 || months > 24) months = 6;
        return ResponseEntity.ok(aiAgentClient.getCardAnalytics(resolveUid(authHeader), months));
    }

    /**
     * GET /analytics/utilities
     * Returns bill history for each utility account, oldest-first, with trend stats.
     */
    @GetMapping("/utilities")
    public ResponseEntity<UtilityAnalyticsResponse> utilityAnalytics(
            @RequestHeader("Authorization") String authHeader) {
        return ResponseEntity.ok(aiAgentClient.getUtilityAnalytics(resolveUid(authHeader)));
    }
}
