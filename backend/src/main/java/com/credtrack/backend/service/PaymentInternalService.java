package com.credtrack.backend.service;

import com.credtrack.backend.dto.PaymentCreateRequest;
import com.credtrack.backend.entity.CardPayment;
import com.credtrack.backend.entity.CardStatement;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.repository.CardPaymentRepository;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.UserCardRepository;
import com.credtrack.backend.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PaymentInternalService {

    private static final Logger log = LoggerFactory.getLogger(PaymentInternalService.class);

    private final CardPaymentRepository   paymentRepo;
    private final CardStatementRepository statementRepo;
    private final UserCardRepository      userCardRepo;
    private final UserRepository          userRepo;

    public PaymentInternalService(CardPaymentRepository paymentRepo,
                                  CardStatementRepository statementRepo,
                                  UserCardRepository userCardRepo,
                                  UserRepository userRepo) {
        this.paymentRepo   = paymentRepo;
        this.statementRepo = statementRepo;
        this.userCardRepo  = userCardRepo;
        this.userRepo      = userRepo;
    }

    @Transactional
    public void create(PaymentCreateRequest req) {
        // Dedup guard — same payment email must not be processed twice
        if (paymentRepo.existsByGmailMessageId(req.getGmailMessageId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Payment already processed for gmailMessageId: " + req.getGmailMessageId());
        }

        User user = userRepo.findById(req.getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        // Best-effort card match — same suffix logic as StatementInternalService
        UserCard userCard = null;
        if (req.getCardLastFour() != null) {
            userCard = userCardRepo.findByUser_IdOrderByAddedAtDesc(req.getUserId()).stream()
                    .filter(uc -> Boolean.TRUE.equals(uc.getIsActive())
                               && (req.getCardLastFour().equals(uc.getLastFour())
                                   || uc.getLastFour().endsWith(req.getCardLastFour())
                                   || req.getCardLastFour().endsWith(uc.getLastFour())))
                    .findFirst()
                    .orElse(null);
        }

        // Always persist the payment — orphan payments (no statement yet) are matched
        // retroactively by StatementInternalService when the statement email arrives later
        CardPayment payment = CardPayment.builder()
                .user(user)
                .userCard(userCard)
                .gmailMessageId(req.getGmailMessageId())
                .cardLastFour(req.getCardLastFour())
                .bank(req.getBank())
                .amount(req.getAmount())
                .paymentDate(req.getPaymentDate())
                .effectiveDate(req.getEffectiveDate())
                .build();

        if (userCard == null) {
            paymentRepo.save(payment);
            log.warn("No registered card found for userId={} lastFour={} — payment saved as orphan",
                    req.getUserId(), req.getCardLastFour());
            return;
        }

        // ── Statement matching (3-tier, most precise first) ────────────────────────────────
        //
        // Tier 1 — Amount match: statementBalance == paymentAmount.
        //   Works for banks that include the balance in the statement email (Chase, BOA, Discover).
        //   Immune to concurrent-payment races because each statement has a unique balance.
        CardStatement stmt = null;
        if (req.getAmount() != null) {
            stmt = statementRepo
                    .findFirstByUserCard_IdAndStatementBalanceAndIsPaidFalse(userCard.getId(), req.getAmount())
                    .orElse(null);
        }

        // Tier 2 — Due-date match: earliest unpaid statement whose due date ≥ payment date.
        //   For banks whose statement email never includes a dollar balance (e.g. Amex).
        //   Payment Jan 8 → dueDate Feb 1; payment Feb 5 → dueDate Mar 1; etc.
        //   Each billing cycle has a unique due date, so concurrent payments safely get
        //   different statements — eliminates the "all grab oldest" race condition.
        if (stmt == null && req.getPaymentDate() != null) {
            stmt = statementRepo
                    .findFirstByUserCard_IdAndIsPaidFalseAndDueDateGreaterThanEqualOrderByDueDateAsc(
                            userCard.getId(), req.getPaymentDate())
                    .orElse(null);
            if (stmt != null) {
                log.info("Date-based match: payment {} ({}) → statement id={} dueDate={}",
                        req.getGmailMessageId(), req.getPaymentDate(), stmt.getId(), stmt.getDueDate());
            }
        }

        // Tier 3 — Last-resort: oldest null-balance unpaid statement (no due date stored).
        if (stmt == null) {
            stmt = statementRepo
                    .findTopByUserCard_IdAndStatementBalanceIsNullAndIsPaidFalseOrderByStatementDateAsc(userCard.getId())
                    .orElse(null);
            if (stmt != null) {
                log.warn("Last-resort fallback: payment {} → oldest null-balance statement id={} for cardId={}",
                        req.getGmailMessageId(), stmt.getId(), userCard.getId());
            }
        }

        if (stmt != null) {
            stmt.setIsPaid(true);
            stmt.setPaidAmount(req.getAmount());
            stmt.setPaymentDate(req.getPaymentDate());
            statementRepo.save(stmt);

            payment.setMatchedStatement(stmt);

            // Atomic conditional UPDATE — lets the DB enforce "latest date wins".
            // All concurrent payment transactions may issue this simultaneously; only the one
            // carrying the most recent date will satisfy the WHERE clause and update the row.
            // This eliminates the read-check-write race where all transactions read null,
            // all pass an in-Java isMoreRecent check, and the last committer wins arbitrarily.
            if (req.getPaymentDate() != null) {
                int updated = userCardRepo.updateLastPaymentIfMoreRecent(
                        userCard.getId(), req.getPaymentDate(), req.getAmount());
                if (updated == 0) {
                    log.debug("Card {} already has a more-recent payment date — skipping lastPayment update",
                            userCard.getId());
                }
            }

            log.info("Statement id={} marked paid for cardId={} amount={} paymentDate={}",
                    stmt.getId(), userCard.getId(), req.getAmount(), req.getPaymentDate());
        } else {
            // No statement matched — saved as orphan for retroactive matching later
            log.info("No unpaid statement matched for cardId={} paymentDate={} — saved as orphan",
                    userCard.getId(), req.getPaymentDate());
        }

        paymentRepo.save(payment);
    }
}
