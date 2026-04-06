import GoogleSignIn
import FirebaseAuth
import FirebaseCore

class AuthManager {

    static let shared = AuthManager()

    func signInWithGoogle(presentingViewController: UIViewController, completion: @escaping (String?) -> Void) {

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(nil)
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in

            guard error == nil, let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                completion(nil)
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { authResult, error in
                guard error == nil else { completion(nil); return }
                authResult?.user.getIDToken { token, _ in completion(token) }
            }
        }
    }
}
