package com.credtrack.backend.dto;

import lombok.Getter;
import lombok.Setter;

import java.util.List;

@Getter @Setter
public class ChatRequest {
    /** Latest user question. Capped to 500 chars server-side. */
    private String question;
    /** Optional context — prior turns, oldest first. */
    private List<ChatTurn> history;

    @Getter @Setter
    public static class ChatTurn {
        private String role;       // "user" or "assistant"
        private String content;
    }
}
