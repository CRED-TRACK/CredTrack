package com.credtrack.backend.service;

import com.credtrack.backend.dto.ChatRequest;
import com.credtrack.backend.dto.ChatResponse;
import com.credtrack.backend.entity.CardProduct;
import com.credtrack.backend.entity.CardRewardRule;
import com.credtrack.backend.entity.UserCard;
import com.credtrack.backend.repository.CardProductRepository;
import com.credtrack.backend.repository.UserCardRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * RAG chat advisor. Given a user question:
 *   1. Embed the question
 *   2. Top-K cosine search over card_terms_chunks scoped to the user's owned cards
 *   3. Build a strictly-formatted prompt with chunks + active reward rules + user message
 *   4. Call Gemini chat → return answer + sources
 *
 * Cached data only — never triggers a scrape on the chat path. If chunks are absent
 * for a card, that card is silently omitted from the retrieval (caller sees no source
 * for it). Acceptable: user knows it just means scraper hasn't covered that product yet.
 */
@Service
public class ChatService {

    private static final Logger log = LoggerFactory.getLogger(ChatService.class);
    private static final int MAX_QUESTION_CHARS = 500;
    private static final int MAX_HISTORY_TURNS = 8;
    private static final int SNIPPET_CHARS = 200;

    private final UserCardRepository userCardRepository;
    private final CardProductRepository cardProductRepository;
    private final RewardRulesService rewardRulesService;
    private final CardTermsChunkSearchService chunkSearchService;
    private final AiAgentChatClient aiAgent;
    private final int topK;

    public ChatService(UserCardRepository userCardRepository,
                       CardProductRepository cardProductRepository,
                       RewardRulesService rewardRulesService,
                       CardTermsChunkSearchService chunkSearchService,
                       AiAgentChatClient aiAgent,
                       @Value("${chat.top-k:6}") int topK) {
        this.userCardRepository = userCardRepository;
        this.cardProductRepository = cardProductRepository;
        this.rewardRulesService = rewardRulesService;
        this.chunkSearchService = chunkSearchService;
        this.aiAgent = aiAgent;
        this.topK = topK;
    }

