package com.credtrack.backend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Per-uid token-bucket rate limiter. In-memory (resets on deploy). Sufficient for
 * solo / small-user scale; swap for Redis if needed later.
 *
 * Default: 60 tokens, refilled at rate (60 / 3600s) = 1 token / minute, so steady-state
 * 60 requests/hour with burst tolerance up to 60 immediately.
 */
@Service
public class ChatRateLimiter {

    private final long capacity;
    private final double refillPerSec;
    private final ConcurrentHashMap<String, Bucket> buckets = new ConcurrentHashMap<>();

    public ChatRateLimiter(
            @Value("${chat.rate-limit.requests-per-hour:60}") long requestsPerHour) {
        this.capacity = requestsPerHour;
        this.refillPerSec = requestsPerHour / 3600.0;
    }

    /** True if request allowed; false if uid is over its quota for the hour. */
    public boolean tryAcquire(String uid) {
        Bucket b = buckets.computeIfAbsent(uid, k -> new Bucket(capacity, Instant.now()));
        synchronized (b) {
            Instant now = Instant.now();
            double elapsed = Duration.between(b.lastRefill, now).toMillis() / 1000.0;
            b.tokens = Math.min(capacity, b.tokens + elapsed * refillPerSec);
            b.lastRefill = now;
            if (b.tokens >= 1.0) {
                b.tokens -= 1.0;
                return true;
            }
            return false;
        }
    }

    private static class Bucket {
        double tokens;
        Instant lastRefill;
        Bucket(long initial, Instant t) { this.tokens = initial; this.lastRefill = t; }
    }
}
