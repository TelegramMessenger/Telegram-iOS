import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum PresentationBuiltinThemeReference: Int32 {
    case dayClassic = 0
    case nightGrayscale = 1
    case day = 2
    case nightAccent = 3
}

public enum PresentationThemeReference: PostboxCoding, Equatable {
    case builtin(PresentationBuiltinThemeReference)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                self = .builtin(PresentationBuiltinThemeReference(rawValue: decoder.decodeInt32ForKey("t", orElse: 0))!)
            default:
                assertionFailure()
                self = .builtin(.dayClassic)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .builtin(reference):
                encoder.encodeInt32(0, forKey: "v")
                encoder.encodeInt32(reference.rawValue, forKey: "t")
        }
    }
    
    public static func ==(lhs: PresentationThemeReference, rhs: PresentationThemeReference) -> Bool {
        switch lhs {
            case let .builtin(reference):
                if case .builtin(reference) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum PresentationFontSize: Int32 {
    case extraSmall = 0
    case small = 1
    case regular = 2
    case large = 3
    case extraLarge = 4
    case extraLargeX2 = 5
    case medium = 6
}

public enum AutomaticThemeSwitchTimeBasedSetting: PostboxCoding, Equatable {
    case manual(fromSeconds: Int32, toSeconds: Int32)
    case automatic(latitude: Double, longitude: Double, sunset: Int32, sunrise: Int32, localizedName: String)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
                self = .manual(fromSeconds: decoder.decodeInt32ForKey("fromSeconds", orElse: 0), toSeconds: decoder.decodeInt32ForKey("toSeconds", orElse: 0))
            case 1:
                self = .automatic(latitude: decoder.decodeDoubleForKey("latitude", orElse: 0.0), longitude: decoder.decodeDoubleForKey("longitude", orElse: 0.0), sunset: decoder.decodeInt32ForKey("sunset", orElse: 0), sunrise: decoder.decodeInt32ForKey("sunrise", orElse: 0), localizedName: decoder.decodeStringForKey("localizedName", orElse: ""))
            default:
                assertionFailure()
                self = .manual(fromSeconds: 0, toSeconds: 1)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .manual(fromSeconds, toSeconds):
                encoder.encodeInt32(0, forKey: "_t")
                encoder.encodeInt32(fromSeconds, forKey: "fromSeconds")
                encoder.encodeInt32(toSeconds, forKey: "toSeconds")
        case let .automatic(latitude, longitude, sunset, sunrise, localizedName):
                encoder.encodeInt32(1, forKey: "_t")
                encoder.encodeDouble(latitude, forKey: "latitude")
                encoder.encodeDouble(longitude, forKey: "longitude")
                encoder.encodeInt32(sunset, forKey: "sunset")
                encoder.encodeInt32(sunrise, forKey: "sunrise")
                encoder.encodeString(localizedName, forKey: "localizedName")
        }
    }
}

public enum AutomaticThemeSwitchTrigger: PostboxCoding, Equatable {
    case none
    case timeBased(setting: AutomaticThemeSwitchTimeBasedSetting)
    case brightness(threshold: Double)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
                self = .none
            case 1:
                self = .timeBased(setting: decoder.decodeObjectForKey("setting", decoder: { AutomaticThemeSwitchTimeBasedSetting(decoder: $0) }) as! AutomaticThemeSwitchTimeBasedSetting)
            case 2:
                self = .brightness(threshold: decoder.decodeDoubleForKey("threshold", orElse: 0.2))
            default:
                assertionFailure()
                self = .none
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .none:
                encoder.encodeInt32(0, forKey: "_t")
            case let .timeBased(setting):
                encoder.encodeInt32(1, forKey: "_t")
                encoder.encodeObject(setting, forKey: "setting")
            case let .brightness(threshold):
                encoder.encodeInt32(2, forKey: "_t")
                encoder.encodeDouble(threshold, forKey: "threshold")
        }
    }
}

public struct AutomaticThemeSwitchSetting: PostboxCoding, Equatable {
    public var trigger: AutomaticThemeSwitchTrigger
    public var theme: PresentationBuiltinThemeReference
    
    public init(trigger: AutomaticThemeSwitchTrigger, theme: PresentationBuiltinThemeReference) {
        self.trigger = trigger
        self.theme = theme
    }
    
