import SwiftUI

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
                    appState.signOut()
                }
                .font(.ctButtonLabel)
                .foregroundColor(.ctGold)
            }
        }
    }
}
