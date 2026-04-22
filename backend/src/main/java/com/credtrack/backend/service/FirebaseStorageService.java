package com.credtrack.backend.service;

import com.google.firebase.cloud.StorageClient;
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

    /**
     * Uploads a PDF to Firebase Storage and returns the storage path.
     * Path pattern: statements/{userId}/{cardId}/{filename}
     */
    public String uploadStatementPdf(String userId, Long cardId, String filename, byte[] bytes) {
        String path = String.format("statements/%s/%d/%s", userId, cardId, filename);
        StorageClient.getInstance().bucket(bucket)
                .create(path, bytes, "application/pdf");
        return path;
    }

    /**
     * Uploads a utility bill PDF to Firebase Storage and returns the storage path.
     * Path pattern: utility-bills/{userId}/{billId}/{filename}
     */
    public String uploadUtilityBillPdf(String userId, Long billId, String filename, byte[] bytes) {
        String path = String.format("utility-bills/%s/%d/%s", userId, billId, filename);
        StorageClient.getInstance().bucket(bucket)
                .create(path, bytes, "application/pdf");
        return path;
    }

    /**
     * Downloads a PDF from Firebase Storage and returns its bytes.
     * Works for both statement and utility bill paths.
     * Returns null if storagePath is null.
     */
    public byte[] downloadStatementPdf(String storagePath) {
        if (storagePath == null || storagePath.isBlank()) return null;
        return StorageClient.getInstance().bucket(bucket)
                .get(storagePath)
                .getContent();
    }
}
