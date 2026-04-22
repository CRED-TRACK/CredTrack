package com.credtrack.backend.repository;

import com.credtrack.backend.entity.UtilityPayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface UtilityPaymentRepository extends JpaRepository<UtilityPayment, Long> {

    boolean existsByGmailMessageId(String gmailMessageId);

    List<UtilityPayment> findByBill_Id(Long billId);

    /** Orphan payments (no bill matched yet) for a user+biller+account. */
    List<UtilityPayment> findByUser_IdAndBillerNameAndAccountLastFourAndBillIsNull(
            String userId, String billerName, String accountLastFour);

    /**
     * Orphan payments whose paymentDate falls within [windowStart, windowEnd].
     * Used when a new bill arrives to match only the payments that chronologically
     * belong to that bill's billing period — prevents all orphans from being
     * dumped onto the first bill saved.
     */
    @Query("""
            SELECT p FROM UtilityPayment p
            WHERE p.user.id          = :userId
              AND p.billerName        = :billerName
              AND p.accountLastFour   = :accountLastFour
              AND p.bill              IS NULL
              AND p.paymentDate      >= :windowStart
              AND p.paymentDate      <= :windowEnd
            ORDER BY p.paymentDate ASC
            """)
    List<UtilityPayment> findOrphansInWindow(
            @Param("userId")         String    userId,
            @Param("billerName")     String    billerName,
            @Param("accountLastFour") String   accountLastFour,
            @Param("windowStart")    LocalDate windowStart,
            @Param("windowEnd")      LocalDate windowEnd);

    /** Sum of all payment amounts linked to a specific bill. */
    @Query("SELECT COALESCE(SUM(p.paymentAmount), 0) FROM UtilityPayment p WHERE p.bill.id = :billId")
    BigDecimal sumPaymentAmountByBillId(@Param("billId") Long billId);

    /** Delete all payments for a given user+biller+account. Used by the reset endpoint. */
    @Transactional
    int deleteByUser_IdAndBillerNameAndAccountLastFour(
            String userId, String billerName, String accountLastFour);
}
