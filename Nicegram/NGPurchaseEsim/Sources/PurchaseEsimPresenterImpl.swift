import UIKit
import NGCustomViews
import NGLocalization
import NGMobileDataFormatter
import NGModels
import NGPicker
import NGRegionsFormatter
import NGMoneyFormatter

protocol PurchaseEsimPresenterInput { }

protocol PurchaseEsimPresenterOutput: AnyObject {
    func display(navigationTitle: String)
    func displayHeader(item: HeaderCardViewModel)
    func display(pickerItems: [PickerTitleViewModel])
    func select(pirckerItemWith: Int, animated: Bool)
    func displayMain(section: DescriptionsSectionViewModel)
    func displayAdditional(section: DescriptionsSectionViewModel?)
    func displayCountries(section: DescriptionsSectionViewModel)
    func display(buttonTitle: String)
    func displayPurchaseError(message: String)
    func displayButton(isLoading: Bool)
    func display(isLoading: Bool)
    func displayFetchError(message: String)
    func hidePlaceholders()
    func handleOrienation() 
}

final class PurchaseEsimPresenter: PurchaseEsimPresenterInput {
    
    //  MARK: - VIP
    
    weak var output: PurchaseEsimPresenterOutput!
    
    //  MARK: - Dependencies
    
    private let mobileDataFormatter: MobileDataFormatter
    private let moneyFormatter: MoneyFormatter
    private let regionsFormatter: RegionsFormatter
    
    //  MARK: - Logic
    
    private var currentOffer: EsimOffer?
    private var currentCountriesCount: Int = 0
    
    //  MARK: - Constants
    
    private let countriesMaxCount = 5
    
    //  MARK: - Lifecycle
    
    init(mobileDataFormatter: MobileDataFormatter, moneyFormatter: MoneyFormatter, regionsFormatter: RegionsFormatter) {
        self.mobileDataFormatter = mobileDataFormatter
        self.moneyFormatter = moneyFormatter
        self.regionsFormatter = regionsFormatter
    }
}

extension PurchaseEsimPresenter: PurchaseEsimInteractorOutput {
    func viewDidLoad() {
        output.display(navigationTitle: ngLocalized("Nicegram.MobileData.Action.Add"))
    }
    
    func present(offers: [EsimOffer]) {
        let sortedOffers = offers.sorted(by: { $0.price.amount < $1.price.amount })
        output.display(pickerItems: sortedOffers.map({ mapOfferToPickerViewModel($0) }))
        output.hidePlaceholders()
    }
    
    func present(countries: [EsimCountry]) {
        output.displayCountries(section: makeCountriesSection(from: countries))
        if let currentOffer = currentOffer {
            output.displayAdditional(section: makeAdditionalSection(from: currentOffer, countriesCount: countries.count))
        }
        currentCountriesCount = countries.count
    }
    
    func present(isPurchasing: Bool) {
        output.displayButton(isLoading: isPurchasing)
    }
    
    func present(purchaseError: Error) {
        output.displayPurchaseError(message: purchaseError.localizedDescription)
    }
    
    func select(offer: EsimOffer, animated: Bool) {
        output.select(pirckerItemWith: offer.id, animated: animated)
        
        output.displayHeader(item: makeHeaderItem(from: offer))
        output.displayMain(section: makeMainSection(from: offer))
        output.displayAdditional(section: makeAdditionalSection(from: offer, countriesCount: currentCountriesCount))
        
        output.display(buttonTitle: ngLocalized("Nicegram.AddMobileData.Button", with: priceString(from: offer.price)))
        
        currentOffer = offer
    }
    
    func present(isLoading: Bool) {
        output.display(isLoading: isLoading)
    }
    
    func present(fetchError: Error) {
        output.displayFetchError(message: fetchError.localizedDescription)
    }
    
    func handleOrientation() {
        output.handleOrienation()
    }
}

//  MARK: - Mapping

private extension PurchaseEsimPresenter {
    func mapOfferToPickerViewModel(_ offer: EsimOffer) -> PickerTitleViewModel {
        return PickerTitleViewModel(id: offer.id, title: priceString(from: offer.price))
    }
    
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
    
