package com.credtrack.backend.service;

import com.credtrack.backend.dto.GmailCredentialRequest;
import com.credtrack.backend.dto.TransactionCreateRequest;
import com.credtrack.backend.dto.TransactionResponse;
import com.credtrack.backend.dto.TransactionUpdateRequest;
import com.credtrack.backend.entity.GmailCredential;
import com.credtrack.backend.entity.Transaction;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.repository.GmailCredentialRepository;
import com.credtrack.backend.repository.TransactionRepository;
import com.credtrack.backend.repository.UserCardRepository;
import com.credtrack.backend.repository.UserRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class TransactionInternalService {

    private final TransactionRepository    transactionRepo;
    private final GmailCredentialRepository credentialRepo;
    private final UserRepository           userRepo;
    private final UserCardRepository       userCardRepo;

    public TransactionInternalService(TransactionRepository transactionRepo,
                                      GmailCredentialRepository credentialRepo,
                                      UserRepository userRepo,
                                      UserCardRepository userCardRepo) {
        this.transactionRepo = transactionRepo;
        this.credentialRepo  = credentialRepo;
        this.userRepo        = userRepo;
        this.userCardRepo    = userCardRepo;
    }

    @Transactional
    public TransactionResponse create(TransactionCreateRequest req) {
        if (transactionRepo.existsByGmailMessageId(req.getGmailMessageId())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Transaction already exists for gmailMessageId: " + req.getGmailMessageId());
        }

        User user = userRepo.findById(req.getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        // Best-effort card reconciliation by last four digits
        UserCard userCard = null;
        if (req.getCardLastFour() != null) {
            userCard = userCardRepo.findByUser_IdOrderByAddedAtDesc(user.getId()).stream()
                    .filter(uc -> req.getCardLastFour().equals(uc.getLastFour()) && Boolean.TRUE.equals(uc.getIsActive()))
                    .findFirst()
                    .orElse(null);
        }

        Transaction t = Transaction.builder()
                .user(user)
                .userCard(userCard)
                .gmailMessageId(req.getGmailMessageId())
                .merchantName(req.getMerchantName())
                .merchantCategory(req.getMerchantCategory())
                .amount(req.getAmount())
                .currency(req.getCurrency() != null ? req.getCurrency() : "USD")
                .transactionDate(req.getTransactionDate())
                .postedDate(req.getPostedDate())
                .cardLastFour(req.getCardLastFour())
                .transactionType(req.getTransactionType())
                .status(req.getStatus() != null ? req.getStatus() : "PENDING")
                .description(req.getDescription())
                .llmConfidence(req.getLlmConfidence())
                .extractionModel(req.getExtractionModel())
                .bankKey(req.getBankKey())
                .build();

        try {
            return TransactionResponse.from(transactionRepo.save(t));
        } catch (DataIntegrityViolationException e) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Duplicate transaction: " + req.getGmailMessageId());
        }
    }

    @Transactional
    public TransactionResponse update(Long id, String userId, TransactionUpdateRequest req) {
        Transaction t = transactionRepo.findByIdAndUser_Id(id, userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Transaction not found"));

        if (req.getMerchantName() != null)     t.setMerchantName(req.getMerchantName());
        if (req.getMerchantCategory() != null) t.setMerchantCategory(req.getMerchantCategory());
        if (req.getStatus() != null)           t.setStatus(req.getStatus());
        if (req.getUserCardId() != null) {
            UserCard uc = userCardRepo.findByIdAndUser_Id(req.getUserCardId(), userId)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Card not found"));
            t.setUserCard(uc);
        }

        return TransactionResponse.from(transactionRepo.save(t));
    }

    @Transactional
    public GmailCredential upsertCredential(GmailCredentialRequest req) {
        User user = userRepo.findById(req.getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        GmailCredential cred = credentialRepo.findByUser_Id(req.getUserId())
                .orElseGet(() -> GmailCredential.builder().user(user).build());

        if (req.getEncryptedRefreshToken() != null) cred.setEncryptedRefreshToken(req.getEncryptedRefreshToken());
        if (req.getAccessToken() != null)            cred.setAccessToken(req.getAccessToken());
        if (req.getTokenExpiryUtc() != null)         cred.setTokenExpiryUtc(req.getTokenExpiryUtc());
        if (req.getGmailAddress() != null)           cred.setGmailAddress(req.getGmailAddress());
        if (req.getHistoryId() != null)              cred.setHistoryId(req.getHistoryId());
        if (req.getLastSyncedAt() != null)           cred.setLastSyncedAt(req.getLastSyncedAt());

        return credentialRepo.save(cred);
    }
}
