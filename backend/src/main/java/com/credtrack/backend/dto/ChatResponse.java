package com.credtrack.backend.dto;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter @Builder
public class ChatResponse {
    private String answer;
    private List<ChatSource> sources;
    private boolean rateLimited;

    @Getter @Builder
    public static class ChatSource {
        private Long chunkId;
        private Long documentId;
        private Long cardProductId;
        private String cardLabel;     // "Chase Freedom Unlimited"
        private String snippet;       // first ~200 chars
        private Double similarity;
    }
}
