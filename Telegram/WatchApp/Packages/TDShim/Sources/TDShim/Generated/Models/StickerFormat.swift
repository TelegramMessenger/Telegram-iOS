//
//  StickerFormat.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes format of a sticker
public indirect enum StickerFormat: Codable, Equatable, Hashable {

    /// The sticker is an image in WEBP format
    case stickerFormatWebp

    /// The sticker is an animation in TGS format
    case stickerFormatTgs

    /// The sticker is a video in WEBM format
    case stickerFormatWebm

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case stickerFormatWebp
        case stickerFormatTgs
        case stickerFormatWebm
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .stickerFormatWebp:
            self = .stickerFormatWebp
        case .stickerFormatTgs:
            self = .stickerFormatTgs
        case .stickerFormatWebm:
            self = .stickerFormatWebm
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .stickerFormatWebp:
            try container.encode(Kind.stickerFormatWebp, forKey: .type)
        case .stickerFormatTgs:
            try container.encode(Kind.stickerFormatTgs, forKey: .type)
        case .stickerFormatWebm:
            try container.encode(Kind.stickerFormatWebm, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

