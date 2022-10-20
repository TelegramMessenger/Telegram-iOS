import Foundation
import EsimAuth
import EsimApiClient

public final class AuthService {
    private var esimAuth: EsimAuth
    
    public static let shared = AuthService()
        
    public init() {
        let esimAuthClient = EsimApiClient(baseUrl: "some" as! URL, apiKey: "some", mobileIdentifier: "some")
        self.esimAuth = EsimAuth(bundleId: "some", apiClient: esimAuthClient)
    }
        
    public var currentUser: EsimUser? {
        return esimAuth.currentUser
    }
    
    public var isAuthorized: Bool {
        return (currentUser != nil)
    }
        
    public func createUser(firstName: String, lastName: String, email: String, password: String, onSentVerificationEmail: (() -> ())?, completion: ((Result<EsimUser, EsimAuthError>) -> ())?) {
        let info = CreateUserDTO(firstName: firstName, lastName: lastName, email: email, password: password, referrerId: nil)
        esimAuth.createUser(info, onSentVerificationEmail: onSentVerificationEmail) { result in
            switch result {
            case .success(let user):
                completion?(.success(user))
//                SharedStoreController.shared.update {
//                    completion?(.success(user))
//                }
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    public func signIn(with provider: AuthProviderProtocol, completion: ((Result<EsimUser, EsimAuthError>) -> ())?) {
        esimAuth.signIn(with: provider, referrerId: nil) { result in
            switch result {
            case .success(let user):
                completion?(.success(user))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
    
    func signOut(completion: ((Result<(), Error>) -> ())?) {
        self.esimAuth.signOut(completion: completion)
    }
    
    func resetPassword(email: String, completion: @escaping (Error?) -> ()) {
        esimAuth.resetPassword(email: email, completion: completion)
    }
}

