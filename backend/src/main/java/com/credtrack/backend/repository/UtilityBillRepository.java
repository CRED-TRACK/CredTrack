package com.credtrack.backend.repository;

import com.credtrack.backend.entity.UtilityBill;
import org.springframework.data.jpa.repository.JpaRepository;

import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface UtilityBillRepository extends JpaRepository<UtilityBill, Long> {

    boolean existsByGmailMessageId(String gmailMessageId);

    /**
     * Content-based dedup check — catches the case where the same bill is delivered
     * via two different emails (e.g. Eversource sends both a "bill ready" notification
     * and a "bill securely delivered" email for each billing cycle).
     * Returns true if a bill with the same user / biller / account / amount / due date
     * already exists, regardless of gmailMessageId.
     */
    boolean existsByUser_IdAndBillerNameAndAccountLastFourAndAmountDueAndDueDate(
            String userId, String billerName, String accountLastFour,
            BigDecimal amountDue, LocalDate dueDate);

    /** List all bills for a user, newest due date first (dueDate is always populated; billDate can be null). */
    List<UtilityBill> findByUser_IdOrderByDueDateDesc(String userId);

    /** List bills for a user filtered by biller, newest due date first. */
    List<UtilityBill> findByUser_IdAndBillerNameOrderByDueDateDesc(String userId, String billerName);

    /** Earliest open (unpaid) bill for a user+biller+account — last-resort fallback when matching a payment. */
    Optional<UtilityBill> findTopByUser_IdAndBillerNameAndAccountLastFourAndIsPaidFalseOrderByDueDateAsc(
            String userId, String billerName, String accountLastFour);

    /**
     * All open (unpaid) bills for a user+biller+account sorted by due date ascending.
     * Used by date-proximity matching so we can find the bill whose dueDate is
     * closest to the payment date (handles installments + overpayments correctly).
     */
    List<UtilityBill> findByUser_IdAndBillerNameAndAccountLastFourAndIsPaidFalseOrderByDueDateAsc(
            String userId, String billerName, String accountLastFour);

    /**
     * Earliest open (unpaid) bill whose amountDue exactly matches the payment amount.
     * Tried first by UtilityPaymentInternalService so that utility payments (which
     * virtually always equal the exact bill amount) are matched correctly even when
     * multiple bills are open simultaneously — e.g. during a historical init scan.
     */
    Optional<UtilityBill> findTopByUser_IdAndBillerNameAndAccountLastFourAndIsPaidFalseAndAmountDueOrderByDueDateAsc(
            String userId, String billerName, String accountLastFour, BigDecimal amountDue);

    /** Delete all bills for a given user+biller+account. Used by the reset endpoint. */
    @Transactional
    int deleteByUser_IdAndBillerNameAndAccountLastFour(
            String userId, String billerName, String accountLastFour);
}
