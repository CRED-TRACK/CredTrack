package com.credtrack.backend.repository;

import com.credtrack.backend.entity.GmailCredential;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface GmailCredentialRepository extends JpaRepository<GmailCredential, Long> {

    Optional<GmailCredential> findByUser_Id(String userId);

    List<GmailCredential> findAll();
}
