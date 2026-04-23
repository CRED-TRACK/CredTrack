package com.credtrack.backend.service;

import com.credtrack.backend.dto.CardSpendingResponse;
import com.credtrack.backend.dto.UtilityAnalyticsResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

/**
 * Calls the AI agent's internal analytics endpoints.
 * The AI agent uses Akka Cluster Sharding to compute analytics per userId
 * and caches results in actor state, so repeated calls within the TTL are free.
 *
 * Injects Spring's auto-configured WebClient.Builder so it inherits the
 * application's snake_case Jackson codec — required to deserialize the AI
 * agent's snake_case JSON into the backend's DTOs.
 */
@Service
public class AiAgentClient {

    private static final Logger log = LoggerFactory.getLogger(AiAgentClient.class);

    private final WebClient webClient;

    public AiAgentClient(
            WebClient.Builder builder,
            @Value("${ai.agent.base-url}") String baseUrl,
            @Value("${app.internal.service-key}") String serviceKey) {
        this.webClient = builder
                .baseUrl(baseUrl)
                .defaultHeader("X-Service-Key", serviceKey)
                .build();
    }

    public CardSpendingResponse getCardAnalytics(String userId, int months) {
        try {
            return webClient.get()
                    .uri("/internal/analytics/cards?userId={uid}&months={m}", userId, months)
                    .retrieve()
                    .bodyToMono(CardSpendingResponse.class)
                    .block();
        } catch (Exception e) {
            log.error("AI agent card analytics call failed for user {} months={}: {}", userId, months, e.getMessage());
            return CardSpendingResponse.builder()
                    .totalSpend(0).totalTransactions(0).months(months)
                    .cards(java.util.List.of()).categories(java.util.List.of())
                    .build();
        }
    }

    public UtilityAnalyticsResponse getUtilityAnalytics(String userId) {
        try {
            return webClient.get()
                    .uri("/internal/analytics/utilities?userId={uid}", userId)
                    .retrieve()
                    .bodyToMono(UtilityAnalyticsResponse.class)
                    .block();
        } catch (Exception e) {
            log.error("AI agent utility analytics call failed for user {}: {}", userId, e.getMessage());
            return UtilityAnalyticsResponse.builder().accounts(java.util.List.of()).build();
        }
    }
}
