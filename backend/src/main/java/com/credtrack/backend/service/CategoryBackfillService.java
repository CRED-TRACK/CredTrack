package com.credtrack.backend.service;

import com.credtrack.backend.entity.AliasSource;
import com.credtrack.backend.entity.CanonicalCategory;
import com.credtrack.backend.entity.CategoryAlias;
import com.credtrack.backend.repository.CategoryAliasRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * One-time deploy backfill: for every distinct transactions.merchant_category that has no
 * canonical_category set yet, ask the LLM to classify it into a CanonicalCategory code,
 * insert an alias row, then update all matching transactions.
 *
 * Gated by app.category-backfill.enabled — flip false after the first deploy completes.
 * Idempotent: re-runs only process rows with canonical_category IS NULL.
 */
@Component
public class CategoryBackfillService implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(CategoryBackfillService.class);

    @PersistenceContext
    private EntityManager em;

    private final CategoryAliasRepository aliasRepository;
    private final CategoryNormalizationService normalizationService;
    private final ChatClient chatClient;
    private final ObjectMapper objectMapper;
    private final boolean enabled;

    public CategoryBackfillService(CategoryAliasRepository aliasRepository,
                                   CategoryNormalizationService normalizationService,
                                   ChatClient.Builder chatClientBuilder,
                                   ObjectMapper objectMapper,
                                   @Value("${app.category-backfill.enabled:true}") boolean enabled) {
        this.aliasRepository = aliasRepository;
        this.normalizationService = normalizationService;
        this.chatClient = chatClientBuilder.build();
        this.objectMapper = objectMapper;
        this.enabled = enabled;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (!enabled) {
            log.info("CategoryBackfillService disabled — skipping");
            return;
        }
        @SuppressWarnings("unchecked")
        List<String> rawCategories = em.createNativeQuery("""
                SELECT DISTINCT merchant_category FROM transactions
                WHERE canonical_category IS NULL AND merchant_category IS NOT NULL
            """).getResultList();

        if (rawCategories.isEmpty()) {
            log.info("CategoryBackfillService: no rows need backfill");
            return;
        }
        log.info("CategoryBackfillService starting: {} distinct raw merchant_category values to classify",
            rawCategories.size());

        Set<String> validCodes = new HashSet<>(Arrays.stream(CanonicalCategory.values()).map(Enum::name).toList());
        int classified = 0;
        int rowsUpdated = 0;
        for (String raw : rawCategories) {
            if (raw == null || raw.isBlank()) continue;
            String key = raw.trim().toLowerCase();
            String code = aliasRepository.findByRawValue(key)
                .map(CategoryAlias::getCanonicalCategory)
                .orElseGet(() -> classifyAndPersist(key, validCodes));

            int updated = em.createNativeQuery("""
                    UPDATE transactions SET canonical_category = :code
                    WHERE merchant_category = :raw AND canonical_category IS NULL
                """)
                .setParameter("code", code)
                .setParameter("raw", raw)
                .executeUpdate();
            rowsUpdated += updated;
            classified++;
        }
        normalizationService.reload();
        log.info("CategoryBackfillService done: classified {} raw values, updated {} transactions",
            classified, rowsUpdated);
    }

    private String classifyAndPersist(String rawLower, Set<String> validCodes) {
        String prompt = """
            You are a strict JSON classifier. Map the given merchant category string to ONE of these codes:
            %s

            Respond with ONLY valid JSON: {"code":"<CODE>","confidence":0.0..1.0}
            If unsure, use "OTHER" with low confidence.

            Input: %s
            """.formatted(String.join(", ", validCodes), rawLower);

        String code = CanonicalCategory.OTHER.code();
        float confidence = 0f;
        try {
            String resp = chatClient.prompt().user(prompt).call().content();
            JsonNode node = objectMapper.readTree(resp);
            String c = node.path("code").asText("OTHER").toUpperCase();
            if (validCodes.contains(c)) code = c;
            confidence = (float) node.path("confidence").asDouble(0);
        } catch (Exception e) {
            log.warn("LLM classify failed for raw='{}': {}", rawLower, e.getMessage());
        }
        try {
            CategoryAlias alias = CategoryAlias.builder()
                .rawValue(rawLower)
                .canonicalCategory(code)
                .source(AliasSource.LLM_SUGGESTED)
                .confidence(confidence)
                .sampleTransactionCount(0L)
                .build();
            aliasRepository.save(alias);
        } catch (Exception e) {
            log.debug("alias insert race for '{}': {}", rawLower, e.getMessage());
        }
        return code;
    }
}
