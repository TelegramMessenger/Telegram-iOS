import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum InstantPageThemeType: Int32 {
    case light = 0
    case dark = 1
    case sepia = 2
    case gray = 3
}

public enum InstantPagePresentationFontSize: Int32 {
    case small = 0
    case standard = 1
    case large = 2
    case xlarge = 3
    case xxlarge = 4
}

public final class InstantPagePresentationSettings: Codable, Equatable {
    public static var defaultSettings = InstantPagePresentationSettings(themeType: .light, fontSize: .standard, forceSerif: false, autoNightMode: true, ignoreAutoNightModeUntil: 0)
    
    public var themeType: InstantPageThemeType
    public var fontSize: InstantPagePresentationFontSize
    public var forceSerif: Bool
    public var autoNightMode: Bool
    public var ignoreAutoNightModeUntil: Int32
    
    public init(themeType: InstantPageThemeType, fontSize: InstantPagePresentationFontSize, forceSerif: Bool, autoNightMode: Bool, ignoreAutoNightModeUntil: Int32) {
        self.themeType = themeType
        self.fontSize = fontSize
        self.forceSerif = forceSerif
        self.autoNightMode = autoNightMode
        self.ignoreAutoNightModeUntil = ignoreAutoNightModeUntil
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.themeType = InstantPageThemeType(rawValue: try container.decode(Int32.self, forKey: "themeType"))!
        self.fontSize = InstantPagePresentationFontSize(rawValue: try container.decode(Int32.self, forKey: "fontSize"))!
        self.forceSerif = try container.decode(Int32.self, forKey: "forceSerif") != 0
        self.autoNightMode = try container.decode(Int32.self, forKey: "autoNightMode") != 0
        self.ignoreAutoNightModeUntil = try container.decode(Int32.self, forKey: "ignoreAutoNightModeUntil")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.themeType.rawValue, forKey: "themeType")
        try container.encode(self.fontSize.rawValue, forKey: "fontSize")
        try container.encode((self.forceSerif ? 1 : 0) as Int32, forKey: "forceSerif")
        try container.encode((self.autoNightMode ? 1 : 0) as Int32, forKey: "autoNightMode")
        try container.encode(self.ignoreAutoNightModeUntil, forKey: "ignoreAutoNightModeUntil")
    }
    
    public static func ==(lhs: InstantPagePresentationSettings, rhs: InstantPagePresentationSettings) -> Bool {
        if lhs.themeType != rhs.themeType {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.forceSerif != rhs.forceSerif {
            return false
        }
        if lhs.autoNightMode != rhs.autoNightMode {
            return false
        }
        if lhs.ignoreAutoNightModeUntil != rhs.ignoreAutoNightModeUntil {
            return false
        }
        return true
    }
    
    public func withUpdatedThemeType(_ themeType: InstantPageThemeType) -> InstantPagePresentationSettings {
        return InstantPagePresentationSettings(themeType: themeType, fontSize: self.fontSize, forceSerif: self.forceSerif, autoNightMode: self.autoNightMode, ignoreAutoNightModeUntil: self.ignoreAutoNightModeUntil)
    }
    
    public func withUpdatedFontSize(_ fontSize: InstantPagePresentationFontSize) -> InstantPagePresentationSettings {
        return InstantPagePresentationSettings(themeType: self.themeType, fontSize: fontSize, forceSerif: self.forceSerif, autoNightMode: self.autoNightMode, ignoreAutoNightModeUntil: self.ignoreAutoNightModeUntil)
    }
    
    public func withUpdatedForceSerif(_ forceSerif: Bool) -> InstantPagePresentationSettings {
        return InstantPagePresentationSettings(themeType: self.themeType, fontSize: self.fontSize, forceSerif: forceSerif, autoNightMode: self.autoNightMode, ignoreAutoNightModeUntil: self.ignoreAutoNightModeUntil)
    }
    
    public func withUpdatedAutoNightMode(_ autoNightMode: Bool) -> InstantPagePresentationSettings {
        return InstantPagePresentationSettings(themeType: self.themeType, fontSize: self.fontSize, forceSerif: self.forceSerif, autoNightMode: autoNightMode, ignoreAutoNightModeUntil: self.ignoreAutoNightModeUntil)
    }
    
    public func withUpdatedIgnoreAutoNightModeUntil(_ ignoreAutoNightModeUntil: Int32) -> InstantPagePresentationSettings {
        return InstantPagePresentationSettings(themeType: self.themeType, fontSize: self.fontSize, forceSerif: self.forceSerif, autoNightMode: autoNightMode, ignoreAutoNightModeUntil: ignoreAutoNightModeUntil)
    }
}

public func updateInstantPagePresentationSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (InstantPagePresentationSettings) -> InstantPagePresentationSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.instantPagePresentationSettings, { entry in
            let currentSettings: InstantPagePresentationSettings
            if let entry = entry?.get(InstantPagePresentationSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = InstantPagePresentationSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
