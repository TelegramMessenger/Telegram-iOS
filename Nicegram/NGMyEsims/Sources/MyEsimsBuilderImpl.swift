import UIKit
import AccountContext
import EsimAuth
import NGAppContext
import NGAuth
import NGPhoneFormatter
import NGModels
import NGMoneyFormatter
import NGPurchaseEsim
import NGRegionsFormatter
import NGRepositories
import NGSetupEsim
import NGTheme

public protocol MyEsimsBuilder {
    func build(deeplink: Deeplink?) -> UIViewController
}

@available(iOS 13, *)
public class MyEsimsBuilderImpl: MyEsimsBuilder {
    
    //  MARK: - Dependencies
    
    private let appContext: AppContext
    private let tgAccountContext: AccountContext
    private let auth: EsimAuth
    private let esimRepository: EsimRepository
    
    private let ngTheme: NGThemeColors
    
    //  MARK: - Lifecycle
    
    public init(appContext: AppContext, tgAccountContext: AccountContext, auth: EsimAuth, esimRepository: EsimRepository, ngTheme: NGThemeColors) {
        self.appContext = appContext
        self.tgAccountContext = tgAccountContext
        self.auth = auth
        self.esimRepository = esimRepository
        self.ngTheme = ngTheme
    }
    
    //  MARK: - Public Functions

    public func build(deeplink: Deeplink?) -> UIViewController {
        let controller = MyEsimsViewController(ngTheme: ngTheme)

        let router = MyEsimsRouter(
            purchaseEsimBuilder: PurchaseEsimBuilderImpl(
                appContext: appContext,
                tgAccountContext: tgAccountContext,
                auth: auth,
                esimRepository: esimRepository,
                ngTheme: ngTheme
            ),
            setupEsimBuilder: SetupEsimBuilderImpl(
                ngTheme: ngTheme
            )
        )
        router.parentViewController = controller
        
        let phoneFormatter = PhoneFormatterImpl()
        let moneyFormatter = MoneyFormatter()
        let regionsFormatter = RegionsFormatter()

        let presenter = MyEsimsPresenter(
            phoneFormatter: phoneFormatter,
            regionsFormatter: regionsFormatter,
            moneyFormatter: moneyFormatter
        )
        presenter.output = controller

        let interactor = MyEsimsInteractor(
            deeplink: deeplink,
            esimRepository: esimRepository
        )
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor
        
        router.purchaseEsimListener = interactor

        return controller
    }
}
