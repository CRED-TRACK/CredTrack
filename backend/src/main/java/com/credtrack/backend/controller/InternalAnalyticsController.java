package com.credtrack.backend.controller;

import com.credtrack.backend.entity.UtilityBill;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.UtilityBillRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/**
 * Internal raw-data endpoints consumed by the AI agent's AnalyticsWorkerActor.
 * Protected by X-Service-Key header (validated by ServiceKeyInterceptor).
 *
 * Card data is statement-based: groups CardStatement rows by YYYY-MM of statementDate,
 * using statementBalance with paidAmount as fallback (AMEX omits statementBalance).
 * Rows where both are null are skipped ("no data").
 */
@RestController
@RequestMapping("/internal/analytics")
public class InternalAnalyticsController {

    private final CardStatementRepository statementRepo;
    private final UtilityBillRepository   billRepo;

    public InternalAnalyticsController(CardStatementRepository statementRepo,
                                        UtilityBillRepository billRepo) {
        this.statementRepo = statementRepo;
        this.billRepo      = billRepo;
    }

    /**
     * GET /internal/analytics/card-data?userId=X&months=6
     *
     * Returns month-on-month statement data grouped by YYYY-MM.
     * Per statement: uses statementBalance first, paidAmount as fallback,
     * skips if both null.
     */
    @GetMapping("/card-data")
    @Transactional(readOnly = true)
    public ResponseEntity<CardStatementRawData> cardData(
            @RequestParam String userId,
            @RequestParam(defaultValue = "6") int months) {

        LocalDate from = LocalDate.now().minusMonths(months);
        List<Object[]> rows = statementRepo.findStatementsForAnalytics(userId, from);

        // month (YYYY-MM) → cardId → accumulated amount
        Map<String, Map<Long, double[]>> byMonthByCard = new LinkedHashMap<>();
        // cardId → [bankKey, lastFour]
        Map<Long, String[]> cardMeta = new HashMap<>();

        for (Object[] row : rows) {
            Long       cardId           = (Long)       row[0];
            String     bankKey          = (String)     row[1];
            String     lastFour         = (String)     row[2];
            LocalDate  statementDate    = (LocalDate)  row[3];
            BigDecimal statementBalance = (BigDecimal) row[4];
            BigDecimal paidAmount       = (BigDecimal) row[5];

            // COALESCE: statementBalance first, paidAmount fallback, skip if both null
            BigDecimal effective = statementBalance != null ? statementBalance
                    : paidAmount != null ? paidAmount : null;
            if (effective == null) continue;

            String month = statementDate.getYear() + "-"
                    + String.format("%02d", statementDate.getMonthValue());
            cardMeta.put(cardId, new String[]{bankKey, lastFour});

            Map<Long, double[]> cardMap = byMonthByCard.computeIfAbsent(month, k -> new LinkedHashMap<>());
            double[] amt = cardMap.computeIfAbsent(cardId, k -> new double[]{0});
            amt[0] += effective.doubleValue();
        }

        List<MonthData> monthlyData = byMonthByCard.entrySet().stream().map(e -> {
            List<MonthCardRow> cards = e.getValue().entrySet().stream().map(ce -> {
                String[] meta = cardMeta.get(ce.getKey());
                return new MonthCardRow(ce.getKey(), meta[0], meta[1], ce.getValue()[0]);
            }).toList();
            return new MonthData(e.getKey(), cards);
        }).toList();

        return ResponseEntity.ok(new CardStatementRawData(monthlyData));
    }

    /**
     * GET /internal/analytics/utility-data?userId=X
     */
    @GetMapping("/utility-data")
    @Transactional(readOnly = true)
    public ResponseEntity<UtilityRawData> utilityData(@RequestParam String userId) {
        List<UtilityBill> bills = billRepo.findByUser_IdOrderByDueDateDesc(userId);
        List<BillRow> billRows = bills.stream()
                .filter(b -> b.getAmountDue() != null)
                .map(b -> {
                    String date = b.getBillDate() != null ? b.getBillDate().toString()
                                : b.getDueDate() != null  ? b.getDueDate().toString() : null;
                    return date != null
                            ? new BillRow(b.getBillerName(), b.getAccountLastFour(),
                                          b.getAmountDue().doubleValue(), date)
                            : null;
                })
                .filter(Objects::nonNull)
                .toList();

        return ResponseEntity.ok(new UtilityRawData(billRows));
    }

    // ── Response records ───────────────────────────────────────────────────────

    public record CardStatementRawData(List<MonthData> monthlyData) {}

    public record MonthData(String month, List<MonthCardRow> cards) {}

    public record MonthCardRow(Long cardId, String bankKey, String lastFour, double amount) {}

    public record UtilityRawData(List<BillRow> bills) {}

    public record BillRow(String billerName, String accountLastFour,
                          double amountDue, String billDate) {}
}
