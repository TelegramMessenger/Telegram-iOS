import EsimPayments

class EcommpayEsimSignatureProviderAdapter {
    
    //  MARK: - Public Properties
    
    var paymentInfo: EsimPaymentInfo?
    
    //  MARK: - Dependencies

    let wrapped: EcommpayEsimSignatureProvider
    
    //  MARK: - Lifecycle
    
    init(wrapped: EcommpayEsimSignatureProvider) {
        self.wrapped = wrapped
    }
}

extension EcommpayEsimSignatureProviderAdapter: EcommpaySignatureProvider {
    func getSignature(params: String, completion: @escaping (Result<String, Error>) -> ()) {
        guard let paymentInfo = paymentInfo else {
            completion(.failure(PaymentError.unknown(meta: nil)))
            return
        }
        
        wrapped.getSignature(signatureParams: params, regionId: paymentInfo.regionId, bundleId: paymentInfo.bundleId, icc: paymentInfo.icc, completion: completion)
    }
}
