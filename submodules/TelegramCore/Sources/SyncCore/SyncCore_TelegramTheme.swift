import Foundation
import Postbox

public enum TelegramBaseTheme: Int32, Codable {
    case classic
    case day
    case night
    case tinted
}

public extension UInt32 {
    init(bitPattern: UInt32) {
        self = bitPattern
    }
}

public final class TelegramThemeSettings: Codable, Equatable {
    public static func == (lhs: TelegramThemeSettings, rhs: TelegramThemeSettings) -> Bool {
        if lhs.baseTheme != rhs.baseTheme {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.outgoingAccentColor != rhs.outgoingAccentColor {
            return false
        }
        if lhs.messageColors != rhs.messageColors {
            return false
        }
        if lhs.animateMessageColors != rhs.animateMessageColors {
            return false
        }
        if lhs.wallpaper != rhs.wallpaper {
            return false
        }
        return true
    }
    
    public let baseTheme: TelegramBaseTheme
    public let accentColor: UInt32
    public let outgoingAccentColor: UInt32?
    public let messageColors: [UInt32]
    public let animateMessageColors: Bool
    public let wallpaper: TelegramWallpaper?
    
    public init(baseTheme: TelegramBaseTheme, accentColor: UInt32, outgoingAccentColor: UInt32?, messageColors: [UInt32], animateMessageColors: Bool, wallpaper: TelegramWallpaper?) {
        self.baseTheme = baseTheme
        self.accentColor = accentColor
        self.outgoingAccentColor = outgoingAccentColor
        self.messageColors = messageColors
        self.animateMessageColors = animateMessageColors
        self.wallpaper = wallpaper
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.baseTheme = TelegramBaseTheme(rawValue: try container.decode(Int32.self, forKey: "baseTheme")) ?? .classic
        self.accentColor = UInt32(bitPattern: try container.decode(Int32.self, forKey: "accent"))
        self.outgoingAccentColor = (try container.decodeIfPresent(Int32.self, forKey: "outgoingAccent")).flatMap { UInt32(bitPattern: $0) }
        let messageColors = try container.decodeIfPresent([Int32].self, forKey: "messageColors") ?? []
        if !messageColors.isEmpty {
            self.messageColors = messageColors.map(UInt32.init(bitPattern:))
        } else {
            if let topMessageColor = try container.decodeIfPresent(Int32.self, forKey: "topMessage"), let bottomMessageColor = try container.decodeIfPresent(Int32.self, forKey: "bottomMessage") {
                self.messageColors = [UInt32(bitPattern: topMessageColor), UInt32(bitPattern: bottomMessageColor)]
            } else {
                self.messageColors = []
            }
        }
        self.animateMessageColors = (try container.decodeIfPresent(Int32.self, forKey: "animateMessageColors") ?? 0) != 0

        self.wallpaper = (try container.decodeIfPresent(TelegramWallpaperNativeCodable.self, forKey: "wallpaper"))?.value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.baseTheme.rawValue, forKey: "baseTheme")
        try container.encode(Int32(bitPattern: self.accentColor), forKey: "accent")
        if let outgoingAccentColor = self.outgoingAccentColor {
            try container.encode(Int32(bitPattern: outgoingAccentColor), forKey: "outgoingAccent")
        } else {
            try container.encodeNil(forKey: "outgoingAccent")
        }
        try container.encode(self.messageColors.map(Int32.init(bitPattern:)), forKey: "messageColors")
        try container.encode((self.animateMessageColors ? 1 : 0) as Int32, forKey: "animateMessageColors")
        try container.encodeIfPresent(self.wallpaper.flatMap(TelegramWallpaperNativeCodable.init), forKey: "wallpaper")
    }
}

public struct TelegramThemeNativeCodable: Codable {
    public let value: TelegramTheme

    public init(_ value: TelegramTheme) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        let id = try container.decode(Int64.self, forKey: "id")
        let accessHash = try container.decode(Int64.self, forKey: "accessHash")
        let slug = try container.decode(String.self, forKey: "slug")
        let emoticon = try container.decodeIfPresent(String.self, forKey: "emoticon")
        let title = try container.decode(String.self, forKey: "title")

        let file: TelegramMediaFile?
        if let fileData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: "file") {
            file = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: fileData.data)))
        } else {
            file = nil
        }

        let legacySettings = try container.decodeIfPresent(TelegramThemeSettings.self, forKey: "settings")
        var settings = try container.decodeIfPresent([TelegramThemeSettings].self, forKey: "settingsArray")
        if settings == nil, let legacySettings = legacySettings {
            settings = [legacySettings]
        }
        
        let isCreator = try container.decode(Int32.self, forKey: "isCreator") != 0
        let isDefault = try container.decode(Int32.self, forKey: "isDefault") != 0
        let installCount = try container.decodeIfPresent(Int32.self, forKey: "installCount")

        self.value = TelegramTheme(
            id: id,
            accessHash: accessHash,
            slug: slug,
            emoticon: emoticon,
            title: title,
            file: file,
            settings: settings,
            isCreator: isCreator,
            isDefault: isDefault,
            installCount: installCount
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.value.id, forKey: "id")
        try container.encode(self.value.accessHash, forKey: "accessHash")
        try container.encode(self.value.slug, forKey: "slug")
        try container.encodeIfPresent(self.value.emoticon, forKey: "emoticon")
        try container.encode(self.value.title, forKey: "title")

        if let file = self.value.file {
            try container.encode(PostboxEncoder().encodeObjectToRawData(file), forKey: "file")
        } else {
            try container.encodeNil(forKey: "file")
        }

        try container.encodeIfPresent(self.value.settings, forKey: "settingsArray")

        try container.encode((self.value.isCreator ? 1 : 0) as Int32, forKey: "isCreator")
        try container.encode((self.value.isDefault ? 1 : 0) as Int32, forKey: "isDefault")

        try container.encodeIfPresent(self.value.installCount, forKey: "installCount")
    }
}

public final class TelegramTheme: Equatable {
    public let id: Int64
    public let accessHash: Int64
    public let slug: String
    public let emoticon: String?
    public let title: String
    public let file: TelegramMediaFile?
    public let settings: [TelegramThemeSettings]?
    public let isCreator: Bool
    public let isDefault: Bool
    public let installCount: Int32?
    
    public init(id: Int64, accessHash: Int64, slug: String, emoticon: String?, title: String, file: TelegramMediaFile?, settings: [TelegramThemeSettings]?, isCreator: Bool, isDefault: Bool, installCount: Int32?) {
        self.id = id
        self.accessHash = accessHash
        self.slug = slug
        self.emoticon = emoticon
        self.title = title
        self.file = file
        self.settings = settings
        self.isCreator = isCreator
        self.isDefault = isDefault
        self.installCount = installCount
    }
    
    public static func ==(lhs: TelegramTheme, rhs: TelegramTheme) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.accessHash != rhs.accessHash {
            return false
        }
        if lhs.slug != rhs.slug {
            return false
        }
        if lhs.emoticon != rhs.emoticon {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.file?.id != rhs.file?.id {
            return false
        }
        if lhs.settings != rhs.settings {
            return false
        }
        if lhs.isCreator != rhs.isCreator {
            return false
        }
        if lhs.isDefault != rhs.isDefault {
            return false
        }
        if lhs.installCount != rhs.installCount {
            return false
        }
        return true
    }
}