    func makeHeaderItem(from offer: EsimOffer) -> HeaderCardViewModel {
        let title = localizedRegionName(offer: offer)
        
        let subtitle: String?
        switch offer.traffic {
        case .payAsYouGo:
            subtitle = ngLocalized("Nicegram.AddMobileData.Subtitle")
        case .megabytes(_):
            subtitle = nil
        }
        
        return HeaderCardViewModel(title: title, subtitle: subtitle, subtitleButtonImage: nil, backgroundImage: UIImage(named: "ng.worldwide.background")!)
    }
    
    func makeMainSection(from offer: EsimOffer) -> DescriptionsSectionViewModel {
        let trafficDescription: String
        switch offer.traffic {
        case .payAsYouGo:
            trafficDescription = localizedRegionName(offer: offer)
        case .megabytes(let megabytes):
            trafficDescription = "\(megabytes) Mb"
        }
        
        let durationDescription: String
        switch offer.duration {
        case .unlimited:
            durationDescription = ngLocalized("Nicegram.MobileData.MyEsim.Duration.Status")
        case .days(let days):
            durationDescription = "\(days) days"
        }
        
        var items = [
            DescriptionItemViewModel(
                image: UIImage(named: "ng.globe"),
                imageBackgroundColor: .ngRedFour,
                title: ngLocalized("Nicegram.Internet.Trafic"),
                subtitle: nil,
                description: trafficDescription
            ),
            DescriptionItemViewModel(
                image: UIImage(named: "ng.calendar"),
                imageBackgroundColor: .ngActiveButton,
                title: ngLocalized("Nicegram.Internet.Duration"),
                subtitle: nil,
                description: durationDescription)
        ]
        
        if offer.includePhoneNumber {
            items.append(
                DescriptionItemViewModel(
                    image: UIImage(named: "ng.phone"),
                    imageBackgroundColor: .ngGreenTwo,
                    title: ngLocalized("Nicegram.Internet.Number"),
                    subtitle: nil,
                    description: ngLocalized("Nicegram.Internet.Number.Included")
                )
            )
        }
                                     
        return DescriptionsSectionViewModel(title: nil, buttonTitle: nil, items: items)
    }
    
    func makeAdditionalSection(from offer: EsimOffer, countriesCount: Int) -> DescriptionsSectionViewModel? {
        switch offer.traffic {
        case .payAsYouGo:
            let items = [
                DescriptionItemViewModel(
                    image: UIImage(named: "ng.chart.bar"),
                    imageBackgroundColor: .ngActiveButton,
                    title: ngLocalized("Nicegram.Internet.Plan.Description"),
                    subtitle: ngLocalized("Nicegram.Internet.Plan.Title").uppercased(),
                    description: nil
                ),
                DescriptionItemViewModel(
                    image: UIImage(named: "ng.globe2"),
                    imageBackgroundColor: .ngLightOrange,
                    title: ngLocalized("Nicegram.Internet.Coverage.Description", with: "\(countriesCount)"),
                    subtitle: ngLocalized("Nicegram.Internet.Coverage.Title").uppercased(),
                    description: nil
                ),
                DescriptionItemViewModel(
                    image: UIImage(named: "ng.creditcard"),
                    imageBackgroundColor: .ngGreenTwo,
                    title: ngLocalized("Nicegram.Internet.Start.Description"),
                    subtitle: ngLocalized("Nicegram.Internet.Start.Title").uppercased(),
                    description: nil
                ),
            ]
            return DescriptionsSectionViewModel(
                title: ngLocalized("Nicegram.Internet.Info.Title"),
                buttonTitle: nil,
                items: items
            )
        case .megabytes(_):
            return nil
        }
    }
    
    func makeCountriesSection(from countries: [EsimCountry]) -> DescriptionsSectionViewModel {
        let buttonTitle = (countries.count > countriesMaxCount) ? ngLocalized("Nicegram.Internet.Countries.SeeAll").uppercased() : nil
        let items = countries.prefix(countriesMaxCount).map({ mapCountryToDescriptionItemViewModel($0) })
        return DescriptionsSectionViewModel(title: ngLocalized("Nicegram.AddMobileData.Countries"), buttonTitle: buttonTitle, items: items)
    }
    
    func priceString(from price: Money) -> String {
        return moneyFormatter.format(price)
    }
    
    func localizedRegionName(offer: EsimOffer) -> String {
        return regionsFormatter.localizedRegionName(isoCode: offer.regionIsoCode)
    }
}
