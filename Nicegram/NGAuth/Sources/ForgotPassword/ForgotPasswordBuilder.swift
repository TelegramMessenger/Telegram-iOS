import UIKit
import EsimAuth
import NGTheme

public protocol ForgotPasswordBuilder {
    func build() -> UIViewController
}

@available(iOS 13, *)
public class ForgotPasswordBuilderImpl: ForgotPasswordBuilder {
    private let ngTheme: NGThemeColors
    private let esimAuth: EsimAuth

    public init(esimAuth: EsimAuth, ngTheme: NGThemeColors) { 
        self.esimAuth = esimAuth
        self.ngTheme = ngTheme
    }

    public func build() -> UIViewController {
        let controller = ForgotPasswordViewController(ngTheme: ngTheme)

        let router = ForgotPasswordRouter()
        router.parentViewController = controller

        let presenter = ForgotPasswordPresenter()
        presenter.output = controller

        let interactor = ForgotPasswordInteractor(esimAuth: esimAuth)
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor

        return controller
    }
}
