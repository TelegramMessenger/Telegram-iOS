import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class LocalizationSettings: PreferencesEntry, Equatable {
    public let languageCode: String
    public let localization: Localization
    
    public init(languageCode: String, localization: Localization) {
        self.languageCode = languageCode
        self.localization = localization
    }
    
    public init(decoder: PostboxDecoder) {
        self.languageCode = decoder.decodeStringForKey("lc", orElse: "en")
        self.localization = decoder.decodeObjectForKey("loc", decoder: { Localization(decoder: $0) }) as! Localization
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.languageCode, forKey: "lc")
        encoder.encodeObject(self.localization, forKey: "loc")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? LocalizationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: LocalizationSettings, rhs: LocalizationSettings) -> Bool {
        return lhs.languageCode == rhs.languageCode && lhs.localization == rhs.localization
    }
}
