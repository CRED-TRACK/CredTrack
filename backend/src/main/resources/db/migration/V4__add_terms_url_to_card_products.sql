ALTER TABLE card_products
    ADD COLUMN IF NOT EXISTS terms_url TEXT;
