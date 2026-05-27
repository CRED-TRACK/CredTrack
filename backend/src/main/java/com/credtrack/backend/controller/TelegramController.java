package com.credtrack.backend.controller;

import com.credtrack.backend.entity.TelegramLinkToken;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.repository.TelegramLinkTokenRepository;
import com.credtrack.backend.repository.UserRepository;
import com.credtrack.backend.service.FirebaseService;
import com.credtrack.backend.service.TelegramService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

@RestController
public class TelegramController {

    private static final Logger log = LoggerFactory.getLogger(TelegramController.class);
    private static final long LINK_TOKEN_TTL_MINUTES = 10;

    private final UserRepository userRepo;
    private final TelegramLinkTokenRepository tokenRepo;
    private final FirebaseService firebaseService;
    private final TelegramService telegramService;
    private final String botUsername;

    public TelegramController(UserRepository userRepo,
                              TelegramLinkTokenRepository tokenRepo,
                              FirebaseService firebaseService,
                              TelegramService telegramService,
                              @Value("${telegram.bot.username:}") String botUsername) {
        this.userRepo        = userRepo;
        this.tokenRepo       = tokenRepo;
        this.firebaseService = firebaseService;
        this.telegramService = telegramService;
        this.botUsername     = botUsername;
    }

    private String resolveUid(String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Missing bearer token");
        }
        return firebaseService.verifyToken(authHeader.substring("Bearer ".length())).getUid();
    }

    // ── User-facing endpoints (Firebase-authed) ────────────────────────────────

    /**
     * GET /api/telegram/status
     * Returns whether Telegram is linked and the current per-event preferences.
     */
    @GetMapping("/api/telegram/status")
    @Transactional(readOnly = true)
    public ResponseEntity<Map<String, Object>> status(
            @RequestHeader("Authorization") String authHeader) {
        String uid = resolveUid(authHeader);
        User u = userRepo.findById(uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        Map<String, Object> prefs = new LinkedHashMap<>();
        prefs.put("notify_statements",    Boolean.TRUE.equals(u.getNotifyStatements()));
        prefs.put("notify_transactions",  Boolean.TRUE.equals(u.getNotifyTransactions()));
        prefs.put("notify_payments",      Boolean.TRUE.equals(u.getNotifyPayments()));
        prefs.put("notify_utility_bills", Boolean.TRUE.equals(u.getNotifyUtilityBills()));

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("linked",       u.getTelegramChatId() != null);
        body.put("bot_username", botUsername);
        body.put("prefs",        prefs);
        return ResponseEntity.ok(body);
    }

    /**
     * POST /api/telegram/link-token
     * Mints a single-use short-lived token. iOS opens
     *   tg://resolve?domain=<botUsername>&start=<token>
     * and the bot's /start <token> handler binds the Telegram chat_id to this user.
     */
    @PostMapping("/api/telegram/link-token")
    @Transactional
    public ResponseEntity<Map<String, Object>> createLinkToken(
            @RequestHeader("Authorization") String authHeader) {
        String uid = resolveUid(authHeader);
        userRepo.findById(uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        // Best-effort expired cleanup
        tokenRepo.deleteExpired(LocalDateTime.now());

        String token = UUID.randomUUID().toString().replace("-", "");
        TelegramLinkToken entity = TelegramLinkToken.builder()
                .token(token)
                .userId(uid)
                .expiresAt(LocalDateTime.now().plusMinutes(LINK_TOKEN_TTL_MINUTES))
                .createdAt(LocalDateTime.now())
                .build();
        tokenRepo.save(entity);

        String deepLink     = "tg://resolve?domain=" + botUsername + "&start=" + token;
        String httpsFallback = "https://t.me/" + botUsername + "?start=" + token;

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("token",         token);
        body.put("bot_username",  botUsername);
        body.put("deep_link",     deepLink);
        body.put("https_link",    httpsFallback);
        body.put("expires_at",    entity.getExpiresAt().toString());
        return ResponseEntity.ok(body);
    }

    /**
     * PATCH /api/telegram/preferences
     * Partial update — only fields present in the body are changed.
     */
    @PatchMapping("/api/telegram/preferences")
    @Transactional
    public ResponseEntity<Void> updatePreferences(
            @RequestHeader("Authorization") String authHeader,
            @RequestBody Map<String, Boolean> body) {
        String uid = resolveUid(authHeader);
        User u = userRepo.findById(uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        if (body.containsKey("notify_statements"))    u.setNotifyStatements(body.get("notify_statements"));
        if (body.containsKey("notify_transactions"))  u.setNotifyTransactions(body.get("notify_transactions"));
        if (body.containsKey("notify_payments"))      u.setNotifyPayments(body.get("notify_payments"));
        if (body.containsKey("notify_utility_bills")) u.setNotifyUtilityBills(body.get("notify_utility_bills"));
        userRepo.save(u);
        return ResponseEntity.noContent().build();
    }

    /**
     * DELETE /api/telegram/link
     * Unlink — clears telegram_chat_id so no further notifications are sent.
     */
    @DeleteMapping("/api/telegram/link")
    @Transactional
    public ResponseEntity<Void> unlink(
            @RequestHeader("Authorization") String authHeader) {
        String uid = resolveUid(authHeader);
        User u = userRepo.findById(uid)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
        u.setTelegramChatId(null);
        userRepo.save(u);
        return ResponseEntity.noContent().build();
    }

    // ── Public Telegram webhook (secret-token authed) ──────────────────────────

    /**
     * POST /public/telegram/webhook
     * Receives every update from Telegram. Authed by X-Telegram-Bot-Api-Secret-Token
     * header which Telegram echoes back from the setWebhook call.
     *
     * Only handles "/start <linkToken>" messages — links the sender's chat_id to a user.
     * Every other update is silently acknowledged so Telegram does not retry.
     */
    @PostMapping("/public/telegram/webhook")
    @Transactional
    public ResponseEntity<Void> webhook(
            @RequestHeader(value = "X-Telegram-Bot-Api-Secret-Token", required = false) String secret,
            @RequestBody Map<String, Object> update) {

        String expected = telegramService.getWebhookSecret();
        if (expected != null && !expected.isBlank() && !expected.equals(secret)) {
            log.warn("Telegram webhook called with bad secret header");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> message = (Map<String, Object>) update.get("message");
            if (message == null) return ResponseEntity.ok().build();

            String text = (String) message.get("text");
            @SuppressWarnings("unchecked")
            Map<String, Object> chat = (Map<String, Object>) message.get("chat");
            if (text == null || chat == null) return ResponseEntity.ok().build();

            String chatId = String.valueOf(chat.get("id"));

            if (!text.startsWith("/start")) {
                telegramService.sendMessage(chatId,
                        "Hi — open the CredTrack app and tap <b>Link Telegram</b> to connect this chat.");
                return ResponseEntity.ok().build();
            }

            String[] parts = text.trim().split("\\s+", 2);
            if (parts.length < 2 || parts[1].isBlank()) {
                telegramService.sendMessage(chatId,
                        "Open CredTrack, go to Settings → Notifications, and tap <b>Link Telegram</b>.");
                return ResponseEntity.ok().build();
            }

            String linkToken = parts[1].trim();
            TelegramLinkToken row = tokenRepo.findById(linkToken).orElse(null);
            if (row == null || row.getExpiresAt().isBefore(LocalDateTime.now())) {
                if (row != null) tokenRepo.delete(row);
                telegramService.sendMessage(chatId,
                        "That link expired. Generate a new one in the app and try again.");
                return ResponseEntity.ok().build();
            }

            User u = userRepo.findById(row.getUserId()).orElse(null);
            if (u == null) {
                tokenRepo.delete(row);
                telegramService.sendMessage(chatId, "Account not found. Try again from the app.");
                return ResponseEntity.ok().build();
            }

            u.setTelegramChatId(chatId);
            userRepo.save(u);
            tokenRepo.delete(row);

            telegramService.sendMessage(chatId,
                    "<b>Linked.</b> CredTrack will message you here. Manage which alerts you receive in Settings → Notifications.");
            log.info("Telegram chat {} linked to user {}", chatId, u.getId());
        } catch (Exception e) {
            log.warn("Telegram webhook handler error: {}", e.getMessage());
        }
        return ResponseEntity.ok().build();
    }
}
