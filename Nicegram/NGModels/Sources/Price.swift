public struct Currency {
    public let isoCode: String
    
    public init(isoCode: String) {
        self.isoCode = isoCode
    }
}

public extension Currency {
    static var usd: Currency {
        return Currency(isoCode: "USD")
    }
    
    static var euro: Currency {
        return Currency(isoCode: "EUR")
    }
}

public struct Money {
    public let amount: Double
    public let currency: Currency
    
    public init(amount: Double, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }
}
