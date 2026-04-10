package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "user_cards",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_user_card_last_four",
        columnNames = {"user_id", "card_product_id", "last_four"}
    )
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class UserCard {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "card_product_id", nullable = false)
    private CardProduct cardProduct;

    // ── Card identity ──────────────────────────────────────────────────────
    @Column(name = "nickname",          length = 100) private String  nickname;
    @Column(name = "last_four",         length = 10)  private String  lastFour;
    @Column(name = "card_holder_name",  length = 150) private String  cardHolderName;

    // ── Financials ─────────────────────────────────────────────────────────
    @Column(name = "credit_limit",      precision = 12, scale = 2) private BigDecimal creditLimit;
    @Column(name = "current_balance",   precision = 12, scale = 2) private BigDecimal currentBalance;
    @Column(name = "statement_balance", precision = 12, scale = 2) private BigDecimal statementBalance;
    @Column(name = "minimum_due",       precision = 12, scale = 2) private BigDecimal minimumDue;

    // ── Key dates ──────────────────────────────────────────────────────────
    @Column(name = "payment_due_date")   private LocalDate paymentDueDate;
    @Column(name = "last_payment_date")  private LocalDate lastPaymentDate;
    @Column(name = "last_payment_amount", precision = 12, scale = 2) private BigDecimal lastPaymentAmount;

    // ── Meta ───────────────────────────────────────────────────────────────
    @Builder.Default
    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    /** True once the AI agent has completed a full historical Gmail scan for this card. */
    @Builder.Default
    @Column(name = "gmail_scan_complete", nullable = false)
    private Boolean gmailScanComplete = false;

    @Column(name = "added_at", nullable = false, updatable = false)
    private LocalDateTime addedAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    private void prePersist() {
        if (addedAt == null) addedAt = LocalDateTime.now();
    }
}
