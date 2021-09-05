import Postbox

public struct WallpaperSettings: PostboxCoding, Equatable {
    public var blur: Bool
    public var motion: Bool
    public var colors: [UInt32]
    public var intensity: Int32?
    public var rotation: Int32?
    
    public init(blur: Bool = false, motion: Bool = false, colors: [UInt32] = [], intensity: Int32? = nil, rotation: Int32? = nil) {
        self.blur = blur
        self.motion = motion
        self.colors = colors
        self.intensity = intensity
        self.rotation = rotation
    }
    
    public init(decoder: PostboxDecoder) {
        self.blur = decoder.decodeInt32ForKey("b", orElse: 0) != 0
        self.motion = decoder.decodeInt32ForKey("m", orElse: 0) != 0
        if let topColor = decoder.decodeOptionalInt32ForKey("c").flatMap(UInt32.init(bitPattern:)) {
            var colors: [UInt32] = [topColor]
            if let bottomColor = decoder.decodeOptionalInt32ForKey("bc").flatMap(UInt32.init(bitPattern:)) {
                colors.append(bottomColor)
            }
            self.colors = colors
        } else {
            self.colors = decoder.decodeInt32ArrayForKey("colors").map(UInt32.init(bitPattern:))
        }

        self.intensity = decoder.decodeOptionalInt32ForKey("i")
        self.rotation = decoder.decodeOptionalInt32ForKey("r")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.blur ? 1 : 0, forKey: "b")
        encoder.encodeInt32(self.motion ? 1 : 0, forKey: "m")
        encoder.encodeInt32Array(self.colors.map(Int32.init(bitPattern:)), forKey: "colors")
        if let intensity = self.intensity {
            encoder.encodeInt32(intensity, forKey: "i")
        } else {
            encoder.encodeNil(forKey: "i")
        }
        if let rotation = self.rotation {
            encoder.encodeInt32(rotation, forKey: "r")
        } else {
            encoder.encodeNil(forKey: "r")
        }
    }
    
    public static func ==(lhs: WallpaperSettings, rhs: WallpaperSettings) -> Bool {
        if lhs.blur != rhs.blur {
            return false
        }
        if lhs.motion != rhs.motion {
            return false
        }
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.intensity != rhs.intensity {
            return false
        }
        if lhs.rotation != rhs.rotation {
            return false
        }
        return true
    }
}

public enum TelegramWallpaper: OrderedItemListEntryContents, Equatable {
    public struct Gradient: Equatable {
        public var id: Int64?
        public var colors: [UInt32]
        public var settings: WallpaperSettings

        public init(
            id: Int64?,
            colors: [UInt32],
            settings: WallpaperSettings
        ) {
            self.id = id
            self.colors = colors
            self.settings = settings
        }
    }

    public struct File: Equatable {
        public var id: Int64
        public var accessHash: Int64
        public var isCreator: Bool
        public var isDefault: Bool
        public var isPattern: Bool
        public var isDark: Bool
        public var slug: String
        public var file: TelegramMediaFile
        public var settings: WallpaperSettings

        public init(
            id: Int64,
            accessHash: Int64,
            isCreator: Bool,
            isDefault: Bool,
            isPattern: Bool,
            isDark: Bool,
            slug: String,
            file: TelegramMediaFile,
            settings: WallpaperSettings
        ) {
            self.id = id
            self.accessHash = accessHash
            self.isCreator = isCreator
            self.isDefault = isDefault
            self.isPattern = isPattern
            self.isDark = isDark
            self.slug = slug
            self.file = file
            self.settings = settings
        }
    }

    case builtin(WallpaperSettings)
    case color(UInt32)
    case gradient(Gradient)
    case image([TelegramMediaImageRepresentation], WallpaperSettings)
    case file(File)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
        case 0:
            let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
            self = .builtin(settings)
        case 1:
            self = .color(UInt32(bitPattern: decoder.decodeInt32ForKey("c", orElse: 0)))
        case 2:
            let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
            self = .image(decoder.decodeObjectArrayWithDecoderForKey("i"), settings)
        case 3:
            let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()
            if let file = decoder.decodeObjectForKey("file", decoder: { TelegramMediaFile(decoder: $0) }) as? TelegramMediaFile {
                self = .file(File(id: decoder.decodeInt64ForKey("id", orElse: 0), accessHash: decoder.decodeInt64ForKey("accessHash", orElse: 0), isCreator: decoder.decodeInt32ForKey("isCreator", orElse: 0) != 0, isDefault: decoder.decodeInt32ForKey("isDefault", orElse: 0) != 0, isPattern: decoder.decodeInt32ForKey("isPattern", orElse: 0) != 0, isDark: decoder.decodeInt32ForKey("isDark", orElse: 0) != 0, slug: decoder.decodeStringForKey("slug", orElse: ""), file: file, settings: settings))
            } else {
                self = .color(0xffffff)
            }
        case 4:
            let settings = decoder.decodeObjectForKey("settings", decoder: { WallpaperSettings(decoder: $0) }) as? WallpaperSettings ?? WallpaperSettings()

