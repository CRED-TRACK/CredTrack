package com.credtrack.backend.controller;

import com.credtrack.backend.dto.CardProductResponse;
import com.credtrack.backend.service.CardProductService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/card-products")
public class CardProductController {

    private final CardProductService service;

    public CardProductController(CardProductService service) {
        this.service = service;
    }

    /**
     * GET /card-products
     * Returns all card products with colours.
     *
     * Optional filter:
     *   GET /card-products?issuer=JPMORGAN+CHASE+BANK+N.A.
     */
    @GetMapping
    public ResponseEntity<List<CardProductResponse>> list(
            @RequestParam(required = false) String issuer) {

        List<CardProductResponse> results = (issuer != null && !issuer.isBlank())
                ? service.findByIssuer(issuer)
                : service.findAll();

        return ResponseEntity.ok(results);
    }
}
