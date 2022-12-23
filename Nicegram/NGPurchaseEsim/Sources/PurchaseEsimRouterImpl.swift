import NGAuth
import NGCountriesList
import NGModels

protocol PurchaseEsimRouterInput: AnyObject {
    func routeToCountriesList(_ countries: [EsimCountry])
    func dismiss()
}

final class PurchaseEsimRouter: PurchaseEsimRouterInput {
    weak var parentViewController: PurchaseEsimViewController?
    
    private let countriesListBuilder: CountriesListBuilder
    
    //  MARK: - Lifecycle
    
    init(countriesListBuilder: CountriesListBuilder) {
        self.countriesListBuilder = countriesListBuilder
    }
    
    //  MARK: - Public Functions
    
    func routeToCountriesList(_ countries: [EsimCountry]) {
        let vc = countriesListBuilder.build(countries: countries)
        parentViewController?.navigationController?.pushViewController(vc, animated: true)
    }

    func dismiss() {
        parentViewController?.dismiss(animated: true, completion: nil)
    }
}
