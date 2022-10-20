import FirebaseAuth

public class GoogleFirebaseAuthenticator: RequiringPresentation {
    
    //  MARK: - Public Properties

    public var presentationDelegate: RequiringPresentationDelegate? {
        get { googleAuthenticator.presentationDelegate }
        set { googleAuthenticator.presentationDelegate = newValue }
    }
    
    //  MARK: - Dependencies
    
    private let googleAuthenticator: GoogleAuthenticator
    
    //  MARK: - Lifecycle
    
    public init(clientId: String) {
        self.googleAuthenticator = GoogleAuthenticator(clientId: clientId)
    }
}

extension GoogleFirebaseAuthenticator: FirebaseAuthProvider {
    public func signIn(completion: ((Result<FirebaseAuthProviderResponse, AuthProviderError>) -> ())?) {
        googleAuthenticator.signIn { result in
            switch result {
            case .success(let response):
                guard let idToken = response.gidUser.authentication.idToken else {
                    completion?(.failure(.unexpected))
                    return
                }
                
                let accessToken = response.gidUser.authentication.accessToken
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                
                Auth.auth().signIn(with: credential) { authResult, error in
                    if let error = error {
                        completion?(.failure(.underlying(error)))
                        return
                    }
                    
                    guard let user = authResult?.user else {
                        completion?(.failure(.unexpected))
                        return
                    }
                    
                    let profile = response.gidUser.profile
                    let profileInfo = AuthProfileMetadata(firstName: profile?.givenName, secondName: profile?.familyName, email: profile?.email)
                    
                    completion?(.success(.init(firebaseUser: user, profileInfo: profileInfo)))
                }
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
}
