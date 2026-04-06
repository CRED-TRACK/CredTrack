package com.credtrack.backend.service;

import com.credtrack.backend.dto.BinLookupResponse;
import com.credtrack.backend.entity.BinRecord;
import com.credtrack.backend.repository.BinRecordRepository;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class BinService {

    private final BinRecordRepository binRecordRepository;

    public BinService(BinRecordRepository binRecordRepository) {
        this.binRecordRepository = binRecordRepository;
    }

    /**
     * Looks up BIN details from a full card number (or a raw BIN).
     *
     * Strategy: try 8-digit BIN first (more specific), fall back to 6-digit.
     * This mirrors how real BIN databases work — newer cards use 8-digit BINs.
     *
     * @param cardNumber full PAN or BIN prefix (min 6 digits)
     * @return BinLookupResponse if found
     */
    public Optional<BinLookupResponse> lookup(String cardNumber) {
        // Strip spaces/dashes in case user passes a formatted number
        String digits = cardNumber.replaceAll("[^0-9]", "");

        if (digits.length() < 6) {
            return Optional.empty();
        }

        // Try 8-digit BIN first
        if (digits.length() >= 8) {
            long bin8 = Long.parseLong(digits.substring(0, 8));
            Optional<BinRecord> result = binRecordRepository.findByBin(bin8);
            if (result.isPresent()) {
                return result.map(BinLookupResponse::from);
            }
        }

        // Fall back to 6-digit BIN
        long bin6 = Long.parseLong(digits.substring(0, 6));
        return binRecordRepository.findByBin(bin6).map(BinLookupResponse::from);
    }
}
