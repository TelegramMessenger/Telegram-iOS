import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

public enum PresentationBuiltinThemeReference: Int32 {
    case dayClassic = 0
    case night = 1
    case day = 2
    case nightAccent = 3
}

public struct WallpaperPresentationOptions: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let motion = WallpaperPresentationOptions(rawValue: 1 << 0)
    public static let blur = WallpaperPresentationOptions(rawValue: 1 << 1)
}

public struct PresentationLocalTheme: PostboxCoding, Equatable {
    public let title: String
    public let resource: LocalFileMediaResource
    public let resolvedWallpaper: TelegramWallpaper?
    
    public init(title: String, resource: LocalFileMediaResource, resolvedWallpaper: TelegramWallpaper?) {
        self.title = title
        self.resource = resource
        self.resolvedWallpaper = resolvedWallpaper
    }
    
    public init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey("title", orElse: "")
        self.resource = decoder.decodeObjectForKey("resource", decoder: { LocalFileMediaResource(decoder: $0) }) as! LocalFileMediaResource
        self.resolvedWallpaper = decoder.decodeObjectForKey("wallpaper", decoder: { TelegramWallpaper(decoder: $0) }) as? TelegramWallpaper
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: "title")
        encoder.encodeObject(self.resource, forKey: "resource")
        if let resolvedWallpaper = self.resolvedWallpaper {
            encoder.encodeObject(resolvedWallpaper, forKey: "wallpaper")
        } else {
            encoder.encodeNil(forKey: "wallpaper")
        }
    }
    
    public static func ==(lhs: PresentationLocalTheme, rhs: PresentationLocalTheme) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if !lhs.resource.isEqual(to: rhs.resource) {
            return false
        }
        if lhs.resolvedWallpaper != rhs.resolvedWallpaper {
            return false
        }
        return true
    }
}

public struct PresentationCloudTheme: PostboxCoding, Equatable {
    public let theme: TelegramTheme
    public let resolvedWallpaper: TelegramWallpaper?
    
    public init(theme: TelegramTheme, resolvedWallpaper: TelegramWallpaper?) {
        self.theme = theme
        self.resolvedWallpaper = resolvedWallpaper
    }
    
    public init(decoder: PostboxDecoder) {
        self.theme = decoder.decodeObjectForKey("theme", decoder: { TelegramTheme(decoder: $0) }) as! TelegramTheme
        self.resolvedWallpaper = decoder.decodeObjectForKey("wallpaper", decoder: { TelegramWallpaper(decoder: $0) }) as? TelegramWallpaper
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.theme, forKey: "theme")
        if let resolvedWallpaper = self.resolvedWallpaper {
            encoder.encodeObject(resolvedWallpaper, forKey: "wallpaper")
        } else {
            encoder.encodeNil(forKey: "wallpaper")
        }
    }
    
    public static func ==(lhs: PresentationCloudTheme, rhs: PresentationCloudTheme) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.resolvedWallpaper != rhs.resolvedWallpaper {
            return false
        }
        return true
    }
}

