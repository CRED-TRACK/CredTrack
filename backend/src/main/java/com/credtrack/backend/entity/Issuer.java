package com.credtrack.backend.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "issuers")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Issuer {

    @Id
    @Column(name = "issuer_name", nullable = false, length = 255)
    private String issuerName;

    @Column(name = "issuer_phone", length = 50)
    private String issuerPhone;

    @Column(name = "issuer_url", length = 500)
    private String issuerUrl;

    @Column(name = "color", length = 20)
    private String color;

}
