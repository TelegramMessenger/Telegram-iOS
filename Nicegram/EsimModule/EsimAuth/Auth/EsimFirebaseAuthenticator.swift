import FirebaseAuth
import EsimApiClientDefinition

public class EsimFirebaseAuthenticator {
    
    //  MARK: - Dependencies
    
    private let apiClient: EsimApiClientProtocol
    private let emailAuthenticator: EmailAuthenticator
    
    //  MARK: - Lifecycle
    
    public init(apiClient: EsimApiClientProtocol, bundleId: String) {
        self.apiClient = apiClient
        self.emailAuthenticator = EmailAuthenticator(bundleId: bundleId)
    }
    
    //  MARK: - Public Functions
    
    public func createUser(_ info: CreateUserDTO, onSentVerificationEmail: (() -> ())?, completion: ((Result<EsimUser, EsimAuthError>) -> ())?) {
        try? Auth.auth().signOut()
        emailAuthenticator.createUser(info, onSentVerificationEmail: onSentVerificationEmail) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let user):
                let profileInfo = AuthProfileMetadata(firstName: info.firstName, secondName: info.lastName, email: info.email)
                self.signIn(withFirebaseUser: user, profileInfo: profileInfo, referrerId: info.referrerId, completion: completion)
            case .failure(let error):
                completion?(.failure(.underlying(error)))
            }
        }
        
    }

    public func signIn(with provider: FirebaseAuthProvider, referrerId: Int?, completion: ((Result<EsimUser, EsimAuthError>) -> ())?) {
        provider.signIn { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let authProviderResponse):
                self.signIn(withFirebaseUser: authProviderResponse.firebaseUser, profileInfo: authProviderResponse.profileInfo, referrerId: referrerId, completion: completion)
            case .failure(let authProviderError):
                completion?(.failure(.authProviderError(authProviderError)))
            }
        }
    }
    
    public func sendPasswordReset(withEmail email: String, completion: @escaping (Error?) -> ()) {
        emailAuthenticator.sendPasswordReset(withEmail: email, completion: completion)
    }
    
    //  MARK: - Private Functions
    
    private func signIn(withFirebaseUser user: User, profileInfo: AuthProfileMetadata, referrerId: Int?, completion: ((Result<EsimUser, EsimAuthError>) -> ())?) {
        user.getIDTokenForcingRefresh(true) { token, error in
            if let error = error {
                completion?(.failure(.underlying(error)))
                return
            }
            
            guard let token = token else {
                completion?(.failure(.unexpected))
                return
            }
            
            self.signInWithFirebase(uid: user.uid, token: token, firstName: profileInfo.firstName, lastName: profileInfo.secondName, email: profileInfo.email, referrerId: referrerId) { result in
                switch result {
                case .success(let user):
                    user.token = token
                    
                    completion?(.success(user))
                case .failure(let apiError):
                    completion?(.failure(.apiClientError(apiError)))
                }
            }
        }
    }

    private func signInWithFirebase(uid: String, token: String, firstName: String?, lastName: String?, email: String?, referrerId: Int?, completion: ((Result<EsimUser, EsimApiError>) -> ())?) {
        let request = ApiRequest<SignInOutputDTO>.post(
            path: "auth/firebase",
            body: SignInInputDTO(uid: uid, token: token, email: email, firstName: firstName, lastName: lastName, referrerId: referrerId))
        apiClient.send(request) { result in
            switch result {
            case .success(let dto): completion?(.success(dto.user))
            case .failure(let apiError): completion?(.failure(apiError))
            }
        }
    }
}

//  MARK: - DTO

private struct SignInInputDTO: Codable {
    let uid: String
    let token: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let referrerId: Int?
}

private struct SignInOutputDTO: Decodable {
    let user: EsimUser
}
