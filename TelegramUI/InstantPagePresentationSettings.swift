import Foundation
import Postbox
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

public final class InstantPagePresentationSettings: PreferencesEntry, Equatable {
    public static var defaultSettings = InstantPagePresentationSettings(themeType: .light, fontSize: .standard, forceSerif: false, autoNightMode: true)
    
    public var themeType: InstantPageThemeType
    public var fontSize: InstantPagePresentationFontSize
    public var forceSerif: Bool
    public var autoNightMode: Bool
    
    public init(themeType: InstantPageThemeType, fontSize: InstantPagePresentationFontSize, forceSerif: Bool, autoNightMode: Bool) {
        self.themeType = themeType
        self.fontSize = fontSize
        self.forceSerif = forceSerif
        self.autoNightMode = autoNightMode
    }
    
    public init(decoder: PostboxDecoder) {
        self.themeType = InstantPageThemeType(rawValue: decoder.decodeInt32ForKey("themeType", orElse: 0))!
        self.fontSize = InstantPagePresentationFontSize(rawValue: decoder.decodeInt32ForKey("fontSize", orElse: 0))!
        self.forceSerif = decoder.decodeInt32ForKey("forceSerif", orElse: 0) != 0
        self.autoNightMode = decoder.decodeInt32ForKey("autoNightMode", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.themeType.rawValue, forKey: "themeType")
        encoder.encodeInt32(self.fontSize.rawValue, forKey: "fontSize")
        encoder.encodeInt32(self.forceSerif ? 1 : 0, forKey: "forceSerif")
        encoder.encodeInt32(self.autoNightMode ? 1 : 0, forKey: "autoNightMode")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? InstantPagePresentationSettings {
            return self == to
        } else {
            return false
        }
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
        return true
    }
    
    func withUpdatedThemeType(_ themeType: InstantPageThemeType) -> InstantPagePresentationSettings {
        return InstantPagePresentationSettings(themeType: themeType, fontSize: self.fontSize, forceSerif: self.forceSerif, autoNightMode: self.autoNightMode)
    }
    
    func withUpdatedFontSize(_ fontSize: InstantPagePresentationFontSize) -> InstantPagePresentationSettings {
        return InstantPagePresentationSettings(themeType: self.themeType, fontSize: fontSize, forceSerif: self.forceSerif, autoNightMode: self.autoNightMode)
    }
    
    func withUpdatedForceSerif(_ forceSerif: Bool) -> InstantPagePresentationSettings {
        return InstantPagePresentationSettings(themeType: self.themeType, fontSize: self.fontSize, forceSerif: forceSerif, autoNightMode: self.autoNightMode)
    }
    
    func withUpdatedAutoNightMode(_ autoNightMode: Bool) -> InstantPagePresentationSettings {
        return InstantPagePresentationSettings(themeType: self.themeType, fontSize: self.fontSize, forceSerif: self.forceSerif, autoNightMode: autoNightMode)
    }
}

func updateInstantPagePresentationSettingsInteractively(postbox: Postbox, _ f: @escaping (InstantPagePresentationSettings) -> InstantPagePresentationSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.instantPagePresentationSettings, { entry in
            let currentSettings: InstantPagePresentationSettings
            if let entry = entry as? InstantPagePresentationSettings {
                currentSettings = entry
            } else {
                currentSettings = InstantPagePresentationSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
