package com.credtrack.backend.service;

import com.credtrack.backend.dto.CardProductResponse;
import com.credtrack.backend.repository.CardProductRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CardProductService {

    private final CardProductRepository repo;

    public CardProductService(CardProductRepository repo) {
        this.repo = repo;
    }

    public List<CardProductResponse> findAll() {
        return repo.findAll().stream().map(CardProductResponse::from).toList();
    }

    /**
     * issuer = any raw issuer name string from any source.
     * Resolved to a bank_key via IssuerKeyResolver before querying.
     */
    public List<CardProductResponse> findByIssuer(String issuer) {
        String key = IssuerKeyResolver.resolve(issuer);
        if (key == null) return List.of();
        return repo.findByBankKey(key).stream().map(CardProductResponse::from).toList();
    }
}
