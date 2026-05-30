package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CardTermsChunk;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CardTermsChunkRepository extends JpaRepository<CardTermsChunk, Long> {
    // Vector similarity queries live in CardTermsChunkSearchService since they need
    // pgvector's `<=>` operator + a vector literal cast that JPA can't express portably.
    int deleteByDocumentId(Long documentId);
}
