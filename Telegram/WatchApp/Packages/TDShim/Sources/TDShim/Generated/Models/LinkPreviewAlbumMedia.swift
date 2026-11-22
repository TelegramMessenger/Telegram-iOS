//
//  LinkPreviewAlbumMedia.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a media from a link preview album
public indirect enum LinkPreviewAlbumMedia: Codable, Equatable, Hashable {

    /// The media is a photo
    case linkPreviewAlbumMediaPhoto(LinkPreviewAlbumMediaPhoto)

    /// The media is a video
    case linkPreviewAlbumMediaVideo(LinkPreviewAlbumMediaVideo)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case linkPreviewAlbumMediaPhoto
        case linkPreviewAlbumMediaVideo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .linkPreviewAlbumMediaPhoto:
            let value = try LinkPreviewAlbumMediaPhoto(from: decoder)
            self = .linkPreviewAlbumMediaPhoto(value)
        case .linkPreviewAlbumMediaVideo:
            let value = try LinkPreviewAlbumMediaVideo(from: decoder)
            self = .linkPreviewAlbumMediaVideo(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .linkPreviewAlbumMediaPhoto(let value):
            try container.encode(Kind.linkPreviewAlbumMediaPhoto, forKey: .type)
            try value.encode(to: encoder)
        case .linkPreviewAlbumMediaVideo(let value):
            try container.encode(Kind.linkPreviewAlbumMediaVideo, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The media is a photo
public struct LinkPreviewAlbumMediaPhoto: Codable, Equatable, Hashable {

    /// Photo description
    public let photo: Photo


    public init(photo: Photo) {
        self.photo = photo
    }
}

/// The media is a video
public struct LinkPreviewAlbumMediaVideo: Codable, Equatable, Hashable {

    /// Video description
    public let video: Video


    public init(video: Video) {
        self.video = video
    }
}

