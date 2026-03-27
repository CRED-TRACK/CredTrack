import Foundation
import Combine
import FirebaseAuth

enum AppScreen {
    case splash, login, home
}

@MainActor
final class AppStateManager: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    @Published var isLoading = false
    @Published var authError: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    func resolveInitialScreen() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let handle = self.authListener {
                Auth.auth().removeStateDidChangeListener(handle)
                self.authListener = nil
            }
            self.currentScreen = user != nil ? .home : .login
        }
    }

    func handleSignInSuccess(token: String) {
        isLoading = false
        currentScreen = .home
    }

    func handleSignInFailure() {
        isLoading = false
        authError = "Sign-in failed. Please try again."
    }
}
