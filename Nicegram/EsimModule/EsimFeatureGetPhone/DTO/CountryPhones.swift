import Foundation
import EsimDTO

public struct CountryPhonesDTO: Decodable {
    public let phones: [CountryPhoneDTO]
    
    public struct CountryPhoneDTO {
        
        public let phoneNumber: String
        public let numberType: NumberTypeDTO
        public let locality: String?
        public let isSmsEmabled: Bool
        public let isVoiceEnabled: Bool
        public let price: Double
    }
}

extension CountryPhonesDTO.CountryPhoneDTO: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case phoneNumber
        case numberType
        case locality
        case capabilities
        case price
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        numberType = try container.decode(NumberTypeDTO.self, forKey: .numberType)
        locality = try container.decodeIfPresent(String.self, forKey: .locality)
        
        let capabilities = (try? container.decode([String: Bool].self, forKey: .capabilities)) ?? [:]
        isSmsEmabled = capabilities["SMS"] ?? false
        isVoiceEnabled = capabilities["voice"] ?? false
        
        price = try container.decode(Double.self, forKey: .price)
    }
    
    
}
