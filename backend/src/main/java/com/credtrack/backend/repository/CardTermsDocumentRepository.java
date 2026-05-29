package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CardTermsDocument;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CardTermsDocumentRepository extends JpaRepository<CardTermsDocument, Long> {

    Optional<CardTermsDocument> findFirstByCardProduct_IdAndIsCurrentTrue(Long cardProductId);
}
