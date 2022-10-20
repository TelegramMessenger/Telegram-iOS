import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

public enum PresentationBuiltinThemeReference: Int32 {
    case dayClassic = 0
    case night = 1
    case day = 2
    case nightAccent = 3
    
    public init(baseTheme: TelegramBaseTheme) {
        switch baseTheme {
            case .classic:
                self = .dayClassic
            case .day:
                self = .day
            case .night:
                self = .night
            case .tinted:
                self = .nightAccent
        }
    }
    
    public var baseTheme: TelegramBaseTheme {
        switch self {
            case .dayClassic:
                return .classic
            case .day:
                return .day
            case .night:
                return .night
            case .nightAccent:
                return .tinted
        }
    }
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
        self.resolvedWallpaper = decoder.decode(TelegramWallpaperNativeCodable.self, forKey: "wallpaper")?.value
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: "title")
        encoder.encodeObject(self.resource, forKey: "resource")
        if let resolvedWallpaper = self.resolvedWallpaper {
            encoder.encode(TelegramWallpaperNativeCodable(resolvedWallpaper), forKey: "wallpaper")
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

public struct PresentationCloudTheme: Codable, Equatable {
    public let theme: TelegramTheme
    public let resolvedWallpaper: TelegramWallpaper?
    public let creatorAccountId: AccountRecordId?
    
    public init(theme: TelegramTheme, resolvedWallpaper: TelegramWallpaper?, creatorAccountId: AccountRecordId?) {
        self.theme = theme
        self.resolvedWallpaper = resolvedWallpaper
        self.creatorAccountId = creatorAccountId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.theme = (try container.decode(TelegramThemeNativeCodable.self, forKey: "theme")).value
        self.resolvedWallpaper = (try container.decodeIfPresent(TelegramWallpaperNativeCodable.self, forKey: "wallpaper"))?.value
        self.creatorAccountId = (try container.decodeIfPresent(Int64.self, forKey: "account")).flatMap(AccountRecordId.init(rawValue:))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(TelegramThemeNativeCodable(self.theme), forKey: "theme")
        try container.encodeIfPresent(self.resolvedWallpaper.flatMap(TelegramWallpaperNativeCodable.init), forKey: "wallpaper")
        try container.encodeIfPresent(self.creatorAccountId?.int64, forKey: "account")
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
                if let cloudTheme = decoder.decode(PresentationCloudTheme.self, forKey: "cloudTheme") {
                    self = .cloud(cloudTheme)
                } else {
                    self = .builtin(.dayClassic)
                }
            case 3:
                self = .builtin(.dayClassic)
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
                encoder.encode(theme, forKey: "cloudTheme")
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

            return Int32(bitPattern: acc & UInt32(0x7fffffff))
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
    
    public var generalThemeReference: PresentationThemeReference {
        let generalThemeReference: PresentationThemeReference
        if case let .cloud(theme) = self, let settings = theme.theme.settings?.first {
            generalThemeReference = .builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme))
        } else {
            generalThemeReference = self
        }
        return generalThemeReference
    }
    
    public var emoticon: String? {
        switch self {
            case .builtin(.dayClassic):
                return "🏠"
            case let .cloud(theme):
                return theme.theme.emoticon
            default:
                return nil
        }
    }
}

public func coloredThemeIndex(reference: PresentationThemeReference, accentColor: PresentationThemeAccentColor?) -> Int64 {
    if let accentColor = accentColor {
        if case .builtin = reference {
            return reference.index * 1000 &+ Int64(accentColor.index)
        } else {
            return reference.index &+ Int64(accentColor.index)
        }
    } else {
        return reference.index
    }
}

public enum PresentationFontSize: Int32, CaseIterable {
    case extraSmall = 0
    case small = 1
    case regular = 2
    case large = 3
    case extraLarge = 4
    case extraLargeX2 = 5
    case medium = 6
}

