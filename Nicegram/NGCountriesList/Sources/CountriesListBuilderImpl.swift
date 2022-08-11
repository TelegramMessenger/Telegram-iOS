import UIKit
import NGMobileDataFormatter
import NGModels
import NGMoneyFormatter
import NGRegionsFormatter
import NGTheme

public protocol CountriesListBuilder {
    func build(countries: [EsimCountry]) -> UIViewController
}

public class CountriesListBuilderImpl: CountriesListBuilder {
    
    //  MARK: - Dependencies
    
    private let ngTheme: NGThemeColors
    
    //  MARK: - Lifecycle
    
    public init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
    }
    
    //  MARK: - Public Functions

    public func build(countries: [EsimCountry]) -> UIViewController {
        let controller = CountriesListViewController(ngTheme: ngTheme)

        let router = CountriesListRouter()
        router.parentViewController = controller
        
        let moneyFormatter: MoneyFormatter = MoneyFormatter()
        let mobileDataFormatter: MobileDataFormatter = MobileDataFormatter(moneyFormatter: moneyFormatter)
        let regionsFormatter: RegionsFormatter = RegionsFormatter()

        let presenter = CountriesListPresenter(
            mobileDataFormatter: mobileDataFormatter,
            moneyFormatter: moneyFormatter,
            regionsFormatter: regionsFormatter)
        presenter.output = controller

        let interactor = CountriesListInteractor(countries: countries, regionsFormatter: regionsFormatter)
        interactor.output = presenter
        interactor.router = router

        controller.output = interactor

        return controller
    }
}
