package com.credtrack.backend.service;

import com.credtrack.backend.dto.UserCardRequest;
import com.credtrack.backend.dto.UserCardResponse;
import com.credtrack.backend.entity.CardProduct;
import com.credtrack.backend.entity.User;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.repository.CardProductRepository;
import com.credtrack.backend.repository.UserCardRepository;
import com.credtrack.backend.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class UserCardService {

    private final UserCardRepository    userCardRepo;
    private final UserRepository        userRepo;
    private final CardProductRepository cardProductRepo;

    public UserCardService(UserCardRepository userCardRepo,
                           UserRepository userRepo,
                           CardProductRepository cardProductRepo) {
        this.userCardRepo    = userCardRepo;
        this.userRepo        = userRepo;
        this.cardProductRepo = cardProductRepo;
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
    public UserCardResponse addCard(UserCardRequest req) {
        User user = userRepo.findById(req.getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        CardProduct product = cardProductRepo.findById(req.getCardProductId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Card product not found"));

        if (req.getLastFour() != null
                && userCardRepo.existsByUser_IdAndCardProduct_IdAndLastFour(
                        req.getUserId(), req.getCardProductId(), req.getLastFour())) {
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

    @Transactional
    public void removeCard(Long cardId, String userId) {
        UserCard card = userCardRepo.findByIdAndUser_Id(cardId, userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Card not found"));
        card.setIsActive(false);
        userCardRepo.save(card);
    }
}