    public init(decoder: PostboxDecoder) {
        self.trigger = decoder.decodeObjectForKey("trigger", decoder: { AutomaticThemeSwitchTrigger(decoder: $0) }) as! AutomaticThemeSwitchTrigger
        self.theme = PresentationBuiltinThemeReference(rawValue: decoder.decodeInt32ForKey("theme", orElse: 0))!
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.trigger, forKey: "trigger")
        encoder.encodeInt32(self.theme.rawValue, forKey: "theme")
    }
}

public struct PresentationThemeSettings: PreferencesEntry {
    public var chatWallpaper: TelegramWallpaper
    public var theme: PresentationThemeReference
    public var themeAccentColor: Int32?
    public var fontSize: PresentationFontSize
    public var automaticThemeSwitchSetting: AutomaticThemeSwitchSetting
    public var disableAnimations: Bool
    
    public var relatedResources: [MediaResourceId] {
        switch self.chatWallpaper {
            case let .image(representations):
                return representations.map({ $0.resource.id })
            default:
                return []
        }
    }
    
    public static var defaultSettings: PresentationThemeSettings {
        return PresentationThemeSettings(chatWallpaper: .builtin, theme: .builtin(.dayClassic), themeAccentColor: nil, fontSize: .regular, automaticThemeSwitchSetting: AutomaticThemeSwitchSetting(trigger: .none, theme: .nightAccent), disableAnimations: true)
    }
    
    public init(chatWallpaper: TelegramWallpaper, theme: PresentationThemeReference, themeAccentColor: Int32?, fontSize: PresentationFontSize, automaticThemeSwitchSetting: AutomaticThemeSwitchSetting, disableAnimations: Bool) {
        self.chatWallpaper = chatWallpaper
        self.theme = theme
        self.themeAccentColor = themeAccentColor
        self.fontSize = fontSize
        self.automaticThemeSwitchSetting = automaticThemeSwitchSetting
        self.disableAnimations = disableAnimations
    }
    
    public init(decoder: PostboxDecoder) {
        self.chatWallpaper = (decoder.decodeObjectForKey("w", decoder: { TelegramWallpaper(decoder: $0) }) as? TelegramWallpaper) ?? .builtin
        self.theme = decoder.decodeObjectForKey("t", decoder: { PresentationThemeReference(decoder: $0) }) as! PresentationThemeReference
        self.themeAccentColor = decoder.decodeOptionalInt32ForKey("themeAccentColor")
        self.fontSize = PresentationFontSize(rawValue: decoder.decodeInt32ForKey("f", orElse: PresentationFontSize.regular.rawValue)) ?? .regular
        self.automaticThemeSwitchSetting = (decoder.decodeObjectForKey("automaticThemeSwitchSetting", decoder: { AutomaticThemeSwitchSetting(decoder: $0) }) as? AutomaticThemeSwitchSetting) ?? AutomaticThemeSwitchSetting(trigger: .none, theme: .nightAccent)
        self.disableAnimations = decoder.decodeBoolForKey("disableAnimations", orElse: true)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.chatWallpaper, forKey: "w")
        encoder.encodeObject(self.theme, forKey: "t")
        if let themeAccentColor = self.themeAccentColor {
            encoder.encodeInt32(themeAccentColor, forKey: "themeAccentColor")
        } else {
            encoder.encodeNil(forKey: "themeAccentColor")
        }
        encoder.encodeInt32(self.fontSize.rawValue, forKey: "f")
        encoder.encodeObject(self.automaticThemeSwitchSetting, forKey: "automaticThemeSwitchSetting")
        encoder.encodeBool(self.disableAnimations, forKey: "disableAnimations")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? PresentationThemeSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: PresentationThemeSettings, rhs: PresentationThemeSettings) -> Bool {
        return lhs.chatWallpaper == rhs.chatWallpaper && lhs.theme == rhs.theme && lhs.themeAccentColor == rhs.themeAccentColor && lhs.fontSize == rhs.fontSize && lhs.automaticThemeSwitchSetting == rhs.automaticThemeSwitchSetting && lhs.disableAnimations == rhs.disableAnimations
    }
}

public func updatePresentationThemeSettingsInteractively(postbox: Postbox, _ f: @escaping (PresentationThemeSettings) -> PresentationThemeSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.presentationThemeSettings, { entry in
            let currentSettings: PresentationThemeSettings
            if let entry = entry as? PresentationThemeSettings {
                currentSettings = entry
            } else {
                currentSettings = PresentationThemeSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
