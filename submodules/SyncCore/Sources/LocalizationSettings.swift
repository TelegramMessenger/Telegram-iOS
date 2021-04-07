import Foundation
import Postbox


public final class LocalizationComponent: Equatable, PostboxCoding {
    public let languageCode: String
    public let localizedName: String
    public let localization: Localization
    public let customPluralizationCode: String?
    
    public init(languageCode: String, localizedName: String, localization: Localization, customPluralizationCode: String?) {
        self.languageCode = languageCode
        self.localizedName = localizedName
        self.localization = localization
        self.customPluralizationCode = customPluralizationCode
    }
    
    public init(decoder: PostboxDecoder) {
        self.languageCode = decoder.decodeStringForKey("lc", orElse: "")
        self.localizedName = decoder.decodeStringForKey("localizedName", orElse: "")
        self.localization = decoder.decodeObjectForKey("loc", decoder: { Localization(decoder: $0) }) as! Localization
        self.customPluralizationCode = decoder.decodeOptionalStringForKey("cpl")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.languageCode, forKey: "lc")
        encoder.encodeString(self.localizedName, forKey: "localizedName")
        encoder.encodeObject(self.localization, forKey: "loc")
        if let customPluralizationCode = self.customPluralizationCode {
            encoder.encodeString(customPluralizationCode, forKey: "cpl")
        } else {
            encoder.encodeNil(forKey: "cpl")
        }
    }
    
    public static func ==(lhs: LocalizationComponent, rhs: LocalizationComponent) -> Bool {
        if lhs.languageCode != rhs.languageCode {
            return false
        }
        if lhs.localizedName != rhs.localizedName {
            return false
        }
        if lhs.localization != rhs.localization {
            return false
        }
        if lhs.customPluralizationCode != rhs.customPluralizationCode {
            return false
        }
        return true
    }
}

public final class LocalizationSettings: PreferencesEntry, Equatable {
    public let primaryComponent: LocalizationComponent
    public let secondaryComponent: LocalizationComponent?
    
    public init(primaryComponent: LocalizationComponent, secondaryComponent: LocalizationComponent?) {
        self.primaryComponent = primaryComponent
        self.secondaryComponent = secondaryComponent
    }
    
    public init(decoder: PostboxDecoder) {
        if let languageCode = decoder.decodeOptionalStringForKey("lc") {
            self.primaryComponent = LocalizationComponent(languageCode: languageCode, localizedName: "", localization: decoder.decodeObjectForKey("loc", decoder: { Localization(decoder: $0) }) as! Localization, customPluralizationCode: nil)
            self.secondaryComponent = nil
        } else {
            self.primaryComponent = decoder.decodeObjectForKey("primaryComponent", decoder: { LocalizationComponent(decoder: $0) }) as! LocalizationComponent
            self.secondaryComponent = decoder.decodeObjectForKey("secondaryComponent", decoder: { LocalizationComponent(decoder: $0) }) as? LocalizationComponent
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.primaryComponent, forKey: "primaryComponent")
        if let secondaryComponent = self.secondaryComponent {
            encoder.encodeObject(secondaryComponent, forKey: "secondaryComponent")
        } else {
            encoder.encodeNil(forKey: "secondaryComponent")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? LocalizationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: LocalizationSettings, rhs: LocalizationSettings) -> Bool {
        return lhs.primaryComponent == rhs.primaryComponent && lhs.secondaryComponent == rhs.secondaryComponent
    }
}
