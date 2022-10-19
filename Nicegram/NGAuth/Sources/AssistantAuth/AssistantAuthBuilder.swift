import UIKit
import AccountContext
import EsimAuth
import EsimApiClient
import NGTheme
import NGEnv

public protocol AssistantAuthBuilder {
    func build() -> UIViewController
}

@available(iOS 13, *)
public class AssistantAuthBuilderImpl: AssistantAuthBuilder {
    private let tgAccountContext: AccountContext
    private let esimAuth: EsimAuth
    private let ngTheme: NGThemeColors
    
    public init(tgAccountContext: AccountContext, esimAuth: EsimAuth, ngTheme: NGThemeColors) {
        self.tgAccountContext = tgAccountContext
        self.esimAuth = esimAuth
        self.ngTheme = ngTheme
    }

    public func build() -> UIViewController {
        let controller = AssistantAuthViewController(ngTheme: ngTheme)
        
        let loginBuilder = LoginBuilderImpl(tgAccountContext: tgAccountContext, esimAuth: esimAuth, ngTheme: ngTheme, loginListener: nil)
        let regist = RegistrationBuilderImpl(esimAuth: esimAuth, ngTheme: ngTheme)

        let router = AssistantAuthRouter(loginBuilder: loginBuilder, regist: regist)
        router.parentViewController = controller

        let presenter = AssistantAuthPresenter()
        presenter.output = controller

        let interactor = AssistantAuthInteractor(esimAuth: esimAuth)
        interactor.output = presenter
        interactor.router = router
        
        controller.output = interactor

        return controller
    }
}
