import Foundation
import Combine

@MainActor
final class UserCardsViewModel: ObservableObject {

    enum State {
        case idle
        case loading
        case loaded([UserCardDTO])
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            let dtos = try await APIClient.shared.fetchUserCards()
            state = .loaded(dtos)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func reload() {
        state = .idle
        Task { await load() }
    }

    /// Optimistically removes the card from the list immediately so the
    /// delete animation plays instantly, then calls the API in background.
    /// If the API fails, reloads the full list to restore correct state.
    func removeCard(_ card: UserCardDTO) {
        guard case .loaded(let cards) = state else { return }
        state = .loaded(cards.filter { $0.id != card.id })
        Task {
            do {
                try await APIClient.shared.deleteUserCard(id: card.id)
            } catch {
                reload()
            }
        }
    }
}
