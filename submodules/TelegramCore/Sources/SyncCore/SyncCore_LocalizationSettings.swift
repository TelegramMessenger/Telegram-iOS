import Foundation
import Postbox

public final class LocalizationComponent: Equatable, Codable {
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.languageCode = (try? container.decode(String.self, forKey: "lc")) ?? ""
        self.localizedName = (try? container.decode(String.self, forKey: "localizedName")) ?? ""
        self.localization = try container.decode(Localization.self, forKey: "loc")
        self.customPluralizationCode = try container.decodeIfPresent(String.self, forKey: "cpl")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.languageCode, forKey: "lc")
        try container.encode(self.localizedName, forKey: "localizedName")
        try container.encode(self.localization, forKey: "loc")
        try container.encodeIfPresent(self.customPluralizationCode, forKey: "cpl")
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

public final class LocalizationSettings: Codable, Equatable {
    public let primaryComponent: LocalizationComponent
    public let secondaryComponent: LocalizationComponent?
    
    public init(primaryComponent: LocalizationComponent, secondaryComponent: LocalizationComponent?) {
        self.primaryComponent = primaryComponent
        self.secondaryComponent = secondaryComponent
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let languageCode = try container.decodeIfPresent(String.self, forKey: "lc") {
            self.primaryComponent = LocalizationComponent(
                languageCode: languageCode,
                localizedName: "",
                localization: try container.decode(Localization.self, forKey: "loc"),
                customPluralizationCode: nil
            )
            self.secondaryComponent = nil
        } else {
            self.primaryComponent = try container.decode(LocalizationComponent.self, forKey: "primaryComponent")
            self.secondaryComponent = try container.decodeIfPresent(LocalizationComponent.self, forKey: "secondaryComponent")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.primaryComponent, forKey: "primaryComponent")
        try container.encodeIfPresent(self.secondaryComponent, forKey: "secondaryComponent")
    }
    
    public static func ==(lhs: LocalizationSettings, rhs: LocalizationSettings) -> Bool {
        return lhs.primaryComponent == rhs.primaryComponent && lhs.secondaryComponent == rhs.secondaryComponent
    }
}
