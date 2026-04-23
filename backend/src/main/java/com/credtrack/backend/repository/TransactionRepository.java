package com.credtrack.backend.repository;

import com.credtrack.backend.entity.Transaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    boolean existsByGmailMessageId(String gmailMessageId);

    Optional<Transaction> findByIdAndUser_Id(Long id, String userId);

    Page<Transaction> findByUser_IdOrderByTransactionDateDesc(String userId, Pageable pageable);

    @Query("""
        SELECT t FROM Transaction t
        WHERE t.user.id = :userId
          AND (:cardId IS NULL OR t.userCard.id = :cardId)
          AND (:startDate IS NULL OR t.transactionDate >= :startDate)
          AND (:endDate IS NULL OR t.transactionDate <= :endDate)
          AND (:type IS NULL OR t.transactionType = :type)
          AND (:search IS NULL OR LOWER(t.merchantName) LIKE CONCAT('%', LOWER(CAST(:search AS string)), '%'))
        ORDER BY t.transactionDate DESC
        """)
    Page<Transaction> findFiltered(
            @Param("userId") String userId,
            @Param("cardId") Long cardId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate,
            @Param("type") String type,
            @Param("search") String search,
            Pageable pageable);

    @Query("""
        SELECT t.merchantCategory, SUM(t.amount), COUNT(t)
        FROM Transaction t
        WHERE t.user.id = :userId
          AND t.transactionDate >= :from
          AND t.transactionDate <= :to
          AND t.transactionType = 'PURCHASE'
        GROUP BY t.merchantCategory
        ORDER BY SUM(t.amount) DESC
        """)
    List<Object[]> summarizeByCategory(
            @Param("userId") String userId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);

    @Query("""
        SELECT t.userCard.id, SUM(t.amount), COUNT(t)
        FROM Transaction t
        WHERE t.user.id = :userId
          AND t.transactionDate >= :from
          AND t.transactionDate <= :to
          AND t.transactionType = 'PURCHASE'
          AND t.userCard IS NOT NULL
        GROUP BY t.userCard.id
        ORDER BY SUM(t.amount) DESC
        """)
    List<Object[]> summarizeByCard(
            @Param("userId") String userId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);

    @Query("""
        SELECT t FROM Transaction t
        WHERE t.user.id = :userId
          AND t.userCard.id = :userCardId
          AND t.transactionDate > :since
        ORDER BY t.transactionDate DESC
        """)
    List<Transaction> findUnbilledTransactions(
            @Param("userId") String userId,
            @Param("userCardId") Long userCardId,
            @Param("since") LocalDate since);

    /** Delete transactions for a card within a date range — used when applying PDF extraction. */
    @Transactional
    @Modifying
    @Query("DELETE FROM Transaction t WHERE t.userCard.id = :cardId AND t.transactionDate >= :from AND t.transactionDate <= :to")
    int deleteByUserCard_IdAndTransactionDateBetween(
            @Param("cardId") Long cardId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);

    /** Hard-delete all linked transactions for a card — used when a card is removed. */
    @Transactional
    void deleteByUserCard_Id(Long userCardId);

    /**
     * Hard-delete orphaned transactions (user_card_id IS NULL) that belong to this card
     * by matching userId + lastFour + bankKey. These have no direct FK to UserCard but
     * their gmail_message_id would block re-import if the card is re-added.
     */
    @Transactional
    @Modifying
    @Query("DELETE FROM Transaction t WHERE t.user.id = :userId AND t.cardLastFour = :lastFour AND t.bankKey = :bankKey AND t.userCard IS NULL")
    int deleteOrphansByUser_IdAndCardLastFourAndBankKey(
            @Param("userId") String userId,
            @Param("lastFour") String lastFour,
            @Param("bankKey") String bankKey);
}
