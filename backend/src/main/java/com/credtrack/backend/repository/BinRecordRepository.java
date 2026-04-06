package com.credtrack.backend.repository;

import com.credtrack.backend.entity.BinRecord;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface BinRecordRepository extends JpaRepository<BinRecord, Long> {

    // Exact BIN lookup — supports both 6-digit and 8-digit BINs
    Optional<BinRecord> findByBin(Long bin);
}