public enum AutomaticThemeSwitchTimeBasedSetting: Codable, Equatable {
    case manual(fromSeconds: Int32, toSeconds: Int32)
    case automatic(latitude: Double, longitude: Double, localizedName: String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        switch try container.decode(Int32.self, forKey: "_t") {
            case 0:
                self = .manual(fromSeconds: try container.decode(Int32.self, forKey: "fromSeconds"), toSeconds: try container.decode(Int32.self, forKey: "toSeconds"))
            case 1:
                self = .automatic(latitude: try container.decode(Double.self, forKey: "latitude"), longitude: try container.decode(Double.self, forKey: "longitude"), localizedName: try container.decode(String.self, forKey: "localizedName"))
            default:
                assertionFailure()
                self = .manual(fromSeconds: 0, toSeconds: 1)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self {
            case let .manual(fromSeconds, toSeconds):
                try container.encode(0 as Int32, forKey: "_t")
                try container.encode(fromSeconds, forKey: "fromSeconds")
                try container.encode(toSeconds, forKey: "toSeconds")
            case let .automatic(latitude, longitude, localizedName):
                try container.encode(1 as Int32, forKey: "_t")
                try container.encode(latitude, forKey: "latitude")
                try container.encode(longitude, forKey: "longitude")
                try container.encode(localizedName, forKey: "localizedName")
        }
    }
}

public enum AutomaticThemeSwitchTrigger: Codable, Equatable {
    case system
    case explicitNone
    case timeBased(setting: AutomaticThemeSwitchTimeBasedSetting)
    case brightness(threshold: Double)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        switch try container.decode(Int32.self, forKey: "_t") {
            case 0:
                self = .system
            case 1:
                self = .timeBased(setting: try container.decode(AutomaticThemeSwitchTimeBasedSetting.self, forKey: "setting"))
            case 2:
                self = .brightness(threshold: try container.decode(Double.self, forKey: "threshold"))
            case 3:
                self = .explicitNone
            default:
                assertionFailure()
                self = .system
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self {
            case .system:
                try container.encode(0 as Int32, forKey: "_t")
            case let .timeBased(setting):
                try container.encode(1 as Int32, forKey: "_t")
                try container.encode(setting, forKey: "setting")
            case let .brightness(threshold):
                try container.encode(2 as Int32, forKey: "_t")
                try container.encode(threshold, forKey: "threshold")
            case .explicitNone:
                try container.encode(3 as Int32, forKey: "_t")
        }
    }
}

public struct AutomaticThemeSwitchSetting: Codable, Equatable {
    public var force: Bool
    public var trigger: AutomaticThemeSwitchTrigger
    public var theme: PresentationThemeReference
    
    public init(force: Bool, trigger: AutomaticThemeSwitchTrigger, theme: PresentationThemeReference) {
        self.force = force
        self.trigger = trigger
        self.theme = theme
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.force = try container.decodeIfPresent(Bool.self, forKey: "force") ?? false
        self.trigger = try container.decode(AutomaticThemeSwitchTrigger.self, forKey: "trigger")
        if let themeData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: "theme_v2") {
            self.theme = PresentationThemeReference(decoder: PostboxDecoder(buffer: MemoryBuffer(data: themeData.data)))
        } else {
            self.theme = .builtin(.night)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.force, forKey: "force")
        try container.encode(self.trigger, forKey: "trigger")

        let themeData = PostboxEncoder().encodeObjectToRawData(self.theme)
        try container.encode(themeData, forKey: "theme_v2")
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
    case preset
    case theme
    
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
            case .custom, .preset, .theme:
                return .clear
        }
        return UIColor(rgb: value)
    }
}

public struct PresentationThemeAccentColor: PostboxCoding, Equatable {
    public static func == (lhs: PresentationThemeAccentColor, rhs: PresentationThemeAccentColor) -> Bool {
        return lhs.index == rhs.index && lhs.baseColor == rhs.baseColor && lhs.accentColor == rhs.accentColor && lhs.bubbleColors == rhs.bubbleColors
    }
    
    public var index: Int32
    public var baseColor: PresentationThemeBaseColor
    public var accentColor: UInt32?
    public var bubbleColors: [UInt32]
    public var wallpaper: TelegramWallpaper?
    public var themeIndex: Int64?
    
    public init(baseColor: PresentationThemeBaseColor) {
        if baseColor != .preset && baseColor != .custom {
            self.index = baseColor.rawValue + 10
        } else {
            self.index = -1
        }
        self.baseColor = baseColor
        self.accentColor = nil
        self.bubbleColors = []
        self.wallpaper = nil
    }
    
