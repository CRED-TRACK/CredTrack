package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "bin_records")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BinRecord {

    @Id
    @Column(name = "bin", nullable = false)
    private Long bin;

    @Column(name = "brand", length = 50)
    private String brand;

    @Column(name = "type", length = 50)
    private String type;

    @Column(name = "category", length = 50)
    private String category;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "issuer", referencedColumnName = "issuer_name", nullable = true)
    private Issuer issuer;

    @Column(name = "issuer_phone", length = 50)
    private String issuerPhone;

    @Column(name = "issuer_url", length = 500)
    private String issuerUrl;

    @Column(name = "iso_code_2", length = 5)
    private String isoCode2;

    @Column(name = "iso_code_3", length = 5)
    private String isoCode3;

    @Column(name = "country_name", length = 100)
    private String countryName;

    @Column(name = "color", length = 20)
    private String color;
}
