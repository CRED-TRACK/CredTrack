package com.credtrack.backend.controller;

import com.credtrack.backend.dto.ChatRequest;
import com.credtrack.backend.dto.ChatResponse;
import com.credtrack.backend.service.ChatRateLimiter;
import com.credtrack.backend.service.ChatService;
import com.credtrack.backend.service.FirebaseService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
public class ChatController {

    private static final Logger log = LoggerFactory.getLogger(ChatController.class);

    private final ChatService chatService;
    private final ChatRateLimiter rateLimiter;
    private final FirebaseService firebaseService;

    public ChatController(ChatService chatService,
                          ChatRateLimiter rateLimiter,
                          FirebaseService firebaseService) {
        this.chatService = chatService;
        this.rateLimiter = rateLimiter;
        this.firebaseService = firebaseService;
    }

    private String resolveUid(String authHeader) {
        String token = authHeader.replace("Bearer ", "");
        return firebaseService.verifyToken(token).getUid();
    }

    @PostMapping("/chat")
    public ResponseEntity<ChatResponse> chat(
            @RequestHeader("Authorization") String authHeader,
            @RequestBody ChatRequest req) {
        String uid = resolveUid(authHeader);
        if (!rateLimiter.tryAcquire(uid)) {
            log.warn("chat_rate_limited uid={}", uid);
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(
                ChatResponse.builder()
                    .answer("You've hit the chat rate limit. Try again in a few minutes.")
                    .sources(List.of())
                    .rateLimited(true)
                    .build());
        }
        return ResponseEntity.ok(chatService.answer(uid, req));
    }
}
