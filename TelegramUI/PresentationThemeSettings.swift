import Foundation
import Postbox
import SwiftSignalKit

public enum PresentationBuilinThemeReference: Int32 {
    case light
    case dark
}

public enum PresentationThemeReference: Coding, Equatable {
    case builtin(PresentationBuilinThemeReference)
    
    public init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                self = .builtin(PresentationBuilinThemeReference(rawValue: decoder.decodeInt32ForKey("t", orElse: 0))!)
            default:
                //assertionFailure()
                self = .builtin(.light)
        }
    }
    
    public func encode(_ encoder: Encoder) {
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

public struct PresentationThemeSettings: PreferencesEntry {
    public let chatWallpaper: TelegramWallpaper
    public let theme: PresentationThemeReference
    
    public static var defaultSettings: PresentationThemeSettings {
        return PresentationThemeSettings(chatWallpaper: .builtin, theme: .builtin(.light))
    }
    
    init(chatWallpaper: TelegramWallpaper, theme: PresentationThemeReference) {
        self.chatWallpaper = chatWallpaper
        self.theme = theme
    }
    
    public init(decoder: Decoder) {
        self.chatWallpaper = (decoder.decodeObjectForKey("w", decoder: { TelegramWallpaper(decoder: $0) }) as? TelegramWallpaper) ?? .builtin
        self.theme = decoder.decodeObjectForKey("t", decoder: { PresentationThemeReference(decoder: $0) }) as! PresentationThemeReference
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeObject(self.chatWallpaper, forKey: "w")
        encoder.encodeObject(self.theme, forKey: "t")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? PresentationThemeSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: PresentationThemeSettings, rhs: PresentationThemeSettings) -> Bool {
        return lhs.chatWallpaper == rhs.chatWallpaper && lhs.theme == rhs.theme
    }
}

func updatePresentationThemeSettingsInteractively(postbox: Postbox, _ f: @escaping (PresentationThemeSettings) -> PresentationThemeSettings) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.presentationThemeSettings, { entry in
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
