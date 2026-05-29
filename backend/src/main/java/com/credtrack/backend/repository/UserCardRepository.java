package com.credtrack.backend.repository;

import com.credtrack.backend.entity.UserCard;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface UserCardRepository extends JpaRepository<UserCard, Long> {

    List<UserCard> findByUser_IdAndIsActiveTrueOrderByAddedAtDesc(String userId);

    List<UserCard> findByUser_IdOrderByAddedAtDesc(String userId);

    Optional<UserCard> findByIdAndUser_Id(Long id, String userId);

    boolean existsByUser_IdAndCardProduct_IdAndLastFour(
            String userId, Long cardProductId, String lastFour);

    /**
     * Atomically updates lastPaymentDate / lastPaymentAmount only when the supplied date
     * is strictly more recent than whatever is already stored (or the field is null).
     *
     * This is the correct fix for the concurrent-payment race: multiple transactions
     * may call this simultaneously, but the DB-level WHERE clause ensures the row is
     * updated only by the transaction carrying the latest date — no pessimistic lock needed.
     *
     * @return 1 if the row was updated, 0 if an equally-or-more-recent date already exists.
     */
    @Modifying
    @Query("UPDATE UserCard uc " +
           "SET uc.lastPaymentDate = :date, uc.lastPaymentAmount = :amount " +
           "WHERE uc.id = :id " +
           "  AND (uc.lastPaymentDate IS NULL OR uc.lastPaymentDate < :date)")
    int updateLastPaymentIfMoreRecent(@Param("id")     Long       id,
                                      @Param("date")   LocalDate  date,
                                      @Param("amount") BigDecimal amount);

    /** Distinct card_product_id values that ≥1 active user_card references. */
    @Query("SELECT DISTINCT uc.cardProduct.id FROM UserCard uc WHERE uc.isActive = true")
    List<Long> findDistinctActiveCardProductIds();
}
