package com.credtrack.backend.service;

import com.credtrack.backend.entity.User;
import com.credtrack.backend.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

@Service
public class TelegramService {

    private static final Logger log = LoggerFactory.getLogger(TelegramService.class);

    public enum EventType {
        STATEMENT,
        TRANSACTION,
        PAYMENT,
        UTILITY_BILL
    }

    private final UserRepository userRepo;
    private final RestTemplate restTemplate = new RestTemplate();

    private final String botToken;
    private final String webhookSecret;
    private final String publicBaseUrl;

    public TelegramService(UserRepository userRepo,
                           @Value("${telegram.bot.token:}") String botToken,
                           @Value("${telegram.webhook.secret:}") String webhookSecret,
                           @Value("${telegram.webhook.public-base-url:}") String publicBaseUrl) {
        this.userRepo       = userRepo;
        this.botToken       = botToken;
        this.webhookSecret  = webhookSecret;
        this.publicBaseUrl  = publicBaseUrl;
    }

    public boolean isConfigured() {
        return botToken != null && !botToken.isBlank();
    }

    /**
     * Send a message if the user has linked Telegram AND has the matching preference enabled.
     * Never throws — notification failures must not break extraction.
     */
    public void notifyIfEnabled(String userId, EventType event, String text) {
        if (!isConfigured()) return;
        try {
            Optional<User> opt = userRepo.findById(userId);
            if (opt.isEmpty()) return;
            User u = opt.get();
            String chatId = u.getTelegramChatId();
            if (chatId == null || chatId.isBlank()) return;
            if (!isEventEnabled(u, event)) return;
            sendMessage(chatId, text);
        } catch (Exception e) {
            log.warn("Telegram notify failed for user={} event={}: {}", userId, event, e.getMessage());
        }
    }

    private boolean isEventEnabled(User u, EventType event) {
        return switch (event) {
            case STATEMENT    -> Boolean.TRUE.equals(u.getNotifyStatements());
            case TRANSACTION  -> Boolean.TRUE.equals(u.getNotifyTransactions());
            case PAYMENT      -> Boolean.TRUE.equals(u.getNotifyPayments());
            case UTILITY_BILL -> Boolean.TRUE.equals(u.getNotifyUtilityBills());
        };
    }

    /**
     * Raw send — used by notifyIfEnabled and by the webhook handler to reply "Linked.".
     * Logs but does not throw.
     */
    public void sendMessage(String chatId, String text) {
        if (!isConfigured()) return;
        String url = "https://api.telegram.org/bot" + botToken + "/sendMessage";
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("chat_id", chatId);
        body.put("text", text);
        body.put("parse_mode", "HTML");
        body.put("disable_web_page_preview", true);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        try {
            restTemplate.postForEntity(url, new HttpEntity<>(body, headers), String.class);
        } catch (Exception e) {
            log.warn("Telegram sendMessage failed chatId={}: {}", chatId, e.getMessage());
        }
    }

    /**
     * On boot, register the webhook with Telegram so /start commands reach the backend.
     * Idempotent — Telegram accepts the same setWebhook payload multiple times.
     */
    @EventListener(ApplicationReadyEvent.class)
    public void registerWebhookOnStartup() {
        if (!isConfigured()) {
            log.info("Telegram bot token not set — skipping webhook registration");
            return;
        }
        if (publicBaseUrl == null || publicBaseUrl.isBlank()) {
            log.warn("telegram.webhook.public-base-url not set — skipping webhook registration");
            return;
        }
        String webhookUrl = publicBaseUrl.replaceAll("/+$", "") + "/public/telegram/webhook";
        String url = "https://api.telegram.org/bot" + botToken + "/setWebhook";

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("url", webhookUrl);
        if (webhookSecret != null && !webhookSecret.isBlank()) {
            body.put("secret_token", webhookSecret);
        }
        body.put("allowed_updates", java.util.List.of("message"));

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        try {
            var resp = restTemplate.postForEntity(url, new HttpEntity<>(body, headers), String.class);
            log.info("Telegram webhook registered at {} — response: {}", webhookUrl, resp.getBody());
        } catch (Exception e) {
            log.warn("Telegram setWebhook failed: {}", e.getMessage());
        }
    }

    public String getWebhookSecret() {
        return webhookSecret;
    }
}
