import NGAuth
import NGCountriesList
import NGModels

protocol PurchaseEsimRouterInput: AnyObject {
    func routeToAuth()
    func routeToCountriesList(_ countries: [EsimCountry])
    func dismiss()
}

final class PurchaseEsimRouter: PurchaseEsimRouterInput {
    weak var parentViewController: PurchaseEsimViewController?
    
    private let loginBuilder: LoginBuilder
    private let countriesListBuilder: CountriesListBuilder
    
    //  MARK: - Lifecycle
    
    init(loginBuilder: LoginBuilder, countriesListBuilder: CountriesListBuilder) {
        self.loginBuilder = loginBuilder
        self.countriesListBuilder = countriesListBuilder
    }
    
    //  MARK: - Public Functions
    
    func routeToAuth() {
        let vc = loginBuilder.build()
        parentViewController?.navigationController?.pushViewController(vc, animated: true)
    }
    
    func routeToCountriesList(_ countries: [EsimCountry]) {
        let vc = countriesListBuilder.build(countries: countries)
        parentViewController?.navigationController?.pushViewController(vc, animated: true)
    }

    func dismiss() {
        parentViewController?.dismiss(animated: true, completion: nil)
    }
}
