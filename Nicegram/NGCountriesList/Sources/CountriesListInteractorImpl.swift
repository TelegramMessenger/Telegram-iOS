import Foundation
import NGModels
import NGRegionsFormatter
import NGSearch

typealias CountriesListInteractorInput = CountriesListViewControllerOutput

protocol CountriesListInteractorOutput {
    func viewDidLoad()
    func present(countries: [EsimCountry])
}

final class CountriesListInteractor {
    
    //  MARK: - VIP
    
    var output: CountriesListInteractorOutput!
    var router: CountriesListRouter!
    
    //  MARK: - Dependencies
    
    private let searchController = KeywordsSearch()
    private let regionsFormatter: RegionsFormatter
    
    //  MARK: - Logic
    
    private var countries: [EsimCountry]
    
    //  MARK: - Lifecycle
    
    public init(countries: [EsimCountry], regionsFormatter: RegionsFormatter) {
        self.countries = countries
        self.regionsFormatter = regionsFormatter
    }
}

//  MARK: - Output

extension CountriesListInteractor: CountriesListInteractorInput {
    func viewDidLoad() {
        output.viewDidLoad()
        output.present(countries: countries)
    }
    
    func didChangeSearchText(to searchText: String) {
        let filteredCountries = searchController.filter(items: countries, by: searchText) { [weak self] country in
            guard let self = self else { return [] }
            
            let isoCode = country.isoCode
            let localizedCountryName = self.regionsFormatter.localizedCountryName(country)
            return [isoCode, country.name, localizedCountryName]
        }
        output.present(countries: filteredCountries)
    }
}
