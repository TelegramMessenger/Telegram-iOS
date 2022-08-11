import Foundation

public struct SecondPhoneCountriesDTO: Decodable {
    public let countries: [SecondPhoneCountryDTO]
    
    public struct SecondPhoneCountryDTO: Decodable {
        
        public let name: String
        public let code: String
        public let prefix: Int
        
        enum CodingKeys: String, CodingKey {
            case name = "country"
            case code
            case prefix
        }
    }
}
