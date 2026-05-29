package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.Map;

@Entity
@Table(name = "card_products")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class CardProduct {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "issuer_name", length = 255)
    private String issuerName;        // display label e.g. "JPMORGAN CHASE BANK N.A."

    @Column(name = "bank_key", length = 50)
    private String bankKey;           // stable key e.g. "CHASE" — used for logo + product lookup

    @Column(name = "product_name", nullable = false, length = 150)
    private String productName;       // e.g. "Sapphire Reserve"

    @Column(name = "official_name", nullable = false, length = 255)
    private String officialName;

    @Column(name = "brand", length = 50)
    private String brand;             // VISA | MASTERCARD | AMEX | DISCOVER

    @Column(name = "face_color", length = 7, nullable = false)
    private String faceColor;

    @Column(name = "gradient_end", length = 7, nullable = false)
    private String gradientEnd;

    @Column(name = "text_color", length = 7, nullable = false)
    private String textColor;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "link", columnDefinition = "jsonb")
    private Map<String, String> link;

    /**
     * Public benefits/T&C page URL used by the ai-agent scraper.
     * NULL = scraper skips this product. Seeded for the user's owned cards in seed_card_reward_rules.sql.
     */
    @Column(name = "terms_url", columnDefinition = "TEXT")
    private String termsUrl;
}
