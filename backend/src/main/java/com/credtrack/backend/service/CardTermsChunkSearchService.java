package com.credtrack.backend.service;

import lombok.Builder;
import lombok.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Vector similarity search over card_terms_chunks. Scoped to a set of card_product_ids
 * (must be the user's own owned cards — enforced upstream in ChatService).
 */
@Service
public class CardTermsChunkSearchService {

    private final JdbcTemplate jdbcTemplate;

    public CardTermsChunkSearchService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Value @Builder
    public static class ChunkHit {
        Long chunkId;
        Long documentId;
        Long cardProductId;
        String chunkText;
        String headingPath;
        Double similarity;
    }

    /**
     * Top-K most similar chunks to the embedded query, restricted to the given card_product_ids
     * (must be non-empty). Uses cosine distance via pgvector's `<=>` operator on an ivfflat index.
     */
    public List<ChunkHit> topK(float[] queryEmbedding, List<Long> cardProductIds, int k) {
        if (cardProductIds == null || cardProductIds.isEmpty()) return List.of();
        String literal = CardTermsChunkInsertService.toVectorLiteral(queryEmbedding);
        String inList = cardProductIds.stream().map(String::valueOf).collect(Collectors.joining(","));
        String sql = """
            SELECT id, document_id, card_product_id, chunk_text, heading_path,
                   1.0 - (embedding <=> ?::vector) AS similarity
            FROM card_terms_chunks
            WHERE card_product_id IN (%s)
            ORDER BY embedding <=> ?::vector
            LIMIT ?
        """.formatted(inList);
        return jdbcTemplate.query(sql, (rs, _i) -> ChunkHit.builder()
            .chunkId(rs.getLong("id"))
            .documentId(rs.getLong("document_id"))
            .cardProductId(rs.getLong("card_product_id"))
            .chunkText(rs.getString("chunk_text"))
            .headingPath(rs.getString("heading_path"))
            .similarity(rs.getDouble("similarity"))
            .build(),
            literal, literal, k);
    }
}
