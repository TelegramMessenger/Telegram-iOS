import FirebaseAuth

public class CustomTokenFirebaseAuthenticator {
    
    //  MARK: - Lifecycle
    
    public init() {}
    
    //  MARK: - Public Functions

    public func signIn(customToken: String, completion: ((Result<User, AuthProviderError>) -> ())?) {
        Auth.auth().signIn(withCustomToken: customToken) { result, error in
            if let error = error {
                completion?(.failure(.underlying(error)))
                return
            }
            
            guard let result = result else {
                completion?(.failure(.unexpected))
                return
            }
            
            completion?(.success(result.user))
        }
    }
}

//  MARK: - FirebaseAuthProvider Adapter

public class CustomTokenFirebaseAuthenticatorAdapter {
    
    //  MARK: - Dependencies
    
    private let authenticator: CustomTokenFirebaseAuthenticator
    
    //  MARK: - Logic
    
    private let customToken: String
    
    //  MARK: - Lifecycle
    
    public init(authenticator: CustomTokenFirebaseAuthenticator, customToken: String) {
        self.authenticator = authenticator
        self.customToken = customToken
    }
}

extension CustomTokenFirebaseAuthenticatorAdapter: FirebaseAuthProvider {
    public func signIn(completion: ((Result<FirebaseAuthProviderResponse, AuthProviderError>) -> ())?) {
        authenticator.signIn(customToken: customToken) { result in
            switch result {
            case .success(let user):
                let profileMetadata = AuthProfileMetadata(firstName: user.displayName, secondName: nil, email: user.email)
                let response = FirebaseAuthProviderResponse(firebaseUser: user, profileInfo: profileMetadata)
                completion?(.success(response))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
}
