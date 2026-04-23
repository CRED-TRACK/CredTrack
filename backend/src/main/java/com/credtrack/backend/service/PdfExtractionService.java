package com.credtrack.backend.service;

import com.credtrack.backend.dto.BillExtractionResult;
import com.credtrack.backend.dto.StatementExtractionResult;
import com.credtrack.backend.dto.StatementExtractionResult.ExtractedTransaction;
import com.credtrack.backend.entity.CardStatement;
import com.credtrack.backend.entity.UtilityBill;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class PdfExtractionService {

    private static final Logger log = LoggerFactory.getLogger(PdfExtractionService.class);

    private static final int MAX_PDF_CHARS_FOR_LLM = 12_000;
    private static final Pattern JSON_BLOCK = Pattern.compile("\\{[\\s\\S]*}", Pattern.DOTALL);

    // Plain ObjectMapper — no SNAKE_CASE strategy — used to parse LLM JSON (camelCase)
    private static final ObjectMapper LLM_MAPPER = new ObjectMapper()
            .configure(com.fasterxml.jackson.databind.DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

    private final ObjectMapper objectMapper;
    private final ChatClient   chatClient;

    // Date formatters for normalizing various input formats to YYYY-MM-DD
    private static final List<DateTimeFormatter> DATE_FORMATS = List.of(
            DateTimeFormatter.ofPattern("MM/dd/yyyy"),
            DateTimeFormatter.ofPattern("MM/dd/yy"),
            DateTimeFormatter.ofPattern("M/dd/yy"),
            DateTimeFormatter.ofPattern("MMMM d, yyyy"),
            DateTimeFormatter.ofPattern("MMM d, yyyy"),
            DateTimeFormatter.ofPattern("MMMM dd, yyyy"),
            DateTimeFormatter.ofPattern("MMM dd, yyyy"),
            DateTimeFormatter.ofPattern("M/d/yyyy"),
            DateTimeFormatter.ofPattern("M/d/yy")
    );

    public PdfExtractionService(ObjectMapper objectMapper, ChatClient.Builder chatClientBuilder) {
        this.objectMapper = objectMapper;
        this.chatClient   = chatClientBuilder.build();
    }

    // ── Card Statement Extraction ─────────────────────────────────────────────

    public StatementExtractionResult extractStatement(CardStatement stmt, byte[] pdfBytes) {
        String text;
        try {
            text = extractText(pdfBytes);
        } catch (Exception e) {
            log.warn("PDFBox extraction failed for statement {}: {}", stmt.getId(), e.getMessage());
            return StatementExtractionResult.builder()
                    .status("FAILED")
                    .failureReason("Could not read PDF: " + e.getMessage())
                    .build();
        }

        if (text == null || text.isBlank()) {
            return StatementExtractionResult.builder()
                    .status("FAILED")
                    .failureReason("PDF appears to be empty or image-only (no extractable text).")
                    .build();
        }

        log.info("Extracted {} chars from statement PDF {}", text.length(), stmt.getId());

        String bankKey = stmt.getUserCard() != null && stmt.getUserCard().getCardProduct() != null
                ? stmt.getUserCard().getCardProduct().getBankKey() : null;

        StatementExtractionResult result = parseStatement(text, bankKey);
        validateStatement(result, stmt);
        return result;
    }

    private StatementExtractionResult parseStatement(String text, String bankKey) {
        StatementExtractionResult.StatementExtractionResultBuilder builder =
                StatementExtractionResult.builder();

        // ── Bank identification ──────────────────────────────────────────────
        String detectedBank = detectBank(text);
        builder.bank(detectedBank);

        // ── Card last four ───────────────────────────────────────────────────
        builder.cardLastFour(extractLastFour(text));

        // ── Statement / closing date ─────────────────────────────────────────
        String stmtDate = firstMatch(text,
                "(?i)(?:Statement|Closing|Statement Closing)\\s+Date[:\\s]+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r)",
                "(?i)Closing Date\\s+(\\d{2}/\\d{2}/\\d{2,4})");
        builder.statementDate(normalizeDate(stmtDate));

        // ── Billing period ───────────────────────────────────────────────────
        String periodStr = firstMatch(text,
                "(?i)(?:Opening|From)[:\\s]+([\\w/,\\s]+?)\\s+(?:to|through|–|-)",
                "(?i)Billing Period[:\\s]+([\\w/,\\s]+?)\\s+(?:to|through|–|-)\\s+([\\w/,\\s]+?)(?:\\s{2,}|\\n)");
        builder.billingPeriodStart(normalizeDate(periodStr));

        String periodEnd = firstMatch(text,
                "(?i)(?:to|through)\\s+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r|Payment)",
                "(?i)Closing Date\\s+([\\w/,\\s]+?)(?:\\s{2,}|\\n)");
        builder.billingPeriodEnd(normalizeDate(periodEnd));

        // ── Balance ──────────────────────────────────────────────────────────
        Double balance = extractAmount(text,
                "(?i)New Balance[:\\s]+\\$?([\\d,]+\\.\\d{2})",
                "(?i)Total Amount Owed[:\\s]+\\$?([\\d,]+\\.\\d{2})",
                "(?i)Balance Due[:\\s]+\\$?([\\d,]+\\.\\d{2})",
                "(?i)New Charges[:\\s]+\\$?([\\d,]+\\.\\d{2})");
        builder.statementBalance(balance);

        // ── Minimum due ──────────────────────────────────────────────────────
        Double minDue = extractAmount(text,
                "(?i)Minimum Payment Due[:\\s]+\\$?([\\d,]+\\.\\d{2})",
                "(?i)Minimum Due[:\\s]+\\$?([\\d,]+\\.\\d{2})",
                "(?i)Minimum Payment[:\\s]+\\$?([\\d,]+\\.\\d{2})");
        builder.minimumDue(minDue);

        // ── Due date ─────────────────────────────────────────────────────────
        String dueDate = firstMatch(text,
                "(?i)Payment Due Date[:\\s]+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r)",
                "(?i)Due Date[:\\s]+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r)",
                "(?i)Pay by[:\\s]+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r)");
        builder.dueDate(normalizeDate(dueDate));

        // ── Transactions via LLM ─────────────────────────────────────────────
        List<ExtractedTransaction> txns = llmExtractTransactions(text, bankKey != null ? bankKey : detectedBank);
        builder.transactions(txns);

        builder.status("AWAITING_CONFIRMATION");
        builder.validationIssues(new ArrayList<>());
        return builder.build();
    }

    private List<ExtractedTransaction> llmExtractTransactions(String text, String bankKey) {
        String truncated = text.length() > MAX_PDF_CHARS_FOR_LLM
                ? text.substring(0, MAX_PDF_CHARS_FOR_LLM) : text;

        String prompt = """
                You are a JSON-only financial data extractor. Respond with ONLY a valid JSON object — no explanations, no markdown, no code blocks.

                Bank: %s

                Extract ALL individual transactions from this credit card statement PDF text.
                Skip summary lines, totals, subtotals, and section headers.
                Include purchases, payments, credits, refunds, and fees.

                Return a JSON object with key "transactions" whose value is an array. Each element must have:
                - date: transaction date in YYYY-MM-DD format (two-digit years like 04/06/26 mean 2026)
                - merchantName: merchant or description, cleaned (remove trailing city/state codes like "SEATTLE WA")
                - amount: absolute value as a number, no $ symbol
                - type: "PURCHASE" for charges/fees, "PAYMENT" for payments made to the account, "CREDIT" for refunds/credits

                If no transactions are found, return: {"transactions":[]}

                Statement text:
                %s

                JSON response:
                """.formatted(bankKey != null ? bankKey : "UNKNOWN", truncated);

        try {
            String raw = chatClient.prompt().user(prompt).call().content();
            log.info("LLM transaction response (first 300 chars): {}",
                    raw != null ? raw.substring(0, Math.min(300, raw.length())) : "null");

            String json = extractJson(raw);
            TransactionListDto dto = LLM_MAPPER.readValue(json, TransactionListDto.class);

            if (dto.transactions == null || dto.transactions.isEmpty()) {
                log.info("LLM extracted 0 transactions (bank={})", bankKey);
                return List.of();
            }

            List<ExtractedTransaction> results = new ArrayList<>();
            for (TransactionDto t : dto.transactions) {
                if (t.merchantName == null || t.merchantName.isBlank()) continue;
                String type = resolveType(t.type);
                results.add(ExtractedTransaction.builder()
                        .date(t.date)
                        .merchantName(t.merchantName.trim())
                        .amount(Math.abs(t.amount))
                        .type(type)
                        .build());
            }
            log.info("LLM extracted {} transactions (bank={})", results.size(), bankKey);
            return results;

        } catch (Exception e) {
            log.warn("LLM transaction extraction failed (bank={}): {}", bankKey, e.getMessage());
            return List.of();
        }
    }

    private String resolveType(String raw) {
        if (raw == null) return "PURCHASE";
        return switch (raw.toUpperCase()) {
            case "PAYMENT" -> "PAYMENT";
            case "CREDIT", "REFUND" -> "CREDIT";
            default -> "PURCHASE";
        };
    }

    private String extractJson(String raw) {
        if (raw == null || raw.isBlank()) throw new IllegalArgumentException("Empty LLM response");
        String cleaned = raw.replaceAll("```json", "").replaceAll("```", "").trim();
        Matcher m = JSON_BLOCK.matcher(cleaned);
        if (m.find()) return m.group();
        throw new IllegalArgumentException("No JSON object found in LLM response");
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class TransactionListDto {
        public List<TransactionDto> transactions;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class TransactionDto {
        public String date;
        public String merchantName;
        public double amount;
        public String type;
    }

    private String detectBank(String text) {
        String upper = text.toUpperCase();
        if (upper.contains("JPMORGAN") || upper.contains("CHASE BANK") || upper.contains("CHASE SAPPHIRE")
                || upper.contains("CHASE FREEDOM") || upper.contains("CHASE SLATE")) return "CHASE";
        if (upper.contains("AMERICAN EXPRESS") || upper.contains("AMERICANEXPRESS")) return "AMEX";
        if (upper.contains("BANK OF AMERICA") || upper.contains("BANKOFAMERICA")) return "BOA";
        if (upper.contains("DISCOVER CARD") || upper.contains("DISCOVER IT")) return "DISCOVER";
        if (upper.contains("CITIBANK") || upper.contains("CITI CARD")) return "CITI";
        if (upper.contains("CAPITAL ONE")) return "CAPITAL_ONE";
        if (upper.contains("WELLS FARGO")) return "WELLS_FARGO";
        return null;
    }

    private String extractLastFour(String text) {
        String[] patterns = {
                "(?i)(?:account|card)\\s+(?:number|ending in|ending)[:\\s#*]+[*Xx0-9 -]*(\\d{4})(?:\\s|$|\\n)",
                "(?i)ending\\s+in\\s+(\\d{4})",
                "(?i)ending\\s+(\\d{4})",
                "(?i)Account\\s+Number[:\\s]+[\\d*x -]*(\\d{4})(?:\\s|$)",
                "\\b(?:Acct|Card)[:\\s]+[*x0-9 -]*(\\d{4})(?:\\s|$)"
        };
        for (String p : patterns) {
            String v = matchGroup(text, p, 1);
            if (v != null) return v;
        }
        return null;
    }

    private void validateStatement(StatementExtractionResult result, CardStatement stmt) {
        List<String> issues = result.getValidationIssues() != null
                ? result.getValidationIssues() : new ArrayList<>();
        boolean wrongStatement = false;

        String storedLast4 = stmt.getCardLastFour();
        String extractedLast4 = result.getCardLastFour();
        if (storedLast4 != null && extractedLast4 != null
                && !storedLast4.endsWith(extractedLast4)
                && !extractedLast4.endsWith(storedLast4)) {
            issues.add("Card number mismatch: statement is for ••••" + extractedLast4
                    + " but your card ends in ••••" + storedLast4 + ".");
            wrongStatement = true;
        }

        String storedBank = stmt.getBank();
        String extractedBank = result.getBank();
        if (storedBank != null && extractedBank != null
                && !storedBank.equalsIgnoreCase(extractedBank)
                && !storedBank.toUpperCase().contains(extractedBank.toUpperCase())
                && !extractedBank.toUpperCase().contains(storedBank.toUpperCase())) {
            issues.add("Bank mismatch: PDF looks like a " + extractedBank
                    + " statement but this statement is for " + storedBank + ".");
            wrongStatement = true;
        }

        if (result.getTransactions() == null || result.getTransactions().isEmpty()) {
            issues.add("No transactions found in this PDF. The statement header data was extracted, "
                    + "but transaction list may not be in a recognized format.");
        }

        if (result.getStatementBalance() == null) {
            issues.add("Could not extract statement balance from this PDF.");
        }

        result.setValidationIssues(issues);
        result.setStatus(wrongStatement ? "WRONG_STATEMENT" : "AWAITING_CONFIRMATION");
    }

    // ── Utility Bill Extraction ───────────────────────────────────────────────

    public BillExtractionResult extractBill(UtilityBill bill, byte[] pdfBytes) {
        String text;
        try {
            text = extractText(pdfBytes);
        } catch (Exception e) {
            log.warn("PDFBox extraction failed for bill {}: {}", bill.getId(), e.getMessage());
            return BillExtractionResult.builder()
                    .status("FAILED")
                    .failureReason("Could not read PDF: " + e.getMessage())
                    .build();
        }

        if (text == null || text.isBlank()) {
            return BillExtractionResult.builder()
                    .status("FAILED")
                    .failureReason("PDF appears to be empty or image-only (no extractable text).")
                    .build();
        }

        BillExtractionResult result = parseBill(text, bill);
        validateBill(result, bill);
        return result;
    }

    private BillExtractionResult parseBill(String text, UtilityBill bill) {
        BillExtractionResult.BillExtractionResultBuilder builder = BillExtractionResult.builder();

        String upper = text.toUpperCase();
        String billerName = bill.getBillerName();
        if (upper.contains("NATIONAL GRID")) billerName = "NATIONAL GRID";
        else if (upper.contains("EVERSOURCE")) billerName = "EVERSOURCE";
        builder.billerName(billerName);

        String acct = firstMatch(text,
                "(?i)Account\\s+(?:Number|#)[:\\s]+[\\d *-]*(\\d{4})(?:\\s|$)",
                "(?i)Account[:\\s]+[\\d *-]*(\\d{4})(?:\\s|$)");
        builder.accountLastFour(acct);

        Double amount = extractAmount(text,
                "(?i)Total Amount Due[:\\s]+\\$?([\\d,]+\\.\\d{2})",
                "(?i)Amount Due[:\\s]+\\$?([\\d,]+\\.\\d{2})",
                "(?i)Total Due[:\\s]+\\$?([\\d,]+\\.\\d{2})",
                "(?i)Balance Due[:\\s]+\\$?([\\d,]+\\.\\d{2})");
        builder.amountDue(amount);

        String dueDate = firstMatch(text,
                "(?i)(?:Payment\\s+)?Due\\s+Date[:\\s]+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r)",
                "(?i)Pay\\s+By[:\\s]+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r)");
        builder.dueDate(normalizeDate(dueDate));

        String billDate = firstMatch(text,
                "(?i)(?:Statement|Bill|Invoice)\\s+Date[:\\s]+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r)",
                "(?i)Billing\\s+Date[:\\s]+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r)");
        builder.billDate(normalizeDate(billDate));

        String periodStart = firstMatch(text,
                "(?i)Service Period[:\\s]+([\\w/,\\s]+?)\\s+(?:to|through|–|-)",
                "(?i)Billing Period[:\\s]+([\\w/,\\s]+?)\\s+(?:to|through|–|-)",
                "(?i)From[:\\s]+([\\w/,\\s]+?)\\s+(?:to|through|–|-)");
        builder.billingPeriodStart(normalizeDate(periodStart));

        String periodEnd = firstMatch(text,
                "(?i)(?:Service|Billing) Period[^\\n]*(?:to|through|–|-)\\s+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r)",
                "(?i)(?:to|through)\\s+([\\w/,\\s]+?)(?:\\s{2,}|\\n|\\r|$)");
        builder.billingPeriodEnd(normalizeDate(periodEnd));

        builder.status("AWAITING_CONFIRMATION");
        builder.validationIssues(new ArrayList<>());
        return builder.build();
    }

    private void validateBill(BillExtractionResult result, UtilityBill bill) {
        List<String> issues = result.getValidationIssues() != null
                ? result.getValidationIssues() : new ArrayList<>();
        boolean wrongBill = false;

        String storedBiller = bill.getBillerName().toUpperCase();
        String extractedBiller = result.getBillerName() != null
                ? result.getBillerName().toUpperCase() : "";

        if (!extractedBiller.isBlank()
                && !storedBiller.contains(extractedBiller)
                && !extractedBiller.contains(storedBiller)) {
            issues.add("Biller mismatch: PDF looks like a " + result.getBillerName()
                    + " bill but this is registered as " + bill.getBillerName() + ".");
            wrongBill = true;
        }

        String storedLast4 = bill.getAccountLastFour();
        String extractedLast4 = result.getAccountLastFour();
        if (storedLast4 != null && extractedLast4 != null && !storedLast4.equals(extractedLast4)) {
            issues.add("Account number mismatch: PDF shows account ••••" + extractedLast4
                    + " but this bill is for account ••••" + storedLast4 + ".");
            wrongBill = true;
        }

        if (result.getAmountDue() == null) {
            issues.add("Could not extract the amount due from this PDF.");
        }

        result.setValidationIssues(issues);
        result.setStatus(wrongBill ? "WRONG_STATEMENT" : "AWAITING_CONFIRMATION");
    }

    // ── JSON helpers for stored extracted_data column ─────────────────────────

    public String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            log.error("JSON serialization error", e);
            return null;
        }
    }

    public StatementExtractionResult parseStatementResult(String json) {
        try {
            return objectMapper.readValue(json, StatementExtractionResult.class);
        } catch (Exception e) {
            log.error("Failed to parse StatementExtractionResult JSON", e);
            return null;
        }
    }

    public BillExtractionResult parseBillResult(String json) {
        try {
            return objectMapper.readValue(json, BillExtractionResult.class);
        } catch (Exception e) {
            log.error("Failed to parse BillExtractionResult JSON", e);
            return null;
        }
    }

    // ── PDFBox text extraction ────────────────────────────────────────────────

    private String extractText(byte[] bytes) throws IOException {
        try (PDDocument doc = org.apache.pdfbox.Loader.loadPDF(bytes)) {
            PDFTextStripper stripper = new PDFTextStripper();
            stripper.setSortByPosition(true);
            return stripper.getText(doc);
        }
    }

    // ── Regex utilities ───────────────────────────────────────────────────────

    private String firstMatch(String text, String... patterns) {
        for (String pattern : patterns) {
            String v = matchGroup(text, pattern, 1);
            if (v != null && !v.isBlank()) return v.trim();
        }
        return null;
    }

    private String matchGroup(String text, String pattern, int group) {
        try {
            Matcher m = Pattern.compile(pattern).matcher(text);
            if (m.find()) return m.group(group);
        } catch (Exception ignored) {}
        return null;
    }

    private Double extractAmount(String text, String... patterns) {
        for (String pattern : patterns) {
            String v = matchGroup(text, pattern, 1);
            if (v != null) {
                try {
                    return Double.parseDouble(v.replace(",", "").trim());
                } catch (NumberFormatException ignored) {}
            }
        }
        return null;
    }

    private String normalizeDate(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String cleaned = raw.trim().replaceAll("\\s+", " ");
        for (DateTimeFormatter fmt : DATE_FORMATS) {
            try {
                return LocalDate.parse(cleaned, fmt).toString();
            } catch (DateTimeParseException ignored) {}
        }
        try {
            LocalDate.parse(cleaned);
            return cleaned;
        } catch (DateTimeParseException ignored) {}
        return null;
    }
}
