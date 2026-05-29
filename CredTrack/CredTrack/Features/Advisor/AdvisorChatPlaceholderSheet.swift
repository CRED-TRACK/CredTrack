import SwiftUI

/// Phase-2 stub. Real chat advisor lands later — this sheet just acknowledges the click.
struct AdvisorChatPlaceholderSheet: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundColor(.NeoPop.NeoPaccha.c500)
                .padding(.top, 30)

            Text("Smart advisor chat is coming soon")
                .font(.ctHeadline)
                .foregroundColor(.ctTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Text("Ask things like “Should I use this card for a Doordash gift card?” and we’ll cross-check your card’s T&C in real time.")
                .font(.ctBody)
                .foregroundColor(.ctTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()

            SynthButton(title: "Close") { onClose() }
                .frame(height: 56)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
        }
        .background(Color.ctBackground.ignoresSafeArea())
    }
}
