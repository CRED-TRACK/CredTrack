import GoogleSignIn
import FirebaseAuth
import FirebaseCore

class AuthManager {

    static let shared = AuthManager()

    func signInWithGoogle(presentingViewController: UIViewController, completion: @escaping (String?) -> Void) {

        print("Step 1: Start Google Sign-In")

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("No clientID")
            completion(nil)
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in

            print("Step 2: Google callback")

            if let error = error {
                print("Google Sign-In error:", error)
                completion(nil)
                return
            }

            guard let user = result?.user else {
                print("No user")
                completion(nil)
                return
            }

            print("Step 3: Got Google user")

            guard let idToken = user.idToken?.tokenString else {
                print("No Google ID token")
                completion(nil)
                return
            }

            print("Step 4: Got Google ID token")

            let accessToken = user.accessToken.tokenString

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            Auth.auth().signIn(with: credential) { authResult, error in

                print("Step 5: Firebase callback")

                if let error = error {
                    print("Firebase sign-in error:", error)
                    completion(nil)
                    return
                }

                print("Step 6: Firebase login success")

                authResult?.user.getIDToken { token, error in
                    print("Step 7: Getting Firebase token")

                    if let token = token {
                        print("FINAL TOKEN:", token)
                        completion(token)
                    } else {
                        print("Token error:", error ?? "unknown")
                        completion(nil)
                    }
                }
            }
        }
    }
}
