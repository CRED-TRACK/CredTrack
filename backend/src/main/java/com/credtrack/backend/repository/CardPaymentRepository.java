package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CardPayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

public interface CardPaymentRepository extends JpaRepository<CardPayment, Long> {

    boolean existsByGmailMessageId(String gmailMessageId);

    // Oldest unmatched payment for a card — used when a new statement arrives
    // to auto-mark it paid if the user paid before the statement email was sent
    Optional<CardPayment> findTopByUserCard_IdAndMatchedStatementIsNullOrderByPaymentDateAsc(Long userCardId);

    /** Hard-delete all linked payments for a card — used when a card is removed. */
    @Transactional
    void deleteByUserCard_Id(Long userCardId);

    /**
     * Hard-delete orphaned payments (user_card_id IS NULL) that belong to this card
     * by matching userId + lastFour + bank. These have no direct FK to UserCard but
     * their gmail_message_id would block re-import if the card is re-added.
     */
    @Transactional
    @Modifying
    @Query("DELETE FROM CardPayment p WHERE p.user.id = :userId AND p.cardLastFour = :lastFour AND p.bank = :bankKey AND p.userCard IS NULL")
    int deleteOrphansByUser_IdAndCardLastFourAndBank(@Param("userId") String userId,
                                                     @Param("lastFour") String lastFour,
                                                     @Param("bankKey") String bankKey);
}
