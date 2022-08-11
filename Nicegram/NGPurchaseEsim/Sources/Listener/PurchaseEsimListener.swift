import NGModels

public protocol PurchaseEsimListener: AnyObject {
    func didPurchase(esim: UserEsim)
    func didTopUp(esim: UserEsim)
}
