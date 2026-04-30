import SwiftUI

struct SplashView: View {

    @EnvironmentObject var appState: AppStateManager

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.88
    @State private var exitScale: CGFloat = 1.0
    @State private var whiteOpacity: Double = 0.0
    @State private var showLoadingSpinner = false
    @State private var minimumDisplayFinished = false
    @State private var didStart = false
    @State private var didStartExit = false

    var body: some View {
        ZStack {
            WaveBackgroundView().ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

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

                Spacer().frame(height: 120)

                if showLoadingSpinner {
                    VStack(spacing: 18) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.ctTextPrimary)
                            .scaleEffect(1.25)

                        Text("Loading your account...")
                            .font(.ctCaption)
                            .foregroundColor(.ctTextSecondary)
                    }
                    .transition(.opacity)
                }

                Spacer()
            }

            Color.white
                .ignoresSafeArea()
                .opacity(whiteOpacity)
        }
        .scaleEffect(exitScale)
        .onAppear(perform: startSplashFlow)
        .onChange(of: appState.didResolveInitialScreen) { _, didResolve in
            guard didResolve, minimumDisplayFinished else { return }
            runExitAnimationIfReady()
        }
    }

    private func startSplashFlow() {
        guard !didStart else { return }
        didStart = true
        appState.resolveInitialScreen()

        withAnimation(.easeOut(duration: 0.7)) {
            logoOpacity = 1
            logoScale = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            minimumDisplayFinished = true
            if appState.didResolveInitialScreen {
                runExitAnimationIfReady()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showLoadingSpinner = true
                }
            }
        }
    }

    private func runExitAnimationIfReady() {
        guard !didStartExit else { return }
        didStartExit = true

        withAnimation(.easeOut(duration: 0.2)) {
            showLoadingSpinner = false
        }
        withAnimation(.easeIn(duration: 0.3)) {
            logoOpacity = 0
        }
        withAnimation(.easeIn(duration: 0.9).delay(0.2)) {
            exitScale = 8.0
            whiteOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            appState.completeSplashTransition()
        }
    }
}

#Preview {
    SplashView().environmentObject(AppStateManager())
}
