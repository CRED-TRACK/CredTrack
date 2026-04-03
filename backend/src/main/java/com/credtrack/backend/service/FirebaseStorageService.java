package com.credtrack.backend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class FirebaseStorageService {

    private static final String BASE_URL = "https://firebasestorage.googleapis.com/v0/b";

    @Value("${firebase.storage.bucket}")
    private String bucket;

    @Value("${firebase.storage.cards-folder}")
    private String cardsFolder;

    /**
     * Generates a public Firebase Storage download URL for a card image.
     * Returns null if filename is null (caller should fall back to issuer color).
     */
    public String getCardImageUrl(String filename) {
        if (filename == null || filename.isBlank()) return null;
        String encodedPath = cardsFolder + "%2F" + filename;
        return String.format("%s/%s/o/%s?alt=media", BASE_URL, bucket, encodedPath);
    }
}
