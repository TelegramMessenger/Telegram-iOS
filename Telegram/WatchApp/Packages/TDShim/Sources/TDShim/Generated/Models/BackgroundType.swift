//
//  BackgroundType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes the type of background
public indirect enum BackgroundType: Codable, Equatable, Hashable {

    /// A wallpaper in JPEG format
    case backgroundTypeWallpaper(BackgroundTypeWallpaper)

    /// A PNG or TGV (gzipped subset of SVG with MIME type "application/x-tgwallpattern") pattern to be combined with the background fill chosen by the user
    case backgroundTypePattern(BackgroundTypePattern)

    /// A filled background
    case backgroundTypeFill(BackgroundTypeFill)

    /// A background from a chat theme based on an emoji; can be used only as a chat background in channels
    case backgroundTypeChatTheme(BackgroundTypeChatTheme)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case backgroundTypeWallpaper
        case backgroundTypePattern
        case backgroundTypeFill
        case backgroundTypeChatTheme
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .backgroundTypeWallpaper:
            let value = try BackgroundTypeWallpaper(from: decoder)
            self = .backgroundTypeWallpaper(value)
        case .backgroundTypePattern:
            let value = try BackgroundTypePattern(from: decoder)
            self = .backgroundTypePattern(value)
        case .backgroundTypeFill:
            let value = try BackgroundTypeFill(from: decoder)
            self = .backgroundTypeFill(value)
        case .backgroundTypeChatTheme:
            let value = try BackgroundTypeChatTheme(from: decoder)
            self = .backgroundTypeChatTheme(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .backgroundTypeWallpaper(let value):
            try container.encode(Kind.backgroundTypeWallpaper, forKey: .type)
            try value.encode(to: encoder)
        case .backgroundTypePattern(let value):
            try container.encode(Kind.backgroundTypePattern, forKey: .type)
            try value.encode(to: encoder)
        case .backgroundTypeFill(let value):
            try container.encode(Kind.backgroundTypeFill, forKey: .type)
            try value.encode(to: encoder)
        case .backgroundTypeChatTheme(let value):
            try container.encode(Kind.backgroundTypeChatTheme, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A wallpaper in JPEG format
public struct BackgroundTypeWallpaper: Codable, Equatable, Hashable {

    /// True, if the wallpaper must be downscaled to fit in 450x450 square and then box-blurred with radius 12
    public let isBlurred: Bool

    /// True, if the background needs to be slightly moved when device is tilted
    public let isMoving: Bool


    public init(
        isBlurred: Bool,
        isMoving: Bool
    ) {
        self.isBlurred = isBlurred
        self.isMoving = isMoving
    }
}

/// A PNG or TGV (gzipped subset of SVG with MIME type "application/x-tgwallpattern") pattern to be combined with the background fill chosen by the user
public struct BackgroundTypePattern: Codable, Equatable, Hashable {

    /// Fill of the background
    public let fill: BackgroundFill

    /// Intensity of the pattern when it is shown above the filled background; 0-100
    public let intensity: Int

    /// True, if the background fill must be applied only to the pattern itself. All other pixels are black in this case. For dark themes only
    public let isInverted: Bool

    /// True, if the background needs to be slightly moved when device is tilted
    public let isMoving: Bool


    public init(
        fill: BackgroundFill,
        intensity: Int,
        isInverted: Bool,
        isMoving: Bool
    ) {
        self.fill = fill
        self.intensity = intensity
        self.isInverted = isInverted
        self.isMoving = isMoving
    }
}

/// A filled background
public struct BackgroundTypeFill: Codable, Equatable, Hashable {

    /// The background fill
    public let fill: BackgroundFill


    public init(fill: BackgroundFill) {
        self.fill = fill
    }
}

/// A background from a chat theme based on an emoji; can be used only as a chat background in channels
public struct BackgroundTypeChatTheme: Codable, Equatable, Hashable {

    /// Name of the emoji chat theme
    public let themeName: String


    public init(themeName: String) {
        self.themeName = themeName
    }
}

