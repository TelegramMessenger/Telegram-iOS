import GoogleSignIn

public struct GoogleAuthResponse {
    public let gidUser: GIDGoogleUser
}

public final class GoogleAuthenticator: RequiringPresentation {
    
    //  MARK: - Public Properties

    public weak var presentationDelegate: RequiringPresentationDelegate?
    
    //  MARK: - Private Properties

    private let clientId: String
    
    //  MARK: - Lifecycle
    
    public init(clientId: String) {
        self.clientId = clientId
    }
    
    //  MARK: - Public Functions

    public func signIn(completion: ((Result<GoogleAuthResponse, AuthProviderError>) -> ())?) {
        guard let presentingViewController = presentationDelegate?.presentingViewController() else {
            fatalError("AuthProviderDelegate must provide presenting view controller for \(type(of: GoogleAuthenticator.self))")
        }
        
        let configuration = GIDConfiguration(clientID: clientId)
        
        GIDSignIn.sharedInstance.signIn(with: configuration, presenting: presentingViewController) { user, error in
            if let error = error {
                if (error as NSError).code == -5 {
                    completion?(.failure(.cancelled(error)))
                } else {
                    completion?(.failure(.underlying(error)))
                }
                return
            }
            
            guard let user = user else {
                completion?(.failure(.unexpected))
                return
            }
            
            completion?(.success(.init(gidUser: user)))
        }
    }
}


