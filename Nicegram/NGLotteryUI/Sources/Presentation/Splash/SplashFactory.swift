import EsimAuth
import NGAppContext
import NGAuth
import NGLottery
import NGStoreKitFacade
import NGSubscription
import NGTelegramRepo
import UIKit

protocol SplashFactory {
    func makeViewController(input: SplashInput, handlers: SplashHandlers, flow: any LotteryFlow) -> UIViewController
}

@available(iOS 13.0, *)
class SplashFactoryImpl {
    
    //  MARK: - Dependencies
    
    private let appContext: AppContext
    
    //  MARK: - Lifecycle
    
    init(appContext: AppContext) {
        self.appContext = appContext
    }
}

@available(iOS 13.0, *)
extension SplashFactoryImpl: SplashFactory {
    func makeViewController(input: SplashInput, handlers: SplashHandlers, flow: any LotteryFlow) -> UIViewController {
        let getLotteryDataUseCase = appContext.resolveGetLotteryDataUseCase()
        
        let getPremiumStatusUseCase = GetPremiumStatusUseCaseImpl(
            premiumStatusRepository: appContext.premiumStatusRepository
        )
        
        let getTicketForPremiumUseCase = GetTicketForPremiumUseCaseImpl(
            storeKitFacade: StoreKitFacade(),
            getTicketForPremiumService: GetTicketForPremiumServiceImpl(
                apiClient: appContext.resolveApiClient()
            ),
            lotteryDataRepository: appContext.lotteryDataRepository
        )
        
        let getCurrentUserUseCase = GetCurrentUserUseCaseImpl(
            esimAuth: appContext.esimAuth
        )
        
        let initiateLoginWithTelegramUseCase = appContext.resolveInitiateLoginWithTelegramUseCase()
        
        let loadLotteryDataUseCase = appContext.resolveLoadLotteryDataUseCase()
        
        let getReferralLinkUseCase = GetReferralLinkUseCaseImpl()
        
        let eventsLogger = appContext.createDefaultEventsLogger()
        
        let viewModel = SplashViewModelImpl(input: input, handlers: handlers, getLotteryDataUseCase: getLotteryDataUseCase, getPremiumStatusUseCase: getPremiumStatusUseCase, getTicketForPremiumUseCase: getTicketForPremiumUseCase, getCurrentUserUseCase: getCurrentUserUseCase, initiateLoginWithTelegramUseCase: initiateLoginWithTelegramUseCase, loadLotteryDataUseCase: loadLotteryDataUseCase, getReferralLinkUseCase: getReferralLinkUseCase, eventsLogger: eventsLogger)
        
        let view = SplashViewController(viewModel: viewModel, flowHolder: flow)
        
        return view
    }
}
