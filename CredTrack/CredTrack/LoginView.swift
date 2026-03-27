import SwiftUI

struct LoginView: View {

    @EnvironmentObject var appState: AppStateManager
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    var body: some View {
        ZStack {
            WaveBackgroundView().ignoresSafeArea()
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("CREDTRACK")
                        .font(.ctWordmark)
                        .foregroundColor(.ctTextPrimary)
                        .kerning(4)

                    Rectangle()
                        .fill(AngularGradient.ctWaveChromatic)
                        .frame(width: 210, height: 1.5)
                }

                Spacer().frame(height: 16)

                Text("Own your credit story")
                    .font(.ctTagline)
                    .foregroundColor(.ctTextSecondary)

                Spacer()

                if let error = appState.authError {
                    Text(error)
                        .font(.ctCaption)
                        .foregroundColor(.red.opacity(0.9))
                        .padding(.bottom, 12)
                }

                Button(action: handleGoogleSignIn) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AngularGradient.ctWaveChromatic, lineWidth: 1.5)
                            )

                        if appState.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            HStack(spacing: 12) {
                                Image("google_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 22, height: 22)

                                Text("Continue with Google")
                                    .font(.ctButtonLabel)
                                    .foregroundColor(.ctTextPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .disabled(appState.isLoading)
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                Text("By continuing you agree to our Terms of Service")
                    .font(.ctCaption)
                    .foregroundColor(.ctTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer().frame(height: 48)
            }
            .opacity(contentOpacity)
            .offset(y: contentOffset)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
                contentOffset = 0
            }
        }
    }

    private func handleGoogleSignIn() {
        guard let vc = UIApplication.shared.topViewController else { return }
        appState.isLoading = true
        appState.authError = nil

        AuthManager.shared.signInWithGoogle(presentingViewController: vc) { token in
            DispatchQueue.main.async {
                if let token {
                    appState.handleSignInSuccess(token: token)
                } else {
                    appState.handleSignInFailure()
                }
            }
        }
    }
}

private extension UIApplication {
    var topViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

#Preview {
    LoginView().environmentObject(AppStateManager())
}
