import UIKit
import AccountContext
import EsimAuth
import NGLogging
import NGModels
import NGMyEsims
import NGRepositories
import NGSpecialOffer
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
    private let tgAccountContext: AccountContext
    private let auth: EsimAuth
    private let esimRepository: EsimRepository
    private let specialOfferService: SpecialOfferService
    private let ngTheme: NGThemeColors
    private weak var listener: AssistantListener?
    
    public init(tgAccountContext: AccountContext, auth: EsimAuth, esimRepository: EsimRepository, specialOfferService: SpecialOfferService, ngTheme: NGThemeColors, listener: AssistantListener?) {
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
            tgAccountContext: tgAccountContext,
            auth: auth,
            esimRepository: esimRepository,
            ngTheme: ngTheme,
            loginListener: controller
        )
        let loginBuilder = LoginBuilderImpl(tgAccountContext: tgAccountContext, esimAuth: auth, ngTheme: ngTheme, loginListener: controller)
        let specialOfferBuilder = SpecialOfferBuilderImpl(
            specialOfferService: specialOfferService,
            ngTheme: ngTheme
        )
        
        let router = AssistantRouter(
            assistantListener: listener,
            myEsimsBuilder: myEsimBuilder,
            loginBuilder: loginBuilder,
            specialOfferBuilder: specialOfferBuilder,
            ngTheme: ngTheme
        )
        router.parentViewController = controller

        let presenter = AssistantPresenter()
        presenter.output = controller

        let interactor = AssistantInteractor(
            deeplink: deeplink,
            esimAuth: auth,
            userEsimsRepository: esimRepository,
            getSpecialOfferUseCase: GetSpecialOfferUseCaseImpl(
                specialOfferService: specialOfferService
            ),
            eventsLogger: LoggersFactory().createDefaultEventsLogger()
        )
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor

        return controller
    }
}
