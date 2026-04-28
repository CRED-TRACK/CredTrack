package com.credtrack.backend.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PostConstruct;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

@Configuration
public class FirebaseConfig {

    private static final Logger log = LoggerFactory.getLogger(FirebaseConfig.class);

    @PostConstruct
    public void init() {
        InputStream serviceAccount = firebaseServiceAccountStream();

        if (serviceAccount == null) {
            log.warn("Firebase service account not provided via env var or classpath file — Firebase will not be initialised");
            return;
        }

        try {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
            }

        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private InputStream firebaseServiceAccountStream() {
        String serviceAccountJson = System.getenv("FIREBASE_SERVICE_ACCOUNT_JSON");
        if (serviceAccountJson != null && !serviceAccountJson.isBlank()) {
            log.info("Initialising Firebase from FIREBASE_SERVICE_ACCOUNT_JSON secret");
            return new ByteArrayInputStream(serviceAccountJson.getBytes(StandardCharsets.UTF_8));
        }

        InputStream classpathStream = getClass().getClassLoader()
                .getResourceAsStream("firebase-service-account.json");
        if (classpathStream != null) {
            log.info("Initialising Firebase from firebase-service-account.json on classpath");
        }
        return classpathStream;
    }
}
