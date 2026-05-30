package com.credtrack.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Bypasses Hibernate to insert chunks into card_terms_chunks because the embedding
 * column is pgvector's `vector(768)` which Hibernate cannot map natively.
 */
@Service
public class CardTermsChunkInsertService {

    private static final Logger log = LoggerFactory.getLogger(CardTermsChunkInsertService.class);

    private final JdbcTemplate jdbcTemplate;

    public CardTermsChunkInsertService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public record ChunkInsert(
        Long documentId,
        Long cardProductId,
        int chunkIndex,
        String chunkText,
        String headingPath,
        Integer tokenCount,
        float[] embedding
    ) {}

    /** Replace-all for a document — call before inserting new chunks. */
    public int deleteByDocumentId(Long documentId) {
        return jdbcTemplate.update("DELETE FROM card_terms_chunks WHERE document_id = ?", documentId);
    }

    public int insertBatch(List<ChunkInsert> chunks) {
        if (chunks.isEmpty()) return 0;
        int total = 0;
        for (ChunkInsert c : chunks) {
            String embeddingLiteral = toVectorLiteral(c.embedding);
            total += jdbcTemplate.update("""
                    INSERT INTO card_terms_chunks
                        (document_id, card_product_id, chunk_index, chunk_text, heading_path, token_count, embedding)
                    VALUES (?, ?, ?, ?, ?, ?, ?::vector)
                """,
                c.documentId, c.cardProductId, c.chunkIndex,
                c.chunkText, c.headingPath, c.tokenCount, embeddingLiteral);
        }
        log.info("chunk_insert document_id={} chunks={} inserted={}",
            chunks.isEmpty() ? null : chunks.get(0).documentId(), chunks.size(), total);
        return total;
    }

    public static String toVectorLiteral(float[] embedding) {
        return "[" + java.util.stream.IntStream.range(0, embedding.length)
            .mapToObj(i -> Float.toString(embedding[i]))
            .collect(Collectors.joining(",")) + "]";
    }
}
