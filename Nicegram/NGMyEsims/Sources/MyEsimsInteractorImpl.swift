import Foundation
import NGModels
import NGAuth
import NGPurchaseEsim
import NGRepositories

typealias MyEsimsInteractorInput = MyEsimsViewControllerOutput

protocol MyEsimsInteractorOutput {
    func viewDidLoad()
    func present(cachedEsims: [UserEsim])
    func present(esims: [UserEsim])
    func present(isLoading: Bool)
    func present(isRefreshing: Bool)
    func present(fetchError: FetchUserEsimsError)
    func present(refreshError: Error)
    func presentBlockedEsimTopUpError()
    func presentExpiredEsimTopUpError()
    func copy(phoneNumber: String)
}

final class MyEsimsInteractor {
    
    //  MARK: - VIP
    
    var output: MyEsimsInteractorOutput!
    var router: MyEsimsRouter!
    
    //  MARK: - Dependencies
    
    private let esimRepository: EsimRepository
    
    //  MARK: - Logic
    
    private var esims: [UserEsim] = []
    
    private var deeplink: Deeplink?
    
    private static let worldwideRegionId = 5000
    
    //  MARK: - Lifecycle
    
    init(deeplink: Deeplink?, esimRepository: EsimRepository) {
        self.deeplink = deeplink
        self.esimRepository = esimRepository
    }
}

//  MARK: - Output

extension MyEsimsInteractor: MyEsimsInteractorInput {
    func viewDidLoad() {
        output.viewDidLoad()
        
        if let esims = esimRepository.getUserEsims() {
            self.esims = esims
            self.output.present(cachedEsims: esims)
        }
        
        fetchAllEsims()
        
        tryHandleDeeplink()
    }
    
    func didTapGetNewEsim() {
        router.routeToPurchaseEsim(regionId: MyEsimsInteractor.worldwideRegionId, deeplink: nil)
    }
    
    func didTapOnEsim(with id: String) {
        showSetupEsim(id: id)
    }
    
    func didTapTopUpOnEsim(with id: String) {
        topUpEsim(id: id)
    }
    
    func didTapCopyPhoneOnEsim(with id: String) {
        guard let esim = findEsim(with: id), let phoneNumber = esim.phoneNumber else { return }
        output.copy(phoneNumber: phoneNumber)
    }
    
    func didTapFaqOnEsim(with id: String) {
        showSetupEsim(id: id)
    }
    
    func didTapRetryFetch() {
        fetchAllEsims()
    }
    
    func didPullToRefresh() {
        refreshEsims(esims)
    }
}

//  MARK: - PurchaseEsimListener

extension MyEsimsInteractor: PurchaseEsimListener {
    func didPurchase(esim: UserEsim) {
        updateEsims()
    }
    
    func didTopUp(esim: UserEsim) {
        updateEsims()
    }
}

//  MARK: - Private Functions

private extension MyEsimsInteractor {
    func fetchAllEsims() {
        output.present(isLoading: true)
        esimRepository.fetchAllEsims { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.output.present(isLoading: false)
                
                switch result {
                case .success(let esims):
                    self.esims = esims
                    self.output.present(esims: esims)
                    self.refreshEsims(esims)
                case .failure(let error):
                    self.output.present(fetchError: error)
                }
            }
        }
    }
    
    func findEsim(with id: String) -> UserEsim? {
        return esims.first(where: { $0.id == id })
    }
    
    func updateEsims() {
        if let esims = esimRepository.getUserEsims() {
            self.esims = esims
            self.output.present(esims: esims)
        }
    }
    
    func topUpEsim(id: String) {
        guard let esim = findEsim(with: id) else { return }
        
        switch esim.state {
        case .blocked:
            output.presentBlockedEsimTopUpError()
        case .expired:
            output.presentExpiredEsimTopUpError()
        case .active:
            router.routeToTopUpEsim(icc: esim.icc, regionId: esim.regionId)
        }
    }
    
    func refreshEsims(_ esims: [UserEsim]) {
        esimRepository.refreshEsims(ids: esims.map(\.id)) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.output.present(isRefreshing: false)
                
                switch result {
                case .success(let esims):
                    self.esims = esims
                    self.output.present(esims: esims)
                case .failure(let error):
                    self.output.present(refreshError: error)
                }
            }
        }
    }
    
    func showSetupEsim(id: String) {
        guard let esim = findEsim(with: id) else { return }
        router.routeToSetupEsim(activationInfo: esim.activationInfo)
    }
    
    func tryHandleDeeplink() {
        guard let deeplink = deeplink else { return }
        
        if deeplink is PurchaseEsimDeeplink {
            router.routeToPurchaseEsim(regionId: MyEsimsInteractor.worldwideRegionId, deeplink: deeplink)
        }
        
        self.deeplink = nil
    }
}
