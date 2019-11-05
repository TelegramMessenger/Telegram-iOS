import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import TelegramApiMac
#else
import Postbox
import SwiftSignalKit
import TelegramApi
#endif

public struct WallpaperSettings: PostboxCoding, Equatable {
    public let blur: Bool
    public let motion: Bool
    public let color: Int32?
    public let intensity: Int32?
    
    public init(blur: Bool = false, motion: Bool = false, color: Int32? = nil, intensity: Int32? = nil) {
        self.blur = blur
        self.motion = motion
        self.color = color
        self.intensity = intensity
    }
    
    public init(decoder: PostboxDecoder) {
        self.blur = decoder.decodeInt32ForKey("b", orElse: 0) != 0
        self.motion = decoder.decodeInt32ForKey("m", orElse: 0) != 0
        self.color = decoder.decodeOptionalInt32ForKey("c")
        self.intensity = decoder.decodeOptionalInt32ForKey("i")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.blur ? 1 : 0, forKey: "b")
        encoder.encodeInt32(self.motion ? 1 : 0, forKey: "m")
        if let color = self.color {
            encoder.encodeInt32(color, forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
        if let intensity = self.intensity {
            encoder.encodeInt32(intensity, forKey: "i")
        } else {
            encoder.encodeNil(forKey: "i")
        }
    }
}

public enum TelegramWallpaper: OrderedItemListEntryContents, Equatable {
    case builtin(WallpaperSettings)
    case color(Int32)
    case image([TelegramMediaImageRepresentation], WallpaperSettings)
    case file(id: Int64, accessHash: Int64, isCreator: Bool, isDefault: Bool, isPattern: Bool, isDark: Bool, slug: String, file: TelegramMediaFile, settings: WallpaperSettings)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
                self = .builtin(settings)
            case 1:
                self = .color(decoder.decodeInt32ForKey("c", orElse: 0))
            case 2:
                let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
                self = .image(decoder.decodeObjectArrayWithDecoderForKey("i"), settings)
            case 3:
                let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
                if let file = decoder.decodeObjectForKey("file", decoder: { TelegramMediaFile(decoder: $0) }) as? TelegramMediaFile {
                    self = .file(id: decoder.decodeInt64ForKey("id", orElse: 0), accessHash: decoder.decodeInt64ForKey("accessHash", orElse: 0), isCreator: decoder.decodeInt32ForKey("isCreator", orElse: 0) != 0, isDefault: decoder.decodeInt32ForKey("isDefault", orElse: 0) != 0, isPattern: decoder.decodeInt32ForKey("isPattern", orElse: 0) != 0, isDark: decoder.decodeInt32ForKey("isDark", orElse: 0) != 0, slug: decoder.decodeStringForKey("slug", orElse: ""), file: file, settings: settings)
                } else {
                    self = .color(0xffffff)
                }

