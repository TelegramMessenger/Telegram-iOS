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
}

public struct PresentationThemeSettings: PreferencesEntry {
    public let chatWallpaper: TelegramWallpaper
    public let theme: PresentationThemeReference
    public let fontSize: PresentationFontSize
    
    public var relatedResources: [MediaResourceId] {
        switch self.chatWallpaper {
            case let .image(representations):
                return representations.map({ $0.resource.id })
            default:
                return []
        }
    }
    
    public static var defaultSettings: PresentationThemeSettings {
        return PresentationThemeSettings(chatWallpaper: .color(0x18222D), theme: .builtin(.nightAccent), fontSize: .regular)
    }
    
    public init(chatWallpaper: TelegramWallpaper, theme: PresentationThemeReference, fontSize: PresentationFontSize) {
        self.chatWallpaper = chatWallpaper
        self.theme = theme
        self.fontSize = fontSize
    }
    
    public init(decoder: PostboxDecoder) {
        self.chatWallpaper = (decoder.decodeObjectForKey("w", decoder: { TelegramWallpaper(decoder: $0) }) as? TelegramWallpaper) ?? .builtin
        self.theme = decoder.decodeObjectForKey("t", decoder: { PresentationThemeReference(decoder: $0) }) as! PresentationThemeReference
        self.fontSize = PresentationFontSize(rawValue: decoder.decodeInt32ForKey("f", orElse: PresentationFontSize.regular.rawValue)) ?? .regular
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.chatWallpaper, forKey: "w")
        encoder.encodeObject(self.theme, forKey: "t")
        encoder.encodeInt32(self.fontSize.rawValue, forKey: "f")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? PresentationThemeSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: PresentationThemeSettings, rhs: PresentationThemeSettings) -> Bool {
        return lhs.chatWallpaper == rhs.chatWallpaper && lhs.theme == rhs.theme && lhs.fontSize == rhs.fontSize
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
