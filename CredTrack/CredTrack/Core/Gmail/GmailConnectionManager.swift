import Foundation
import Combine
import AuthenticationServices
import UIKit

@MainActor
final class GmailConnectionManager: ObservableObject {

    @Published var isConnected   = false
    @Published var gmailAddress: String? = nil
    @Published var isChecking    = false
    @Published var isConnecting  = false
    @Published var connectError: String? = nil

    private var authSession: ASWebAuthenticationSession?
    private let contextProvider = WebAuthContextProvider()

    // MARK: - Status check

    func checkStatus() async {
        isChecking = true
        defer { isChecking = false }
        do {
            let status   = try await APIClient.shared.fetchGmailStatus()
            isConnected  = status.connected
            gmailAddress = status.gmailAddress
        } catch {
            isConnected  = false
            gmailAddress = nil
        }
    }

    // MARK: - OAuth connect

    func startOAuth() {
        connectError = nil
        isConnecting = true

        Task {
            do {
                let urlString = try await APIClient.shared.fetchGmailAuthURL()
                guard let url = URL(string: urlString) else {
                    connectError = "Invalid authorization URL."
                    isConnecting = false
                    return
                }
                beginWebAuth(url: url)
            } catch {
                connectError = "Gmail connection is being set up. Please try again later."
                isConnecting = false
            }
        }
    }

    private func beginWebAuth(url: URL) {
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "credtrack"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                self?.isConnecting = false
                guard error == nil, let callback = callbackURL else { return }
                if callback.host == "gmail" {
                    await self?.checkStatus()
                }
            }
        }
        session.presentationContextProvider = contextProvider
        session.prefersEphemeralWebBrowserSession = false
        authSession = session
        session.start()
    }
}

// MARK: - Presentation context provider
// Kept as a separate NSObject subclass because @Published doesn't work
// correctly when mixed with NSObject in the same class.

final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // presentationAnchor is always called on the main thread by ASWebAuthenticationSession
        MainActor.assumeIsolated {
            // Prefer foreground-active scene; fall back to any connected scene.
            // Force-unwrap is safe: this method is only called while the app is
            // actively presenting an ASWebAuthenticationSession, so a scene always exists.
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let scene = (scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first)!
            return scene.windows.first(where: { $0.isKeyWindow })
                ?? scene.windows.first
                ?? UIWindow(windowScene: scene)
        }
    }
}
