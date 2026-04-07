package com.credtrack.backend.service;

import com.credtrack.backend.dto.TransactionResponse;
import com.credtrack.backend.dto.TransactionSummaryResponse;
import com.credtrack.backend.dto.TransactionSummaryResponse.CardSummary;
import com.credtrack.backend.dto.TransactionSummaryResponse.CategorySummary;
import com.credtrack.backend.entity.Transaction;
import com.credtrack.backend.repository.TransactionRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class TransactionQueryService {

    private final TransactionRepository repo;

    public TransactionQueryService(TransactionRepository repo) {
        this.repo = repo;
    }

    public Page<TransactionResponse> list(String userId, Long cardId,
                                          LocalDate startDate, LocalDate endDate,
                                          String type, String search,
                                          int page, int size) {
        return repo.findFiltered(userId, cardId, startDate, endDate, type, search,
                        PageRequest.of(page, size))
                .map(TransactionResponse::from);
    }

    public TransactionResponse get(Long id, String userId) {
        Transaction t = repo.findByIdAndUser_Id(id, userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Transaction not found"));
        return TransactionResponse.from(t);
    }

    public TransactionSummaryResponse summary(String userId, String month) {
        YearMonth ym = (month != null) ? YearMonth.parse(month) : YearMonth.now();
        LocalDate from = ym.atDay(1);
        LocalDate to   = ym.atEndOfMonth();

        List<Object[]> byCat  = repo.summarizeByCategory(userId, from, to);
        List<Object[]> byCard = repo.summarizeByCard(userId, from, to);

        BigDecimal total = byCat.stream()
                .map(r -> (BigDecimal) r[1])
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        long totalCount = byCat.stream()
                .mapToLong(r -> (Long) r[2])
                .sum();

        List<CategorySummary> catSummaries = byCat.stream()
                .map(r -> CategorySummary.builder()
                        .category((String) r[0])
                        .totalSpent((BigDecimal) r[1])
                        .count((Long) r[2])
                        .build())
                .toList();

        List<CardSummary> cardSummaries = byCard.stream()
                .map(r -> CardSummary.builder()
                        .userCardId((Long) r[0])
                        .totalSpent((BigDecimal) r[1])
                        .count((Long) r[2])
                        .build())
                .toList();

        return TransactionSummaryResponse.builder()
                .month(ym.toString())
                .totalSpent(total)
                .transactionCount(totalCount)
                .byCategory(catSummaries)
                .byCard(cardSummaries)
                .build();
    }
}
