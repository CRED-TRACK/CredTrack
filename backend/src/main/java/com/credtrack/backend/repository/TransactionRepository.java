package com.credtrack.backend.repository;

import com.credtrack.backend.entity.Transaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

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
          AND (:search IS NULL OR LOWER(t.merchantName) LIKE LOWER(CONCAT('%', :search, '%')))
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
}
