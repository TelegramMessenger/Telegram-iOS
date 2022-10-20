import EsimPayments

public struct EsimPaymentInfo {
    public let regionId: Int
    public let bundleId: Int
    public let state: State
    public let price: Double
    public let currency: PaymentCurrency
    public let description: String?
    
    public init(regionId: Int, bundleId: Int, state: EsimPaymentInfo.State, price: Double, currency: PaymentCurrency, description: String?) {
        self.regionId = regionId
        self.bundleId = bundleId
        self.state = state
        self.price = price
        self.currency = currency
        self.description = description
    }
    
    public enum State {
        case updateCurrent(icc: String)
        case new
    }
}

public extension EsimPaymentInfo {
    var icc: String? {
        if case .updateCurrent(let icc) = state {
            return icc
        } else {
            return nil
        }
    }
    
    var updateCurrentBundle: Bool {
        return (icc != nil)
    }
}
