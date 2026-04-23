package com.credtrack.backend.scheduler;

import com.credtrack.backend.dto.BillExtractionResult;
import com.credtrack.backend.dto.StatementExtractionResult;
import com.credtrack.backend.dto.StatementExtractionResult.ExtractedTransaction;
import com.credtrack.backend.entity.CardStatement;
import com.credtrack.backend.entity.Transaction;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.entity.UtilityBill;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.TransactionRepository;
import com.credtrack.backend.repository.UtilityBillRepository;
import com.credtrack.backend.service.FirebaseStorageService;
import com.credtrack.backend.service.PdfExtractionService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Polls every 2 minutes for PENDING PDF uploads, extracts data, and auto-applies
 * when confident (AWAITING_CONFIRMATION → EXTRACTED).
 * Only leaves WRONG_STATEMENT for user review.
 */
@Component
public class PdfExtractionScheduler {

    private static final Logger log = LoggerFactory.getLogger(PdfExtractionScheduler.class);

    private final CardStatementRepository statementRepo;
    private final UtilityBillRepository   billRepo;
    private final TransactionRepository   transactionRepo;
    private final FirebaseStorageService  storageService;
    private final PdfExtractionService    extractionService;

    public PdfExtractionScheduler(CardStatementRepository statementRepo,
                                  UtilityBillRepository billRepo,
                                  TransactionRepository transactionRepo,
                                  FirebaseStorageService storageService,
                                  PdfExtractionService extractionService) {
        this.statementRepo     = statementRepo;
        this.billRepo          = billRepo;
        this.transactionRepo   = transactionRepo;
        this.storageService    = storageService;
        this.extractionService = extractionService;
    }

    @Scheduled(fixedDelay = 120_000)
    @Transactional
    public void processPendingStatements() {
        List<CardStatement> pending = statementRepo.findByPdfStatusOrderByCreatedAtAsc("PENDING");
        if (pending.isEmpty()) return;

        log.info("PDF scheduler: processing {} pending statement(s)", pending.size());

        for (CardStatement stmt : pending) {
            try {
                stmt.setPdfStatus("EXTRACTING");
                statementRepo.save(stmt);

                byte[] bytes = storageService.downloadPdf(stmt.getFirebasePath());
                if (bytes == null || bytes.length == 0) {
                    fail(stmt, "PDF file not found in storage.");
                    continue;
                }

                StatementExtractionResult result = extractionService.extractStatement(stmt, bytes);
                stmt.setExtractedData(extractionService.toJson(result));

                if ("AWAITING_CONFIRMATION".equals(result.getStatus())) {
                    applyStatementExtraction(stmt, result);
                    stmt.setPdfStatus("EXTRACTED");
                    log.info("Statement {} → auto-applied (EXTRACTED)", stmt.getId());
                } else {
                    stmt.setPdfStatus(result.getStatus()); // WRONG_STATEMENT or FAILED
                    log.info("Statement {} extraction → {} (needs review)", stmt.getId(), result.getStatus());
                }
                statementRepo.save(stmt);

            } catch (Exception e) {
                log.error("Extraction error for statement {}: {}", stmt.getId(), e.getMessage(), e);
                fail(stmt, "Unexpected error: " + e.getMessage());
            }
        }
    }

    @Scheduled(fixedDelay = 120_000, initialDelay = 30_000)
    @Transactional
    public void processPendingBills() {
        List<UtilityBill> pending = billRepo.findByPdfStatusOrderByCreatedAtAsc("PENDING");
        if (pending.isEmpty()) return;

        log.info("PDF scheduler: processing {} pending bill(s)", pending.size());

        for (UtilityBill bill : pending) {
            try {
                bill.setPdfStatus("EXTRACTING");
                billRepo.save(bill);

                byte[] bytes = storageService.downloadPdf(bill.getFirebasePath());
                if (bytes == null || bytes.length == 0) {
                    failBill(bill, "PDF file not found in storage.");
                    continue;
                }

                BillExtractionResult result = extractionService.extractBill(bill, bytes);
                bill.setExtractedData(extractionService.toJson(result));

                if ("AWAITING_CONFIRMATION".equals(result.getStatus())) {
                    applyBillExtraction(bill, result);
                    bill.setPdfStatus("EXTRACTED");
                    log.info("Bill {} → auto-applied (EXTRACTED)", bill.getId());
                } else {
                    bill.setPdfStatus(result.getStatus()); // WRONG_STATEMENT or FAILED
                    log.info("Bill {} extraction → {} (needs review)", bill.getId(), result.getStatus());
                }
                billRepo.save(bill);

            } catch (Exception e) {
                log.error("Extraction error for bill {}: {}", bill.getId(), e.getMessage(), e);
                failBill(bill, "Unexpected error: " + e.getMessage());
            }
        }
    }

