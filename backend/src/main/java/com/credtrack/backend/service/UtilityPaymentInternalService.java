package com.credtrack.backend.service;

import com.credtrack.backend.dto.UtilityPaymentCreateRequest;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.entity.UtilityBill;
import com.credtrack.backend.entity.UtilityPayment;
import com.credtrack.backend.repository.UserRepository;
import com.credtrack.backend.repository.UtilityBillRepository;
import com.credtrack.backend.repository.UtilityPaymentRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

@Service
public class UtilityPaymentInternalService {

    private static final Logger log = LoggerFactory.getLogger(UtilityPaymentInternalService.class);

    private final UtilityPaymentRepository paymentRepo;
    private final UtilityBillRepository    billRepo;
    private final UserRepository           userRepo;

    public UtilityPaymentInternalService(UtilityPaymentRepository paymentRepo,
                                         UtilityBillRepository billRepo,
                                         UserRepository userRepo) {
        this.paymentRepo = paymentRepo;
        this.billRepo    = billRepo;
        this.userRepo    = userRepo;
    }

    @Transactional
    public void create(UtilityPaymentCreateRequest req) {
        // Dedup guard
        if (paymentRepo.existsByGmailMessageId(req.getGmailMessageId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Utility payment already processed for gmailMessageId: " + req.getGmailMessageId());
        }

        User user = userRepo.findById(req.getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        // 1. Try exact amount match first — handles the common case where the user pays the
        //    exact bill amount and multiple open bills exist simultaneously (historical init scan).
        // 2. Fall back to date-proximity: the open bill whose dueDate is closest to the
        //    payment date, within a ±90 day window. This correctly handles installment payments
        //    (two payments for the same bill) and slight overpayments (e.g. $120 for a $119.52 bill).
        //    Payments are processed in chronological order so each one "claims" the nearest open bill.
        // 3. Last resort: the absolute earliest open bill (catches orphan payments with no date).
        UtilityBill bill = billRepo
                .findTopByUser_IdAndBillerNameAndAccountLastFourAndIsPaidFalseAndAmountDueOrderByDueDateAsc(
                        req.getUserId(), req.getBillerName(), req.getAccountLastFour(), req.getPaymentAmount())
                .orElseGet(() -> findBestMatchingBill(
                        req.getUserId(), req.getBillerName(), req.getAccountLastFour(), req.getPaymentDate())
                        .orElse(null));

        UtilityPayment payment = UtilityPayment.builder()
                .user(user)
                .bill(bill)   // null = orphan payment; matched when bill email arrives
                .billerName(req.getBillerName())
                .accountLastFour(req.getAccountLastFour())
                .gmailMessageId(req.getGmailMessageId())
                .paymentAmount(req.getPaymentAmount())
                .paymentDate(req.getPaymentDate())
                .build();

        paymentRepo.save(payment);

        if (bill == null) {
            log.info("No open bill found for user={} biller={} acct={} — payment saved as orphan",
                    req.getUserId(), req.getBillerName(), req.getAccountLastFour());
            return;
        }

        // Recompute total paid across all payments on this bill and auto-mark if covered
        BigDecimal total = paymentRepo.sumPaymentAmountByBillId(bill.getId());
        bill.setTotalPaid(total);

        if (bill.getAmountDue() != null && total.compareTo(bill.getAmountDue()) >= 0) {
            bill.setIsPaid(true);
            log.info("Bill id={} marked paid — totalPaid={} amountDue={}",
                    bill.getId(), total, bill.getAmountDue());
        } else {
            log.info("Bill id={} partial payment — totalPaid={} of amountDue={}",
                    bill.getId(), total, bill.getAmountDue());
        }

        billRepo.save(bill);
    }

    /**
     * Date-proximity matching: returns the open bill whose dueDate is closest to
     * paymentDate, within a ±90 day window. Falls back to the absolute earliest
     * open bill when paymentDate is null or nothing is within the window.
     *
     * This correctly handles:
     *  - Installment payments: both payments for the same bill land on that bill
     *    because the same bill's dueDate is closest to both payment dates.
     *  - Slight overpayments ($120 for a $119.52 bill): close enough in date to
     *    match the right bill even though the amount isn't exact.
     *  - The historical init scan: all payments arrive in date order so each one
     *    "claims" the nearest open bill before subsequent payments are processed.
     */
    private Optional<UtilityBill> findBestMatchingBill(String userId, String billerName,
                                                        String accountLastFour, LocalDate paymentDate) {
        List<UtilityBill> openBills = billRepo
                .findByUser_IdAndBillerNameAndAccountLastFourAndIsPaidFalseOrderByDueDateAsc(
                        userId, billerName, accountLastFour);

        if (openBills.isEmpty()) return Optional.empty();
        if (paymentDate == null)  return Optional.of(openBills.get(0));

        // Match to the open bill whose dueDate is closest to paymentDate within ±90 days,
        // with a strong preference for UPCOMING bills (dueDate >= paymentDate) over overdue ones.
        //
        // Why: utility users typically pay early (before the due date). Treating upcoming bills
        // first means a payment made on Apr 17 for a May 9 bill wins over the Apr 9 bill that
        // just passed — which is the correct assignment for installment payments.
        // Overdue bills (dueDate < paymentDate) are only used as fallback when no upcoming bill
        // is within range, correctly handling slightly late payments.
        Optional<UtilityBill> proximate = openBills.stream()
                .filter(b -> b.getDueDate() != null)
                .filter(b -> Math.abs(ChronoUnit.DAYS.between(b.getDueDate(), paymentDate)) <= 90)
                .min(Comparator
                        // Primary: upcoming bills (dueDate >= paymentDate) rank before overdue
                        .comparingInt((UtilityBill b) -> b.getDueDate().isBefore(paymentDate) ? 1 : 0)
                        // Secondary: within each group, pick the closest due date
                        .thenComparingLong(b -> Math.abs(ChronoUnit.DAYS.between(b.getDueDate(), paymentDate))));

        return proximate.isPresent() ? proximate : Optional.of(openBills.get(0));
    }
}
