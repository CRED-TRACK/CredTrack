package com.credtrack.backend.repository;

import com.credtrack.backend.entity.Issuer;
import org.springframework.data.jpa.repository.JpaRepository;

public interface IssuerRepository extends JpaRepository<Issuer, String> {
}
