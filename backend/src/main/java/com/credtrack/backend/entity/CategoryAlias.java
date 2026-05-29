package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(
    name = "category_aliases",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_category_alias_raw_value",
        columnNames = {"raw_value"}
    )
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class CategoryAlias {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "raw_value", length = 255, nullable = false)
    private String rawValue;

    @Column(name = "canonical_category", length = 64, nullable = false)
    private String canonicalCategory;

    @Enumerated(EnumType.STRING)
    @Column(name = "source", length = 24, nullable = false)
    @Builder.Default
    private AliasSource source = AliasSource.SEED;

    @Column(name = "confidence")
    private Float confidence;

    @Builder.Default
    @Column(name = "sample_transaction_count", nullable = false)
    private Long sampleTransactionCount = 0L;

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
