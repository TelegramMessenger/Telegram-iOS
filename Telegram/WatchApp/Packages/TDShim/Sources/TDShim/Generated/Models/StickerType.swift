//
//  StickerType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes type of sticker
public indirect enum StickerType: Codable, Equatable, Hashable {

    /// The sticker is a regular sticker
    case stickerTypeRegular

    /// The sticker is a mask in WEBP format to be placed on photos or videos
    case stickerTypeMask

    /// The sticker is a custom emoji to be used inside message text and caption
    case stickerTypeCustomEmoji

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case stickerTypeRegular
        case stickerTypeMask
        case stickerTypeCustomEmoji
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .stickerTypeRegular:
            self = .stickerTypeRegular
        case .stickerTypeMask:
            self = .stickerTypeMask
        case .stickerTypeCustomEmoji:
            self = .stickerTypeCustomEmoji
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .stickerTypeRegular:
            try container.encode(Kind.stickerTypeRegular, forKey: .type)
        case .stickerTypeMask:
            try container.encode(Kind.stickerTypeMask, forKey: .type)
        case .stickerTypeCustomEmoji:
            try container.encode(Kind.stickerTypeCustomEmoji, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

