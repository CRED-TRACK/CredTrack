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

        // Primary: match by payment amount == statement balance.
        // This avoids the race condition where concurrent payments all grab the same "oldest unpaid".
        CardStatement stmt = null;
        if (req.getAmount() != null) {
            stmt = statementRepo
                    .findFirstByUserCard_IdAndStatementBalanceAndIsPaidFalse(userCard.getId(), req.getAmount())
                    .orElse(null);
        }

        // Fallback for banks where statement balance is never extracted (e.g. Amex — the statement
        // email only contains links, no dollar amount). Match to oldest unpaid statement with null balance.
        if (stmt == null) {
            stmt = statementRepo
                    .findTopByUserCard_IdAndStatementBalanceIsNullAndIsPaidFalseOrderByStatementDateAsc(userCard.getId())
                    .orElse(null);
            if (stmt != null) {
                log.info("Amount match failed; falling back to oldest null-balance statement id={} for cardId={}",
                        stmt.getId(), userCard.getId());
            }
        }

        if (stmt != null) {
            stmt.setIsPaid(true);
            stmt.setPaidAmount(req.getAmount());
            stmt.setPaymentDate(req.getPaymentDate());
            statementRepo.save(stmt);

            payment.setMatchedStatement(stmt);

            // Update UserCard last payment fields
            userCard.setLastPaymentDate(req.getPaymentDate());
            userCard.setLastPaymentAmount(req.getAmount());
            userCardRepo.save(userCard);

            log.info("Statement id={} marked paid for cardId={} amount={} paymentDate={}",
                    stmt.getId(), userCard.getId(), req.getAmount(), req.getPaymentDate());
        } else {
            // No statement matched — saved as orphan
            log.info("No unpaid statement matched amount={} for cardId={} — payment saved as orphan",
                    req.getAmount(), userCard.getId());
        }

        paymentRepo.save(payment);
    }
}
