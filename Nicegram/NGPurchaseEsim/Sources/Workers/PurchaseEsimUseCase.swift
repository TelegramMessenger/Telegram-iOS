import UIKit
import EsimAuth
import NGModels
import NGRepositories

class PurchaseEsimUseCase {
    
    //  MARK: - Dependencies
    
    private let auth: EsimAuth
    private let userEsimsRepository: UserEsimsRepository
    private let purchaseEsimService: PurchaseEsimService
    
    //  MARK: - Lifecycle
    
    init(auth: EsimAuth, userEsimsRepository: UserEsimsRepository, purchaseEsimService: PurchaseEsimService) {
        self.auth = auth
        self.userEsimsRepository = userEsimsRepository
        self.purchaseEsimService = purchaseEsimService
    }
    
    //  MARK: - Public Functions

    func topUpEsim(icc: String, offer: EsimOffer, from vc: UIViewController,  completion: ((Result<UserEsim, PurchaseEsimError>) -> ())?) {
        guard auth.isAuthorized else {
            completion?(.failure(.notAuthorized))
            return
        }
        
        purchaseEsimService.topUpEsim(icc: icc, offer: offer, from: vc) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let esim):
                self.userEsimsRepository.updateEsim(esim)
            case .failure(_):
                break
            }
            
            completion?(result)
        }
    }
    func purchaseEsim(offer: EsimOffer, from vc: UIViewController, completion: ((Result<UserEsim, PurchaseEsimError>) -> ())?) {
        guard auth.isAuthorized else {
            completion?(.failure(.notAuthorized))
            return
        }
        
        purchaseEsimService.purchaseEsim(offer: offer, from: vc) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let esim):
                self.userEsimsRepository.addEsim(esim)
            case .failure(_):
                break
            }
            
            completion?(result)
        }
    }
}