    public init(index: Int32, baseColor: PresentationThemeBaseColor, accentColor: UInt32? = nil, bubbleColors: [UInt32] = [], wallpaper: TelegramWallpaper? = nil) {
        self.index = index
        self.baseColor = baseColor
        self.accentColor = accentColor
        self.bubbleColors = bubbleColors
        self.wallpaper = wallpaper
    }
    
    public init(themeIndex: Int64) {
        self.index = -1
        self.baseColor = .theme
        self.accentColor = nil
        self.bubbleColors = []
        self.wallpaper = nil
        self.themeIndex = themeIndex
    }
    
    public init(decoder: PostboxDecoder) {
        self.index = decoder.decodeInt32ForKey("i", orElse: -1)
        self.baseColor = PresentationThemeBaseColor(rawValue: decoder.decodeInt32ForKey("b", orElse: 0)) ?? .blue
        self.accentColor = decoder.decodeOptionalInt32ForKey("c").flatMap { UInt32(bitPattern: $0) }

        let bubbleColors = decoder.decodeInt32ArrayForKey("bubbleColors")
        if !bubbleColors.isEmpty {
            self.bubbleColors = bubbleColors.map(UInt32.init(bitPattern:))
        } else {
            if let bubbleTopColor = decoder.decodeOptionalInt32ForKey("bt") {
                if let bubbleBottomColor = decoder.decodeOptionalInt32ForKey("bb") {
                    self.bubbleColors = [UInt32(bitPattern: bubbleTopColor), UInt32(bitPattern: bubbleBottomColor)]
                } else {
                    self.bubbleColors = [UInt32(bitPattern: bubbleTopColor)]
                }
            } else {
                self.bubbleColors = []
            }
        }

        self.wallpaper = decoder.decode(TelegramWallpaperNativeCodable.self, forKey: "w")?.value
        self.themeIndex = decoder.decodeOptionalInt64ForKey("t")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.index, forKey: "i")
        encoder.encodeInt32(self.baseColor.rawValue, forKey: "b")
        if let value = self.accentColor {
            encoder.encodeInt32(Int32(bitPattern: value), forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
        encoder.encodeInt32Array(self.bubbleColors.map(Int32.init(bitPattern:)), forKey: "bubbleColors")
        if let wallpaper = self.wallpaper {
            encoder.encode(TelegramWallpaperNativeCodable(wallpaper), forKey: "w")
        } else {
            encoder.encodeNil(forKey: "w")
        }
        if let themeIndex = self.themeIndex {
            encoder.encodeInt64(themeIndex, forKey: "t")
        } else {
            encoder.encodeNil(forKey: "t")
        }
    }
    
    public var color: UIColor {
        if let value = self.accentColor {
            return UIColor(rgb: UInt32(bitPattern: value))
        } else {
            return self.baseColor.color
        }
    }
    
    public func colorFor(baseTheme: TelegramBaseTheme) -> UIColor {
        if let value = self.accentColor {
            return UIColor(rgb: UInt32(bitPattern: value))
        } else {
            if baseTheme == .night && self.baseColor == .blue {
                return UIColor(rgb: 0x3e88f7)
            } else {
                return self.baseColor.color
            }
        }
    }
    
    public var customBubbleColors: [UInt32] {
        return self.bubbleColors
    }
    
    public var plainBubbleColors: [UInt32] {
        return self.bubbleColors
    }
    
    public func withUpdatedWallpaper(_ wallpaper: TelegramWallpaper?) -> PresentationThemeAccentColor {
        return PresentationThemeAccentColor(index: self.index, baseColor: self.baseColor, accentColor: self.accentColor, bubbleColors: self.bubbleColors, wallpaper: wallpaper)
    }
}

public struct PresentationChatBubbleSettings: Codable, Equatable {
    public var mainRadius: Int32
    public var auxiliaryRadius: Int32
    public var mergeBubbleCorners: Bool
    
    public static var `default`: PresentationChatBubbleSettings = PresentationChatBubbleSettings(mainRadius: 16, auxiliaryRadius: 8, mergeBubbleCorners: true)
    
