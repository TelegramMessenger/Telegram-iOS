import Foundation

public struct EsimCountry {
    public let id: Int
    public let isoCode: String
    public let name: String
    public let regionIds: [Int]
    public let payAsYouGoRate: Money?
    
    public init(id: Int, isoCode: String, name: String, regionIds: [Int], payAsYouGoRate: Money?) {
        self.id = id
        self.isoCode = isoCode
        self.name = name
        self.regionIds = regionIds
        self.payAsYouGoRate = payAsYouGoRate
    }
}
