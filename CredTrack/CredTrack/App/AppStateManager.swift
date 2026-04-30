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
    @Published private(set) var isResolvingInitialScreen = false
    @Published private(set) var didResolveInitialScreen = false

    private var authListener: AuthStateDidChangeListenerHandle?
    private var resolvedInitialScreen: AppScreen?

    func resolveInitialScreen() {
        guard !isResolvingInitialScreen, !didResolveInitialScreen else { return }
        isResolvingInitialScreen = true
        authError = nil

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let handle = self.authListener {
                Auth.auth().removeStateDidChangeListener(handle)
                self.authListener = nil
            }
            guard let user else {
                print("[CredTrack][Auth] initial_state no_firebase_user")
                self.finishInitialResolution(screen: .login)
                return
            }

            print("[CredTrack][Auth] initial_state firebase_user uid=\(user.uid) base_url=\(APIConfig.baseURL)")
            self.isLoading = true
            user.getIDToken { token, error in
                Task { @MainActor in
                    guard let token, error == nil else {
                        print("[CredTrack][Auth] initial_state token_fetch_failed error=\(error?.localizedDescription ?? "unknown")")
                        self.isLoading = false
                        self.authError = "Could not restore your session. Please sign in again."
                        self.finishInitialResolution(screen: .login)
                        return
                    }

                    do {
                        // Re-sync the backend user record on cold start so fresh
                        // databases or redeploys do not break authenticated flows.
                        print("[CredTrack][Auth] initial_state backend_login_start uid=\(user.uid)")
                        _ = try await APIClient.shared.login(token: token)
                        print("[CredTrack][Auth] initial_state backend_login_success uid=\(user.uid)")
                        self.finishInitialResolution(screen: .home)
                    } catch {
                        print("[CredTrack][Auth] initial_state backend_login_failed error=\(error.localizedDescription)")
                        self.authError = error.localizedDescription
                        self.finishInitialResolution(screen: .login)
                    }

                    self.isLoading = false
                }
            }
        }
    }

    func handleSignInSuccess(token: String) {
        Task {
            do {
                print("[CredTrack][Auth] sign_in_success backend_login_start base_url=\(APIConfig.baseURL)")
                _ = try await APIClient.shared.login(token: token)
                print("[CredTrack][Auth] sign_in_success backend_login_success")
                isLoading = false
                currentScreen = .home
            } catch {
                print("[CredTrack][Auth] sign_in_success backend_login_failed error=\(error.localizedDescription)")
                isLoading = false
                authError = error.localizedDescription
            }
        }
    }

    func handleSignInFailure() {
        print("[CredTrack][Auth] sign_in_failure")
        isLoading = false
        authError = "Sign-in failed. Please try again."
    }

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        currentScreen = .login
    }

    func completeSplashTransition() {
        guard currentScreen == .splash else { return }
        currentScreen = resolvedInitialScreen ?? .login
    }

    private func finishInitialResolution(screen: AppScreen) {
        resolvedInitialScreen = screen
        isResolvingInitialScreen = false
        didResolveInitialScreen = true
    }
}
