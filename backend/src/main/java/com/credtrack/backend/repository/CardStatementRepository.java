package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CardStatement;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

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

    // Payment tracking — unpaid statements where balance is positive OR null (unknown, e.g. Amex).
    // Excludes zero/negative balance (bank owes user, no payment needed).
    @Query("SELECT CASE WHEN COUNT(s) > 0 THEN TRUE ELSE FALSE END FROM CardStatement s " +
           "WHERE s.userCard.id = :cardId AND s.isPaid = false " +
           "AND (s.statementBalance IS NULL OR s.statementBalance > 0)")
    boolean hasUnpaidStatements(@Param("cardId") Long cardId);

    // Match by exact balance — primary matching strategy (full-balance payments)
    Optional<CardStatement> findFirstByUserCard_IdAndStatementBalanceAndIsPaidFalse(
            Long userCardId, BigDecimal statementBalance);

    // Fallback for banks that don't include balance in statement emails (e.g. Amex).
    // Used when amount-based matching fails and the statement balance was never extracted.
    Optional<CardStatement> findTopByUserCard_IdAndStatementBalanceIsNullAndIsPaidFalseOrderByStatementDateAsc(Long userCardId);

    // Oldest unpaid statement — orphan auto-match on statement arrival
    Optional<CardStatement> findTopByUserCard_IdAndIsPaidFalseOrderByStatementDateAsc(Long userCardId);
}