    private void applyStatementExtraction(CardStatement stmt, StatementExtractionResult result) {
        if (result.getStatementBalance() != null)
            stmt.setStatementBalance(BigDecimal.valueOf(result.getStatementBalance()));
        if (result.getMinimumDue() != null)
            stmt.setMinimumDue(BigDecimal.valueOf(result.getMinimumDue()));
        if (result.getDueDate() != null)
            try { stmt.setDueDate(LocalDate.parse(result.getDueDate())); } catch (Exception ignored) {}
        if (result.getStatementDate() != null)
            try { stmt.setStatementDate(LocalDate.parse(result.getStatementDate())); } catch (Exception ignored) {}

        UserCard card = stmt.getUserCard();
        if (card != null && result.getTransactions() != null && !result.getTransactions().isEmpty()) {
            LocalDate periodStart = parseDateSafe(result.getBillingPeriodStart());
            LocalDate periodEnd   = parseDateSafe(result.getBillingPeriodEnd());
            if (periodStart == null && stmt.getStatementDate() != null)
                periodStart = stmt.getStatementDate().minusDays(30);
            if (periodEnd == null && stmt.getStatementDate() != null)
                periodEnd = stmt.getStatementDate();

            if (periodStart != null && periodEnd != null) {
                int deleted = transactionRepo.deleteByUserCard_IdAndTransactionDateBetween(
                        card.getId(), periodStart, periodEnd);
                log.debug("Deleted {} Gmail transactions for statement {}", deleted, stmt.getId());

                String bankKey = card.getCardProduct() != null ? card.getCardProduct().getBankKey() : null;
                int idx = 0;
                for (ExtractedTransaction txn : result.getTransactions()) {
                    LocalDate txnDate = parseDateSafe(txn.getDate());
                    if (txnDate == null) continue;
                    String syntheticId = "PDF-" + stmt.getId() + "-" + (idx++);
                    if (transactionRepo.existsByGmailMessageId(syntheticId)) continue;
                    transactionRepo.save(Transaction.builder()
                            .user(stmt.getUser())
                            .userCard(card)
                            .gmailMessageId(syntheticId)
                            .merchantName(txn.getMerchantName())
                            .amount(BigDecimal.valueOf(txn.getAmount()))
                            .transactionDate(txnDate)
                            .cardLastFour(card.getLastFour())
                            .transactionType(txn.getType() != null ? txn.getType() : "PURCHASE")
                            .status("CONFIRMED")
                            .bankKey(bankKey)
                            .build());
                }
            }
        }
    }

    private void applyBillExtraction(UtilityBill bill, BillExtractionResult result) {
        if (result.getAmountDue() != null)
            bill.setAmountDue(BigDecimal.valueOf(result.getAmountDue()));
        if (result.getDueDate() != null)
            try { bill.setDueDate(LocalDate.parse(result.getDueDate())); } catch (Exception ignored) {}
        if (result.getBillDate() != null)
            try { bill.setBillDate(LocalDate.parse(result.getBillDate())); } catch (Exception ignored) {}
        if (result.getBillingPeriodStart() != null)
            try { bill.setBillingPeriodStart(LocalDate.parse(result.getBillingPeriodStart())); } catch (Exception ignored) {}
        if (result.getBillingPeriodEnd() != null)
            try { bill.setBillingPeriodEnd(LocalDate.parse(result.getBillingPeriodEnd())); } catch (Exception ignored) {}
    }

    private void fail(CardStatement stmt, String reason) {
        try {
            stmt.setExtractedData(extractionService.toJson(
                    StatementExtractionResult.builder().status("FAILED").failureReason(reason).build()));
            stmt.setPdfStatus("FAILED");
            statementRepo.save(stmt);
        } catch (Exception ignored) {}
    }

    private void failBill(UtilityBill bill, String reason) {
        try {
            bill.setExtractedData(extractionService.toJson(
                    BillExtractionResult.builder().status("FAILED").failureReason(reason).build()));
            bill.setPdfStatus("FAILED");
            billRepo.save(bill);
        } catch (Exception ignored) {}
    }

    private LocalDate parseDateSafe(String iso) {
        if (iso == null) return null;
        try { return LocalDate.parse(iso); } catch (Exception e) { return null; }
    }
}
