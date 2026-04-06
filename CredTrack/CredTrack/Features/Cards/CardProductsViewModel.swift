import Foundation
import Combine

@MainActor
final class CardProductsViewModel: ObservableObject {

    enum State {
        case idle
        case loading
        case loaded([CardModel])
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    func load() async {
        guard case .idle = state else { return }   // don't reload if already in flight
        state = .loading
        do {
            let dtos   = try await APIClient.shared.fetchCardProducts()
            let models = dtos.map { $0.toCardModel() }
            state = .loaded(models)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func reload() {
        state = .idle
        Task { await load() }
    }
}
