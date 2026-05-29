package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(
    name = "card_terms_documents",
    indexes = {
        @Index(name = "idx_card_terms_doc_product_fetched_at", columnList = "card_product_id, fetched_at")
    }
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class CardTermsDocument {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "card_product_id", nullable = false)
    private CardProduct cardProduct;

    @Column(name = "source_url", columnDefinition = "TEXT", nullable = false)
    private String sourceUrl;

    @Column(name = "content_hash", length = 64, nullable = false)
    private String contentHash;

    @Column(name = "cleaned_text", columnDefinition = "TEXT", nullable = false)
    private String cleanedText;

    @Column(name = "http_status")
    private Integer httpStatus;

    @Column(name = "fetched_at", nullable = false)
    private LocalDateTime fetchedAt;

    @Builder.Default
    @Column(name = "is_current", nullable = false)
    private Boolean isCurrent = false;

    @Column(name = "extractor_model", length = 100)
    private String extractorModel;

    @Column(name = "extracted_rules_count")
    private Integer extractedRulesCount;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    private void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
