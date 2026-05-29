package com.credtrack.backend.service;

import com.credtrack.backend.entity.CardRewardRule;
import com.credtrack.backend.entity.RuleSource;
import com.credtrack.backend.repository.CardRewardRuleRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

/**
 * CRUD on CardRewardRule. The scraper-driven replace-all path only touches LLM_SCRAPED rows;
 * SEED and USER_OVERRIDE rules are never deleted by the scraper.
 */
@Service
public class RewardRulesService {

    private static final Logger log = LoggerFactory.getLogger(RewardRulesService.class);

    private final CardRewardRuleRepository ruleRepository;

    public RewardRulesService(CardRewardRuleRepository ruleRepository) {
        this.ruleRepository = ruleRepository;
    }

    public List<CardRewardRule> findActiveForCardProducts(List<Long> cardProductIds, LocalDate asOf) {
        if (cardProductIds.isEmpty()) return List.of();
        return ruleRepository.findActiveForCardProducts(cardProductIds, asOf);
    }

    @Transactional
    public void replaceScrapedRulesForProduct(Long cardProductId, List<CardRewardRule> newRules) {
        int deleted = ruleRepository.deleteByCardProductIdAndSource(cardProductId, RuleSource.LLM_SCRAPED);
        log.info("replaced LLM_SCRAPED rules for card_product_id={} deleted={} new={}",
            cardProductId, deleted, newRules.size());
        for (CardRewardRule r : newRules) {
            r.setSource(RuleSource.LLM_SCRAPED);
            ruleRepository.save(r);
        }
    }
}