    public init(mainRadius: Int32, auxiliaryRadius: Int32, mergeBubbleCorners: Bool) {
        self.mainRadius = mainRadius
        self.auxiliaryRadius = auxiliaryRadius
        self.mergeBubbleCorners = mergeBubbleCorners
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.mainRadius = try container.decodeIfPresent(Int32.self, forKey: "mainRadius") ?? 16
        self.auxiliaryRadius = try container.decodeIfPresent(Int32.self, forKey: "auxiliaryRadius") ?? 8
        self.mergeBubbleCorners = (try container.decodeIfPresent(Int32.self, forKey: "mergeBubbleCorners") ?? 1) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.mainRadius, forKey: "mainRadius")
        try container.encode(self.auxiliaryRadius, forKey: "auxiliaryRadius")
        try container.encode((self.mergeBubbleCorners ? 1 : 0) as Int32, forKey: "mergeBubbleCorners")
    }
}

public struct PresentationThemeSettings: Codable {
    private struct DictionaryKey: Codable, Hashable {
        var key: Int64

        init(_ key: Int64) {
            self.key = key
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)

            self.key = try container.decode(Int64.self, forKey: "k")
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)

            try container.encode(self.key, forKey: "k")
        }
    }

    public var theme: PresentationThemeReference
    public var themePreferredBaseTheme: [Int64: TelegramBaseTheme]
    public var themeSpecificAccentColors: [Int64: PresentationThemeAccentColor]
    public var themeSpecificChatWallpapers: [Int64: TelegramWallpaper]
    public var useSystemFont: Bool
    public var fontSize: PresentationFontSize
    public var listsFontSize: PresentationFontSize
    public var chatBubbleSettings: PresentationChatBubbleSettings
    public var automaticThemeSwitchSetting: AutomaticThemeSwitchSetting
    public var largeEmoji: Bool
    public var reduceMotion: Bool
    
    private func wallpaperResources(_ wallpaper: TelegramWallpaper) -> [MediaResourceId] {
        switch wallpaper {
            case let .image(representations, _):
                return representations.map { $0.resource.id }
            case let .file(file):
                var resources: [MediaResourceId] = []
                resources.append(file.file.resource.id)
                resources.append(contentsOf: file.file.previewRepresentations.map { $0.resource.id })
                return resources
            default:
                return []
        }
    }
    
    public var relatedResources: [MediaResourceId] {
        var resources: [MediaResourceId] = []
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
        return PresentationThemeSettings(theme: .builtin(.dayClassic), themePreferredBaseTheme: [:], themeSpecificAccentColors: [:], themeSpecificChatWallpapers: [:], useSystemFont: true, fontSize: .regular, listsFontSize: .regular, chatBubbleSettings: .default, automaticThemeSwitchSetting: AutomaticThemeSwitchSetting(force: false, trigger: .system, theme: .builtin(.night)), largeEmoji: true, reduceMotion: false)
    }
    
    public init(theme: PresentationThemeReference, themePreferredBaseTheme: [Int64: TelegramBaseTheme], themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], themeSpecificChatWallpapers: [Int64: TelegramWallpaper], useSystemFont: Bool, fontSize: PresentationFontSize, listsFontSize: PresentationFontSize, chatBubbleSettings: PresentationChatBubbleSettings, automaticThemeSwitchSetting: AutomaticThemeSwitchSetting, largeEmoji: Bool, reduceMotion: Bool) {
        self.theme = theme
        self.themePreferredBaseTheme = themePreferredBaseTheme
        self.themeSpecificAccentColors = themeSpecificAccentColors
        self.themeSpecificChatWallpapers = themeSpecificChatWallpapers
        self.useSystemFont = useSystemFont
        self.fontSize = fontSize
        self.listsFontSize = listsFontSize
        self.chatBubbleSettings = chatBubbleSettings
        self.automaticThemeSwitchSetting = automaticThemeSwitchSetting
        self.largeEmoji = largeEmoji
        self.reduceMotion = reduceMotion
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let themeData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: "t") {
            self.theme = PresentationThemeReference(decoder: PostboxDecoder(buffer: MemoryBuffer(data: themeData.data)))
        } else {
            self.theme = .builtin(.dayClassic)
        }
        
        var mappedThemePreferredBaseTheme: [Int64: TelegramBaseTheme] = [:]
        let themePreferredBaseThemeDict = try container.decodeIfPresent([Int64: Int64].self, forKey: "themePreferredBaseTheme") ?? [:]
        for (key, value) in themePreferredBaseThemeDict {
            if let baseTheme = TelegramBaseTheme(rawValue: Int32(clamping: value)) {
                mappedThemePreferredBaseTheme[key] = baseTheme
            }
        }
        self.themePreferredBaseTheme = mappedThemePreferredBaseTheme

        let themeSpecificChatWallpapersDict = try container.decode([DictionaryKey: TelegramWallpaperNativeCodable].self, forKey: "themeSpecificChatWallpapers")
        var mappedThemeSpecificChatWallpapers: [Int64: TelegramWallpaper] = [:]
        for (key, value) in themeSpecificChatWallpapersDict {
            mappedThemeSpecificChatWallpapers[key.key] = value.value
        }
        self.themeSpecificChatWallpapers = mappedThemeSpecificChatWallpapers

        let themeSpecificAccentColorsDict = try container.decode([DictionaryKey: AdaptedPostboxDecoder.RawObjectData].self, forKey: "themeSpecificAccentColors")
        var mappedThemeSpecificAccentColors: [Int64: PresentationThemeAccentColor] = [:]
        for (key, value) in themeSpecificAccentColorsDict {
            let innerDecoder = PostboxDecoder(buffer: MemoryBuffer(data: value.data))
            mappedThemeSpecificAccentColors[key.key] = PresentationThemeAccentColor(decoder: innerDecoder)
        }
        self.themeSpecificAccentColors = mappedThemeSpecificAccentColors
        
        self.useSystemFont = (try container.decodeIfPresent(Int32.self, forKey: "useSystemFont") ?? 1) != 0

        let fontSize = PresentationFontSize(rawValue: try container.decodeIfPresent(Int32.self, forKey: "f") ?? PresentationFontSize.regular.rawValue) ?? .regular
        self.fontSize = fontSize
        self.listsFontSize = PresentationFontSize(rawValue: try container.decodeIfPresent(Int32.self, forKey: "lf") ?? PresentationFontSize.regular.rawValue) ?? fontSize

        self.chatBubbleSettings = try container.decodeIfPresent(PresentationChatBubbleSettings.self, forKey: "chatBubbleSettings") ?? PresentationChatBubbleSettings.default
        self.automaticThemeSwitchSetting = try container.decodeIfPresent(AutomaticThemeSwitchSetting.self, forKey: "automaticThemeSwitchSetting") ?? AutomaticThemeSwitchSetting(force: false, trigger: .system, theme: .builtin(.night))

        self.largeEmoji = try container.decodeIfPresent(Bool.self, forKey: "largeEmoji") ?? true
        self.reduceMotion = try container.decodeIfPresent(Bool.self, forKey: "reduceMotion") ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(PostboxEncoder().encodeObjectToRawData(self.theme), forKey: "t")

        var mappedThemePreferredBaseTheme: [Int64: Int64] = [:]
        for (key, value) in self.themePreferredBaseTheme {
            mappedThemePreferredBaseTheme[key] = Int64(value.rawValue)
        }
        try container.encode(mappedThemePreferredBaseTheme, forKey: "themePreferredBaseTheme")
        
        var mappedThemeSpecificAccentColors: [DictionaryKey: AdaptedPostboxEncoder.RawObjectData] = [:]
        for (key, value) in self.themeSpecificAccentColors {
            mappedThemeSpecificAccentColors[DictionaryKey(key)] = PostboxEncoder().encodeObjectToRawData(value)
        }
        try container.encode(mappedThemeSpecificAccentColors, forKey: "themeSpecificAccentColors")

        var mappedThemeSpecificChatWallpapers: [DictionaryKey: TelegramWallpaperNativeCodable] = [:]
        for (key, value) in self.themeSpecificChatWallpapers {
            mappedThemeSpecificChatWallpapers[DictionaryKey(key)] = TelegramWallpaperNativeCodable(value)
        }
        try container.encode(mappedThemeSpecificChatWallpapers, forKey: "themeSpecificChatWallpapers")

        try container.encode((self.useSystemFont ? 1 : 0) as Int32, forKey: "useSystemFont")
        try container.encode(self.fontSize.rawValue, forKey: "f")
        try container.encode(self.listsFontSize.rawValue, forKey: "lf")
        try container.encode(self.chatBubbleSettings, forKey: "chatBubbleSettings")
        try container.encode(self.automaticThemeSwitchSetting, forKey: "automaticThemeSwitchSetting")
        try container.encode(self.largeEmoji, forKey: "largeEmoji")
        try container.encode(self.reduceMotion, forKey: "reduceMotion")
    }
    
    public static func ==(lhs: PresentationThemeSettings, rhs: PresentationThemeSettings) -> Bool {
        return lhs.theme == rhs.theme && lhs.themePreferredBaseTheme == rhs.themePreferredBaseTheme && lhs.themeSpecificAccentColors == rhs.themeSpecificAccentColors && lhs.themeSpecificChatWallpapers == rhs.themeSpecificChatWallpapers && lhs.useSystemFont == rhs.useSystemFont && lhs.fontSize == rhs.fontSize && lhs.listsFontSize == rhs.listsFontSize && lhs.chatBubbleSettings == rhs.chatBubbleSettings && lhs.automaticThemeSwitchSetting == rhs.automaticThemeSwitchSetting && lhs.largeEmoji == rhs.largeEmoji && lhs.reduceMotion == rhs.reduceMotion
    }
    
    public func withUpdatedTheme(_ theme: PresentationThemeReference) -> PresentationThemeSettings {
        return PresentationThemeSettings(theme: theme, themePreferredBaseTheme: self.themePreferredBaseTheme, themeSpecificAccentColors: self.themeSpecificAccentColors, themeSpecificChatWallpapers: self.themeSpecificChatWallpapers, useSystemFont: self.useSystemFont, fontSize: self.fontSize, listsFontSize: self.listsFontSize, chatBubbleSettings: self.chatBubbleSettings, automaticThemeSwitchSetting: self.automaticThemeSwitchSetting, largeEmoji: self.largeEmoji, reduceMotion: self.reduceMotion)
    }
    
    public func withUpdatedThemePreferredBaseTheme(_ themePreferredBaseTheme: [Int64: TelegramBaseTheme]) -> PresentationThemeSettings {
        return PresentationThemeSettings(theme: self.theme, themePreferredBaseTheme: themePreferredBaseTheme, themeSpecificAccentColors: self.themeSpecificAccentColors, themeSpecificChatWallpapers: self.themeSpecificChatWallpapers, useSystemFont: self.useSystemFont, fontSize: self.fontSize, listsFontSize: self.listsFontSize, chatBubbleSettings: self.chatBubbleSettings, automaticThemeSwitchSetting: self.automaticThemeSwitchSetting, largeEmoji: self.largeEmoji, reduceMotion: self.reduceMotion)
    }
    
    public func withUpdatedThemeSpecificAccentColors(_ themeSpecificAccentColors: [Int64: PresentationThemeAccentColor]) -> PresentationThemeSettings {
        return PresentationThemeSettings(theme: self.theme, themePreferredBaseTheme: self.themePreferredBaseTheme, themeSpecificAccentColors: themeSpecificAccentColors, themeSpecificChatWallpapers: self.themeSpecificChatWallpapers, useSystemFont: self.useSystemFont, fontSize: self.fontSize, listsFontSize: self.listsFontSize, chatBubbleSettings: self.chatBubbleSettings, automaticThemeSwitchSetting: self.automaticThemeSwitchSetting, largeEmoji: self.largeEmoji, reduceMotion: self.reduceMotion)
    }
    
    public func withUpdatedThemeSpecificChatWallpapers(_ themeSpecificChatWallpapers: [Int64: TelegramWallpaper]) -> PresentationThemeSettings {
        return PresentationThemeSettings(theme: self.theme, themePreferredBaseTheme: self.themePreferredBaseTheme, themeSpecificAccentColors: self.themeSpecificAccentColors, themeSpecificChatWallpapers: themeSpecificChatWallpapers, useSystemFont: self.useSystemFont, fontSize: self.fontSize, listsFontSize: self.listsFontSize, chatBubbleSettings: self.chatBubbleSettings, automaticThemeSwitchSetting: self.automaticThemeSwitchSetting, largeEmoji: self.largeEmoji, reduceMotion: self.reduceMotion)
    }
    
    public func withUpdatedUseSystemFont(_ useSystemFont: Bool) -> PresentationThemeSettings {
        return PresentationThemeSettings(theme: self.theme, themePreferredBaseTheme: self.themePreferredBaseTheme, themeSpecificAccentColors: self.themeSpecificAccentColors, themeSpecificChatWallpapers: self.themeSpecificChatWallpapers, useSystemFont: useSystemFont, fontSize: self.fontSize, listsFontSize: self.listsFontSize, chatBubbleSettings: self.chatBubbleSettings, automaticThemeSwitchSetting: self.automaticThemeSwitchSetting, largeEmoji: self.largeEmoji, reduceMotion: self.reduceMotion)
    }
    
    public func withUpdatedFontSizes(fontSize: PresentationFontSize, listsFontSize: PresentationFontSize) -> PresentationThemeSettings {
        return PresentationThemeSettings(theme: self.theme, themePreferredBaseTheme: self.themePreferredBaseTheme, themeSpecificAccentColors: self.themeSpecificAccentColors, themeSpecificChatWallpapers: self.themeSpecificChatWallpapers, useSystemFont: self.useSystemFont, fontSize: fontSize, listsFontSize: listsFontSize, chatBubbleSettings: self.chatBubbleSettings, automaticThemeSwitchSetting: self.automaticThemeSwitchSetting, largeEmoji: self.largeEmoji, reduceMotion: self.reduceMotion)
    }
    
    public func withUpdatedChatBubbleSettings(_ chatBubbleSettings: PresentationChatBubbleSettings) -> PresentationThemeSettings {
        return PresentationThemeSettings(theme: self.theme, themePreferredBaseTheme: self.themePreferredBaseTheme, themeSpecificAccentColors: self.themeSpecificAccentColors, themeSpecificChatWallpapers: self.themeSpecificChatWallpapers, useSystemFont: self.useSystemFont, fontSize: self.fontSize, listsFontSize: self.listsFontSize, chatBubbleSettings: chatBubbleSettings, automaticThemeSwitchSetting: self.automaticThemeSwitchSetting, largeEmoji: self.largeEmoji, reduceMotion: self.reduceMotion)
    }
    
    public func withUpdatedAutomaticThemeSwitchSetting(_ automaticThemeSwitchSetting: AutomaticThemeSwitchSetting) -> PresentationThemeSettings {
        return PresentationThemeSettings(theme: self.theme, themePreferredBaseTheme: self.themePreferredBaseTheme, themeSpecificAccentColors: self.themeSpecificAccentColors, themeSpecificChatWallpapers: self.themeSpecificChatWallpapers, useSystemFont: self.useSystemFont, fontSize: self.fontSize, listsFontSize: self.listsFontSize, chatBubbleSettings: self.chatBubbleSettings, automaticThemeSwitchSetting: automaticThemeSwitchSetting, largeEmoji: self.largeEmoji, reduceMotion: self.reduceMotion)
    }
    
    public func withUpdatedLargeEmoji(_ largeEmoji: Bool) -> PresentationThemeSettings {
        return PresentationThemeSettings(theme: self.theme, themePreferredBaseTheme: self.themePreferredBaseTheme, themeSpecificAccentColors: self.themeSpecificAccentColors, themeSpecificChatWallpapers: self.themeSpecificChatWallpapers, useSystemFont: self.useSystemFont, fontSize: self.fontSize, listsFontSize: self.listsFontSize, chatBubbleSettings: self.chatBubbleSettings, automaticThemeSwitchSetting: self.automaticThemeSwitchSetting, largeEmoji: largeEmoji, reduceMotion: self.reduceMotion)
    }
    
    public func withUpdatedReduceMotion(_ reduceMotion: Bool) -> PresentationThemeSettings {
        return PresentationThemeSettings(theme: self.theme, themePreferredBaseTheme: self.themePreferredBaseTheme, themeSpecificAccentColors: self.themeSpecificAccentColors, themeSpecificChatWallpapers: self.themeSpecificChatWallpapers, useSystemFont: self.useSystemFont, fontSize: self.fontSize, listsFontSize: self.listsFontSize, chatBubbleSettings: self.chatBubbleSettings, automaticThemeSwitchSetting: self.automaticThemeSwitchSetting, largeEmoji: self.largeEmoji, reduceMotion: reduceMotion)
    }
}

public func updatePresentationThemeSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (PresentationThemeSettings) -> PresentationThemeSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.presentationThemeSettings, { entry in
            let currentSettings: PresentationThemeSettings
            if let entry = entry?.get(PresentationThemeSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = PresentationThemeSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
