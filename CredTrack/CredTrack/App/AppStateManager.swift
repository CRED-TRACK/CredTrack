import Foundation
import Combine
import FirebaseAuth
import GoogleSignIn

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
            guard let user else {
                self.currentScreen = .login
                return
            }

            self.isLoading = true
            user.getIDToken { token, error in
                Task { @MainActor in
                    guard let token, error == nil else {
                        self.isLoading = false
                        self.authError = "Could not restore your session. Please sign in again."
                        self.currentScreen = .login
                        return
                    }

                    do {
                        // Re-sync the backend user record on cold start so fresh
                        // databases or redeploys do not break authenticated flows.
                        _ = try await APIClient.shared.login(token: token)
                        self.currentScreen = .home
                    } catch {
                        self.authError = error.localizedDescription
                        self.currentScreen = .login
                    }

                    self.isLoading = false
                }
            }
        }
    }

    func handleSignInSuccess(token: String) {
        Task {
            do {
                _ = try await APIClient.shared.login(token: token)
                isLoading = false
                currentScreen = .home
            } catch {
                isLoading = false
                authError = error.localizedDescription
            }
        }
    }

    func handleSignInFailure() {
        isLoading = false
        authError = "Sign-in failed. Please try again."
    }

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        currentScreen = .login
    }
}
