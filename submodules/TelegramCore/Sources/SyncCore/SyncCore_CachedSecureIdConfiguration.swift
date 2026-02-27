import Foundation
import Postbox

public struct SecureIdConfiguration: Codable {
    public let nativeLanguageByCountry: [String: String]
    
    public init(jsonString: String) {
        self.nativeLanguageByCountry = (try? JSONDecoder().decode(Dictionary<String, String>.self, from: jsonString.data(using: .utf8) ?? Data())) ?? [:]
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        let nativeLanguageByCountryData = try container.decode(Data.self, forKey: "nativeLanguageByCountry")
        self.nativeLanguageByCountry = (try? JSONDecoder().decode(Dictionary<String, String>.self, from: nativeLanguageByCountryData)) ?? [:]
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        let nativeLanguageByCountryData = (try? JSONEncoder().encode(self.nativeLanguageByCountry)) ?? Data()
        try container.encode(nativeLanguageByCountryData, forKey: "nativeLanguageByCountry")
    }
}

public final class CachedSecureIdConfiguration: Codable {
    public let value: SecureIdConfiguration
    public let hash: Int32
    
    public init(value: SecureIdConfiguration, hash: Int32) {
        self.value = value
        self.hash = hash
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.value = try container.decode(SecureIdConfiguration.self, forKey: "value")
        self.hash = try container.decode(Int32.self, forKey: "hash")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.value, forKey: "value")
        try container.encode(self.hash, forKey: "hash")
    }
}
