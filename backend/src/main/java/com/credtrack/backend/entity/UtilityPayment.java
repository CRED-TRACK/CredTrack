package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "utility_payments",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_utility_payment_gmail_message_id",
        columnNames = {"gmail_message_id"}
    )
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class UtilityPayment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** Null until matched to a bill; orphan payments matched when the bill email arrives. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "bill_id")
    private UtilityBill bill;

    @Column(name = "biller_name", nullable = false, length = 50)
    private String billerName;

    @Column(name = "account_last_four", length = 10)
    private String accountLastFour;

    @Column(name = "gmail_message_id", nullable = false, length = 50)
    private String gmailMessageId;

    @Column(name = "payment_amount", precision = 12, scale = 2)
    private BigDecimal paymentAmount;

    @Column(name = "payment_date")
    private LocalDate paymentDate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    private void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
