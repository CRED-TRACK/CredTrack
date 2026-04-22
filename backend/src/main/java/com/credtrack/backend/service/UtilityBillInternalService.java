package com.credtrack.backend.service;

import com.credtrack.backend.dto.UtilityBillCreateRequest;
import com.credtrack.backend.dto.UtilityBillResponse;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.entity.UtilityBill;
import com.credtrack.backend.entity.UtilityPayment;
import com.credtrack.backend.entity.UserUtilityAccount;
import com.credtrack.backend.repository.UserRepository;
import com.credtrack.backend.repository.UserUtilityAccountRepository;
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
import java.util.List;

@Service
public class UtilityBillInternalService {

    private static final Logger log = LoggerFactory.getLogger(UtilityBillInternalService.class);

    private final UtilityBillRepository        billRepo;
    private final UtilityPaymentRepository     paymentRepo;
    private final UserRepository               userRepo;
    private final UserUtilityAccountRepository utilityAccountRepo;

    public UtilityBillInternalService(UtilityBillRepository billRepo,
                                      UtilityPaymentRepository paymentRepo,
                                      UserRepository userRepo,
                                      UserUtilityAccountRepository utilityAccountRepo) {
        this.billRepo           = billRepo;
        this.paymentRepo        = paymentRepo;
        this.userRepo           = userRepo;
        this.utilityAccountRepo = utilityAccountRepo;
    }

    @Transactional
    public UtilityBillResponse create(UtilityBillCreateRequest req) {
        // Dedup guard 1 — same email must not be processed twice
        if (billRepo.existsByGmailMessageId(req.getGmailMessageId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Utility bill already exists for gmailMessageId: " + req.getGmailMessageId());
        }

        // Dedup guard 2 — content-based: same biller + account + amount + due date.
        // Catches duplicate-email patterns where two different emails describe the same
        // billing cycle (e.g. Eversource "bill ready" + "bill securely delivered").
        if (req.getAmountDue() != null && req.getDueDate() != null
                && billRepo.existsByUser_IdAndBillerNameAndAccountLastFourAndAmountDueAndDueDate(
                        req.getUserId(), req.getBillerName(), req.getAccountLastFour(),
                        req.getAmountDue(), req.getDueDate())) {
            log.info("Skipping duplicate bill (same amount+dueDate already stored) — " +
                     "biller={} acct={} amount={} due={} gmailMsgId={}",
                    req.getBillerName(), req.getAccountLastFour(),
                    req.getAmountDue(), req.getDueDate(), req.getGmailMessageId());
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Duplicate utility bill (same amount+dueDate already stored): "
                    + req.getBillerName() + " $" + req.getAmountDue() + " due " + req.getDueDate());
        }

        User user = userRepo.findById(req.getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        // Best-effort link to registered utility account
        UserUtilityAccount account = utilityAccountRepo
                .findByUser_IdAndBillerNameAndAccountLastFour(
                        req.getUserId(), req.getBillerName(), req.getAccountLastFour())
                .orElse(null);

        UtilityBill bill = UtilityBill.builder()
                .user(user)
                .utilityAccount(account)
                .billerName(req.getBillerName())
                .accountLastFour(req.getAccountLastFour())
                .gmailMessageId(req.getGmailMessageId())
                .billDate(req.getBillDate())
                .billingPeriodStart(req.getBillingPeriodStart())
                .billingPeriodEnd(req.getBillingPeriodEnd())
                .amountDue(req.getAmountDue())
                .dueDate(req.getDueDate())
                .build();

        UtilityBill saved = billRepo.save(bill);

        // Link orphan payments (paid before bill email arrived) and recompute total.
        // Use a date-windowed query so only payments that chronologically belong to
        // THIS bill are matched — prevents all orphans from being dumped onto the
        // first bill saved (which happened when payments arrived before bills during init).
        LocalDate windowStart = req.getBillingPeriodStart() != null
                ? req.getBillingPeriodStart()
                : (req.getBillDate() != null
                        ? req.getBillDate().minusDays(30)
                        : req.getDueDate().minusDays(90));
        LocalDate windowEnd = req.getDueDate() != null
                ? req.getDueDate().plusDays(60)
                : LocalDate.now().plusDays(60);

        List<UtilityPayment> orphans = paymentRepo.findOrphansInWindow(
                req.getUserId(), req.getBillerName(), req.getAccountLastFour(),
                windowStart, windowEnd);

        if (!orphans.isEmpty()) {
            BigDecimal total = BigDecimal.ZERO;
            for (UtilityPayment p : orphans) {
                p.setBill(saved);
                paymentRepo.save(p);
                total = total.add(p.getPaymentAmount() != null ? p.getPaymentAmount() : BigDecimal.ZERO);
            }
            saved.setTotalPaid(total);
            if (saved.getAmountDue() != null && total.compareTo(saved.getAmountDue()) >= 0) {
                saved.setIsPaid(true);
                log.info("Bill id={} auto-marked paid from {} orphan payment(s), total={}",
                        saved.getId(), orphans.size(), total);
            }
            saved = billRepo.save(saved);
        }

        List<UtilityPayment> payments = paymentRepo.findByBill_Id(saved.getId());
        return UtilityBillResponse.from(saved, payments);
    }
}
