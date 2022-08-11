import EsimApiClientDefinition

public enum TelegramSignInBySessionError: Error {
    case sessionMissed
    case sessionExpired
    case underlying(Error)
}

public protocol TelegramSignInBySessionProvider {
    func signIn(session: TelegramAuthSession, completion: ((Result<EsimUser, TelegramSignInBySessionError>) -> ())?)
}

public class TelegramSignInBySessionProviderImpl {
    
    //  MARK: - Dependencies
    
    private let apiClient: EsimApiClientProtocol
    
    //  MARK: - Lifecycle
    
    public init(apiClient: EsimApiClientProtocol) {
        self.apiClient = apiClient
    }
    
}

extension TelegramSignInBySessionProviderImpl: TelegramSignInBySessionProvider {
    public func signIn(session: TelegramAuthSession, completion: ((Result<EsimUser, TelegramSignInBySessionError>) -> ())?) {
        let request = ApiRequest<TelegramSignInBySessionResponse>.post(
            path: "telegram/auth",
            body: TelegramSignInBySessionBody(sessionId: session.id)
        )
        
        apiClient.send(request) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let success):
                completion?(.success(success.user))
            case .failure(let error):
                completion?(.failure(self.mapApiError(error)))
            }
        }
    }
}

private extension TelegramSignInBySessionProviderImpl{
    func mapApiError(_ apiError: EsimApiError) -> TelegramSignInBySessionError {
        switch apiError {
        case .notAuthorized(_), .underlying(_), .unexpected:
            return .underlying(apiError)
        case .someServerError(let serverError):
            return mapSomeServerError(serverError)
        }
    }
    
    func mapSomeServerError(_ serverError: SomeEsimServerError) -> TelegramSignInBySessionError {
        switch serverError.code {
        case 406:
            return .sessionExpired
        default:
            return .underlying(serverError)
        }
    }
}

private typealias TelegramSignInBySessionBody = TelegramAuthSessionDTO

private struct TelegramSignInBySessionResponse: Decodable {
    let user: EsimUser
}
