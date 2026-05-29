-- One-time clean-slate: remove all hand-authored SEED rules. The ai-agent scraper
-- now writes LLM_SCRAPED rules as the single source of truth. User overrides
-- (source='USER_OVERRIDE') are NOT deleted.
DELETE FROM card_reward_rules WHERE source = 'SEED';

-- Reset terms_url to NULL so the scraper picks them up only when explicitly set
-- (avoid stale URL drift). The set-terms-url calls happen via /internal/* now.
-- NOTE: comment out the next line if you want to keep the URLs seeded for local dev.
-- UPDATE card_products SET terms_url = NULL WHERE terms_url IS NOT NULL;
