package com.credtrack.backend.repository;

import com.credtrack.backend.entity.BinRecord;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BinRecordRepository extends JpaRepository<BinRecord, Long> {
}
