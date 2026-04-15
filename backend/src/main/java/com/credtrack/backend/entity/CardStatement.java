package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "card_statements",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_statement_gmail_message_id",
        columnNames = {"gmail_message_id"}
    )
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class CardStatement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Always know the user
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    // Nullable — resolved by cardLastFour; null if card not yet registered in CredTrack
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_card_id")
    private UserCard userCard;

    @Column(name = "gmail_message_id", nullable = false, length = 50)
    private String gmailMessageId;

    @Column(name = "card_last_four", length = 10)
    private String cardLastFour;

    @Column(name = "bank", length = 50)
    private String bank;

    @Column(name = "statement_date")
    private LocalDate statementDate;

    @Column(name = "statement_balance", precision = 12, scale = 2)
    private BigDecimal statementBalance;

    @Column(name = "minimum_due", precision = 12, scale = 2)
    private BigDecimal minimumDue;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(name = "view_statement_url", columnDefinition = "TEXT")
    private String viewStatementUrl;

    @Column(name = "make_payment_url", columnDefinition = "TEXT")
    private String makePaymentUrl;

    @Builder.Default
    @Column(name = "is_paid", columnDefinition = "boolean not null default false")
    private Boolean isPaid = false;

    // Denormalized from the matched CardPayment for easy display — set when a payment is matched
    @Column(name = "paid_amount", precision = 12, scale = 2)
    private BigDecimal paidAmount;

    @Column(name = "payment_date")
    private LocalDate paymentDate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    private void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
