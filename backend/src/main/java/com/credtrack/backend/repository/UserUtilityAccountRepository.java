package com.credtrack.backend.repository;

import com.credtrack.backend.entity.UserUtilityAccount;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserUtilityAccountRepository extends JpaRepository<UserUtilityAccount, Long> {

    List<UserUtilityAccount> findByUser_Id(String userId);

    Optional<UserUtilityAccount> findByUser_IdAndBillerNameAndAccountLastFour(
            String userId, String billerName, String accountLastFour);

    boolean existsByUser_IdAndBillerNameAndAccountLastFour(
            String userId, String billerName, String accountLastFour);
}
