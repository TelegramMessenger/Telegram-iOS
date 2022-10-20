import AuthenticationServices
import FirebaseAuth

@available(iOS 13, *)
public class AppleFirebaseAuthenticator: RequiringPresentation {
    
    //  MARK: - Public Properties

    public var presentationDelegate: RequiringPresentationDelegate? {
        get { appleAuthenticator.presentationDelegate }
        set { appleAuthenticator.presentationDelegate = newValue }
    }
    
    //  MARK: - Dependencies
    
    private let appleAuthenticator: AppleAuthenticator
    
    //  MARK: - Lifecycle
    
    public init(appleAuthenticator: AppleAuthenticator = .init()) {
        self.appleAuthenticator = appleAuthenticator
    }
}

@available(iOS 13, *)
extension AppleFirebaseAuthenticator: FirebaseAuthProvider {
    public func signIn(completion: ((Result<FirebaseAuthProviderResponse, AuthProviderError>) -> ())?) {
        appleAuthenticator.signIn { result in
            switch result {
            case .success(let response):
                let appleIDCredential = response.credential
                let nonce = response.nonce
                let metatdata = response.metadata
                
                guard let appleIDToken = appleIDCredential.identityToken else {
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    return
                }
                
                let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)
                
                Auth.auth().signIn(with: credential) { result, error in
                    if let error = error {
                        completion?(.failure(.underlying(error)))
                        return
                    }
                    
                    guard let user = result?.user else {
                        completion?(.failure(.unexpected))
                        return
                    }
                    
                    let profileMetadata = AuthProfileMetadata(firstName: metatdata.fullname, secondName: nil, email: metatdata.email)
                    
                    completion?(.success(.init(firebaseUser: user, profileInfo: profileMetadata)))
                }
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
}
