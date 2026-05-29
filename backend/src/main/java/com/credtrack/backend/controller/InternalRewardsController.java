package com.credtrack.backend.controller;

import com.credtrack.backend.entity.*;
import com.credtrack.backend.repository.CardProductRepository;
import com.credtrack.backend.repository.CardRewardRuleRepository;
import com.credtrack.backend.repository.CardTermsDocumentRepository;
import com.credtrack.backend.repository.UserCardRepository;
import lombok.Builder;
import lombok.Getter;
import lombok.Setter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Internal endpoints for the ai-agent scraper and one-off admin pushes
 * (e.g. Discover / Freedom Flex quarterly 5% rotating category).
 * Auth: X-Service-Key (handled by ServiceKeyInterceptor on /internal/**).
 */
@RestController
@RequestMapping("/internal")
public class InternalRewardsController {

    private static final Logger log = LoggerFactory.getLogger(InternalRewardsController.class);

    private final CardProductRepository cardProductRepository;
    private final CardRewardRuleRepository ruleRepository;
    private final UserCardRepository userCardRepository;
    private final CardTermsDocumentRepository termsDocumentRepository;

    public InternalRewardsController(CardProductRepository cardProductRepository,
                                     CardRewardRuleRepository ruleRepository,
                                     UserCardRepository userCardRepository,
                                     CardTermsDocumentRepository termsDocumentRepository) {
        this.cardProductRepository = cardProductRepository;
        this.ruleRepository = ruleRepository;
        this.userCardRepository = userCardRepository;
        this.termsDocumentRepository = termsDocumentRepository;
    }

    @Getter @Builder
    public static class CardProductToScrape {
        private Long cardProductId;
        private String bankKey;
        private String productName;
        private String officialName;
        private String termsUrl;
        private Integer ownerCount;
        private String lastContentHash;
        private java.time.LocalDateTime lastFetchedAt;
    }

    /**
     * Returns the card_products that the scraper should process this cycle:
     * any product with terms_url set AND at least one active UserCard referencing it.
     * Each row includes the current `is_current` document's content hash so the
     * fetcher can short-circuit if the page is unchanged.
     */
    @GetMapping("/card-products-to-scrape")
    public ResponseEntity<java.util.List<CardProductToScrape>> listToScrape() {
        java.util.List<Long> owned = userCardRepository.findDistinctActiveCardProductIds();
        if (owned.isEmpty()) return ResponseEntity.ok(java.util.List.of());

        java.util.List<CardProductToScrape> out = new java.util.ArrayList<>();
        for (Long id : owned) {
            cardProductRepository.findById(id).ifPresent(cp -> {
                if (cp.getTermsUrl() == null || cp.getTermsUrl().isBlank()) return;
                var doc = termsDocumentRepository.findFirstByCardProduct_IdAndIsCurrentTrue(id).orElse(null);
                out.add(CardProductToScrape.builder()
                    .cardProductId(cp.getId())
                    .bankKey(cp.getBankKey())
                    .productName(cp.getProductName())
                    .officialName(cp.getOfficialName())
                    .termsUrl(cp.getTermsUrl())
                    .ownerCount(null)
                    .lastContentHash(doc != null ? doc.getContentHash() : null)
                    .lastFetchedAt(doc != null ? doc.getFetchedAt() : null)
                    .build());
            });
        }
        return ResponseEntity.ok(out);
    }

    @Getter @Setter
    public static class QuarterlyRefreshRequest {
        /** Either card_product_id OR (bank_key + product_name). At least one required. */
        private Long cardProductId;
        private String bankKey;
        private String productName;

        /** Canonical category code, e.g. GAS_STATIONS, GROCERIES_SUPERMARKETS. */
        private String canonicalCategory;
        private Integer rateBps;          // default 500 = 5%
        private Integer baseRateBps;      // default 100 = 1%
        private BigDecimal capAmount;     // default 1500
        private String capGroupKey;       // optional — share cap across multiple rules (Discover Q2 = Dining + Home Improvement combined)
        private LocalDate effectiveFrom;  // required
        private LocalDate effectiveTo;    // required
        private String notes;
    }

    @PostMapping("/card-reward-rules/quarterly-refresh")
    @Transactional
    public ResponseEntity<?> quarterlyRefresh(@RequestBody QuarterlyRefreshRequest req) {
        if (req.getCanonicalCategory() == null
            || req.getEffectiveFrom() == null
            || req.getEffectiveTo() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "canonical_category, effective_from, effective_to required");
        }
        CanonicalCategory.fromCode(req.getCanonicalCategory())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Unknown canonical_category: " + req.getCanonicalCategory()));

        CardProduct product = resolveProduct(req);

        CardRewardRule rule = CardRewardRule.builder()
            .cardProduct(product)
            .canonicalCategory(req.getCanonicalCategory())
            .rateBps(req.getRateBps() != null ? req.getRateBps() : 500)
            .baseRateBps(req.getBaseRateBps() != null ? req.getBaseRateBps() : 100)
            .capType(req.getCapAmount() != null ? CapType.AMOUNT : CapType.NONE)
            .capAmount(req.getCapAmount() != null ? req.getCapAmount() : new BigDecimal("1500.00"))
            .capPeriod(CapPeriod.QUARTER)
            .capGroupKey(req.getCapGroupKey())
            .requiresUserChoice(false)
            .effectiveFrom(req.getEffectiveFrom())
            .effectiveTo(req.getEffectiveTo())
            .source(RuleSource.USER_OVERRIDE)
            .sourceConfidence(1.0f)
            .notes(req.getNotes() != null ? req.getNotes()
                : "Quarterly 5% category. Activate at the issuer's site each quarter.")
            .build();

        try {
            ruleRepository.save(rule);
        } catch (org.springframework.dao.DataIntegrityViolationException e) {
            log.info("quarterly-refresh duplicate for product_id={} cat={} from={} — skipping",
                product.getId(), req.getCanonicalCategory(), req.getEffectiveFrom());
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body("Rule already exists for this product+category+effective_from. Delete it first to replace.");
        }
        log.info("quarterly-refresh saved product_id={} cat={} from={} to={}",
            product.getId(), req.getCanonicalCategory(), req.getEffectiveFrom(), req.getEffectiveTo());
        return ResponseEntity.status(HttpStatus.CREATED).body(rule.getId());
    }

    // ─── Scraper writeback endpoints ────────────────────────────────────────

    @Getter @Setter
    public static class TermsDocumentRequest {
        private Long cardProductId;
        private String sourceUrl;
        private String contentHash;
        private String cleanedText;
        private Integer httpStatus;
        private String extractorModel;
        private Integer extractedRulesCount;
    }

    @Getter @Builder
    public static class TermsDocumentResponse {
        private Long id;
        private boolean duplicateOfCurrent;
    }

    /** Creates a CardTermsDocument and flips the prior `is_current=true` doc (if any). */
    @PostMapping("/card-terms-documents")
    @Transactional
    public ResponseEntity<TermsDocumentResponse> createTermsDocument(@RequestBody TermsDocumentRequest req) {
        if (req.getCardProductId() == null || req.getSourceUrl() == null
            || req.getContentHash() == null || req.getCleanedText() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "card_product_id, source_url, content_hash, cleaned_text required");
        }
        CardProduct product = cardProductRepository.findById(req.getCardProductId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                "card_product_id not found: " + req.getCardProductId()));

        var existing = termsDocumentRepository
            .findFirstByCardProduct_IdAndIsCurrentTrue(req.getCardProductId())
            .orElse(null);
        if (existing != null && req.getContentHash().equals(existing.getContentHash())) {
            return ResponseEntity.ok(TermsDocumentResponse.builder()
                .id(existing.getId()).duplicateOfCurrent(true).build());
        }
        if (existing != null) {
            existing.setIsCurrent(false);
            termsDocumentRepository.save(existing);
        }
        CardTermsDocument doc = CardTermsDocument.builder()
            .cardProduct(product)
            .sourceUrl(req.getSourceUrl())
            .contentHash(req.getContentHash())
            .cleanedText(req.getCleanedText())
            .httpStatus(req.getHttpStatus())
            .fetchedAt(java.time.LocalDateTime.now())
            .isCurrent(true)
            .extractorModel(req.getExtractorModel())
            .extractedRulesCount(req.getExtractedRulesCount())
            .build();
        termsDocumentRepository.save(doc);
        log.info("terms_document saved id={} card_product_id={} hash={}",
            doc.getId(), product.getId(), req.getContentHash());
        return ResponseEntity.status(HttpStatus.CREATED).body(
            TermsDocumentResponse.builder().id(doc.getId()).duplicateOfCurrent(false).build());
    }

    @Getter @Setter
    public static class RuleInput {
        private String canonicalCategory;
        private Integer rateBps;
        private Integer baseRateBps;
        private String capPeriod;            // NONE | CALENDAR_YEAR | QUARTER | ...
        private BigDecimal capAmount;
        private String capGroupKey;
        private Boolean requiresUserChoice;
        private String channelRestriction;
        private java.util.List<String> exclusions;
        private String notes;
        private Float confidence;
        private LocalDate effectiveFrom;     // optional, defaults to today
        private LocalDate effectiveTo;       // optional
    }

    @Getter @Setter
    public static class RewardRulesUpsertRequest {
        private Long cardProductId;
        private Long documentId;
        /** Minimum confidence floor (defaults to 0.6). Rules below this are dropped. */
        private Float minConfidence;
        private java.util.List<RuleInput> rules;
    }

    /**
     * Replace-all for source='LLM_SCRAPED' rules of one card_product.
     * SEED and USER_OVERRIDE rules are NEVER touched. Confidence floor filters noise.
     */
    @PostMapping("/card-reward-rules")
    @Transactional
    public ResponseEntity<?> upsertScrapedRules(@RequestBody RewardRulesUpsertRequest req) {
        if (req.getCardProductId() == null || req.getRules() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "card_product_id and rules required");
        }
        CardProduct product = cardProductRepository.findById(req.getCardProductId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                "card_product_id not found: " + req.getCardProductId()));

        float floor = req.getMinConfidence() != null ? req.getMinConfidence() : 0.6f;
        LocalDate today = LocalDate.now();

        int deleted = ruleRepository.deleteByCardProductIdAndSource(
            req.getCardProductId(), RuleSource.LLM_SCRAPED);
        // Force delete to flush so subsequent inserts don't collide with the rows we just removed.
        ruleRepository.flush();

        // Dedupe by canonical_category — Gemini sometimes returns multiple rules for the same
        // category (e.g. dining mentioned in two sections). Keep highest-confidence; ties keep first.
        java.util.LinkedHashMap<String, RuleInput> deduped = new java.util.LinkedHashMap<>();
        for (RuleInput r : req.getRules()) {
            if (r.getCanonicalCategory() == null) continue;
            String key = r.getCanonicalCategory();
            RuleInput existing = deduped.get(key);
            if (existing == null) {
                deduped.put(key, r);
            } else {
                float a = existing.getConfidence() != null ? existing.getConfidence() : 0f;
                float b = r.getConfidence() != null ? r.getConfidence() : 0f;
                if (b > a) deduped.put(key, r);
            }
        }

        int saved = 0;
        int skipped = 0;
        for (RuleInput r : deduped.values()) {
            if (r.getCanonicalCategory() == null || r.getRateBps() == null) { skipped++; continue; }
            if (CanonicalCategory.fromCode(r.getCanonicalCategory()).isEmpty()) { skipped++; continue; }
            if (r.getConfidence() != null && r.getConfidence() < floor) { skipped++; continue; }

            CapPeriod capPeriod = CapPeriod.NONE;
            if (r.getCapPeriod() != null) {
                try { capPeriod = CapPeriod.valueOf(r.getCapPeriod()); } catch (Exception ignored) {}
            }
            CapType capType = r.getCapAmount() != null && r.getCapAmount().signum() > 0
                ? CapType.AMOUNT : CapType.NONE;

            String[] exclusions = r.getExclusions() == null ? null
                : r.getExclusions().toArray(String[]::new);

            CardRewardRule entity = CardRewardRule.builder()
                .cardProduct(product)
                .canonicalCategory(r.getCanonicalCategory())
                .rateBps(r.getRateBps())
                .baseRateBps(r.getBaseRateBps())
                .capType(capType)
                .capAmount(r.getCapAmount())
                .capPeriod(capPeriod)
                .capGroupKey(r.getCapGroupKey())
                .requiresUserChoice(Boolean.TRUE.equals(r.getRequiresUserChoice()))
                .channelRestriction(r.getChannelRestriction())
                .exclusions(exclusions)
                .effectiveFrom(r.getEffectiveFrom() != null ? r.getEffectiveFrom() : today)
                .effectiveTo(r.getEffectiveTo())
                .source(RuleSource.LLM_SCRAPED)
                .sourceConfidence(r.getConfidence())
                .sourceDocumentId(req.getDocumentId())
                .notes(r.getNotes())
                .build();
            ruleRepository.save(entity);
            saved++;
        }
        log.info("scraped_rules_upsert product_id={} deleted_prev={} saved={} skipped={}",
            req.getCardProductId(), deleted, saved, skipped);
        return ResponseEntity.ok(java.util.Map.of(
            "deleted_previous", deleted, "saved", saved, "skipped", skipped));
    }

    private CardProduct resolveProduct(QuarterlyRefreshRequest req) {
        if (req.getCardProductId() != null) {
            return cardProductRepository.findById(req.getCardProductId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                    "card_product_id not found: " + req.getCardProductId()));
        }
        if (req.getBankKey() != null && req.getProductName() != null) {
            return cardProductRepository
                .findByBankKeyAndProductName(req.getBankKey(), req.getProductName())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                    "no card_product matching bank_key=" + req.getBankKey()
                        + " product_name=" + req.getProductName()));
        }
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
            "Provide either card_product_id or (bank_key + product_name)");
    }
}
