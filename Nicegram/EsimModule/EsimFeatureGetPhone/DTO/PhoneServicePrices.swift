public struct PhoneServicePricesDTO {
    public let inboundCallPrice: Double
    public let outboundCallPrice: Double
    public let inboundSmsPrice: Double
    public let outboundSmsPrice: Double
}

extension PhoneServicePricesDTO: Decodable {
    private struct CallPricesDTO: Decodable {
        let outboundCallPrice: Double
        let inboundCallPrice: Double
    }
    
    private struct SmsPricesDTO: Decodable {
        let inboundSmsPrice: Double
        let outboundSmsPrice: Double
    }
    
    enum CodingKeys: String, CodingKey {
        case phone
        case sms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let callPrices = try container.decode(CallPricesDTO.self, forKey: .phone)
        let smsPrices = try container.decode(SmsPricesDTO.self, forKey: .sms)
        
        inboundCallPrice = callPrices.inboundCallPrice
        outboundCallPrice = callPrices.outboundCallPrice
        inboundSmsPrice = smsPrices.inboundSmsPrice
        outboundSmsPrice = smsPrices.outboundSmsPrice
    }
}
