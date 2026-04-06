import Foundation
import Combine
import FirebaseAuth

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Stats model

    struct Stats {
        let totalCards:  Int
        let activeCards: Int
        let totalLimit:  Double
    }

    // MARK: - Firebase-derived (synchronous, always ready)

    var userName: String {
        let name = Auth.auth().currentUser?.displayName ?? ""
        if !name.isEmpty { return name }
        return Auth.auth().currentUser?.email?
            .components(separatedBy: "@").first?.capitalized ?? "User"
    }

    var userEmail: String {
        Auth.auth().currentUser?.email ?? ""
    }

    var userInitials: String {
        let words = userName.split(separator: " ").prefix(2)
        let letters = words.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var memberSince: String {
        guard let date = Auth.auth().currentUser?.metadata.creationDate else { return "—" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        return fmt.string(from: date)
    }

    // MARK: - Remote state

    @Published var stats: Stats?        = nil
    @Published var isLoadingStats: Bool = true

    // MARK: - Load

    func load() async {
        do {
            let cards = try await APIClient.shared.fetchUserCards()
            stats = Stats(
                totalCards:  cards.count,
                activeCards: cards.filter(\.isActive).count,
                totalLimit:  cards.compactMap(\.creditLimit).reduce(0, +)
            )
        } catch {
            // stats remains nil — UI shows dashes gracefully
        }
        isLoadingStats = false
    }
}
