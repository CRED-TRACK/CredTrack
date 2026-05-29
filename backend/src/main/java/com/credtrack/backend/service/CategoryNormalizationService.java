package com.credtrack.backend.service;

import com.credtrack.backend.entity.AliasSource;
import com.credtrack.backend.entity.CanonicalCategory;
import com.credtrack.backend.entity.CategoryAlias;
import com.credtrack.backend.repository.CategoryAliasRepository;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Single source of truth for raw merchant_category string → CanonicalCategory code.
 * Loads category_aliases into memory; refreshed hourly and on every internal alias write.
 * Unknown raw values default to OTHER and persist a stub row (confidence=0) so the
 * scraper/backfill loop can later label them.
 */
@Service
public class CategoryNormalizationService {

    private static final Logger log = LoggerFactory.getLogger(CategoryNormalizationService.class);

    private final CategoryAliasRepository aliasRepository;
    private final Map<String, String> cache = new ConcurrentHashMap<>();

    public CategoryNormalizationService(CategoryAliasRepository aliasRepository) {
        this.aliasRepository = aliasRepository;
    }

    @PostConstruct
    public void init() {
        reload();
    }

    @Scheduled(fixedRate = 3_600_000) // 1h
    public void scheduledReload() {
        reload();
    }

    public synchronized void reload() {
        Map<String, String> fresh = new HashMap<>();
        for (CategoryAlias alias : aliasRepository.findAll()) {
            fresh.put(normalizeKey(alias.getRawValue()), alias.getCanonicalCategory());
        }
        cache.clear();
        cache.putAll(fresh);
        log.info("CategoryNormalizationService cache reloaded: {} aliases", cache.size());
    }

    public String normalize(String raw) {
        if (raw == null || raw.isBlank()) return CanonicalCategory.OTHER.code();
        String key = normalizeKey(raw);
        String hit = cache.get(key);
        if (hit != null) return hit;
        return persistStubAndReturnOther(key);
    }

    @Transactional
    String persistStubAndReturnOther(String key) {
        if (aliasRepository.findByRawValue(key).isPresent()) {
            // race — another thread just inserted it; refresh cache lazily
            cache.computeIfAbsent(key, k ->
                aliasRepository.findByRawValue(k).map(CategoryAlias::getCanonicalCategory).orElse(CanonicalCategory.OTHER.code()));
            return cache.getOrDefault(key, CanonicalCategory.OTHER.code());
        }
        CategoryAlias stub = CategoryAlias.builder()
            .rawValue(key)
            .canonicalCategory(CanonicalCategory.OTHER.code())
            .source(AliasSource.LLM_SUGGESTED)
            .confidence(0f)
            .sampleTransactionCount(1L)
            .build();
        try {
            aliasRepository.save(stub);
            cache.put(key, CanonicalCategory.OTHER.code());
        } catch (Exception e) {
            log.debug("alias stub insert race for '{}': {}", key, e.getMessage());
        }
        return CanonicalCategory.OTHER.code();
    }

    private static String normalizeKey(String raw) {
        return raw.trim().toLowerCase();
    }
}
