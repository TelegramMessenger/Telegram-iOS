import UIKit
import EsimAuth
import NGTheme

public protocol RegistrationBuilder {
    func build() -> UIViewController
}

@available(iOS 13, *)
public class RegistrationBuilderImpl: RegistrationBuilder {
    private let esimAuth: EsimAuth
    private let ngTheme: NGThemeColors
    
    public init(
        esimAuth: EsimAuth,
        ngTheme: NGThemeColors
    ) {
        self.esimAuth = esimAuth
        self.ngTheme = ngTheme
    }

    public func build() -> UIViewController {
        let controller = RegistrationViewController(ngTheme: ngTheme)

        let router = RegistrationRouter()
        router.parentViewController = controller

        let presenter = RegistrationPresenter()
        presenter.output = controller

        let interactor = RegistrationInteractor(esimAuth: esimAuth)
        interactor.output = presenter
        interactor.router = router
        
        controller.output = interactor

        return controller
    }
}
