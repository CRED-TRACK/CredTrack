package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.Map;

@Entity
@Table(name = "card_products")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CardProduct {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "issuer_name", referencedColumnName = "issuer_name", nullable = false)
    private Issuer issuer;

    @Column(name = "product_name", nullable = false, length = 150)
    private String productName;           // Display name e.g. "Sapphire Preferred"

    @Column(name = "official_name", nullable = false, length = 255)
    private String officialName;          // Exact canonical name for internet lookups

    @Column(name = "image_filename", length = 150)
    private String imageFilename;         // Filename in Firebase Storage, null = fallback to issuer color

    @Column(name = "brand", length = 50)
    private String brand;                 // VISA, MASTERCARD, AMEX, DISCOVER

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "link", columnDefinition = "jsonb")
    private Map<String, String> link;     // e.g. {"apply": "...", "rewards": "...", "info": "..."}
}
