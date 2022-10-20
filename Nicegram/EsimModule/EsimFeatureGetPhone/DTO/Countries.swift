import Foundation

public struct SecondPhoneCountriesDTO: Decodable {
    public let countries: [PhonesGroupDTO]
}

public struct SecondPhoneCountryDTO {
    public let name: String
    public let code: String
    public let prefix: Int
}

public struct CustomPhonesGroupDTO {
    public let name: String
    public let code: String
    public let imageUrl: URL?
}

public enum PhonesGroupDTO: Decodable {
    case country(SecondPhoneCountryDTO)
    case custom(CustomPhonesGroupDTO)
    
    enum CodingKeys: String, CodingKey {
        case name = "country"
        case code
        case prefix
        case icon
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let name = try container.decode(String.self, forKey: .name)
        let code = try container.decode(String.self, forKey: .code)
        let prefix = try container.decodeIfPresent(Int.self, forKey: .prefix)
        let icon = try container.decodeIfPresent(URL.self, forKey: .icon)
        
        if let prefix = prefix {
            let country = SecondPhoneCountryDTO(name: name, code: code, prefix: prefix)
            self = .country(country)
        } else {
            let group = CustomPhonesGroupDTO(name: name, code: code, imageUrl: icon)
            self = .custom(group)
        }
    }
}


