package com.credtrack.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.time.Duration;

/**
 * Thin client to the ai-agent's internal LLM endpoints. Keeps all AI/LLM
 * vendor coupling in the ai-agent repo; backend only sees plain JSON.
 *   POST {ai-agent}/internal/embed  → { embedding: [...], dim }
 *   POST {ai-agent}/internal/chat   → { answer }
 */
@Service
public class AiAgentChatClient {

    private static final Logger log = LoggerFactory.getLogger(AiAgentChatClient.class);

    private final WebClient webClient;
    private final ObjectMapper objectMapper;
    private final int timeoutSeconds;

    public AiAgentChatClient(ObjectMapper objectMapper,
                             @Value("${ai.agent.base-url:http://localhost:8081}") String baseUrl,
                             @Value("${ai.agent.chat-timeout-seconds:60}") int timeoutSeconds) {
        this.objectMapper = objectMapper;
        this.timeoutSeconds = timeoutSeconds;
        this.webClient = WebClient.builder().baseUrl(baseUrl).build();
    }

    public float[] embed(String text) {
        String resp = webClient.post()
            .uri("/internal/embed")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(java.util.Map.of("text", text))
            .retrieve()
            .onStatus(HttpStatusCode::isError, r -> r.bodyToMono(String.class).defaultIfEmpty("")
                .flatMap(b -> Mono.error(new IllegalStateException(
                    "ai-agent /embed " + r.statusCode().value() + ": " + b))))
            .bodyToMono(String.class)
            .block(Duration.ofSeconds(timeoutSeconds));

        if (resp == null) throw new IllegalStateException("ai-agent /embed empty response");
        try {
            JsonNode values = objectMapper.readTree(resp).path("embedding");
            if (!values.isArray() || values.isEmpty()) {
                throw new IllegalStateException("ai-agent /embed missing values: " + resp);
            }
            float[] out = new float[values.size()];
            for (int i = 0; i < values.size(); i++) out[i] = (float) values.get(i).asDouble();
            return out;
        } catch (Exception e) {
            log.error("ai_agent_embed_parse error={}", e.getMessage());
            throw new IllegalStateException("Failed to parse ai-agent embed response", e);
        }
    }

    public String chat(String prompt) {
        String resp = webClient.post()
            .uri("/internal/chat")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(java.util.Map.of("prompt", prompt))
            .retrieve()
            .onStatus(HttpStatusCode::isError, r -> r.bodyToMono(String.class).defaultIfEmpty("")
                .flatMap(b -> Mono.error(new IllegalStateException(
                    "ai-agent /chat " + r.statusCode().value() + ": " + b))))
            .bodyToMono(String.class)
            .block(Duration.ofSeconds(timeoutSeconds));

        if (resp == null) throw new IllegalStateException("ai-agent /chat empty response");
        try {
            JsonNode root = objectMapper.readTree(resp);
            JsonNode answer = root.path("answer");
            if (!answer.isTextual()) {
                throw new IllegalStateException("ai-agent /chat missing answer: " + resp);
            }
            return answer.asText();
        } catch (Exception e) {
            log.error("ai_agent_chat_parse error={}", e.getMessage());
            throw new IllegalStateException("Failed to parse ai-agent chat response", e);
        }
    }
}
