package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;
import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    private String id;

    @Column(unique = true, nullable = false)
    private String email;

    private String name;

    private String profilePicture;

    private String provider;

    private Boolean emailVerified;

    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    private LocalDateTime lastLogin;

    @Column(name = "telegram_chat_id")
    private String telegramChatId;

    @Column(name = "notify_statements", nullable = false,
            columnDefinition = "BOOLEAN NOT NULL DEFAULT TRUE")
    private Boolean notifyStatements = Boolean.TRUE;

    @Column(name = "notify_transactions", nullable = false,
            columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE")
    private Boolean notifyTransactions = Boolean.FALSE;

    @Column(name = "notify_payments", nullable = false,
            columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE")
    private Boolean notifyPayments = Boolean.FALSE;

    @Column(name = "notify_utility_bills", nullable = false,
            columnDefinition = "BOOLEAN NOT NULL DEFAULT FALSE")
    private Boolean notifyUtilityBills = Boolean.FALSE;
}