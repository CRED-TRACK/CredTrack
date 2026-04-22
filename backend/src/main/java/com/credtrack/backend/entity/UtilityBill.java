package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "utility_bills",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_utility_bill_gmail_message_id",
        columnNames = {"gmail_message_id"}
    )
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class UtilityBill {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** Best-effort link to the registered utility account; null if not matched. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "utility_account_id")
    private UserUtilityAccount utilityAccount;

    @Column(name = "biller_name", nullable = false, length = 50)
    private String billerName;

    @Column(name = "account_last_four", length = 10)
    private String accountLastFour;

    @Column(name = "gmail_message_id", nullable = false, length = 50)
    private String gmailMessageId;

    @Column(name = "bill_date")
    private LocalDate billDate;

    @Column(name = "billing_period_start")
    private LocalDate billingPeriodStart;

    @Column(name = "billing_period_end")
    private LocalDate billingPeriodEnd;

    @Column(name = "amount_due", precision = 12, scale = 2)
    private BigDecimal amountDue;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Builder.Default
    @Column(name = "is_paid", nullable = false)
    private Boolean isPaid = false;

    /** Running total of all linked payments — updated each time a payment is received. */
    @Builder.Default
    @Column(name = "total_paid", precision = 12, scale = 2)
    private BigDecimal totalPaid = BigDecimal.ZERO;

    @Column(name = "firebase_path", columnDefinition = "TEXT")
    private String firebasePath;

    @Column(name = "pdf_status", length = 20)
    private String pdfStatus;   // PENDING | EXTRACTED | FAILED | null

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    private void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (totalPaid == null) totalPaid = BigDecimal.ZERO;
    }
}
