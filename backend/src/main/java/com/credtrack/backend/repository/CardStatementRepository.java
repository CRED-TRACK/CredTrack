package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CardStatement;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

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
    // statementDate <= paymentDate ensures we only match statements that had already closed
    // before the payment was made, preventing mid-cycle payments from being matched to
    // the still-open statement they were made during.
    Optional<CardStatement> findFirstByUserCard_IdAndIsPaidFalseAndStatementDateLessThanEqualAndDueDateGreaterThanEqualOrderByDueDateAsc(
            Long userCardId, java.time.LocalDate paymentDate, java.time.LocalDate paymentDate2);

    // Last-resort fallback — oldest null-balance unpaid statement (no due date available).
    Optional<CardStatement> findTopByUserCard_IdAndStatementBalanceIsNullAndIsPaidFalseOrderByStatementDateAsc(Long userCardId);

    // Oldest unpaid statement — orphan auto-match on statement arrival
    Optional<CardStatement> findTopByUserCard_IdAndIsPaidFalseOrderByStatementDateAsc(Long userCardId);

    /** Find statements with a given PDF status, oldest first — used by the extraction scheduler. */
    List<CardStatement> findByPdfStatusOrderByCreatedAtAsc(String pdfStatus);

    /** Collect firebase paths for all statements linked to a card — used before deletion to purge storage. */
    @Query("SELECT s.firebasePath FROM CardStatement s WHERE s.userCard.id = :cardId AND s.firebasePath IS NOT NULL")
    List<String> findFirebasePathsByUserCard_Id(@Param("cardId") Long cardId);

    /** Hard-delete all linked statements for a card — used when a card is removed. */
    @Transactional
    void deleteByUserCard_Id(Long userCardId);

    /**
     * Hard-delete orphaned statements (user_card_id IS NULL) that belong to this card
     * by matching userId + lastFour + bank. These have no direct FK to UserCard but
     * their gmail_message_id would block re-import if the card is re-added.
     */
    @Transactional
    @Modifying
    @Query("DELETE FROM CardStatement s WHERE s.user.id = :userId AND s.cardLastFour = :lastFour AND s.bank = :bankKey AND s.userCard IS NULL")
    int deleteOrphansByUser_IdAndCardLastFourAndBank(
            @Param("userId") String userId,
            @Param("lastFour") String lastFour,
            @Param("bankKey") String bankKey);
}
