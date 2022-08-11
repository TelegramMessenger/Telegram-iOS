import Foundation
import EsimApiClientDefinition
import EsimDTO

public struct SecondPhoneUserInfoResponseDTO: Decodable {
    
    public let phones: [UserPhoneDTO]
    public let user: UserDTO
    public let notificationsCount: Int
    
    public struct UserPhoneDTO: Decodable {
        
        public let phone: String
        public let countryCode: String
        public let numberType: NumberTypeDTO
        @EsimApiBool public var smsEnabled: Bool
        @EsimApiBool public var voiceEnabled: Bool
        public let notificationsCount: Int
        @EsimApiDate public var expiredAt: Date
        @EsimApiBool public var isExpired: Bool
        @EsimApiBool public var autorenewEnabled: Bool
        public let price: Double
        
        enum CodingKeys: String, CodingKey {
            case phone
            case countryCode
            case numberType
            case smsEnabled = "sms"
            case voiceEnabled = "voice"
            case notificationsCount = "unread"
            case expiredAt
            case isExpired
            case autorenewEnabled = "autorenew"
            case price
        }
    }
    
    public struct UserDTO: Decodable {
        public let balance: Double
    }
    
    enum CodingKeys: String, CodingKey {
        case phones
        case user
        case notificationsCount = "unread"
    }
}
