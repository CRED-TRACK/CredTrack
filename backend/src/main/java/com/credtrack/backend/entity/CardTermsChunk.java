package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Read-side projection of card_terms_chunks. The `embedding vector(768)` column is
 * managed entirely outside Hibernate (Flyway V7 creates it, CardTermsChunkInsertService
 * writes it via JdbcTemplate with `?::vector` cast). Reads happen via native cosine
 * similarity queries — see CardTermsChunkRepository.
 */
@Entity
@Table(name = "card_terms_chunks")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class CardTermsChunk {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "document_id", nullable = false)
    private Long documentId;

    @Column(name = "card_product_id", nullable = false)
    private Long cardProductId;

    @Column(name = "chunk_index", nullable = false)
    private Integer chunkIndex;

    @Column(name = "chunk_text", columnDefinition = "TEXT", nullable = false)
    private String chunkText;

    @Column(name = "heading_path", length = 512)
    private String headingPath;

    @Column(name = "token_count")
    private Integer tokenCount;

    @Column(name = "created_at", nullable = false, updatable = false, insertable = false)
    private LocalDateTime createdAt;
}
