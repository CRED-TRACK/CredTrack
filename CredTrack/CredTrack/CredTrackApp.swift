import SwiftUI
import FirebaseCore
import GoogleSignIn
import Synth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        NeuUtils.baseColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        return true
    }
}

@main
struct CredTrackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppStateManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch appState.currentScreen {
                case .splash:
                    SplashView()
                        .transition(.opacity)
                case .login:
                    LoginView()
                        .transition(.opacity)
                case .home:
                    MainTabView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: appState.currentScreen)
            .environmentObject(appState)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
