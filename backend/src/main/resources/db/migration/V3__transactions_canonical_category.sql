ALTER TABLE transactions
    ADD COLUMN IF NOT EXISTS canonical_category VARCHAR(64);

CREATE INDEX IF NOT EXISTS idx_txn_canonical_category
    ON transactions (user_id, user_card_id, canonical_category, transaction_date);
