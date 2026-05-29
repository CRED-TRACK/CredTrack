package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "user_card_category_choices",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_user_card_choice_effective_from",
        columnNames = {"user_card_id", "choice_kind", "effective_from"}
    )
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class UserCardCategoryChoice {

    public static final String KIND_BOA_CUSTOMIZED_3PCT = "BOA_CUSTOMIZED_3PCT";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_card_id", nullable = false)
    private UserCard userCard;

    @Column(name = "choice_kind", length = 64, nullable = false)
    private String choiceKind;

    @Column(name = "canonical_category", length = 64, nullable = false)
    private String canonicalCategory;

    @Column(name = "effective_from", nullable = false)
    private LocalDate effectiveFrom;

    @Column(name = "effective_to")
    private LocalDate effectiveTo;

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
