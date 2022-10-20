import UIKit
import EsimApiClientDefinition
import EsimMobileDataPayments

public final class EsimPurchaseProvider {
    
    //  MARK: - Dependencies
    
    private let paymentProvider: EsimPaymentProvider
    private let purchaseCompletener: EsimPurchaseCompletener
    private let unlocker: EsimPurchaseUnlocker
    
    //  MARK: - Lifecycle
    
    public init(paymentProvider: EsimPaymentProvider, purchaseCompletener: EsimPurchaseCompletener, unlocker: EsimPurchaseUnlocker) {
        self.paymentProvider = paymentProvider
        self.purchaseCompletener = purchaseCompletener
        self.unlocker = unlocker
    }
    
    public convenience init(paymentProvider: EsimPaymentProvider, apiClient: EsimApiClientProtocol) {
        let purchaseCompletener = EsimPurchaseCompletenerImpl(apiClient: apiClient)
        let unlocker = EsimPurchaseUnlockerImpl(apiClient: apiClient)
        self.init(paymentProvider: paymentProvider, purchaseCompletener: purchaseCompletener, unlocker: unlocker)
    }
}

extension EsimPurchaseProvider {
    public func purchase(_ info: EsimPaymentInfo, from vc: UIViewController, completion: @escaping (Result<EsimPurchaseResponse, EsimPurchaseError>) -> ()) {
        paymentProvider.pay(info, from: vc) { [weak self] paymentResult in
            guard let self = self else { return }
            
            switch paymentResult {
            case .success(let paymentId):
                let paymentType: PaymentType
                switch self.paymentProvider.identifier {
                case "ecommpay":
                    paymentType = .ecommpay
                default:
                    fatalError("Unknown payment provider")
                }
                
                self.purchaseCompletener.completePurchase(icc: info.icc, regionId: info.regionId, bundleId: info.bundleId, paymentId: paymentId, paymentType: paymentType) { completePurchaseResult in
                    switch completePurchaseResult {
                    case .success(let completePurchaseResponse):
                        completion(.success(completePurchaseResponse))
                    case .failure(let completePurchaseError):
                        self.unlocker.unlock(paymentId: paymentId,completion: nil)
                        completion(.failure(.completePurchaseError(completePurchaseError)))
                    }
                }
            case .failure(let paymentError):
                self.unlocker.unlock(paymentId: paymentError.meta?.paymentId, completion: nil)
                completion(.failure(.paymentError(paymentError)))
            }
        }
    }
}