            default:
                assertionFailure()
                self = .color(0xffffff)
        }
    }
    
    public var hasWallpaper: Bool {
        switch self {
            case .color:
                return false
            default:
                return true
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .builtin(settings):
                encoder.encodeInt32(0, forKey: "v")
                encoder.encodeObject(settings, forKey: "settings")
            case let .color(color):
                encoder.encodeInt32(1, forKey: "v")
                encoder.encodeInt32(color, forKey: "c")
            case let .image(representations, settings):
                encoder.encodeInt32(2, forKey: "v")
                encoder.encodeObjectArray(representations, forKey: "i")
                encoder.encodeObject(settings, forKey: "settings")
            case let .file(id, accessHash, isCreator, isDefault, isPattern, isDark, slug, file, settings):
                encoder.encodeInt32(3, forKey: "v")
                encoder.encodeInt64(id, forKey: "id")
                encoder.encodeInt64(accessHash, forKey: "accessHash")
                encoder.encodeInt32(isCreator ? 1 : 0, forKey: "isCreator")
                encoder.encodeInt32(isDefault ? 1 : 0, forKey: "isDefault")
                encoder.encodeInt32(isPattern ? 1 : 0, forKey: "isPattern")
                encoder.encodeInt32(isDark ? 1 : 0, forKey: "isDark")
                encoder.encodeString(slug, forKey: "slug")
                encoder.encodeObject(file, forKey: "file")
                encoder.encodeObject(settings, forKey: "settings")
        }
    }
    
    public static func ==(lhs: TelegramWallpaper, rhs: TelegramWallpaper) -> Bool {
        switch lhs {
            case let .builtin(settings):
                if case .builtin(settings) = rhs {
                    return true
                } else {
                    return false
                }
            case let .color(color):
                if case .color(color) = rhs {
                    return true
                } else {
                    return false
                }
            case let .image(representations, settings):
                if case .image(representations, settings) = rhs {
                    return true
                } else {
                    return false
            }
            case let .file(lhsId, _, lhsIsCreator, lhsIsDefault, lhsIsPattern, lhsIsDark, lhsSlug, lhsFile, lhsSettings):
                if case let .file(rhsId, _, rhsIsCreator, rhsIsDefault, rhsIsPattern, rhsIsDark, rhsSlug, rhsFile, rhsSettings) = rhs, lhsId == rhsId, lhsIsCreator == rhsIsCreator, lhsIsDefault == rhsIsDefault, lhsIsPattern == rhsIsPattern, lhsIsDark == rhsIsDark, lhsSlug == rhsSlug, lhsFile == rhsFile, lhsSettings == rhsSettings {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public var settings: WallpaperSettings? {
        switch self {
            case let .builtin(settings), let .image(_, settings), let .file(_, _, _, _, _, _, _, _, settings):
                return settings
            default:
                return nil
        }
    }
    
    public func withUpdatedSettings(_ settings: WallpaperSettings) -> TelegramWallpaper {
        switch self {
            case .builtin:
                return .builtin(settings)
            case .color:
                return self
            case let .image(representations, _):
                return .image(representations, settings)
            case let .file(id, accessHash, isCreator, isDefault, isPattern, isDark, slug, file, _):
                return .file(id: id, accessHash: accessHash, isCreator: isCreator, isDefault: isDefault, isPattern: settings.color != nil ? true : isPattern, isDark: isDark, slug: slug, file: file, settings: settings)
        }
    }
}

extension WallpaperSettings {
    init(apiWallpaperSettings: Api.WallPaperSettings) {
        switch apiWallpaperSettings {
            case let .wallPaperSettings(flags, backgroundColor, intensity):
                self = WallpaperSettings(blur: (flags & 1 << 1) != 0, motion: (flags & 1 << 2) != 0, color: backgroundColor, intensity: intensity)
        }
    }
}

func apiWallpaperSettings(_ wallpaperSettings: WallpaperSettings) -> Api.WallPaperSettings {
    var flags: Int32 = 0
    if wallpaperSettings.blur {
        flags |= (1 << 1)
    }
    if wallpaperSettings.motion {
        flags |= (1 << 2)
    }
    return .wallPaperSettings(flags: flags, backgroundColor: wallpaperSettings.color, intensity: wallpaperSettings.intensity)
}

extension TelegramWallpaper {
    init(apiWallpaper: Api.WallPaper) {
        switch apiWallpaper {
            case let .wallPaper(id, flags, accessHash, slug, document, settings):
                if let file = telegramMediaFileFromApiDocument(document) {
                    let wallpaperSettings: WallpaperSettings
                    if let settings = settings {
                        wallpaperSettings = WallpaperSettings(apiWallpaperSettings: settings)
                    } else {
                        wallpaperSettings = WallpaperSettings()
                    }
                    self = .file(id: id, accessHash: accessHash, isCreator: (flags & 1 << 0) != 0, isDefault: (flags & 1 << 1) != 0, isPattern: (flags & 1 << 3) != 0, isDark: (flags & 1 << 4) != 0, slug: slug, file: file, settings: wallpaperSettings)
                } else {
                    assertionFailure()
                    self = .color(0xffffff)
                }
        }
    }
}
