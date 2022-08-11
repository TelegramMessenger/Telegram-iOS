public struct EsimOffer {
    public let id: Int
    public let title: String
    public let regionId: Int
    public let regionIsoCode: String
    public let traffic: Traffic
    public let duration: Duration
    public let price: Money
    public let includePhoneNumber: Bool
    
    public init(id: Int, title: String, regionId: Int, regionIsoCode: String, traffic: EsimOffer.Traffic, duration: EsimOffer.Duration, price: Money, includePhoneNumber: Bool) {
        self.id = id
        self.title = title
        self.regionId = regionId
        self.regionIsoCode = regionIsoCode
        self.traffic = traffic
        self.duration = duration
        self.price = price
        self.includePhoneNumber = includePhoneNumber
    }
    
    public enum Traffic {
        case megabytes(Int)
        case payAsYouGo
    }
    
    public enum Duration {
        case days(Int)
        case unlimited
    }
}
