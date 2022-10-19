import Foundation
import EsimApiClientDefinition

public struct TelegramID {
    public let id: Int64
    
    public init(id: Int64) {
        self.id = id
    }
}

public typealias TelegramSignInError = TelegramSignInBySessionError

public class TelegramAuthenticator {
    
    //  MARK: - Dependencies
    
    private let sessionProvider: TelegramAuthSessionProvider
    private let sessionStorage: TelegramAuthSessionStorage
    private let signInBySessionProvider: TelegramSignInBySessionProvider
    
    //  MARK: - Lifecycle
    
    public init(sessionProvider: TelegramAuthSessionProvider, sessionStorage: TelegramAuthSessionStorage, signInBySessionProvider: TelegramSignInBySessionProvider) {
        self.sessionProvider = sessionProvider
        self.sessionStorage = sessionStorage
        self.signInBySessionProvider = signInBySessionProvider
    }
    
    //  MARK: - Public Functions

    public func fetchSession(telegramId: TelegramID?, completion: ((Result<TelegramAuthSession, TelegramAuthSessionError>) -> ())?) {
        sessionProvider.fetchSession(telegramId: telegramId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let session):
                self.saveSession(session)
            case .failure(_):
                break
            }
            
            completion?(result)
        }
    }
    
    public func signIn(completion: ((Result<EsimUser, TelegramSignInError>) -> ())?) {
        guard let session = getSession() else {
            completion?(.failure(.sessionMissed))
            return
        }
        
        signInBySessionProvider.signIn(session: session) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(_):
                self.saveSession(nil)
            case .failure(let error):
                switch error {
                case .sessionExpired:
                    self.saveSession(nil)
                case .sessionMissed, .sessionNotApproved, .underlying(_):
                    break
                }
            }

            completion?(result)
        }
    }
    
    public func clear() {
        saveSession(nil)
    }
    
    public func hasPendingSession() -> Bool {
        return (getSession() != nil)
    }
    
    //  MARK: - Private Functions

    private func saveSession(_ session: TelegramAuthSession?) {
        sessionStorage.saveSession(session)
    }
    
    private func getSession() -> TelegramAuthSession? {
        return sessionStorage.getSession()
    }
}

public extension TelegramAuthenticator {
    convenience init(apiClient: EsimApiClientProtocol) {
        let sessionProvider = TelegramAuthSessionProviderImpl(apiClient: apiClient)
        let sessionStorage = TelegramAuthSessionUserDefaultsStorage()
        let signInBySessionProvider = TelegramSignInBySessionProviderImpl(apiClient: apiClient)
        self.init(sessionProvider: sessionProvider, sessionStorage: sessionStorage, signInBySessionProvider: signInBySessionProvider)
    }
}
