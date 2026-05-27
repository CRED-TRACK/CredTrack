package com.credtrack.backend.repository;

import com.credtrack.backend.entity.TelegramLinkToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.LocalDateTime;

public interface TelegramLinkTokenRepository extends JpaRepository<TelegramLinkToken, String> {

    @Modifying
    @Query("delete from TelegramLinkToken t where t.expiresAt < :cutoff")
    int deleteExpired(LocalDateTime cutoff);
}
