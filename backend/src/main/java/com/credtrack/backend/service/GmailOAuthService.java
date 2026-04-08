package com.credtrack.backend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import javax.crypto.Cipher;
import javax.crypto.Mac;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.Base64;
import java.util.Map;

@Service
public class GmailOAuthService {

    private static final String AUTH_URL  = "https://accounts.google.com/o/oauth2/auth";
    private static final String TOKEN_URL = "https://oauth2.googleapis.com/token";
    private static final String SCOPE     = "https://www.googleapis.com/auth/gmail.readonly";
    private static final int    GCM_IV_LENGTH  = 12;
    private static final int    GCM_TAG_BITS   = 128;

    @Value("${google.oauth.client-id}")
    private String clientId;

    @Value("${google.oauth.client-secret}")
    private String clientSecret;

    @Value("${google.oauth.redirect-uri}")
    private String redirectUri;

    @Value("${google.oauth.state-secret}")
    private String stateSecret;

    @Value("${app.encryption.key}")
    private String encryptionKeyB64;

    private final RestTemplate restTemplate = new RestTemplate();

    // ── Authorization URL ─────────────────────────────────────────────────────

    public String buildAuthUrl(String uid) {
        String state = signState(uid);
        return UriComponentsBuilder.fromUriString(AUTH_URL)
                .queryParam("client_id",     clientId)
                .queryParam("redirect_uri",  redirectUri)
                .queryParam("scope",         SCOPE)
                .queryParam("response_type", "code")
                .queryParam("access_type",   "offline")
                .queryParam("prompt",        "consent")
                .queryParam("state",         state)
                .build().toUriString();
    }

    // ── Code exchange ─────────────────────────────────────────────────────────

    public record TokenResponse(
            String accessToken,
            String refreshToken,
            LocalDateTime expiryUtc
    ) {}

    @SuppressWarnings("unchecked")
    public TokenResponse exchangeCode(String code) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("code",          code);
        params.add("client_id",     clientId);
        params.add("client_secret", clientSecret);
        params.add("redirect_uri",  redirectUri);
        params.add("grant_type",    "authorization_code");

        ResponseEntity<Map> resp = restTemplate.postForEntity(
                TOKEN_URL, new HttpEntity<>(params, headers), Map.class);

        Map<String, Object> body = resp.getBody();
        if (body == null || !body.containsKey("access_token")) {
            throw new RuntimeException("Token exchange failed — no access_token in response");
        }

        String accessToken  = (String) body.get("access_token");
        String refreshToken = (String) body.getOrDefault("refresh_token", "");
        int    expiresIn    = (int) body.getOrDefault("expires_in", 3600);
        LocalDateTime expiry = LocalDateTime.now(ZoneOffset.UTC).plusSeconds(expiresIn);

        return new TokenResponse(accessToken, refreshToken, expiry);
    }

    // ── Token refresh ─────────────────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    public TokenResponse refreshAccessToken(String refreshToken) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("refresh_token", refreshToken);
        params.add("client_id",     clientId);
        params.add("client_secret", clientSecret);
        params.add("grant_type",    "refresh_token");

        ResponseEntity<Map> resp = restTemplate.postForEntity(
                TOKEN_URL, new HttpEntity<>(params, headers), Map.class);

        Map<String, Object> body = resp.getBody();
        if (body == null || !body.containsKey("access_token")) {
            throw new RuntimeException("Token refresh failed — no access_token in response");
        }

        String accessToken = (String) body.get("access_token");
        int    expiresIn   = (int) body.getOrDefault("expires_in", 3600);
        LocalDateTime expiry = LocalDateTime.now(ZoneOffset.UTC).plusSeconds(expiresIn);

        return new TokenResponse(accessToken, refreshToken, expiry);
    }

    // ── State signing & verification ──────────────────────────────────────────

    /** Returns {@code base64url(uid) + "." + base64url(hmac(uid))} */
    public String signState(String uid) {
        String uidB64  = b64url(uid.getBytes(StandardCharsets.UTF_8));
        String mac     = b64url(hmacSha256(uid, stateSecret));
        return uidB64 + "." + mac;
    }

    /**
     * Verifies the HMAC and returns the uid.
     * Throws {@link IllegalArgumentException} if the state is invalid.
     */
    public String verifyState(String state) {
        String[] parts = state.split("\\.", 2);
        if (parts.length != 2) throw new IllegalArgumentException("Malformed OAuth state");

        String uid = new String(Base64.getUrlDecoder().decode(parts[0]), StandardCharsets.UTF_8);
        String expected = b64url(hmacSha256(uid, stateSecret));
        if (!expected.equals(parts[1])) throw new IllegalArgumentException("OAuth state HMAC mismatch");
        return uid;
    }

    // ── Token encryption (AES-256-GCM) ───────────────────────────────────────

    public String encrypt(String plaintext) {
        try {
            byte[]    keyBytes = Base64.getDecoder().decode(encryptionKeyB64);
            SecretKey key      = new SecretKeySpec(keyBytes, "AES");
            byte[]    iv       = new byte[GCM_IV_LENGTH];
            new SecureRandom().nextBytes(iv);

            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(GCM_TAG_BITS, iv));
            byte[] ciphertext = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));

            // Store as base64(iv || ciphertext)
            byte[] combined = ByteBuffer.allocate(iv.length + ciphertext.length)
                    .put(iv).put(ciphertext).array();
            return Base64.getEncoder().encodeToString(combined);
        } catch (Exception e) {
            throw new RuntimeException("Encryption failed", e);
        }
    }

    public String decrypt(String encryptedB64) {
        try {
            byte[]    combined = Base64.getDecoder().decode(encryptedB64);
            // Use Arrays.copyOfRange — ByteBuffer.wrap().array() returns the full backing
            // array regardless of offset/length, giving the wrong IV and corrupt ciphertext.
            byte[]    iv       = Arrays.copyOfRange(combined, 0, GCM_IV_LENGTH);
            byte[]    ct       = Arrays.copyOfRange(combined, GCM_IV_LENGTH, combined.length);
            byte[]    keyBytes = Base64.getDecoder().decode(encryptionKeyB64);
            SecretKey key      = new SecretKeySpec(keyBytes, "AES");

            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(GCM_TAG_BITS, iv));
            return new String(cipher.doFinal(ct), StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new RuntimeException("Decryption failed", e);
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private byte[] hmacSha256(String data, String secret) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new RuntimeException("HMAC failed", e);
        }
    }

    private String b64url(byte[] data) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(data);
    }
}
