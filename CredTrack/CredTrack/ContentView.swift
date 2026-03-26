import SwiftUI

struct ContentView: View {

    var body: some View {
        Button("Sign in with Google") {
            signIn()
        }
    }

    func signIn() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            return
        }

        AuthManager.shared.signInWithGoogle(presentingViewController: rootVC) { token in
            if let token = token {
                print("Send this token to backend:", token)
            }
        }
    }
}
