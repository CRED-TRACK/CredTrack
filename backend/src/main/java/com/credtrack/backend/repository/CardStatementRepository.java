package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CardStatement;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.math.BigDecimal;
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

    // Match by exact balance — primary matching strategy (full-balance payments)
    Optional<CardStatement> findFirstByUserCard_IdAndStatementBalanceAndIsPaidFalse(
            Long userCardId, BigDecimal statementBalance);

    // Date-based match — for banks that never include balance in statement emails (e.g. Amex).
    // Returns the unpaid statement whose due date is the earliest one on-or-after the payment date.
    // Example: payment Jan 8 → dueDate Feb 1; payment Feb 5 → dueDate Mar 1.
    // Each billing cycle has a unique due date so concurrent payments safely get different statements.
    Optional<CardStatement> findFirstByUserCard_IdAndIsPaidFalseAndDueDateGreaterThanEqualOrderByDueDateAsc(
            Long userCardId, java.time.LocalDate paymentDate);

    // Last-resort fallback — oldest null-balance unpaid statement (no due date available).
    Optional<CardStatement> findTopByUserCard_IdAndStatementBalanceIsNullAndIsPaidFalseOrderByStatementDateAsc(Long userCardId);

    // Oldest unpaid statement — orphan auto-match on statement arrival
    Optional<CardStatement> findTopByUserCard_IdAndIsPaidFalseOrderByStatementDateAsc(Long userCardId);
}