public enum PresentationThemeReference: PostboxCoding, Equatable {
    case builtin(PresentationBuiltinThemeReference)
    case local(PresentationLocalTheme)
    case cloud(PresentationCloudTheme)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                self = .builtin(PresentationBuiltinThemeReference(rawValue: decoder.decodeInt32ForKey("t", orElse: 0))!)
            case 1:
                if let localTheme = decoder.decodeObjectForKey("localTheme", decoder: { PresentationLocalTheme(decoder: $0) }) as? PresentationLocalTheme {
                    self = .local(localTheme)
                } else {
                    self = .builtin(.dayClassic)
                }
            case 2:
                if let cloudTheme = decoder.decodeObjectForKey("cloudTheme", decoder: { PresentationCloudTheme(decoder: $0) }) as? PresentationCloudTheme {
                    self = .cloud(cloudTheme)
                } else {
                    self = .builtin(.dayClassic)
                }
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
            case let .local(theme):
                encoder.encodeInt32(1, forKey: "v")
                encoder.encodeObject(theme, forKey: "localTheme")
            case let .cloud(theme):
                encoder.encodeInt32(2, forKey: "v")
                encoder.encodeObject(theme, forKey: "cloudTheme")
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
            case let .local(lhsTheme):
                if case let .local(rhsTheme) = rhs, lhsTheme == rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .cloud(lhsTheme):
                if case let .cloud(rhsTheme) = rhs, lhsTheme == rhsTheme {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public var index: Int64 {
        let namespace: Int32
        let id: Int32
        
        func themeId(for id: Int64) -> Int32 {
            var acc: UInt32 = 0
            let low = UInt32(UInt64(bitPattern: id) & (0xffffffff as UInt64))
            let high = UInt32((UInt64(bitPattern: id) >> 32) & (0xffffffff as UInt64))
            acc = (acc &* 20261) &+ high
            acc = (acc &* 20261) &+ low
            
            return Int32(bitPattern: acc & UInt32(0x7FFFFFFF))
        }
        
        switch self {
            case let .builtin(reference):
                namespace = 0
                id = reference.rawValue
            case let .local(theme):
                namespace = 1
                id = themeId(for: theme.resource.fileId)
            case let .cloud(theme):
                namespace = 2
                id = themeId(for: theme.theme.id)
        }
        
        return (Int64(namespace) << 32) | Int64(bitPattern: UInt64(UInt32(bitPattern: id)))
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
    case automatic(latitude: Double, longitude: Double, localizedName: String)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
                self = .manual(fromSeconds: decoder.decodeInt32ForKey("fromSeconds", orElse: 0), toSeconds: decoder.decodeInt32ForKey("toSeconds", orElse: 0))
            case 1:
                self = .automatic(latitude: decoder.decodeDoubleForKey("latitude", orElse: 0.0), longitude: decoder.decodeDoubleForKey("longitude", orElse: 0.0), localizedName: decoder.decodeStringForKey("localizedName", orElse: ""))
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
            case let .automatic(latitude, longitude, localizedName):
                encoder.encodeInt32(1, forKey: "_t")
                encoder.encodeDouble(latitude, forKey: "latitude")
                encoder.encodeDouble(longitude, forKey: "longitude")
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
    public var theme: PresentationThemeReference
    
    public init(trigger: AutomaticThemeSwitchTrigger, theme: PresentationThemeReference) {
        self.trigger = trigger
        self.theme = theme
    }
    
    public init(decoder: PostboxDecoder) {
        self.trigger = decoder.decodeObjectForKey("trigger", decoder: { AutomaticThemeSwitchTrigger(decoder: $0) }) as! AutomaticThemeSwitchTrigger
        if let theme = decoder.decodeObjectForKey("theme_v2", decoder: { PresentationThemeReference(decoder: $0) }) as? PresentationThemeReference {
            self.theme = theme
        } else if let legacyValue = decoder.decodeOptionalInt32ForKey("theme") {
            self.theme = .builtin(PresentationBuiltinThemeReference(rawValue: legacyValue) ?? .nightAccent)
        } else {
            self.theme = .builtin(.nightAccent)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.trigger, forKey: "trigger")
        encoder.encodeObject(self.theme, forKey: "theme_v2")
    }
}

public enum PresentationThemeBaseColor: Int32, CaseIterable {
    case blue
    case cyan
    case green
    case pink
    case orange
    case purple
    case red
    case yellow
    case gray
    case black
    case white
    case custom
    
    public var color: UIColor {
        let value: UInt32
        switch self {
            case .blue:
                value = 0x007aff
            case .cyan:
                value = 0x00c2ed
            case .green:
                value = 0x29b327
            case .pink:
                value = 0xeb6ca4
            case .orange:
                value = 0xf08200
            case .purple:
                value = 0x9472ee
            case .red:
                value = 0xd33213
            case .yellow:
                value = 0xedb400
            case .gray:
                value = 0x6d839e
            case .black:
                value = 0x000000
            case .white:
                value = 0xffffff
            case .custom:
                return .clear
        }
        return UIColor(rgb: value)
    }
    
    public var outgoingGradientColors: (UIColor, UIColor) {
        switch self {
            case .blue:
                return (UIColor(rgb: 0x63BFFB), UIColor(rgb: 0x007AFF))
            case .cyan:
                return (UIColor(rgb: 0x5CE0E9), UIColor(rgb: 0x00C2ED))
            case .green:
                return (UIColor(rgb: 0x93D374), UIColor(rgb: 0x29B327))
            case .pink:
                return (UIColor(rgb: 0xE296C1), UIColor(rgb: 0xEB6CA4))
            case .orange:
                return (UIColor(rgb: 0xF2A451), UIColor(rgb: 0xF08200))
            case .purple:
                return (UIColor(rgb: 0xAC98E6), UIColor(rgb: 0x9472EE))
            case .red:
                return (UIColor(rgb: 0xE06D54), UIColor(rgb: 0xD33213))
            case .yellow:
                return (UIColor(rgb: 0xF7DA6B), UIColor(rgb: 0xEDB400))
            case .gray:
                return (UIColor(rgb: 0x7D8E9A), UIColor(rgb: 0x6D839E))
            case .black:
                return (UIColor(rgb: 0x000000), UIColor(rgb: 0x000000))
            case .white:
                return (UIColor(rgb: 0xffffff), UIColor(rgb: 0xffffff))
            case .custom:
                return (UIColor(rgb: 0x000000), UIColor(rgb: 0x000000))
        }
    }
}

public struct PresentationThemeAccentColor: PostboxCoding, Equatable {
    public var baseColor: PresentationThemeBaseColor
    public var value: Int32?
    
    public init(baseColor: PresentationThemeBaseColor, value: Int32? = nil) {
        self.baseColor = baseColor
        self.value = value
    }
    
    public init(decoder: PostboxDecoder) {
        self.baseColor = PresentationThemeBaseColor(rawValue: decoder.decodeInt32ForKey("b", orElse: 0)) ?? .blue
        self.value = decoder.decodeOptionalInt32ForKey("c")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.baseColor.rawValue, forKey: "b")
        if let value = self.value {
            encoder.encodeInt32(value, forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
    }
    
    public var color: UIColor {
        if let value = self.value {
            return UIColor(rgb: UInt32(bitPattern: value))
        } else {
            return self.baseColor.color
        }
    }
}

public struct PresentationThemeSettings: PreferencesEntry {
    public var chatWallpaper: TelegramWallpaper
    public var theme: PresentationThemeReference
    public var themeSpecificAccentColors: [Int64: PresentationThemeAccentColor]
    public var themeSpecificChatWallpapers: [Int64: TelegramWallpaper]
    public var fontSize: PresentationFontSize
    public var automaticThemeSwitchSetting: AutomaticThemeSwitchSetting
    public var largeEmoji: Bool
    public var disableAnimations: Bool
    
    private func wallpaperResources(_ wallpaper: TelegramWallpaper) -> [MediaResourceId] {
        switch self.chatWallpaper {
            case let .image(representations, _):
                return representations.map { $0.resource.id }
            case let .file(_, _, _, _, _, _, _, file, _):
                var resources: [MediaResourceId] = []
                resources.append(file.resource.id)
                resources.append(contentsOf: file.previewRepresentations.map { $0.resource.id })
                return resources
            default:
                return []
        }
    }
    
    public var relatedResources: [MediaResourceId] {
        var resources: [MediaResourceId] = []
        resources.append(contentsOf: wallpaperResources(self.chatWallpaper))
        for (_, chatWallpaper) in self.themeSpecificChatWallpapers {
            resources.append(contentsOf: wallpaperResources(chatWallpaper))
        }
        switch self.theme {
            case .builtin:
                break
            case let .local(theme):
                resources.append(theme.resource.id)
            case let .cloud(theme):
                if let file = theme.theme.file {
                    resources.append(file.resource.id)
                }
                if let chatWallpaper = theme.resolvedWallpaper {
                    resources.append(contentsOf: wallpaperResources(chatWallpaper))
                }
        }
        return resources
    }
    
    public static var defaultSettings: PresentationThemeSettings {
        return PresentationThemeSettings(chatWallpaper: .builtin(WallpaperSettings()), theme: .builtin(.dayClassic), themeSpecificAccentColors: [:], themeSpecificChatWallpapers: [:], fontSize: .regular, automaticThemeSwitchSetting: AutomaticThemeSwitchSetting(trigger: .none, theme: .builtin(.nightAccent)), largeEmoji: true, disableAnimations: true)
    }
    
    public init(chatWallpaper: TelegramWallpaper, theme: PresentationThemeReference, themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], themeSpecificChatWallpapers: [Int64: TelegramWallpaper], fontSize: PresentationFontSize, automaticThemeSwitchSetting: AutomaticThemeSwitchSetting, largeEmoji: Bool, disableAnimations: Bool) {
        self.chatWallpaper = chatWallpaper
        self.theme = theme
        self.themeSpecificAccentColors = themeSpecificAccentColors
        self.themeSpecificChatWallpapers = themeSpecificChatWallpapers
        self.fontSize = fontSize
        self.automaticThemeSwitchSetting = automaticThemeSwitchSetting
        self.largeEmoji = largeEmoji
        self.disableAnimations = disableAnimations
    }
    
    public init(decoder: PostboxDecoder) {
        self.chatWallpaper = (decoder.decodeObjectForKey("w", decoder: { TelegramWallpaper(decoder: $0) }) as? TelegramWallpaper) ?? .builtin(WallpaperSettings())
        self.theme = decoder.decodeObjectForKey("t", decoder: { PresentationThemeReference(decoder: $0) }) as? PresentationThemeReference ?? .builtin(.dayClassic)

        self.themeSpecificChatWallpapers = decoder.decodeObjectDictionaryForKey("themeSpecificChatWallpapers", keyDecoder: { decoder in
            return decoder.decodeInt64ForKey("k", orElse: 0)
        }, valueDecoder: { decoder in
            return TelegramWallpaper(decoder: decoder)
        })
        
        self.themeSpecificAccentColors = decoder.decodeObjectDictionaryForKey("themeSpecificAccentColors", keyDecoder: { decoder in
            return decoder.decodeInt64ForKey("k", orElse: 0)
        }, valueDecoder: { decoder in
            return PresentationThemeAccentColor(decoder: decoder)
        })
        
        if self.themeSpecificAccentColors[PresentationThemeReference.builtin(.day).index] == nil, let themeAccentColor = decoder.decodeOptionalInt32ForKey("themeAccentColor") {
            let baseColor: PresentationThemeBaseColor
            switch themeAccentColor {
                case 0xf83b4c:
                    baseColor = .red
                case 0xff7519:
                    baseColor = .orange
                case 0xeba239:
                    baseColor = .yellow
                case 0x29b327:
                    baseColor = .green
                case 0x00c2ed:
                    baseColor = .cyan
                case 0x007ee5:
                    baseColor = .blue
                case 0x7748ff:
                    baseColor = .purple
                case 0xff5da2:
                    baseColor = .pink
                default:
                    baseColor = .blue
            }
            self.themeSpecificAccentColors[PresentationThemeReference.builtin(.day).index] = PresentationThemeAccentColor(baseColor: baseColor)
        }
        
        self.fontSize = PresentationFontSize(rawValue: decoder.decodeInt32ForKey("f", orElse: PresentationFontSize.regular.rawValue)) ?? .regular
        self.automaticThemeSwitchSetting = (decoder.decodeObjectForKey("automaticThemeSwitchSetting", decoder: { AutomaticThemeSwitchSetting(decoder: $0) }) as? AutomaticThemeSwitchSetting) ?? AutomaticThemeSwitchSetting(trigger: .none, theme: .builtin(.nightAccent))
        self.largeEmoji = decoder.decodeBoolForKey("largeEmoji", orElse: true)
        self.disableAnimations = decoder.decodeBoolForKey("disableAnimations", orElse: true)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.chatWallpaper, forKey: "w")
        encoder.encodeObject(self.theme, forKey: "t")
        encoder.encodeObjectDictionary(self.themeSpecificAccentColors, forKey: "themeSpecificAccentColors", keyEncoder: { key, encoder in
            encoder.encodeInt64(key, forKey: "k")
        })
        encoder.encodeObjectDictionary(self.themeSpecificChatWallpapers, forKey: "themeSpecificChatWallpapers", keyEncoder: { key, encoder in
            encoder.encodeInt64(key, forKey: "k")
        })
        encoder.encodeInt32(self.fontSize.rawValue, forKey: "f")
        encoder.encodeObject(self.automaticThemeSwitchSetting, forKey: "automaticThemeSwitchSetting")
        encoder.encodeBool(self.largeEmoji, forKey: "largeEmoji")
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
        return lhs.chatWallpaper == rhs.chatWallpaper && lhs.theme == rhs.theme && lhs.themeSpecificAccentColors == rhs.themeSpecificAccentColors && lhs.themeSpecificChatWallpapers == rhs.themeSpecificChatWallpapers && lhs.fontSize == rhs.fontSize && lhs.automaticThemeSwitchSetting == rhs.automaticThemeSwitchSetting && lhs.largeEmoji == rhs.largeEmoji && lhs.disableAnimations == rhs.disableAnimations
    }
}

public func updatePresentationThemeSettingsInteractively(accountManager: AccountManager, _ f: @escaping (PresentationThemeSettings) -> PresentationThemeSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings, { entry in
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
