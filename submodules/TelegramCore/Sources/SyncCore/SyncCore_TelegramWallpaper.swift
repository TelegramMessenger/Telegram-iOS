import Postbox

public struct WallpaperSettings: Codable, Equatable {
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.blur = try container.decode(Int32.self, forKey: "b") != 0
        self.motion = try container.decode(Int32.self, forKey: "m") != 0
        if let topColor = (try container.decodeIfPresent(Int32.self, forKey: "c")).flatMap(UInt32.init(bitPattern:)) {
            var colors: [UInt32] = [topColor]
            if let bottomColor = (try container.decodeIfPresent(Int32.self, forKey: "bc")).flatMap(UInt32.init(bitPattern:)) {
                colors.append(bottomColor)
            }
            self.colors = colors
        } else {
            self.colors = (try container.decode([Int32].self, forKey: "colors")).map(UInt32.init(bitPattern:))
        }

        self.intensity = try container.decodeIfPresent(Int32.self, forKey: "i")
        self.rotation = try container.decodeIfPresent(Int32.self, forKey: "r")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.blur ? 1 : 0) as Int32, forKey: "b")
        try container.encode((self.motion ? 1 : 0) as Int32, forKey: "m")
        try container.encode(self.colors.map(Int32.init(bitPattern:)), forKey: "colors")
        try container.encodeIfPresent(self.intensity, forKey: "i")
        try container.encodeIfPresent(self.rotation, forKey: "r")
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

public struct TelegramWallpaperNativeCodable: Codable {
    public let value: TelegramWallpaper

    public init(_ value: TelegramWallpaper) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        switch try container.decode(Int32.self, forKey: "v") {
        case 0:
            let settings = try container.decode(WallpaperSettings.self, forKey: "settings")
            self.value = .builtin(settings)
        case 1:
            self.value = .color(UInt32(bitPattern: try container.decode(Int32.self, forKey: "c")))
        case 2:
            let settings = try container.decode(WallpaperSettings.self, forKey: "settings")
            let representations = (try container.decode([AdaptedPostboxDecoder.RawObjectData].self, forKey: "i")).map { itemData in
                return TelegramMediaImageRepresentation(decoder: PostboxDecoder(buffer: MemoryBuffer(data: itemData.data)))
            }
            self.value = .image(representations, settings)
        case 3:
            let settings = try container.decode(WallpaperSettings.self, forKey: "settings")
            if let fileData = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: "file") {
                let file = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: fileData.data)))
                self.value = .file(TelegramWallpaper.File(
                    id: try container.decode(Int64.self, forKey: "id"),
                    accessHash: try container.decode(Int64.self, forKey: "accessHash"),
                    isCreator: try container.decode(Int32.self, forKey: "isCreator") != 0,
                    isDefault: try container.decode(Int32.self, forKey: "isDefault") != 0,
                    isPattern: try container.decode(Int32.self, forKey: "isPattern") != 0,
                    isDark: try container.decode(Int32.self, forKey: "isDark") != 0,
                    slug: try container.decode(String.self, forKey: "slug"),
                    file: file,
                    settings: settings
                ))
            } else {
                self.value = .color(0xffffff)
            }
        case 4:
            let settings = try container.decode(WallpaperSettings.self, forKey: "settings")

            var colors: [UInt32] = []

            if let topColor = (try container.decodeIfPresent(Int32.self, forKey: "c1")).flatMap(UInt32.init(bitPattern:)) {
                colors.append(topColor)
                if let bottomColor = (try container.decodeIfPresent(Int32.self, forKey: "c2")).flatMap(UInt32.init(bitPattern:)) {
                    colors.append(bottomColor)
                }
            } else {
                colors = (try container.decode([Int32].self, forKey: "colors")).map(UInt32.init(bitPattern:))
            }

            self.value = .gradient(TelegramWallpaper.Gradient(
                id: try container.decodeIfPresent(Int64.self, forKey: "id"),
                colors: colors,
                settings: settings
            ))
        default:
            assertionFailure()
            self.value = .color(0xffffff)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self.value {
            case let .builtin(settings):
                try container.encode(0 as Int32, forKey: "v")
                try container.encode(settings, forKey: "settings")
            case let .color(color):
                try container.encode(1 as Int32, forKey: "v")
                try container.encode(Int32(bitPattern: color), forKey: "c")
            case let .gradient(gradient):
                try container.encode(4 as Int32, forKey: "v")
                try container.encodeIfPresent(gradient.id, forKey: "id")
                try container.encode(gradient.colors.map(Int32.init(bitPattern:)), forKey: "colors")
                try container.encode(gradient.settings, forKey: "settings")
            case let .image(representations, settings):
                try container.encode(2 as Int32, forKey: "v")
                try container.encode(representations.map { item in
                    return PostboxEncoder().encodeObjectToRawData(item)
                }, forKey: "i")
                try container.encode(settings, forKey: "settings")
            case let .file(file):
                try container.encode(3 as Int32, forKey: "v")
                try container.encode(file.id, forKey: "id")
                try container.encode(file.accessHash, forKey: "accessHash")
                try container.encode((file.isCreator ? 1 : 0) as Int32, forKey: "isCreator")
                try container.encode((file.isDefault ? 1 : 0) as Int32, forKey: "isDefault")
                try container.encode((file.isPattern ? 1 : 0) as Int32, forKey: "isPattern")
                try container.encode((file.isDark ? 1 : 0) as Int32, forKey: "isDark")
                try container.encode(file.slug, forKey: "slug")
                try container.encode(PostboxEncoder().encodeObjectToRawData(file.file), forKey: "file")
                try container.encode(file.settings, forKey: "settings")
        }
    }
}

public enum TelegramWallpaper: Equatable {
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
    
    public var hasWallpaper: Bool {
        switch self {
            case .color:
                return false
            default:
                return true
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
