package com.credtrack.backend.controller;

import com.credtrack.backend.dto.CategoryChoiceRequest;
import com.credtrack.backend.dto.CategoryChoiceResponse;
import com.credtrack.backend.dto.CategoryDTO;
import com.credtrack.backend.dto.DashboardResponse;
import com.credtrack.backend.entity.CanonicalCategory;
import com.credtrack.backend.service.AdvisorDashboardService;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.UserCardCategoryChoiceService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.List;

@RestController
public class RewardsController {

    private final AdvisorDashboardService dashboardService;
    private final UserCardCategoryChoiceService choiceService;
    private final FirebaseService firebaseService;

    public RewardsController(AdvisorDashboardService dashboardService,
                             UserCardCategoryChoiceService choiceService,
                             FirebaseService firebaseService) {
        this.dashboardService = dashboardService;
        this.choiceService = choiceService;
        this.firebaseService = firebaseService;
    }

    private String resolveUid(String authHeader) {
        String token = authHeader.replace("Bearer ", "");
        return firebaseService.verifyToken(token).getUid();
    }

    @GetMapping("/recommendations/dashboard")
    public ResponseEntity<DashboardResponse> dashboard(
            @RequestHeader("Authorization") String authHeader) {
        String uid = resolveUid(authHeader);
        return ResponseEntity.ok(dashboardService.buildFor(uid));
    }

    @GetMapping("/recommendations/categories")
    public ResponseEntity<List<CategoryDTO>> categories(
            @RequestHeader("Authorization") String authHeader) {
        resolveUid(authHeader);
        List<CategoryDTO> result = Arrays.stream(CanonicalCategory.values())
            .map(CategoryDTO::from)
            .toList();
        return ResponseEntity.ok(result);
    }

    @PutMapping("/user-cards/{userCardId}/category-choice")
    public ResponseEntity<CategoryChoiceResponse> setCategoryChoice(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable Long userCardId,
            @RequestBody CategoryChoiceRequest req) {
        String uid = resolveUid(authHeader);
        var saved = choiceService.upsertChoice(
            uid, userCardId, req.getChoiceKind(), req.getCanonicalCategory());
        return ResponseEntity.ok(CategoryChoiceResponse.from(saved));
    }
}
