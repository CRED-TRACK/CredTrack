-- Vector-bearing chunk table for RAG retrieval by the chat advisor.
-- Hibernate intentionally does NOT manage the `embedding` column — inserts go
-- through CardTermsChunkInsertService using JdbcTemplate + `?::vector` cast.
CREATE TABLE IF NOT EXISTS card_terms_chunks (
    id              BIGSERIAL PRIMARY KEY,
    document_id     BIGINT NOT NULL REFERENCES card_terms_documents(id) ON DELETE CASCADE,
    card_product_id BIGINT NOT NULL REFERENCES card_products(id) ON DELETE CASCADE,
    chunk_index     INTEGER NOT NULL,
    chunk_text      TEXT NOT NULL,
    heading_path    VARCHAR(512),
    token_count     INTEGER,
    embedding       vector(768) NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_card_terms_chunks_document_id
    ON card_terms_chunks (document_id);

CREATE INDEX IF NOT EXISTS idx_card_terms_chunks_card_product_id
    ON card_terms_chunks (card_product_id);

CREATE INDEX IF NOT EXISTS idx_card_terms_chunks_embedding
    ON card_terms_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 50);
