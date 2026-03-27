import SwiftUI

struct SplashView: View {

    @EnvironmentObject var appState: AppStateManager

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.88
    @State private var exitScale: CGFloat = 1.0
    @State private var whiteOpacity: Double = 0.0

    var body: some View {
        ZStack {
            WaveBackgroundView().ignoresSafeArea()

            VStack(spacing: 10) {
                Text("CREDTRACK")
                    .font(.ctWordmark)
                    .foregroundColor(.ctTextPrimary)
                    .kerning(4)

                Rectangle()
                    .fill(Color.ctGold)
                    .frame(width: 210, height: 1.5)
            }
            .opacity(logoOpacity)
            .scaleEffect(logoScale)

            Color.white
                .ignoresSafeArea()
                .opacity(whiteOpacity)
        }
        .scaleEffect(exitScale)
        .onAppear(perform: runEntranceAnimation)
    }

    private func runEntranceAnimation() {
        withAnimation(.easeOut(duration: 0.7)) {
            logoOpacity = 1
            logoScale = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            runExitAnimation()
        }
    }

    private func runExitAnimation() {
        withAnimation(.easeIn(duration: 0.3)) {
            logoOpacity = 0
        }
        withAnimation(.easeIn(duration: 0.9).delay(0.2)) {
            exitScale = 8.0
            whiteOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            appState.resolveInitialScreen()
        }
    }
}

#Preview {
    SplashView().environmentObject(AppStateManager())
}
