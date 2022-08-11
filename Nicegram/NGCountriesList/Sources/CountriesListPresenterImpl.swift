import UIKit
import NGCustomViews
import NGLocalization
import NGMobileDataFormatter
import NGModels
import NGMoneyFormatter
import NGRegionsFormatter

protocol CountriesListPresenterInput { }

protocol CountriesListPresenterOutput: AnyObject {
    func display(navigationTitle: String)
    func display(searchPlaceholder: String)
    func display(items: [DescriptionItemViewModel])
}

final class CountriesListPresenter: CountriesListPresenterInput {
    
    //  MARK: - VIP
    
    weak var output: CountriesListPresenterOutput!
    
    //  MARK: - Dependencies
    
    private let mobileDataFormatter: MobileDataFormatter
    private let moneyFormatter: MoneyFormatter
    private let regionsFormatter: RegionsFormatter
    
    //  MARK: - Lifecycle
    
    init(mobileDataFormatter: MobileDataFormatter, moneyFormatter: MoneyFormatter, regionsFormatter: RegionsFormatter) {
        self.mobileDataFormatter = mobileDataFormatter
        self.moneyFormatter = moneyFormatter
        self.regionsFormatter = regionsFormatter
    }
}

//  MARK: - Output

extension CountriesListPresenter: CountriesListInteractorOutput {
    func viewDidLoad() {
        output.display(navigationTitle: ngLocalized("Nicegram.Internet.Countries.Title"))
        output.display(searchPlaceholder: ngLocalized("Nicegram.Internet.Countries.Search"))
    }
    
    func present(countries: [EsimCountry]) {
        let viewItems = countries.map({ mapCountryToDescriptionItemViewModel($0) })
        output.display(items: viewItems)
    }
}

//  MARK: - Mapping

private extension CountriesListPresenter {
    // TODO: Repeated code from NGPurchaseEsim presenter
    func mapCountryToDescriptionItemViewModel(_ country: EsimCountry) -> DescriptionItemViewModel {
        let flagImage = regionsFormatter.countryFlagImage(country)
        let countryName = regionsFormatter.localizedCountryName(country)
        let priceDescription: String?
        if let rate = country.payAsYouGoRate {
            priceDescription = mobileDataFormatter.pricePerMb(rate)
        } else {
            priceDescription = nil
        }
        
        return DescriptionItemViewModel(image: flagImage, imageBackgroundColor: .clear, title: countryName, subtitle: nil, description: priceDescription)
    }
}
