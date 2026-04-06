package com.credtrack.backend.repository;

import com.credtrack.backend.entity.UserCard;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserCardRepository extends JpaRepository<UserCard, Long> {

    List<UserCard> findByUser_IdAndIsActiveTrueOrderByAddedAtDesc(String userId);

    List<UserCard> findByUser_IdOrderByAddedAtDesc(String userId);

    Optional<UserCard> findByIdAndUser_Id(Long id, String userId);

    boolean existsByUser_IdAndCardProduct_IdAndLastFour(
            String userId, Long cardProductId, String lastFour);
}
