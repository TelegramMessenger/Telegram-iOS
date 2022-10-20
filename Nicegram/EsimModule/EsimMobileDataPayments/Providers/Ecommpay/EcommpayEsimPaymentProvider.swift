import UIKit
import EsimApiClientDefinition
import EsimPayments

public class EcommpayEsimPaymentProvider {
    
    //  MARK: - Dependencies
    
    private let paymentProvider: EcommpayPaymentProvider
    private let signatureProvider: EcommpayEsimSignatureProviderAdapter
    
    //  MARK: - Lifecycle
    
    public init(projectId: Int, merchantId: String, customerId: String, signatureProvider: EcommpayEsimSignatureProvider) {
        let adapter = EcommpayEsimSignatureProviderAdapter(wrapped: signatureProvider)
        self.signatureProvider = adapter
        self.paymentProvider = EcommpayPaymentProvider(projectId: projectId, merchantId: merchantId, customerId: customerId, signatureProvider: adapter)
    }
    
    public convenience init(projectId: Int, merchantId: String, customerId: String, apiClient: EsimApiClientProtocol) {
        let signatureProvider = EcommpayEsimSignatureProviderImpl(apiClient: apiClient)
        self.init(projectId: projectId, merchantId: merchantId, customerId: customerId, signatureProvider: signatureProvider)
    }
}

extension EcommpayEsimPaymentProvider: EsimPaymentProvider {
    public var identifier: String { return paymentProvider.identifier }
    
    public func pay(_ info: EsimPaymentInfo, from vc: UIViewController, completion: @escaping (Result<String, PaymentError>) -> ()) {
        signatureProvider.paymentInfo = info
        paymentProvider.pay(price: info.price, currency: info.currency, description: info.description, from: vc, completion: completion)
    }
}
