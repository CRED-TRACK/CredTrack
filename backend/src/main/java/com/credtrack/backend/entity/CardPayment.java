package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "card_payments",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_payment_gmail_message_id",
        columnNames = {"gmail_message_id"}
    )
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class CardPayment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    // Nullable — best-effort match by card last four
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_card_id")
    private UserCard userCard;

    // Nullable — null until matched to a statement (orphan payments have no match yet)
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "matched_statement_id")
    private CardStatement matchedStatement;

    @Column(name = "gmail_message_id", nullable = false, length = 50)
    private String gmailMessageId;

    @Column(name = "card_last_four", length = 10)
    private String cardLastFour;

    @Column(name = "bank", length = 50)
    private String bank;

    @Column(name = "amount", precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(name = "payment_date")
    private LocalDate paymentDate;

    @Column(name = "effective_date")
    private LocalDate effectiveDate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    private void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
