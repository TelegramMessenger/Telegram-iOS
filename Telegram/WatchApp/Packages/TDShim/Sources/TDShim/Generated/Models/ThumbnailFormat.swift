//
//  ThumbnailFormat.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes format of a thumbnail
public indirect enum ThumbnailFormat: Codable, Equatable, Hashable {

    /// The thumbnail is in JPEG format
    case thumbnailFormatJpeg

    /// The thumbnail is in static GIF format. It will be used only for some bot inline query results
    case thumbnailFormatGif

    /// The thumbnail is in MPEG4 format. It will be used only for some animations and videos
    case thumbnailFormatMpeg4

    /// The thumbnail is in PNG format. It will be used only for background patterns
    case thumbnailFormatPng

    /// The thumbnail is in TGS format. It will be used only for sticker sets
    case thumbnailFormatTgs

    /// The thumbnail is in WEBM format. It will be used only for sticker sets
    case thumbnailFormatWebm

    /// The thumbnail is in WEBP format. It will be used only for some stickers and sticker sets
    case thumbnailFormatWebp

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case thumbnailFormatJpeg
        case thumbnailFormatGif
        case thumbnailFormatMpeg4
        case thumbnailFormatPng
        case thumbnailFormatTgs
        case thumbnailFormatWebm
        case thumbnailFormatWebp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .thumbnailFormatJpeg:
            self = .thumbnailFormatJpeg
        case .thumbnailFormatGif:
            self = .thumbnailFormatGif
        case .thumbnailFormatMpeg4:
            self = .thumbnailFormatMpeg4
        case .thumbnailFormatPng:
            self = .thumbnailFormatPng
        case .thumbnailFormatTgs:
            self = .thumbnailFormatTgs
        case .thumbnailFormatWebm:
            self = .thumbnailFormatWebm
        case .thumbnailFormatWebp:
            self = .thumbnailFormatWebp
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .thumbnailFormatJpeg:
            try container.encode(Kind.thumbnailFormatJpeg, forKey: .type)
        case .thumbnailFormatGif:
            try container.encode(Kind.thumbnailFormatGif, forKey: .type)
        case .thumbnailFormatMpeg4:
            try container.encode(Kind.thumbnailFormatMpeg4, forKey: .type)
        case .thumbnailFormatPng:
            try container.encode(Kind.thumbnailFormatPng, forKey: .type)
        case .thumbnailFormatTgs:
            try container.encode(Kind.thumbnailFormatTgs, forKey: .type)
        case .thumbnailFormatWebm:
            try container.encode(Kind.thumbnailFormatWebm, forKey: .type)
        case .thumbnailFormatWebp:
            try container.encode(Kind.thumbnailFormatWebp, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

