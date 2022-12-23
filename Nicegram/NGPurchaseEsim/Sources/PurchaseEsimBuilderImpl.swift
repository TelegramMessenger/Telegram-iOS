import UIKit
import AccountContext
import EsimAuth
import EsimMobileDataPurchaseProvider
import EsimMobileDataPayments
import NGApiClient
import NGAppContext
import NGAuth
import NGCountriesList
import NGMappers
import NGMobileDataFormatter
import NGModels
import NGMoneyFormatter
import NGRegionsFormatter
import NGRepositories
import NGTheme
import NGEnv

public protocol PurchaseEsimBuilder {
    func build(icc: String?, regionId: Int, deeplink: Deeplink?, listener: PurchaseEsimListener?) -> UIViewController
}

@available(iOS 13, *)
public class PurchaseEsimBuilderImpl: PurchaseEsimBuilder {
    
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

    public func build(icc: String?, regionId: Int, deeplink: Deeplink?, listener: PurchaseEsimListener?) -> UIViewController {
        let controller = PurchaseEsimViewController(ngTheme: ngTheme)

        let router = PurchaseEsimRouter(
            countriesListBuilder: CountriesListBuilderImpl(
                ngTheme: ngTheme
            )
        )
        router.parentViewController = controller
        
        let moneyFormatter = MoneyFormatter()
        let mobileDataFormatter = MobileDataFormatter(moneyFormatter: moneyFormatter)
        let regionsFormatter = RegionsFormatter()

        let presenter = PurchaseEsimPresenter(
            mobileDataFormatter: mobileDataFormatter,
            moneyFormatter: moneyFormatter,
            regionsFormatter: regionsFormatter)
        presenter.output = controller
        
        let apiClient = createNicegramApiClient(auth: auth)
        let paymentProvider = EcommpayEsimPaymentProvider(
            projectId: NGENV.ecommpay_project_id,
            merchantId: NGENV.ecommpay_merchant_id, 
            customerId: "", apiClient: apiClient
        )
        let purchaseProvider = EsimPurchaseProvider(paymentProvider: paymentProvider, apiClient: apiClient)
        let purchaseService = PurchaseEsimServiceImpl(purchaseProvider: purchaseProvider, userEsimMapper: UserEsimMapper())

        let interactor = PurchaseEsimInteractor(
            icc: icc,
            regionId: regionId,
            deeplink: deeplink,
            esimRepository: esimRepository,
            purchaseEsimUseCase: PurchaseEsimUseCase(
                getCurrentUserUseCase: appContext.resolveGetCurrentUserUseCase(),
                userEsimsRepository: esimRepository,
                purchaseEsimService: purchaseService
            ),
            initiateLoginWithTelegramUseCase: appContext.resolveInitiateLoginWithTelegramUseCase()
        )
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor
        
        interactor.listener = listener

        return controller
    }
}
