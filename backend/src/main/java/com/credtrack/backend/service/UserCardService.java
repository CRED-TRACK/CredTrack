package com.credtrack.backend.service;

import com.credtrack.backend.dto.UserCardRequest;
import com.credtrack.backend.dto.UserCardResponse;
import com.credtrack.backend.entity.CardProduct;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.repository.CardPaymentRepository;
import com.credtrack.backend.repository.CardProductRepository;
import com.credtrack.backend.repository.CardStatementRepository;
import com.credtrack.backend.repository.TransactionRepository;
import com.credtrack.backend.repository.UserCardRepository;
import com.credtrack.backend.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class UserCardService {

    private static final Logger log = LoggerFactory.getLogger(UserCardService.class);

    private final UserCardRepository      userCardRepo;
    private final UserRepository          userRepo;
    private final CardProductRepository   cardProductRepo;
    private final CardPaymentRepository   cardPaymentRepo;
    private final CardStatementRepository cardStatementRepo;
    private final TransactionRepository   transactionRepo;

    public UserCardService(UserCardRepository userCardRepo,
                           UserRepository userRepo,
                           CardProductRepository cardProductRepo,
                           CardPaymentRepository cardPaymentRepo,
                           CardStatementRepository cardStatementRepo,
                           TransactionRepository transactionRepo) {
        this.userCardRepo      = userCardRepo;
        this.userRepo          = userRepo;
        this.cardProductRepo   = cardProductRepo;
        this.cardPaymentRepo   = cardPaymentRepo;
        this.cardStatementRepo = cardStatementRepo;
        this.transactionRepo   = transactionRepo;
    }

    public List<UserCardResponse> getCardsForUser(String userId, boolean includeInactive) {
        var cards = includeInactive
                ? userCardRepo.findByUser_IdOrderByAddedAtDesc(userId)
                : userCardRepo.findByUser_IdAndIsActiveTrueOrderByAddedAtDesc(userId);
        return cards.stream().map(UserCardResponse::from).toList();
    }

    public UserCardResponse getCard(Long cardId, String userId) {
        return userCardRepo.findByIdAndUser_Id(cardId, userId)
                .map(UserCardResponse::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Card not found"));
    }

    @Transactional
    public UserCardResponse addCard(String userId, UserCardRequest req) {
        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        CardProduct product = cardProductRepo.findById(req.getCardProductId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Card product not found"));

        if (req.getLastFour() != null
                && userCardRepo.existsByUser_IdAndCardProduct_IdAndLastFour(
                        userId, req.getCardProductId(), req.getLastFour())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Card already added");
        }

        UserCard card = UserCard.builder()
                .user(user)
                .cardProduct(product)
                .nickname(req.getNickname())
                .lastFour(req.getLastFour())
                .cardHolderName(req.getCardHolderName())
                .creditLimit(req.getCreditLimit())
                .currentBalance(req.getCurrentBalance())
                .statementBalance(req.getStatementBalance())
                .minimumDue(req.getMinimumDue())
                .paymentDueDate(req.getPaymentDueDate())
                .lastPaymentDate(req.getLastPaymentDate())
                .lastPaymentAmount(req.getLastPaymentAmount())
                .build();

        // The AI agent poll coordinator checks gmailScanComplete on every cycle.
        // A newly added card has gmailScanComplete=false, so the next poll will
        // automatically spawn an InitCardScanActor for it — no explicit trigger needed.
        return UserCardResponse.from(userCardRepo.save(card));
    }

    @Transactional
    public UserCardResponse updateCard(Long cardId, String userId, UserCardRequest req) {
        UserCard card = userCardRepo.findByIdAndUser_Id(cardId, userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Card not found"));

        if (req.getNickname()          != null) card.setNickname(req.getNickname());
        if (req.getCardHolderName()    != null) card.setCardHolderName(req.getCardHolderName());
        if (req.getCreditLimit()       != null) card.setCreditLimit(req.getCreditLimit());
        if (req.getCurrentBalance()    != null) card.setCurrentBalance(req.getCurrentBalance());
        if (req.getStatementBalance()  != null) card.setStatementBalance(req.getStatementBalance());
        if (req.getMinimumDue()        != null) card.setMinimumDue(req.getMinimumDue());
        if (req.getPaymentDueDate()    != null) card.setPaymentDueDate(req.getPaymentDueDate());
        if (req.getLastPaymentDate()   != null) card.setLastPaymentDate(req.getLastPaymentDate());
        if (req.getLastPaymentAmount() != null) card.setLastPaymentAmount(req.getLastPaymentAmount());
        if (req.getIsActive()          != null) card.setIsActive(req.getIsActive());

        return UserCardResponse.from(userCardRepo.save(card));
    }

    /**
     * Hard-deletes a card and EVERY trace associated with it from the database:
     *
     *   Step 1 — payments first (they hold FK refs to statements via matched_statement_id)
     *     a) Linked payments   (user_card_id = cardId)
     *     b) Orphaned payments (user_card_id IS NULL, matched by userId + lastFour + bankKey)
     *
     *   Step 2 — transactions
     *     a) Linked transactions
     *     b) Orphaned transactions
     *
     *   Step 3 — statements (safe now that all payments referencing them are gone)
     *     a) Linked statements
     *     b) Orphaned statements
     *
     *   Step 4 — the UserCard row itself
     *
     * Orphaned records are emails that arrived before the card was registered in CredTrack.
     * Without this cleanup their gmail_message_id unique-constraint entries would survive,
     * blocking re-import if the same card is added again later.
     */
    @Transactional
    public void removeCard(Long cardId, String userId) {
        UserCard card = userCardRepo.findByIdAndUser_Id(cardId, userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Card not found"));

        String lastFour = card.getLastFour();
        String bankKey  = card.getCardProduct() != null ? card.getCardProduct().getBankKey() : null;

        // ── Step 1: payments ────────────────────────────────────────────────
        cardPaymentRepo.deleteByUserCard_Id(cardId);
        int orphanPayments = (lastFour != null && bankKey != null)
                ? cardPaymentRepo.deleteOrphansByUser_IdAndCardLastFourAndBank(userId, lastFour, bankKey)
                : 0;

        // ── Step 2: transactions ─────────────────────────────────────────────
        transactionRepo.deleteByUserCard_Id(cardId);
        int orphanTxns = (lastFour != null && bankKey != null)
                ? transactionRepo.deleteOrphansByUser_IdAndCardLastFourAndBankKey(userId, lastFour, bankKey)
                : 0;

        // ── Step 3: statements ───────────────────────────────────────────────
        cardStatementRepo.deleteByUserCard_Id(cardId);
        int orphanStatements = (lastFour != null && bankKey != null)
                ? cardStatementRepo.deleteOrphansByUser_IdAndCardLastFourAndBank(userId, lastFour, bankKey)
                : 0;

        // ── Step 4: the card itself ───────────────────────────────────────────
        userCardRepo.delete(card);

        log.info("Card {} ({} / lastFour={}) hard-deleted for user {} — " +
                 "orphaned records also purged: {} payment(s), {} transaction(s), {} statement(s)",
                cardId, bankKey, lastFour, userId,
                orphanPayments, orphanTxns, orphanStatements);
    }
}
