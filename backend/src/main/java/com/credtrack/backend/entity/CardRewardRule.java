package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "card_reward_rules",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_rule_product_category_effective_from",
        columnNames = {"card_product_id", "canonical_category", "effective_from"}
    )
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class CardRewardRule {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "card_product_id", nullable = false)
    private CardProduct cardProduct;

    @Column(name = "canonical_category", length = 64, nullable = false)
    private String canonicalCategory;

    @Column(name = "rate_bps", nullable = false)
    private Integer rateBps;

    @Column(name = "base_rate_bps")
    private Integer baseRateBps;

    @Enumerated(EnumType.STRING)
    @Column(name = "cap_type", length = 16, nullable = false)
    @Builder.Default
    private CapType capType = CapType.NONE;

    @Column(name = "cap_amount", precision = 12, scale = 2)
    private BigDecimal capAmount;

    @Enumerated(EnumType.STRING)
    @Column(name = "cap_period", length = 32, nullable = false)
    @Builder.Default
    private CapPeriod capPeriod = CapPeriod.NONE;

    @Column(name = "cap_group_key", length = 64)
    private String capGroupKey;

    @Builder.Default
    @Column(name = "requires_user_choice", nullable = false)
    private Boolean requiresUserChoice = false;

    @Column(name = "channel_restriction", length = 64)
    private String channelRestriction;

    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "exclusions", columnDefinition = "text[]")
    private String[] exclusions;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

    @Enumerated(EnumType.STRING)
    @Column(name = "source", length = 24, nullable = false)
    @Builder.Default
    private RuleSource source = RuleSource.SEED;

    @Column(name = "source_confidence")
    private Float sourceConfidence;

    @Column(name = "source_document_id")
    private Long sourceDocumentId;

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;

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
