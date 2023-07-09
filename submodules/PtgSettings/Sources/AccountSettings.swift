import Foundation
import Postbox
import TelegramCore

extension ApplicationSpecificPreferencesKeys {
    public static let ptgAccountSettings = applicationSpecificPreferencesKey(100)
}

public struct PtgAccountSettings: Codable, Equatable {
    public let ignoreAllContentRestrictions: Bool
    
    public static var `default`: PtgAccountSettings {
        return PtgAccountSettings(ignoreAllContentRestrictions: false)
    }
    
    public init(ignoreAllContentRestrictions: Bool) {
        self.ignoreAllContentRestrictions = ignoreAllContentRestrictions
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.ignoreAllContentRestrictions = (try container.decodeIfPresent(Int32.self, forKey: "iacr") ?? 0) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode((self.ignoreAllContentRestrictions ? 1 : 0) as Int32, forKey: "iacr")
    }
    
    public init(_ entry: PreferencesEntry?) {
        self = entry?.get(PtgAccountSettings.self) ?? .default
    }
}
