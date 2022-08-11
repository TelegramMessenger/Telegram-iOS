import Foundation
import EsimApiClientDefinition

public struct TelegramAuthSession {
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
}

public typealias TelegramAuthSessionError = Error

public protocol TelegramAuthSessionProvider {
    func fetchSession(telegramId: TelegramID, completion: ((Result<TelegramAuthSession, TelegramAuthSessionError>) -> ())?)
}

public class TelegramAuthSessionProviderImpl {
    
    //  MARK: - Dependencies
    
    private let apiClient: EsimApiClientProtocol
    
    //  MARK: - Lifecycle
    
    public init(apiClient: EsimApiClientProtocol) {
        self.apiClient = apiClient
    }
    
}

extension TelegramAuthSessionProviderImpl: TelegramAuthSessionProvider {
    public func fetchSession(telegramId: TelegramID, completion:  ((Result<TelegramAuthSession, TelegramAuthSessionError>) -> ())?) {
        let request = ApiRequest<TelegramAuthSessionResponse>.post(
            path: "telegram/session",
            body: TelegramAuthSessionBody(telegramId: telegramId.id)
        )
       
        apiClient.send(request) { result in
            switch result {
            case .success(let success):
                let session = TelegramAuthSession(id: success.sessionId)
                completion?(.success(session))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }
}

private struct TelegramAuthSessionBody: Encodable {
    let telegramId: Int64
}

private typealias TelegramAuthSessionResponse = TelegramAuthSessionDTO
