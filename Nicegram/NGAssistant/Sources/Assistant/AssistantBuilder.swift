import UIKit
import AccountContext
import EsimAuth
import NGApiClient
import NGAppContext
import NGAuth
import NGLogging
import NGLottery
import NGLotteryUI
import NGModels
import NGMyEsims
import NGRepositories
import NGSpecialOffer
import NGTelegramRepo
import NGTheme
import Postbox
import NGAuth

public protocol AssistantBuilder {
    func build(deeplink: Deeplink?) -> UIViewController
}

public protocol AssistantListener: AnyObject {
    func onOpenChat(chatURL: URL?)
}

@available(iOS 13, *)
public class AssistantBuilderImpl: AssistantBuilder {
    private let appContext: AppContext
    private let tgAccountContext: AccountContext
    private let auth: EsimAuth
    private let esimRepository: EsimRepository
    private let specialOfferService: SpecialOfferService
    private let ngTheme: NGThemeColors
    private weak var listener: AssistantListener?
    
    public init(appContext: AppContext, tgAccountContext: AccountContext, auth: EsimAuth, esimRepository: EsimRepository, specialOfferService: SpecialOfferService, ngTheme: NGThemeColors, listener: AssistantListener?) {
        self.appContext = appContext
        self.tgAccountContext = tgAccountContext
        self.auth = auth
        self.esimRepository = esimRepository
        self.specialOfferService = specialOfferService
        self.ngTheme = ngTheme
        self.listener = listener
    }

    public func build(deeplink: Deeplink?) -> UIViewController {
        let controller = AssistantViewController(ngTheme: ngTheme)
        let myEsimBuilder = MyEsimsBuilderImpl(
            appContext: appContext,
            tgAccountContext: tgAccountContext,
            auth: auth,
            esimRepository: esimRepository,
            ngTheme: ngTheme
        )
        let specialOfferBuilder = SpecialOfferBuilderImpl(
            specialOfferService: specialOfferService,
            ngTheme: ngTheme
        )
        
        let lotteryFlowFactory = LotteryFlowFactoryImpl(
            appContext: appContext
        )
        
        let router = AssistantRouter(
            assistantListener: listener,
            myEsimsBuilder: myEsimBuilder,
            specialOfferBuilder: specialOfferBuilder,
            lotteryFlowFactory: lotteryFlowFactory,
            ngTheme: ngTheme
        )
        router.parentViewController = controller

        let presenter = AssistantPresenter()
        presenter.output = controller

        let interactor = AssistantInteractor(
            deeplink: deeplink,
            esimAuth: auth,
            userEsimsRepository: esimRepository,
            getCurrentUserUseCase: appContext.resolveGetCurrentUserUseCase(),
            getSpecialOfferUseCase: GetSpecialOfferUseCaseImpl(
                specialOfferService: specialOfferService
            ),
            getReferralLinkUseCase: GetReferralLinkUseCaseImpl(),
            initiateLoginWithTelegramUseCase: appContext.resolveInitiateLoginWithTelegramUseCase(),
            getLotteryDataUseCase: appContext.resolveGetLotteryDataUseCase(),
            eventsLogger: LoggersFactory().createDefaultEventsLogger()
        )
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor

        return controller
    }
}
