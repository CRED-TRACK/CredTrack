package com.credtrack.backend.service;

import com.credtrack.backend.dto.TransactionResponse;
import com.credtrack.backend.dto.UnbilledSpendResponse;
import com.credtrack.backend.entity.Transaction;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.TransactionRepository;
import com.credtrack.backend.repository.UserCardRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Service
public class UnbilledSpendService {

    private final TransactionRepository    transactionRepo;
    private final CardStatementRepository  statementRepo;
    private final UserCardRepository       userCardRepo;

    public UnbilledSpendService(TransactionRepository transactionRepo,
                                CardStatementRepository statementRepo,
                                UserCardRepository userCardRepo) {
        this.transactionRepo = transactionRepo;
        this.statementRepo   = statementRepo;
        this.userCardRepo    = userCardRepo;
    }

    public UnbilledSpendResponse computeUnbilled(String userId, Long userCardId) {
        userCardRepo.findByIdAndUser_Id(userCardId, userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Card not found"));

        // Latest closed statement date — all transactions after this are unbilled.
        // If no statement exists yet, use epoch so all known transactions are included.
        LocalDate since = statementRepo
                .findTopByUserCard_IdOrderByStatementDateDesc(userCardId)
                .map(s -> s.getStatementDate())
                .orElse(LocalDate.EPOCH);

        List<Transaction> txns = transactionRepo.findUnbilledTransactions(userId, userCardId, since);

        BigDecimal total = txns.stream()
                .map(Transaction::getAmount)
                .filter(a -> a != null)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        List<TransactionResponse> responses = txns.stream()
                .map(TransactionResponse::from)
                .toList();

        return UnbilledSpendResponse.builder()
                .userCardId(userCardId)
                .since(since)
                .unbilledTotal(total)
                .transactions(responses)
                .build();
    }
}
