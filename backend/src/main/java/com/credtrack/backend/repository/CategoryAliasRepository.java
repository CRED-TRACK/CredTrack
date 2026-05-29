package com.credtrack.backend.repository;

import com.credtrack.backend.entity.CategoryAlias;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CategoryAliasRepository extends JpaRepository<CategoryAlias, Long> {

    Optional<CategoryAlias> findByRawValue(String rawValue);
}
