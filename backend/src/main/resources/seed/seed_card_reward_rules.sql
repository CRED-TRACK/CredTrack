-- Hand-authored reward rules for the user's 4 owned cards. All rows source='SEED'.
-- The ai-agent scraper (Phase 2) replaces only source='LLM_SCRAPED' rows; these SEED rows stay put.
--
-- The rules are written using subqueries so they resolve the correct card_product_id by
-- (bank_key, product_name) regardless of prior seed insert order.

-- ─────────────────────────────────────────────────────────────────────────────
-- Set terms_url for the 4 products the scraper will hit in Phase 2.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE card_products SET terms_url = 'https://card.americanexpress.com/d/blue-cash-everyday-credit-card/'
  WHERE bank_key = 'AMEX' AND product_name = 'Blue Cash Everyday';

UPDATE card_products SET terms_url = 'https://creditcards.chase.com/cash-back-credit-cards/freedom/unlimited'
  WHERE bank_key = 'CHASE' AND product_name = 'Freedom Unlimited';

UPDATE card_products SET terms_url = 'https://www.discover.com/credit-cards/cash-back/it-card.html'
  WHERE bank_key = 'DISCOVER' AND product_name = 'Discover It Cash Back';

UPDATE card_products SET terms_url = 'https://www.bankofamerica.com/credit-cards/products/cash-rewards-credit-card/'
  WHERE bank_key = 'BOA' AND product_name = 'Customized Cash Rewards';

-- ─────────────────────────────────────────────────────────────────────────────
-- Amex Blue Cash Everyday — 3% Grocery/Gas/Online (separate $6k/yr caps each), 1% base.
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'GROCERIES_SUPERMARKETS', 300, 100, 'AMOUNT', 6000.00, 'CALENDAR_YEAR',
       NULL, false, NULL, ARRAY['warehouse_clubs','specialty_food_stores'],
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% at U.S. supermarkets on up to $6,000 in purchases per calendar year, then 1%.', NOW(), NOW()
FROM card_products WHERE bank_key = 'AMEX' AND product_name = 'Blue Cash Everyday'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'GAS_STATIONS', 300, 100, 'AMOUNT', 6000.00, 'CALENDAR_YEAR',
       NULL, false, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% at U.S. gas stations on up to $6,000 in purchases per calendar year, then 1%.', NOW(), NOW()
FROM card_products WHERE bank_key = 'AMEX' AND product_name = 'Blue Cash Everyday'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'ONLINE_RETAIL', 300, 100, 'AMOUNT', 6000.00, 'CALENDAR_YEAR',
       NULL, false, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% on U.S. online retail purchases on up to $6,000 per calendar year, then 1%.', NOW(), NOW()
FROM card_products WHERE bank_key = 'AMEX' AND product_name = 'Blue Cash Everyday'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'OTHER', 100, 100, 'NONE', NULL, 'NONE',
       NULL, false, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '1% cash back on other eligible purchases.', NOW(), NOW()
FROM card_products WHERE bank_key = 'AMEX' AND product_name = 'Blue Cash Everyday'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- Chase Freedom Unlimited — 5% travel via Chase Travel portal, 3% dining, 3% drugstores, 1.5% base.
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'TRAVEL_PORTAL', 500, 150, 'NONE', NULL, 'NONE',
       NULL, false, 'TRAVEL_PORTAL_ONLY', NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '5% on travel booked through Chase Travel. Direct airline/hotel bookings earn the base rate.', NOW(), NOW()
FROM card_products WHERE bank_key = 'CHASE' AND product_name = 'Freedom Unlimited'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'DINING_RESTAURANTS', 300, 150, 'NONE', NULL, 'NONE',
       NULL, false, NULL, ARRAY['gift_cards'],
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% on dining including takeout and eligible delivery. Excludes gift card purchases at restaurants.', NOW(), NOW()
FROM card_products WHERE bank_key = 'CHASE' AND product_name = 'Freedom Unlimited'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'DRUGSTORES', 300, 150, 'NONE', NULL, 'NONE',
       NULL, false, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% on drugstore purchases.', NOW(), NOW()
FROM card_products WHERE bank_key = 'CHASE' AND product_name = 'Freedom Unlimited'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'OTHER', 150, 150, 'NONE', NULL, 'NONE',
       NULL, false, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '1.5% unlimited on everything else.', NOW(), NOW()
FROM card_products WHERE bank_key = 'CHASE' AND product_name = 'Freedom Unlimited'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- Discover It Cash Back — 1% baseline. The 5% rotating-quarter rule is added by
-- POST /internal/card-reward-rules/quarterly-refresh each quarter (Phase 2).
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'OTHER', 100, 100, 'NONE', NULL, 'NONE',
       NULL, false, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '1% cash back on everything outside the rotating 5% category.', NOW(), NOW()
