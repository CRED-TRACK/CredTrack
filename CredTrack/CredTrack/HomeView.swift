import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        ZStack {
            Color.ctBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Welcome to CredTrack")
                    .font(.ctHeadline)
                    .foregroundColor(.ctTextPrimary)

                Button("Sign Out") {
                    try? Auth.auth().signOut()
                    appState.currentScreen = .login
                }
                .font(.ctButtonLabel)
                .foregroundColor(.ctGold)
            }
        }
    }
}

#Preview {
    HomeView()
}
