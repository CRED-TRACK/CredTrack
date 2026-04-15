package com.credtrack.backend.service;

import com.credtrack.backend.dto.CardStatementResponse;
import com.credtrack.backend.dto.StatementCreateRequest;
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
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class StatementInternalService {

    private static final Logger log = LoggerFactory.getLogger(StatementInternalService.class);

    private final CardStatementRepository statementRepo;
    private final CardPaymentRepository   paymentRepo;
    private final UserRepository          userRepo;
    private final UserCardRepository      userCardRepo;

    public StatementInternalService(CardStatementRepository statementRepo,
                                    CardPaymentRepository paymentRepo,
                                    UserRepository userRepo,
                                    UserCardRepository userCardRepo) {
        this.statementRepo = statementRepo;
        this.paymentRepo   = paymentRepo;
        this.userRepo      = userRepo;
        this.userCardRepo  = userCardRepo;
    }

    @Transactional
    public CardStatementResponse create(StatementCreateRequest req) {
        // Dedup guard — gmailMessageId is unique
        if (statementRepo.existsByGmailMessageId(req.getGmailMessageId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Statement already exists for gmailMessageId: " + req.getGmailMessageId());
        }

        User user = userRepo.findById(req.getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        // Best-effort card match by last four digits
        // Null if the card hasn't been added to CredTrack yet — statement still saved
        UserCard userCard = null;
        if (req.getCardLastFour() != null) {
            userCard = userCardRepo.findByUser_IdOrderByAddedAtDesc(user.getId()).stream()
                    .filter(uc -> Boolean.TRUE.equals(uc.getIsActive())
                               && (req.getCardLastFour().equals(uc.getLastFour())
                                   || uc.getLastFour().endsWith(req.getCardLastFour())
                                   || req.getCardLastFour().endsWith(uc.getLastFour())))
                    .findFirst()
                    .orElse(null);
        }

        CardStatement statement = CardStatement.builder()
                .user(user)
                .userCard(userCard)
                .gmailMessageId(req.getGmailMessageId())
                .cardLastFour(req.getCardLastFour())
                .bank(req.getBank())
                .statementDate(req.getStatementDate())
                .statementBalance(req.getStatementBalance())
                .minimumDue(req.getMinimumPaymentDue())
                .dueDate(req.getDueDate())
                .viewStatementUrl(req.getViewStatementUrl())
                .makePaymentUrl(req.getMakePaymentUrl())
                .build();

        try {
            CardStatement saved = statementRepo.save(statement);

            // Update UserCard with latest statement figures so the card detail
            // screen always shows current balance, minimum due, and payment due date
            if (userCard != null) {
                userCard.setStatementBalance(req.getStatementBalance());
                userCard.setMinimumDue(req.getMinimumPaymentDue());
                userCard.setPaymentDueDate(req.getDueDate());

                // Check for an orphan payment — user may have paid before the statement
                // email was sent (bank shows statement on app 1-2 days before emailing it).
                // Guard: only auto-match if the orphan payment date is within 45 days
                // before the statement date (prevents stale Dec payments matching Apr statements).
                if (saved.getStatementDate() != null) {
                    java.time.LocalDate statementDate = saved.getStatementDate();
                    java.time.LocalDate windowStart   = statementDate.minusDays(45);

                    CardPayment orphan = paymentRepo
                            .findTopByUserCard_IdAndMatchedStatementIsNullOrderByPaymentDateAsc(userCard.getId())
                            .orElse(null);

                    if (orphan != null && orphan.getPaymentDate() != null
                            && !orphan.getPaymentDate().isBefore(windowStart)
                            && !orphan.getPaymentDate().isAfter(statementDate)) {
                        saved.setIsPaid(true);
                        saved.setPaidAmount(orphan.getAmount());
                        saved.setPaymentDate(orphan.getPaymentDate());
                        statementRepo.save(saved);

                        orphan.setMatchedStatement(saved);
                        paymentRepo.save(orphan);

                        userCard.setLastPaymentDate(orphan.getPaymentDate());
                        userCard.setLastPaymentAmount(orphan.getAmount());

                        log.info("Orphan payment id={} auto-matched to new statement id={} for cardId={}",
                                orphan.getId(), saved.getId(), userCard.getId());
                    } else if (orphan != null) {
                        log.debug("Orphan payment id={} paymentDate={} outside 45-day window for statement date={} — skipped",
                                orphan.getId(), orphan.getPaymentDate(), statementDate);
                    }
                }

                userCardRepo.save(userCard);
            }

            return CardStatementResponse.from(saved);
        } catch (DataIntegrityViolationException e) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Duplicate statement: " + req.getGmailMessageId());
        }
    }
}