            var colors: [UInt32] = []

            if let topColor = decoder.decodeOptionalInt32ForKey("c1").flatMap(UInt32.init(bitPattern:)) {
                colors.append(topColor)
                if let bottomColor = decoder.decodeOptionalInt32ForKey("c2").flatMap(UInt32.init(bitPattern:)) {
                    colors.append(bottomColor)
                }
            } else {
                colors = decoder.decodeInt32ArrayForKey("colors").map(UInt32.init(bitPattern:))
            }

            self = .gradient(Gradient(id: decoder.decodeOptionalInt64ForKey("id"), colors: colors, settings: settings))
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
                encoder.encodeInt32(Int32(bitPattern: color), forKey: "c")
            case let .gradient(gradient):
                encoder.encodeInt32(4, forKey: "v")
                if let id = gradient.id {
                    encoder.encodeInt64(id, forKey: "id")
                } else {
                    encoder.encodeNil(forKey: "id")
                }
                encoder.encodeInt32Array(gradient.colors.map(Int32.init(bitPattern:)), forKey: "colors")
                encoder.encodeObject(gradient.settings, forKey: "settings")
            case let .image(representations, settings):
                encoder.encodeInt32(2, forKey: "v")
                encoder.encodeObjectArray(representations, forKey: "i")
                encoder.encodeObject(settings, forKey: "settings")
            case let .file(file):
                encoder.encodeInt32(3, forKey: "v")
                encoder.encodeInt64(file.id, forKey: "id")
                encoder.encodeInt64(file.accessHash, forKey: "accessHash")
                encoder.encodeInt32(file.isCreator ? 1 : 0, forKey: "isCreator")
                encoder.encodeInt32(file.isDefault ? 1 : 0, forKey: "isDefault")
                encoder.encodeInt32(file.isPattern ? 1 : 0, forKey: "isPattern")
                encoder.encodeInt32(file.isDark ? 1 : 0, forKey: "isDark")
                encoder.encodeString(file.slug, forKey: "slug")
                encoder.encodeObject(file.file, forKey: "file")
                encoder.encodeObject(file.settings, forKey: "settings")
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
            case let .gradient(gradient):
                if case .gradient(gradient) = rhs {
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
            case let .file(file):
                if case .file(file) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public func isBasicallyEqual(to wallpaper: TelegramWallpaper) -> Bool {
        switch self {
            case .builtin:
                if case .builtin = wallpaper {
                    return true
                } else {
                    return false
                }
            case let .color(color):
                if case .color(color) = wallpaper {
                    return true
                } else {
                    return false
                }
            case let .gradient(lhsGradient):
                if case let .gradient(rhsGradient) = wallpaper, lhsGradient.colors == rhsGradient.colors {
                    return true
                } else {
                    return false
                }
            case let .image(representations, _):
                if case .image(representations, _) = wallpaper {
                    return true
                } else {
                    return false
                }
            case let .file(lhsFile):
                if case let .file(rhsFile) = wallpaper, lhsFile.slug == rhsFile.slug, lhsFile.settings.colors == rhsFile.settings.colors, lhsFile.settings.intensity == rhsFile.settings.intensity {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public var settings: WallpaperSettings? {
        switch self {
        case let .builtin(settings), let .image(_, settings):
            return settings
        case let .file(file):
            return file.settings
        case let .gradient(gradient):
            return gradient.settings
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
        case var .gradient(gradient):
            gradient.settings = settings
            return .gradient(gradient)
        case let .image(representations, _):
            return .image(representations, settings)
        case var .file(file):
            file.settings = settings
            return .file(file)
        }
    }
}
