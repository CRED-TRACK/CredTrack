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
}
