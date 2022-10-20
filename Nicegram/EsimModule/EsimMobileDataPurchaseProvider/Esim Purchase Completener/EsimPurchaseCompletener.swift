public protocol EsimPurchaseCompletener {
    func completePurchase(icc: String?, regionId: Int, bundleId: Int, paymentId: String, paymentType: PaymentType, completion: @escaping (Result<EsimPurchaseResponse, Error>) -> ())
}
