package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CardPayment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CardPaymentRepository extends JpaRepository<CardPayment, Long> {

    boolean existsByGmailMessageId(String gmailMessageId);

    // Oldest unmatched payment for a card — used when a new statement arrives
    // to auto-mark it paid if the user paid before the statement email was sent
    Optional<CardPayment> findTopByUserCard_IdAndMatchedStatementIsNullOrderByPaymentDateAsc(Long userCardId);
}
