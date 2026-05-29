package com.credtrack.backend.repository;

import com.credtrack.backend.entity.UserCardCategoryChoice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface UserCardCategoryChoiceRepository extends JpaRepository<UserCardCategoryChoice, Long> {

    @Query("""
        SELECT c FROM UserCardCategoryChoice c
        WHERE c.userCard.id IN :userCardIds
          AND c.effectiveFrom <= :asOf
          AND (c.effectiveTo IS NULL OR c.effectiveTo >= :asOf)
    """)
    List<UserCardCategoryChoice> findActiveForUserCards(
        @Param("userCardIds") List<Long> userCardIds,
        @Param("asOf") LocalDate asOf
    );

    @Query("""
        SELECT c FROM UserCardCategoryChoice c
        WHERE c.userCard.id = :userCardId
          AND c.choiceKind = :choiceKind
          AND c.effectiveFrom <= :asOf
          AND (c.effectiveTo IS NULL OR c.effectiveTo >= :asOf)
        ORDER BY c.effectiveFrom DESC
    """)
    Optional<UserCardCategoryChoice> findActive(
        @Param("userCardId") Long userCardId,
        @Param("choiceKind") String choiceKind,
        @Param("asOf") LocalDate asOf
    );
}
