import Foundation
import FirebaseAuth
import EsimApiClientDefinition

private let kCurrentUser = "auth_service_current_user_data"

public final class EsimAuth {
    
    //  MARK: - Dependencies
    
    private let firebaseAuthenticator: EsimFirebaseAuthenticator
    private let telegramAuthenticator: TelegramAuthenticator
    
    //  MARK: - Public Properties
    
    public var currentUser: EsimUser? {
        return _currentUser
    }
    
    public var isAuthorized: Bool {
        return (currentUser != nil)
    }
    
    //  MARK: - Private Properties
    
    private lazy var _currentUser: EsimUser? = {
        let storage = UserDefaults.standard
        if let data = storage.data(forKey: kCurrentUser) {
            return try? JSONDecoder().decode(EsimUser.self, from: data)
        } else {
            return nil
        }
    }()
    
    //  MARK: - Lifecycle
    
    public init(bundleId: String, apiClient: EsimApiClientProtocol) {
        self.firebaseAuthenticator = EsimFirebaseAuthenticator(apiClient: apiClient, bundleId: bundleId)
        self.telegramAuthenticator = TelegramAuthenticator(apiClient: apiClient)
    }
    
    //  MARK: - Public Functions
    
    public func createUser(_ info: CreateUserDTO, onSentVerificationEmail: (() -> ())?, completion: ((Result<EsimUser, EsimAuthError>) -> ())?) {
        firebaseAuthenticator.createUser(info, onSentVerificationEmail: onSentVerificationEmail, completion: completion)
    }
    
    public func signIn(with provider: FirebaseAuthProvider, referrerId: Int?, completion: ((Result<EsimUser, EsimAuthError>) -> ())?) {
        firebaseAuthenticator.signIn(with: provider, referrerId: referrerId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let user):
                self.setCurrentUser(user)
            case .failure(_):
                break
            }
            
            completion?(result)
        }
    }
    
    public func signOut(completion: ((Result<(), Error>) -> ())?) {
        do {
            try Auth.auth().signOut()
            setCurrentUser(nil)
            completion?(.success(()))
        } catch {
            completion?(.failure(error))
        }
    }
    
    public func resetPassword(email: String, completion: @escaping (Error?) -> ()) {
        firebaseAuthenticator.sendPasswordReset(withEmail: email, completion: completion)
    }
    
    //  MARK: - Private Functions
    
    private func setCurrentUser(_ user: EsimUser?) {
        if let user = user {
            UserDefaults.standard.setValue(try? JSONEncoder().encode(user), forKey: kCurrentUser)
        } else {
            currentUser?.token = nil
            UserDefaults.standard.setValue(nil, forKey: kCurrentUser)
        }
        
        _currentUser = user
    }
}

//  MARK: - Telegram SignIn

public extension EsimAuth {
    func trySignInWithTelegram(completion: ((Result<EsimUser, TelegramSignInError>) -> ())?) {
        if let currentUser = currentUser {
            telegramAuthenticator.clear()
            completion?(.success(currentUser))
            return
        }
        
        telegramAuthenticator.signIn { [weak self] result in
            // TODO: !Duplicated code
            guard let self = self else { return }
            
            switch result {
            case .success(let user):
                self.setCurrentUser(user)
            case .failure(_):
                break
            }
            
            completion?(result)
        }
    }
}
