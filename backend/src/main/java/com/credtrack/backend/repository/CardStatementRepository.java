package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CardStatement;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface CardStatementRepository extends JpaRepository<CardStatement, Long> {

    boolean existsByGmailMessageId(String gmailMessageId);

    Optional<CardStatement> findByIdAndUser_Id(Long id, String userId);

    // All statements for a user (across all cards), newest first
    Page<CardStatement> findByUser_IdOrderByStatementDateDesc(String userId, Pageable pageable);

    // Statements filtered by a specific card
    Page<CardStatement> findByUserCard_IdAndUser_IdOrderByStatementDateDesc(
            Long userCardId, String userId, Pageable pageable);

    // Latest statement for a card — used to update UserCard fields
    Optional<CardStatement> findTopByUserCard_IdOrderByStatementDateDesc(Long userCardId);
}
