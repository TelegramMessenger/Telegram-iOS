import AccountContext
import NGApiClient
import NGAuth
import NGCore
import NGEnv
import NGLogging
import NGLottery
import NGSubscription
import NGTelegramRepo
import EsimAuth
import Foundation


@available(iOS 13.0, *)
public class AppContext {
    
    //  MARK: - Public Properties

    public let accountContext: AccountContext
    public let esimAuth: EsimAuth
    public let premiumStatusRepository: PremiumStatusRepository
    public let lotteryDataRepository: LotteryDataRepository

    
    //  MARK: - Dependencies
    
   
    
    //  MARK: - Lifecycle
    
    public init(accountContext: AccountContext) {
        self.accountContext = accountContext
        self.esimAuth = EsimAuth(
            bundleId: NGENV.bundle_id,
            apiClient: createNicegramApiClient(auth: nil)
        )
        self.premiumStatusRepository = PremiumStatusRepositoryImpl()
        self.lotteryDataRepository = LotteryDataRepositoryImpl()
    }
}

@available(iOS 13.0, *)
public extension AppContext {
    func resolveApiClient() -> ApiClient {
        return createNicegramApiClient(auth: self.esimAuth)
    }
}

@available(iOS 13.0, *)
public extension AppContext {
    func createDefaultEventsLogger() -> EventsLogger {
        return LoggersFactory().createDefaultEventsLogger()
    }
}

@available(iOS 13.0, *)
public extension AppContext {
    func resolveGetCurrentUserUseCase() -> GetCurrentUserUseCase {
        return GetCurrentUserUseCaseImpl(
            esimAuth: esimAuth
        )
    }
    
    func resolveInitiateLoginWithTelegramUseCase() -> InitiateLoginWithTelegramUseCase {
        return InitiateLoginWithTelegramUseCaseImpl(
            getTelegramIdUseCase: GetTelegramIdUseCaseImpl(
                accountContext: self.accountContext
            ),
            telegramAuthenticator: TelegramAuthenticator(
                apiClient: self.resolveApiClient()
            )
        )
    }
}

@available(iOS 13.0, *)
public extension AppContext {
    func resolveGetLotteryDataUseCase() -> GetLotteryDataUseCase {
        return GetLotteryDataUseCaseImpl(
            lotteryDataRepository: lotteryDataRepository
        )
    }
    
    func resolveLoadLotteryDataUseCase() -> LoadLotteryDataUseCase {
        return LoadLotteryDataUseCaseImpl(
            loadLotteryDataNetworkService: LoadLotteryDataNetworkServiceImpl(
                apiClient: self.resolveApiClient()
            ),
            lotteryDataRepository: self.lotteryDataRepository
        )
    }
}