    public ChatResponse answer(String userId, ChatRequest req) {
        String question = sanitize(req.getQuestion());
        if (question.isBlank()) {
            return ChatResponse.builder()
                .answer("Ask me which card to use for any specific purchase.")
                .sources(List.of()).build();
        }

        List<UserCard> cards = userCardRepository.findByUser_IdAndIsActiveTrueOrderByAddedAtDesc(userId);
        if (cards.isEmpty()) {
            return ChatResponse.builder()
                .answer("You have no cards yet. Add a card in the Cards tab and I can recommend the best one.")
                .sources(List.of()).build();
        }

        List<Long> cardProductIds = cards.stream()
            .map(c -> c.getCardProduct().getId()).distinct().toList();
        Map<Long, CardProduct> productById = new HashMap<>();
        cardProductRepository.findAllById(cardProductIds).forEach(p -> productById.put(p.getId(), p));

        // 1. Embed query via ai-agent (all LLM calls live there)
        float[] qvec;
        try {
            qvec = aiAgent.embed(question);
        } catch (Exception e) {
            log.warn("chat_event=embed_failed uid={} error={}", userId, e.getMessage());
            return ChatResponse.builder()
                .answer("I couldn't process that question right now. Try again in a moment.")
                .sources(List.of()).build();
        }

        // 2. Retrieve chunks
        List<CardTermsChunkSearchService.ChunkHit> hits =
            chunkSearchService.topK(qvec, cardProductIds, topK);

        // 3. Build prompt context
        StringBuilder context = new StringBuilder();
        context.append("USER CARDS:\n");
        LocalDate today = LocalDate.now();
        List<CardRewardRule> rules = rewardRulesService.findActiveForCardProducts(cardProductIds, today);
        Map<Long, List<CardRewardRule>> rulesByCard = new HashMap<>();
        for (CardRewardRule r : rules) {
            rulesByCard.computeIfAbsent(r.getCardProduct().getId(), k -> new ArrayList<>()).add(r);
        }
        for (UserCard card : cards) {
            CardProduct cp = productById.get(card.getCardProduct().getId());
            String label = cp != null ? cp.getProductName() : "card #" + card.getCardProduct().getId();
            String bank = cp != null && cp.getBankKey() != null ? cp.getBankKey() : "";
            context.append("- ").append(bank).append(" ").append(label).append(":\n");
            for (CardRewardRule r : rulesByCard.getOrDefault(card.getCardProduct().getId(), List.of())) {
                context.append("    ").append(r.getCanonicalCategory())
                    .append(" = ").append(fmtRate(r.getRateBps())).append("%");
                if (r.getCapAmount() != null) {
                    context.append(" (cap $").append(r.getCapAmount()).append(" ")
                        .append(r.getCapPeriod()).append(")");
                }
                if (r.getChannelRestriction() != null) {
                    context.append(" [").append(r.getChannelRestriction()).append("]");
                }
                if (r.getNotes() != null && !r.getNotes().isBlank()) {
                    context.append(" — ").append(r.getNotes());
                }
                context.append("\n");
            }
        }

        context.append("\nRELEVANT T&C EXCERPTS:\n");
        int sIdx = 1;
        List<ChatResponse.ChatSource> sources = new ArrayList<>();
        for (CardTermsChunkSearchService.ChunkHit h : hits) {
            CardProduct cp = productById.get(h.getCardProductId());
            String label = cp != null ? (cp.getBankKey() + " " + cp.getProductName())
                                       : ("card #" + h.getCardProductId());
            context.append("[S").append(sIdx).append("] ").append(label).append(":\n")
                   .append(truncate(h.getChunkText(), 600)).append("\n\n");
            sources.add(ChatResponse.ChatSource.builder()
                .chunkId(h.getChunkId())
                .documentId(h.getDocumentId())
                .cardProductId(h.getCardProductId())
                .cardLabel(label)
                .snippet(truncate(h.getChunkText(), SNIPPET_CHARS))
                .similarity(h.getSimilarity())
                .build());
            sIdx++;
        }
        if (hits.isEmpty()) {
            context.append("(No T&C excerpts indexed yet — answer from the rules table only.)\n");
        }

        String history = renderHistory(req.getHistory());

        String prompt = """
            You are CredTrack's reward advisor. Use ONLY the cards, rules, and T&C excerpts
            below. If the answer isn't in the context, say "I don't have that detail for your
            cards yet" instead of guessing.

            Recommend the single best card for the user's purchase. Cite source labels like
            [S1] when you reference T&C content. Keep the answer under 6 sentences.

            =====
            %s
            =====

            %sUSER QUESTION:
            %s
            """.formatted(context.toString(), history, question);

        String answerText;
        try {
            answerText = aiAgent.chat(prompt).trim();
        } catch (Exception e) {
            log.warn("chat_event=llm_failed uid={} error={}", userId, e.getMessage());
            return ChatResponse.builder()
                .answer("I couldn't reach the advisor model. Try again shortly.")
                .sources(sources).build();
        }

        log.info("chat_event=answered uid={} q_chars={} hits={} cards={}",
            userId, question.length(), hits.size(), cards.size());

        return ChatResponse.builder()
            .answer(answerText)
            .sources(sources)
            .build();
    }

    private static String sanitize(String q) {
        if (q == null) return "";
        String trimmed = q.trim();
        if (trimmed.length() > MAX_QUESTION_CHARS) {
            trimmed = trimmed.substring(0, MAX_QUESTION_CHARS);
        }
        return trimmed;
    }

    private static String renderHistory(List<ChatRequest.ChatTurn> turns) {
        if (turns == null || turns.isEmpty()) return "";
        int start = Math.max(0, turns.size() - MAX_HISTORY_TURNS);
        StringBuilder b = new StringBuilder("PRIOR TURNS:\n");
        for (int i = start; i < turns.size(); i++) {
            ChatRequest.ChatTurn t = turns.get(i);
            if (t == null || t.getContent() == null || t.getContent().isBlank()) continue;
            String role = "assistant".equalsIgnoreCase(t.getRole()) ? "Assistant" : "User";
            b.append(role).append(": ").append(truncate(t.getContent(), 240)).append("\n");
        }
        b.append("\n");
        return b.toString();
    }

    private static String fmtRate(int bps) {
        double pct = bps / 100.0;
        return pct == Math.floor(pct) ? String.valueOf((int) pct) : String.format("%.2g", pct);
    }

    private static String truncate(String s, int max) {
        if (s == null) return "";
        return s.length() <= max ? s : s.substring(0, max) + "…";
    }
}
