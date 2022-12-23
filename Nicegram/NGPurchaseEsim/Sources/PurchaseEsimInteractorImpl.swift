import Foundation
import NGAuth
import NGCoreUI
import NGModels
import NGRepositories
import UIKit

typealias PurchaseEsimInteractorInput = PurchaseEsimViewControllerOutput

protocol PurchaseEsimInteractorOutput {
    func viewDidLoad()
    func present(offers: [EsimOffer])
    func present(countries: [EsimCountry])
    func select(offer: EsimOffer, animated: Bool)
    func present(isPurchasing: Bool)
    func present(purchaseError: Error)
    func present(isLoading: Bool)
    func present(fetchError: Error)
    func handleOrientation()
    func presentLoginLoading(_: Bool)
}

final class PurchaseEsimInteractor {
    
    //  MARK: - VIP
    
    var output: PurchaseEsimInteractorOutput!
    var router: PurchaseEsimRouter!
    
    //  MARK: - Dependencies
    
    private let esimRepository: EsimRepository
    
    private let purchaseEsimUseCase: PurchaseEsimUseCase
    private let initiateLoginWithTelegramUseCase: InitiateLoginWithTelegramUseCase
    
    //  MARK: - Listener
    
    weak var listener: PurchaseEsimListener?
    
    //  MARK: - Lifecycle
    
    public init(icc: String?, regionId: Int, deeplink: Deeplink?, esimRepository: EsimRepository, purchaseEsimUseCase: PurchaseEsimUseCase, initiateLoginWithTelegramUseCase: InitiateLoginWithTelegramUseCase) {
        self.icc = icc
        self.regionId = regionId
        self.deeplink = deeplink
        self.esimRepository = esimRepository
        self.purchaseEsimUseCase = purchaseEsimUseCase
        self.initiateLoginWithTelegramUseCase = initiateLoginWithTelegramUseCase
    }
    
    //  MARK: - Logic
    
    private let icc: String?
    private let regionId: Int
    
    private var deeplink: Deeplink?
    
    private var offers: [EsimOffer] = []
    private var countries: [EsimCountry] = []
    
    private var selectedOffer: EsimOffer?
    
    private var purchaseEsimDeeplink: PurchaseEsimDeeplink?
}

//  MARK: - Output

extension PurchaseEsimInteractor: PurchaseEsimInteractorInput {
    func viewDidLoad() {
        output.viewDidLoad()
        fetchData()
        tryHandleDeeplink()
    }
    
    func selectOffer(with id: Int) {
        guard let offer = offers.first(where: { $0.id == id }) else { return }
        self.selectedOffer = offer
        output.select(offer: offer, animated: true)
    }
    
    func purchaseTapped() {
        purchase()
    }
    
    func seeAllCountriesTapped() {
        router.routeToCountriesList(countries)
    }
    
    func retryPurchaseTapped() {
        purchase()
    }
    
    func retryFetchTapped() {
        fetchData()
    }
}

private extension PurchaseEsimInteractor {
    func fetchData() {
        output.present(isLoading: true)
        esimRepository.fetch { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.output.present(isLoading: false)
                
                switch result {
                case .success(_):
                    self.getOffers()
                    self.getCountries()
                case .failure(let error):
                    self.output.present(fetchError: error)
                }
            }
        }
    }
    
    func getOffers() {
        let offers = esimRepository.getOffersWith(regionId: regionId)
        self.offers = offers
        
        self.output.present(offers: offers)
        
        let sortedOffers = offers.sorted(by: { $0.price.amount < $1.price.amount })
        
        let defaultIndexToSelect = (sortedOffers.count - 1) / 2
        let indexToSelect = sortedOffers.firstIndex(where: { $0.id == purchaseEsimDeeplink?.bundleId }) ?? defaultIndexToSelect
        self.purchaseEsimDeeplink = nil
        
        if sortedOffers.indices.contains(indexToSelect) {
            selectOffer(with: sortedOffers[indexToSelect].id)
        }
    }
    
    func getCountries() {
        let countries = esimRepository.getCountriesWith(regionId: regionId)
        self.countries = countries
        self.output.present(countries: countries)
    }
    
    func purchase() {
        guard let selectedOffer = selectedOffer else { return }
        
        if let icc = icc {
            topUpEsim(icc: icc, offer: selectedOffer)
        } else {
            purchaseEsim(offer: selectedOffer)
        }
    }
    
    func purchaseEsim(offer: EsimOffer) {
        output.present(isPurchasing: true)
        guard let parent = router.parentViewController else { return }
        purchaseEsimUseCase.purchaseEsim(offer: offer, from: parent) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.output.present(isPurchasing: false)
                self.output.handleOrientation()
                switch result {
                case .success(let esim):
                    self.listener?.didPurchase(esim: esim)
                case .failure(let error):
                    self.handlePurchaseEsimError(error)
                }
            }
        }
    }
    
    func topUpEsim(icc: String, offer: EsimOffer) {
        output.present(isPurchasing: true)
        guard let parent = router.parentViewController else { return }
        purchaseEsimUseCase.topUpEsim(icc: icc, offer: offer, from: parent) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.output.present(isPurchasing: false)
                
                switch result {
                case .success(let esim):
                    self.listener?.didTopUp(esim: esim)
                case .failure(let error):
                    self.handlePurchaseEsimError(error)
                }
            }
        }
    }
    
    func handlePurchaseEsimError(_ error: PurchaseEsimError) {
        switch error {
        case .cancelled:
            break
        case .notAuthorized:
            Alerts.show(.needLoginWithTelegram(onConfirm: { [weak self] in
                self?.initiateLoginWithTelegram()
            }))
        case .underlying(let error):
            self.output.present(purchaseError: error)
        }
    }
    
    func initiateLoginWithTelegram() {
        DispatchQueue.main.async {
            self.output.presentLoginLoading(true)
        }
        initiateLoginWithTelegramUseCase.initiateLoginWithTelegram { [weak self] result in
            guard let self else { return }
            
            DispatchQueue.main.async {
                self.output.presentLoginLoading(false)
                
                switch result {
                case .success(let url):
                    UIApplication.shared.open(url)
                case .failure(let error):
                    Alerts.show(.error(error))
                }
            }
        }
    }
    
    func tryHandleDeeplink() {
        if let purchaseEsimDeeplink = deeplink as? PurchaseEsimDeeplink {
            self.purchaseEsimDeeplink = purchaseEsimDeeplink
        }
        
        self.deeplink = nil
    }
}
