import Foundation
import Postbox

public struct SecureIdConfiguration: PostboxCoding {
    public let nativeLanguageByCountry: [String: String]
    
    public init(jsonString: String) {
        self.nativeLanguageByCountry = (try? JSONDecoder().decode(Dictionary<String, String>.self, from: jsonString.data(using: .utf8) ?? Data())) ?? [:]
    }
    
    public init(decoder: PostboxDecoder) {
        let nativeLanguageByCountryData = decoder.decodeBytesForKey("nativeLanguageByCountry")!
        self.nativeLanguageByCountry = (try? JSONDecoder().decode(Dictionary<String, String>.self, from: nativeLanguageByCountryData.dataNoCopy())) ?? [:]
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let nativeLanguageByCountryData = (try? JSONEncoder().encode(self.nativeLanguageByCountry)) ?? Data()
        encoder.encodeBytes(MemoryBuffer(data: nativeLanguageByCountryData), forKey: "nativeLanguageByCountry")
    }
}

public final class CachedSecureIdConfiguration: PostboxCoding {
    public let value: SecureIdConfiguration
    public let hash: Int32
    
    public init(value: SecureIdConfiguration, hash: Int32) {
        self.value = value
        self.hash = hash
    }
    
    public init(decoder: PostboxDecoder) {
        self.value = decoder.decodeObjectForKey("value", decoder: { SecureIdConfiguration(decoder: $0) }) as! SecureIdConfiguration
        self.hash = decoder.decodeInt32ForKey("hash", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.value, forKey: "value")
        encoder.encodeInt32(self.hash, forKey: "hash")
    }
}
