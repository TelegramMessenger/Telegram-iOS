import UIKit
import EsimMobileDataPurchaseProvider
import EsimMobileDataPayments
import EsimPayments
import NGMappers
import NGModels

class PurchaseEsimServiceImpl {
    
    //  MARK: - Dependencies
    
    private let purchaseProvider: EsimPurchaseProvider
    private let userEsimMapper: UserEsimMapper
    
    //  MARK: - Lifecycle
    
    init(purchaseProvider: EsimPurchaseProvider, userEsimMapper: UserEsimMapper) {
        self.purchaseProvider = purchaseProvider
        self.userEsimMapper = userEsimMapper
    }
    
}

extension PurchaseEsimServiceImpl: PurchaseEsimService {
    func topUpEsim(icc: String, offer: EsimOffer, from vc: UIViewController, completion: ((Result<UserEsim, PurchaseEsimError>) -> ())?) {
        purchase(icc: icc, offer: offer, from: vc, completion: completion)
    }
    
    func purchaseEsim(offer: EsimOffer, from vc: UIViewController, completion: ((Result<UserEsim, PurchaseEsimError>) -> ())?) {
        purchase(icc: nil, offer: offer, from: vc, completion: completion)
    }
}

//  MARK: - Private Functions

private extension PurchaseEsimServiceImpl {
    func purchase(icc: String?, offer: EsimOffer, from vc: UIViewController, completion: ((Result<UserEsim, PurchaseEsimError>) -> ())?) {
        let paymentInfo = makePaymentInfo(icc: icc, offer: offer)
        
        purchaseProvider.purchase(paymentInfo, from: vc) { [weak self] result in
            guard let self = self else { return }
            
            completion?(self.mapPurchaseResult(result))
        }
    }
    
    func makePaymentInfo(icc: String?, offer: EsimOffer) -> EsimPaymentInfo {
        let state: EsimPaymentInfo.State
        if let icc = icc {
            state = .updateCurrent(icc: icc)
        } else {
            state = .new
        }
        
        let currency = PaymentCurrency(isoCode: offer.price.currency.isoCode)
        
        let paymentDescription = generatePaymentDescription(offer: offer)
        
        return EsimPaymentInfo(regionId: offer.regionId, bundleId: offer.id, state: state, price: offer.price.amount, currency: currency, description: paymentDescription)
    }
    
    func generatePaymentDescription(offer: EsimOffer) -> String {
        var result = "Appvillis for \"\(offer.title)\""
        
        switch offer.duration {
        case .days(let days):
            result.append(" \(days) days")
        case .unlimited:
            break
        }
        
        switch offer.traffic {
        case .megabytes(let megabytes):
            result.append(" \(megabytes) MB")
        case .payAsYouGo:
            break
        }
        
        result.append(" plan")
        
        return result
    }
    
    func mapPurchaseResult(_ result: Result<EsimPurchaseResponse, EsimPurchaseError>) -> Result<UserEsim, PurchaseEsimError> {
        switch result {
        case .success(let dto):
            if let esim = mapPurchaseSuccess(dto) {
                return .success(esim)
            } else {
                return .failure(.underlying(MessageError.unknown))
            }
        case .failure(let errorDto):
            return .failure(mapPurchaseError(errorDto))
        }
    }
    
    func mapPurchaseSuccess(_ dto: EsimPurchaseResponse) -> UserEsim? {
        return userEsimMapper.map(dto.esim)
    }
    
    func mapPurchaseError(_ errorDto: EsimPurchaseError) -> PurchaseEsimError {
        switch errorDto {
        case .notAuthorized:
            return .notAuthorized
        case .paymentError(let paymentError):
            if paymentError.isCancelled {
                return .cancelled
            } else {
                return .underlying(paymentError)
            }
        case .completePurchaseError(let error):
            return .underlying(error)
        }
    }
}
