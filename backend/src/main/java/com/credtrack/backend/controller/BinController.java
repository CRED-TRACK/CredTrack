package com.credtrack.backend.controller;

import com.credtrack.backend.dto.BinLookupResponse;
import com.credtrack.backend.service.BinService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/bins")
public class BinController {

    private final BinService binService;

    public BinController(BinService binService) {
        this.binService = binService;
    }

    /**
     * GET /bins/{cardNumber}
     *
     * Pass a full card number or just the first 6-8 digits.
     * Spaces and dashes are stripped automatically.
     *
     * Examples:
     *   GET /bins/4111111111111111   → Visa card
     *   GET /bins/411111            → same result via 6-digit BIN
     *   GET /bins/4111-1111-1111-1111 → spaces/dashes stripped
     */
    @GetMapping("/{cardNumber}")
    public ResponseEntity<BinLookupResponse> lookup(@PathVariable String cardNumber) {
        return binService.lookup(cardNumber)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
