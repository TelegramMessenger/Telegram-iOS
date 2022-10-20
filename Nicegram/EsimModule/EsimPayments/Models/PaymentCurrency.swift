public struct PaymentCurrency {
    public let isoCode: String
    
    public init(isoCode: String) {
        self.isoCode = isoCode
    }
}

public extension PaymentCurrency {
    static var usd: PaymentCurrency {
        return PaymentCurrency(isoCode: "USD")
    }
    
    static var euro: PaymentCurrency {
        return PaymentCurrency(isoCode: "EUR")
    }
}
