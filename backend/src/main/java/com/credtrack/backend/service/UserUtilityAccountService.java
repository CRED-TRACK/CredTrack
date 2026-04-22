package com.credtrack.backend.service;

import com.credtrack.backend.dto.UserUtilityAccountRequest;
import com.credtrack.backend.dto.UserUtilityAccountResponse;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.entity.UserUtilityAccount;
import com.credtrack.backend.repository.UserRepository;
import com.credtrack.backend.repository.UserUtilityAccountRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Set;

@Service
public class UserUtilityAccountService {

    private static final Set<String> VALID_BILLERS = Set.of("EVERSOURCE", "NATIONAL_GRID");

    private final UserUtilityAccountRepository utilityAccountRepo;
    private final UserRepository               userRepo;

    public UserUtilityAccountService(UserUtilityAccountRepository utilityAccountRepo,
                                     UserRepository userRepo) {
        this.utilityAccountRepo = utilityAccountRepo;
        this.userRepo           = userRepo;
    }

    public List<UserUtilityAccountResponse> getAccounts(String userId) {
        return utilityAccountRepo.findByUser_Id(userId).stream()
                .map(UserUtilityAccountResponse::from)
                .toList();
    }

    @Transactional
    public UserUtilityAccountResponse addAccount(String userId, UserUtilityAccountRequest req) {
        if (!VALID_BILLERS.contains(req.getBillerName())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "billerName must be EVERSOURCE or NATIONAL_GRID");
        }
        if (req.getAccountLastFour() == null || req.getAccountLastFour().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "accountLastFour is required");
        }

        if (utilityAccountRepo.existsByUser_IdAndBillerNameAndAccountLastFour(
                userId, req.getBillerName(), req.getAccountLastFour())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Utility account already registered");
        }

        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        UserUtilityAccount account = UserUtilityAccount.builder()
                .user(user)
                .billerName(req.getBillerName())
                .accountLastFour(req.getAccountLastFour())
                .build();

        return UserUtilityAccountResponse.from(utilityAccountRepo.save(account));
    }

    @Transactional
    public void removeAccount(String userId, Long accountId) {
        UserUtilityAccount account = utilityAccountRepo.findById(accountId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Utility account not found"));
        if (!account.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Not your account");
        }
        utilityAccountRepo.delete(account);
    }
}
