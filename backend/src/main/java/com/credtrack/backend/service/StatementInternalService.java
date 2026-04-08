package com.credtrack.backend.service;

import com.credtrack.backend.dto.CardStatementResponse;
import com.credtrack.backend.dto.StatementCreateRequest;
import com.credtrack.backend.entity.CardStatement;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.UserCardRepository;
import com.credtrack.backend.repository.UserRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class StatementInternalService {

    private final CardStatementRepository statementRepo;
    private final UserRepository          userRepo;
    private final UserCardRepository      userCardRepo;

    public StatementInternalService(CardStatementRepository statementRepo,
                                    UserRepository userRepo,
                                    UserCardRepository userCardRepo) {
        this.statementRepo = statementRepo;
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
                    .filter(uc -> req.getCardLastFour().equals(uc.getLastFour())
                               && Boolean.TRUE.equals(uc.getIsActive()))
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
                userCardRepo.save(userCard);
            }

            return CardStatementResponse.from(saved);
        } catch (DataIntegrityViolationException e) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Duplicate statement: " + req.getGmailMessageId());
        }
    }
}
