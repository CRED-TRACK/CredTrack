package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(
    name = "user_utility_accounts",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_utility_account",
        columnNames = {"user_id", "biller_name", "account_last_four"}
    )
)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class UserUtilityAccount {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** EVERSOURCE or NATIONAL_GRID */
    @Column(name = "biller_name", nullable = false, length = 50)
    private String billerName;

    /** Last 4 digits of the utility account number — used for Gmail search + dedup. */
    @Column(name = "account_last_four", nullable = false, length = 10)
    private String accountLastFour;

    /**
     * Set to true by the AI agent after the one-time historical init scan
     * (bills then payments over the last 2 years) completes for this account.
     * While false the coordinator runs the init path; once true it switches to
     * the normal incremental poll path.
     */
    @Column(name = "utility_init_complete", nullable = false)
    private boolean utilityInitComplete = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    private void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }
}
