public protocol EsimPurchaseUnlocker {
    func unlock(paymentId: String?, completion: ((Result<(), Error>) -> ())?)
}
