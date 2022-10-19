import UIKit
import AccountContext
import EsimAuth
import NGApiClient
import NGTheme

public protocol LoginBuilder {
    func build() -> UIViewController
}

public protocol LoginListener: AnyObject {
    func onLogin()
    func onOpenTelegamBot(session: String)
}

@available(iOS 13, *)
public class LoginBuilderImpl: LoginBuilder {
    private let tgAccountContext: AccountContext
    private let esimAuth: EsimAuth
    private let ngTheme: NGThemeColors
    private let loginListener: LoginListener?
    
    public init(
        tgAccountContext: AccountContext,
        esimAuth: EsimAuth,
        ngTheme: NGThemeColors,
        loginListener: LoginListener?
    ) {
        self.tgAccountContext = tgAccountContext
        self.esimAuth = esimAuth
        self.ngTheme = ngTheme
        self.loginListener = loginListener
    }

    public func build() -> UIViewController {
        let controller = LoginViewController(ngTheme: ngTheme)
        let forgotPasswordBuilder = ForgotPasswordBuilderImpl(esimAuth: esimAuth, ngTheme: ngTheme)
        let registrationBuilder = RegistrationBuilderImpl(esimAuth: esimAuth, ngTheme: ngTheme)

        let router = LoginRouter(registrationBuilder: registrationBuilder, forgotPasswordBuilder: forgotPasswordBuilder)
        router.parentViewController = controller

        let presenter = LoginPresenter()
        presenter.output = controller
        
        let telegramAuthenticator = TelegramAuthenticator(
            apiClient: createNicegramApiClient(auth: esimAuth)
        )

        let interactor = LoginInteractor(
            tgAccountContext: tgAccountContext,
            esimAuth: esimAuth,
            telegramAuthenticator: telegramAuthenticator,
            loginListener: loginListener
        )
        interactor.output = presenter
        interactor.router = router
        
        controller.output = interactor

        return controller
    }
}
