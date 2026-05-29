import Foundation
import Combine

@MainActor
final class AdvisorViewModel: ObservableObject {

    enum State {
        case idle
        case loading
        case loaded(AdvisorDashboardDTO)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var selectedCategory: String? = nil
    @Published var categories: [AdvisorCategoryDTO] = []
    @Published var bofaSheetVisible: Bool = false
    @Published var chatSheetVisible: Bool = false
    @Published var categoryPickerVisible: Bool = false

    /// Card section that owns the BofA Customized Cash product (if any).
    var bofaSection: AdvisorCardSectionDTO? {
        guard case .loaded(let dash) = state else { return nil }
        return dash.cards.first { isBofaCustomized($0) }
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            async let dashTask = APIClient.shared.fetchAdvisorDashboard()
            async let catsTask = APIClient.shared.fetchAdvisorCategories()
            let dash = try await dashTask
            let cats = try await catsTask
            categories = cats
            state = .loaded(dash)
            // Auto-show BofA modal on first load if owned + no choice yet.
            if let bofa = dash.cards.first(where: { isBofaCustomized($0) }) {
                let needsChoice = bofa.warnings.contains { $0.code == "BOA_3PCT_CHOICE_MISSING" }
                if needsChoice { bofaSheetVisible = true }
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func reload() {
        Task { await load() }
    }

    func saveBofaChoice(_ canonical: String) async throws {
        guard let bofa = bofaSection else { throw APIError.invalidURL }
        _ = try await APIClient.shared.setAdvisorCategoryChoice(
            userCardId: bofa.userCardId,
            choiceKind: "BOA_CUSTOMIZED_3PCT",
            canonicalCategory: canonical
        )
        await load()
    }

    func currentBofaChoice() -> String? {
        bofaSection?.rewards.first { $0.userChoiceActive != nil }?.userChoiceActive
    }

    private func isBofaCustomized(_ card: AdvisorCardSectionDTO) -> Bool {
        guard let key = card.bankKey?.uppercased(), key == "BOA" else { return false }
        return card.productName.lowercased().contains("customized")
    }

    // MARK: - Category-first ranking model

    struct RankedEntry: Identifiable, Hashable {
        let cardId: Int
        let cardName: String        // nickname or productName
        let bankKey: String?
        let lastFour: String?
        let effectiveRateBps: Int
        let rateLabel: String
        let capRemaining: Double?
        let capExhausted: Bool
        let blocked: Bool           // true when requires-choice not met
        let notes: String?

        var id: Int { cardId }
    }

    struct CategoryGroup: Identifiable, Hashable {
        let category: String        // canonical code
        let displayName: String
        let iconHint: String
        let entries: [RankedEntry]  // sorted by effectiveRateBps desc
        var id: String { category }

        var best: RankedEntry?       { entries.first }
        var runnerUp: RankedEntry?   { entries.dropFirst().first }
    }

    /// Builds one row per canonical category — ranked across all owned cards.
    /// Honors selectedCategory as a filter (shows only that one).
    func categoryGroups() -> [CategoryGroup] {
        guard case .loaded(let dash) = state else { return [] }

        var byCategory: [String: [RankedEntry]] = [:]
        for card in dash.cards {
            for rule in card.rewards {
                let blocked = rule.requiresUserChoice
                    && (rule.userChoiceActive == nil
                        || rule.userChoiceActive != rule.canonicalCategory)
                let entry = RankedEntry(
                    cardId: card.userCardId,
                    cardName: card.nickname ?? card.productName,
                    bankKey: card.bankKey,
                    lastFour: card.lastFour,
                    effectiveRateBps: rule.effectiveRateBps,
                    rateLabel: rule.rateLabel,
                    capRemaining: rule.capRemaining,
                    capExhausted: rule.capExhausted,
                    blocked: blocked,
                    notes: rule.notes
                )
                byCategory[rule.canonicalCategory, default: []].append(entry)
            }
        }

        let allCats: [String] = selectedCategory.map { [$0] } ?? Array(byCategory.keys)
        let groups: [CategoryGroup] = allCats.compactMap { code in
            guard let raw = byCategory[code], !raw.isEmpty else { return nil }
            let ranked = raw.sorted { lhs, rhs in
                if lhs.effectiveRateBps != rhs.effectiveRateBps {
                    return lhs.effectiveRateBps > rhs.effectiveRateBps
                }
                let lr = lhs.capRemaining ?? Double.greatestFiniteMagnitude
                let rr = rhs.capRemaining ?? Double.greatestFiniteMagnitude
                return lr > rr
            }
            let meta = categories.first { $0.code == code }
            return CategoryGroup(
                category: code,
                displayName: meta?.displayName ?? code,
                iconHint: meta?.iconHint ?? "creditcard.fill",
                entries: ranked
            )
        }

        return groups.sorted { lhs, rhs in
            let l = lhs.best?.effectiveRateBps ?? 0
            let r = rhs.best?.effectiveRateBps ?? 0
            if l != r { return l > r }
            return lhs.displayName < rhs.displayName
        }
    }

    // MARK: - Filtered rendering helpers

    func filteredSections() -> [AdvisorCardSectionDTO] {
        guard case .loaded(let dash) = state else { return [] }
        guard let cat = selectedCategory else { return dash.cards }
        return dash.cards.map { card in
            // Keep only rewards matching the selected category; drop the section if none.
            AdvisorCardSectionDTO(
                userCardId: card.userCardId,
                productName: card.productName,
                issuerName: card.issuerName,
                bankKey: card.bankKey,
                faceColor: card.faceColor,
                gradientEnd: card.gradientEnd,
                textColor: card.textColor,
                lastFour: card.lastFour,
                nickname: card.nickname,
                rewards: card.rewards.filter { $0.canonicalCategory == cat },
                warnings: card.warnings
            )
        }.filter { !$0.rewards.isEmpty }
    }

    func bestCardId(for category: String) -> Int? {
        if case .loaded(let dash) = state {
            return dash.categoryRankings.first(where: { $0.category == category })?.bestUserCardId
        }
        return nil
    }
}