FROM card_products WHERE bank_key = 'DISCOVER' AND product_name = 'Discover It Cash Back'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- BofA Customized Cash Rewards — 3% user-chosen category (one of 6), 2% groceries + warehouse,
-- combined cap $2,500/quarter across the 3% + 2% bonus categories. 1% base.
-- Six "3% rule rows" exist (one per eligible category), each requires_user_choice=true; only the row
-- matching the user's active choice earns 3%, others fall back to base rate at query time.
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'GAS_STATIONS', 300, 100, 'AMOUNT', 2500.00, 'QUARTER',
       'BOA_3PCT_PLUS_2PCT', true, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% on the category you choose. Combined $2,500/quarter cap with the 2% category, then 1%.', NOW(), NOW()
FROM card_products WHERE bank_key = 'BOA' AND product_name = 'Customized Cash Rewards'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'ONLINE_RETAIL', 300, 100, 'AMOUNT', 2500.00, 'QUARTER',
       'BOA_3PCT_PLUS_2PCT', true, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% on online shopping if chosen. Combined $2,500/quarter cap with the 2% category, then 1%.', NOW(), NOW()
FROM card_products WHERE bank_key = 'BOA' AND product_name = 'Customized Cash Rewards'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'DINING_RESTAURANTS', 300, 100, 'AMOUNT', 2500.00, 'QUARTER',
       'BOA_3PCT_PLUS_2PCT', true, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% on dining if chosen. Combined $2,500/quarter cap with the 2% category, then 1%.', NOW(), NOW()
FROM card_products WHERE bank_key = 'BOA' AND product_name = 'Customized Cash Rewards'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'TRAVEL_GENERAL', 300, 100, 'AMOUNT', 2500.00, 'QUARTER',
       'BOA_3PCT_PLUS_2PCT', true, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% on travel if chosen. Combined $2,500/quarter cap with the 2% category, then 1%.', NOW(), NOW()
FROM card_products WHERE bank_key = 'BOA' AND product_name = 'Customized Cash Rewards'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'DRUGSTORES', 300, 100, 'AMOUNT', 2500.00, 'QUARTER',
       'BOA_3PCT_PLUS_2PCT', true, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% on drug stores if chosen. Combined $2,500/quarter cap with the 2% category, then 1%.', NOW(), NOW()
FROM card_products WHERE bank_key = 'BOA' AND product_name = 'Customized Cash Rewards'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'HOME_IMPROVEMENT', 300, 100, 'AMOUNT', 2500.00, 'QUARTER',
       'BOA_3PCT_PLUS_2PCT', true, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '3% on home improvement if chosen. Combined $2,500/quarter cap with the 2% category, then 1%.', NOW(), NOW()
FROM card_products WHERE bank_key = 'BOA' AND product_name = 'Customized Cash Rewards'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

-- 2% Grocery + 2% Warehouse Club, share the same combined cap as the 3% chosen category.
INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'GROCERIES_SUPERMARKETS', 200, 100, 'AMOUNT', 2500.00, 'QUARTER',
       'BOA_3PCT_PLUS_2PCT', false, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '2% at grocery stores and wholesale clubs. Shares the $2,500/quarter combined cap with the 3% category.', NOW(), NOW()
FROM card_products WHERE bank_key = 'BOA' AND product_name = 'Customized Cash Rewards'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'WAREHOUSE_CLUB', 200, 100, 'AMOUNT', 2500.00, 'QUARTER',
       'BOA_3PCT_PLUS_2PCT', false, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '2% at wholesale clubs. Shares the $2,500/quarter combined cap with the 3% category.', NOW(), NOW()
FROM card_products WHERE bank_key = 'BOA' AND product_name = 'Customized Cash Rewards'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;

INSERT INTO card_reward_rules
  (card_product_id, canonical_category, rate_bps, base_rate_bps, cap_type, cap_amount, cap_period,
   cap_group_key, requires_user_choice, channel_restriction, exclusions,
   effective_from, effective_to, source, source_confidence, notes, created_at, updated_at)
SELECT id, 'OTHER', 100, 100, 'NONE', NULL, 'NONE',
       NULL, false, NULL, NULL,
       '2024-01-01', NULL, 'SEED', 1.0,
       '1% on everything else.', NOW(), NOW()
FROM card_products WHERE bank_key = 'BOA' AND product_name = 'Customized Cash Rewards'
ON CONFLICT (card_product_id, canonical_category, effective_from) DO NOTHING;
