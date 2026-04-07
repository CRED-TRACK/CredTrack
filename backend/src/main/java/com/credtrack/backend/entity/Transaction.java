package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "transactions",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_transaction_gmail_message_id",
        columnNames = {"gmail_message_id"}
    )
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Transaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_card_id")
    private UserCard userCard;

    @Column(name = "gmail_message_id", nullable = false, length = 50)
    private String gmailMessageId;

    @Column(name = "merchant_name",     length = 255) private String merchantName;
    @Column(name = "merchant_category", length = 100) private String merchantCategory;

    @Column(name = "amount", precision = 12, scale = 2, nullable = false)
    private BigDecimal amount;

    @Builder.Default
    @Column(name = "currency", length = 3)
    private String currency = "USD";

    @Column(name = "transaction_date", nullable = false) private LocalDate transactionDate;
    @Column(name = "posted_date")                        private LocalDate postedDate;

    @Column(name = "card_last_four", length = 4)   private String cardLastFour;
    @Column(name = "transaction_type", length = 30) private String transactionType;

    @Builder.Default
    @Column(name = "status", length = 30)
    private String status = "PENDING";

    @Column(name = "description",        columnDefinition = "TEXT") private String description;
    @Column(name = "llm_confidence",     length = 10)               private String llmConfidence;
    @Column(name = "extraction_model",   length = 50)               private String extractionModel;
    @Column(name = "bank_key",           length = 50)               private String bankKey;

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
