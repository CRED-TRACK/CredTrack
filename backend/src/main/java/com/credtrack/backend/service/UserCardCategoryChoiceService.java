package com.credtrack.backend.service;

import com.credtrack.backend.entity.CanonicalCategory;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.entity.UserCardCategoryChoice;
import com.credtrack.backend.repository.UserCardCategoryChoiceRepository;
import com.credtrack.backend.repository.UserCardRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class UserCardCategoryChoiceService {

    private final UserCardCategoryChoiceRepository choiceRepository;
    private final UserCardRepository userCardRepository;

    public UserCardCategoryChoiceService(UserCardCategoryChoiceRepository choiceRepository,
                                         UserCardRepository userCardRepository) {
        this.choiceRepository = choiceRepository;
        this.userCardRepository = userCardRepository;
    }

    public Map<Long, UserCardCategoryChoice> findActiveBofaChoices(List<Long> userCardIds, LocalDate asOf) {
        if (userCardIds.isEmpty()) return Map.of();
        Map<Long, UserCardCategoryChoice> out = new HashMap<>();
        for (UserCardCategoryChoice c : choiceRepository.findActiveForUserCards(userCardIds, asOf)) {
            if (UserCardCategoryChoice.KIND_BOA_CUSTOMIZED_3PCT.equals(c.getChoiceKind())) {
                out.put(c.getUserCard().getId(), c);
            }
        }
        return out;
    }

    @Transactional
    public UserCardCategoryChoice upsertChoice(String userId, Long userCardId,
                                               String choiceKind, String canonicalCategory) {
        UserCard card = userCardRepository.findByIdAndUser_Id(userCardId, userId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User card not found"));

        CanonicalCategory.fromCode(canonicalCategory)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Unknown canonical category: " + canonicalCategory));

        if (!UserCardCategoryChoice.KIND_BOA_CUSTOMIZED_3PCT.equals(choiceKind)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Unsupported choice_kind: " + choiceKind);
        }

        LocalDate today = LocalDate.now();
        // Close any currently-active choice of the same kind.
        choiceRepository.findActive(userCardId, choiceKind, today).ifPresent(prev -> {
            prev.setEffectiveTo(today.minusDays(1));
            choiceRepository.save(prev);
        });

        UserCardCategoryChoice fresh = UserCardCategoryChoice.builder()
            .userCard(card)
            .choiceKind(choiceKind)
            .canonicalCategory(canonicalCategory)
            .effectiveFrom(today)
            .effectiveTo(null)
            .build();
        return choiceRepository.save(fresh);
    }
}
