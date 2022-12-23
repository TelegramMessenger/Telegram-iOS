import NGCore
import NGEnv
import NGTelegramRepo
import NGUtils
import class EsimAuth.TelegramAuthenticator
import struct EsimAuth.TelegramID
import Foundation

public protocol InitiateLoginWithTelegramUseCase {
    func initiateLoginWithTelegram(completion: @escaping (Result<URL, Error>) -> Void)
}

public class InitiateLoginWithTelegramUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let getTelegramIdUseCase: GetTelegramIdUseCase
    private let telegramAuthenticator: TelegramAuthenticator
    
    //  MARK: - Lifecycle
    
    public init(getTelegramIdUseCase: GetTelegramIdUseCase, telegramAuthenticator: TelegramAuthenticator) {
        self.getTelegramIdUseCase = getTelegramIdUseCase
        self.telegramAuthenticator = telegramAuthenticator
    }
}

extension InitiateLoginWithTelegramUseCaseImpl: InitiateLoginWithTelegramUseCase {
    public func initiateLoginWithTelegram(completion: @escaping (Result<URL, Error>) -> Void) {
        let botDomain = NGENV.telegram_auth_bot
        let telegramId: EsimAuth.TelegramID?
        if let int64id = getTelegramIdUseCase.getTelegramId()?.int64Value {
            telegramId = .init(id: int64id)
        } else {
            telegramId = nil
        }
        telegramAuthenticator.fetchSession(telegramId: telegramId) { sessionResult in
            switch sessionResult {
            case .success(let success):
                if let url = makeBotUrl(domain: botDomain, startParam: success.id) {
                    completion(.success(url))
                } else {
                    completion(.failure(UnexpectedError()))
                }
            case .failure(let failure):
                completion(.failure(failure))
            }
        }
    }
}
