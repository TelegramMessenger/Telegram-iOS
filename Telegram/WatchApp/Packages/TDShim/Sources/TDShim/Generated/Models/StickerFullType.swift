//
//  StickerFullType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains full information about sticker type
public indirect enum StickerFullType: Codable, Equatable, Hashable {

    /// The sticker is a regular sticker
    case stickerFullTypeRegular(StickerFullTypeRegular)

    /// The sticker is a mask in WEBP format to be placed on photos or videos
    case stickerFullTypeMask(StickerFullTypeMask)

    /// The sticker is a custom emoji to be used inside message text and caption. Currently, only Telegram Premium users can use custom emoji
    case stickerFullTypeCustomEmoji(StickerFullTypeCustomEmoji)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case stickerFullTypeRegular
        case stickerFullTypeMask
        case stickerFullTypeCustomEmoji
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .stickerFullTypeRegular:
            let value = try StickerFullTypeRegular(from: decoder)
            self = .stickerFullTypeRegular(value)
        case .stickerFullTypeMask:
            let value = try StickerFullTypeMask(from: decoder)
            self = .stickerFullTypeMask(value)
        case .stickerFullTypeCustomEmoji:
            let value = try StickerFullTypeCustomEmoji(from: decoder)
            self = .stickerFullTypeCustomEmoji(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .stickerFullTypeRegular(let value):
            try container.encode(Kind.stickerFullTypeRegular, forKey: .type)
            try value.encode(to: encoder)
        case .stickerFullTypeMask(let value):
            try container.encode(Kind.stickerFullTypeMask, forKey: .type)
            try value.encode(to: encoder)
        case .stickerFullTypeCustomEmoji(let value):
            try container.encode(Kind.stickerFullTypeCustomEmoji, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The sticker is a regular sticker
public struct StickerFullTypeRegular: Codable, Equatable, Hashable {

    /// Premium animation of the sticker; may be null. If present, only Telegram Premium users can use the sticker
    public let premiumAnimation: File?


    public init(premiumAnimation: File?) {
        self.premiumAnimation = premiumAnimation
    }
}

/// The sticker is a mask in WEBP format to be placed on photos or videos
public struct StickerFullTypeMask: Codable, Equatable, Hashable {

    /// Position where the mask is placed; may be null
    public let maskPosition: MaskPosition?


    public init(maskPosition: MaskPosition?) {
        self.maskPosition = maskPosition
    }
}

/// The sticker is a custom emoji to be used inside message text and caption. Currently, only Telegram Premium users can use custom emoji
public struct StickerFullTypeCustomEmoji: Codable, Equatable, Hashable {

    /// Identifier of the custom emoji
    public let customEmojiId: TdInt64

    /// True, if the sticker must be repainted to a text color in messages, the color of the Telegram Premium badge in emoji status, white color on chat photos, or another appropriate color in other places
    public let needsRepainting: Bool


    public init(
        customEmojiId: TdInt64,
        needsRepainting: Bool
    ) {
        self.customEmojiId = customEmojiId
        self.needsRepainting = needsRepainting
    }
}

