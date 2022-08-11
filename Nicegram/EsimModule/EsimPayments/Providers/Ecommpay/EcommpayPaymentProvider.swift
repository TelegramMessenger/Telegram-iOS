import ecommpaySDK

public final class EcommpayPaymentProvider {
    
    //  MARK: - Private Properties
    
    private let ecommpaySDK = EcommpaySDK()
    private let projectId: Int
    private let merchantId: String
    private let customerId: String?
    
    //  MARK: - Dependencies
    
    private let signatureProvider: EcommpaySignatureProvider
    
    //  MARK: - Lifecycle
    
    public init(projectId: Int, merchantId: String, customerId: String?, signatureProvider: EcommpaySignatureProvider) {
        self.projectId = projectId
        self.merchantId = merchantId
        self.customerId = customerId
        self.signatureProvider = signatureProvider
    }
    
    //  MARK: - Private Functions
    
    private func generatePaymentId() -> String {
        return UUID().uuidString
    }

    private func makePaymentInfo(price: Double, currency: PaymentCurrency, description: String?) -> PaymentInfo {
        let paymentId = generatePaymentId()
        let paymentAmount = Int((price * 100).rounded())
        let paymentCurrency = currency.isoCode
        
        let paymentInfo: PaymentInfo = .init(projectID: projectId, paymentID: paymentId, paymentAmount: paymentAmount, paymentCurrency: paymentCurrency, paymentDescription: description, customerID: customerId, regionCode: Locale.current.regionCode)
        
        // Apple Pay
        paymentInfo.setApplePayMerchantID(merchantID: merchantId)
        paymentInfo.applePayDescription = description
        
        return paymentInfo
    }
}

extension EcommpayPaymentProvider: PaymentProvider {
    public var identifier: String { return "ecommpay" }
    
    public func pay(price: Double, currency: PaymentCurrency, description: String?, from vc: UIViewController, completion: @escaping (Result<String, PaymentError>) -> ()) {
        let paymentInfo = makePaymentInfo(price: price, currency: currency, description: description)
        let signatureParams = paymentInfo.getParamsForSignature()
        
        let errorMeta = PaymentError.Meta(paymentId: paymentInfo.paymentID)
        
        signatureProvider.getSignature(params: signatureParams) { result in
            switch result {
            case .success(let signature):
                paymentInfo.setSignature(value: signature)
                self.ecommpaySDK.presentPayment(at: vc, paymentInfo: paymentInfo) { result in
                    if let error = result.error {
                        completion(.failure(.underlying(error: error, meta: errorMeta)))
                        return
                    }
                    
                    switch result.status {
                    case .Cancelled:
                        completion(.failure(.cancelled(meta: errorMeta)))
                    case .Decline:
                        completion(.failure(.decline(meta: errorMeta)))
                    case .Error, .Unknown:
                        completion(.failure(.unknown(meta: errorMeta)))
                    case .Success:
                        guard let paymentId = paymentInfo.paymentID else {
                            completion(.failure(.unknown(meta: errorMeta)))
                            return
                        }
                        completion(.success(paymentId))
                    @unknown default:
                        completion(.failure(.unknown(meta: errorMeta)))
                    }
                }
            case .failure(let error):
                completion(.failure(.underlying(error: error, meta: errorMeta)))
            }
        }
    }
}

