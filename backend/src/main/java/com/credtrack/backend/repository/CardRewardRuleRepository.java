package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CardRewardRule;
import com.credtrack.backend.entity.RuleSource;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;

public interface CardRewardRuleRepository extends JpaRepository<CardRewardRule, Long> {

    @Query("""
        SELECT r FROM CardRewardRule r
        WHERE r.cardProduct.id IN :cardProductIds
          AND r.effectiveFrom <= :asOf
          AND (r.effectiveTo IS NULL OR r.effectiveTo >= :asOf)
        ORDER BY r.cardProduct.id, r.canonicalCategory, r.rateBps DESC
    """)
    List<CardRewardRule> findActiveForCardProducts(
        @Param("cardProductIds") List<Long> cardProductIds,
        @Param("asOf") LocalDate asOf
    );

    @Modifying
    @Query("DELETE FROM CardRewardRule r WHERE r.cardProduct.id = :cardProductId AND r.source = :source")
    int deleteByCardProductIdAndSource(@Param("cardProductId") Long cardProductId,
                                       @Param("source") RuleSource source);
}
