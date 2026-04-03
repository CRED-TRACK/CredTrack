package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CardProduct;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface CardProductRepository extends JpaRepository<CardProduct, Long> {
    List<CardProduct> findByIssuer_IssuerName(String issuerName);
}
