import Postbox

public enum TelegramBaseTheme: Int32 {
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

public final class TelegramThemeSettings: PostboxCoding, Equatable {
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
    
    public init(decoder: PostboxDecoder) {
        self.baseTheme = TelegramBaseTheme(rawValue: decoder.decodeInt32ForKey("baseTheme", orElse: 0)) ?? .classic
        self.accentColor = UInt32(bitPattern: decoder.decodeInt32ForKey("accent", orElse: 0))
        self.outgoingAccentColor = decoder.decodeOptionalInt32ForKey("outgoingAccent").flatMap { UInt32(bitPattern: $0) }
        let messageColors = decoder.decodeInt32ArrayForKey("messageColors")
        if !messageColors.isEmpty {
            self.messageColors = messageColors.map(UInt32.init(bitPattern:))
        } else {
            if let topMessageColor = decoder.decodeOptionalInt32ForKey("topMessage"), let bottomMessageColor = decoder.decodeOptionalInt32ForKey("bottomMessage") {
                self.messageColors = [UInt32(bitPattern: topMessageColor), UInt32(bitPattern: bottomMessageColor)]
            } else {
                self.messageColors = []
            }
        }
        self.animateMessageColors = decoder.decodeInt32ForKey("animateMessageColors", orElse: 0) != 0
        self.wallpaper = decoder.decodeObjectForKey("wallpaper", decoder: { TelegramWallpaper(decoder: $0) }) as? TelegramWallpaper
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.baseTheme.rawValue, forKey: "baseTheme")
        encoder.encodeInt32(Int32(bitPattern: self.accentColor), forKey: "accent")
        if let outgoingAccentColor = self.outgoingAccentColor {
            encoder.encodeInt32(Int32(bitPattern: outgoingAccentColor), forKey: "outgoingAccent")
        } else {
            encoder.encodeNil(forKey: "outgoingAccent")
        }
        encoder.encodeInt32Array(self.messageColors.map(Int32.init(bitPattern:)), forKey: "messageColors")
        encoder.encodeInt32(self.animateMessageColors ? 1 : 0, forKey: "animateMessageColors")
        if let wallpaper = self.wallpaper {
            encoder.encodeObject(wallpaper, forKey: "wallpaper")
        } else {
            encoder.encodeNil(forKey: "wallpaper")
        }
    }
}

public final class TelegramTheme: OrderedItemListEntryContents, Equatable {
    public let id: Int64
    public let accessHash: Int64
    public let slug: String
    public let title: String
    public let file: TelegramMediaFile?
    public let settings: TelegramThemeSettings?
    public let isCreator: Bool
    public let isDefault: Bool
    public let installCount: Int32?
    
    public init(id: Int64, accessHash: Int64, slug: String, title: String, file: TelegramMediaFile?, settings: TelegramThemeSettings?, isCreator: Bool, isDefault: Bool, installCount: Int32?) {
        self.id = id
        self.accessHash = accessHash
        self.slug = slug
        self.title = title
        self.file = file
        self.settings = settings
        self.isCreator = isCreator
        self.isDefault = isDefault
        self.installCount = installCount
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey("id", orElse: 0)
        self.accessHash = decoder.decodeInt64ForKey("accessHash", orElse: 0)
        self.slug = decoder.decodeStringForKey("slug", orElse: "")
        self.title = decoder.decodeStringForKey("title", orElse: "")
        self.file = decoder.decodeObjectForKey("file", decoder: { TelegramMediaFile(decoder: $0) }) as? TelegramMediaFile
        self.settings = decoder.decodeObjectForKey("settings", decoder: { TelegramThemeSettings(decoder: $0) }) as? TelegramThemeSettings
        self.isCreator = decoder.decodeInt32ForKey("isCreator", orElse: 0) != 0
        self.isDefault = decoder.decodeInt32ForKey("isDefault", orElse: 0) != 0
        self.installCount = decoder.decodeOptionalInt32ForKey("installCount")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: "id")
        encoder.encodeInt64(self.accessHash, forKey: "accessHash")
        encoder.encodeString(self.slug, forKey: "slug")
        encoder.encodeString(self.title, forKey: "title")
        if let file = self.file {
            encoder.encodeObject(file, forKey: "file")
        } else {
            encoder.encodeNil(forKey: "file")
        }
        if let settings = self.settings {
            encoder.encodeObject(settings, forKey: "settings")
        } else {
            encoder.encodeNil(forKey: "settings")
        }
        encoder.encodeInt32(self.isCreator ? 1 : 0, forKey: "isCreator")
        encoder.encodeInt32(self.isDefault ? 1 : 0, forKey: "isDefault")
        if let installCount = self.installCount {
            encoder.encodeInt32(installCount, forKey: "installCount")
        } else {
            encoder.encodeNil(forKey: "installCount")
        }
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
