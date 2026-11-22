//
//  PaidMedia.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a paid media
public indirect enum PaidMedia: Codable, Equatable, Hashable {

    /// The media is hidden until the invoice is paid
    case paidMediaPreview(PaidMediaPreview)

    /// The media is a photo
    case paidMediaPhoto(PaidMediaPhoto)

    /// The media is a video
    case paidMediaVideo(PaidMediaVideo)

    /// The media is unsupported
    case paidMediaUnsupported

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case paidMediaPreview
        case paidMediaPhoto
        case paidMediaVideo
        case paidMediaUnsupported
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .paidMediaPreview:
            let value = try PaidMediaPreview(from: decoder)
            self = .paidMediaPreview(value)
        case .paidMediaPhoto:
            let value = try PaidMediaPhoto(from: decoder)
            self = .paidMediaPhoto(value)
        case .paidMediaVideo:
            let value = try PaidMediaVideo(from: decoder)
            self = .paidMediaVideo(value)
        case .paidMediaUnsupported:
            self = .paidMediaUnsupported
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .paidMediaPreview(let value):
            try container.encode(Kind.paidMediaPreview, forKey: .type)
            try value.encode(to: encoder)
        case .paidMediaPhoto(let value):
            try container.encode(Kind.paidMediaPhoto, forKey: .type)
            try value.encode(to: encoder)
        case .paidMediaVideo(let value):
            try container.encode(Kind.paidMediaVideo, forKey: .type)
            try value.encode(to: encoder)
        case .paidMediaUnsupported:
            try container.encode(Kind.paidMediaUnsupported, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The media is hidden until the invoice is paid
public struct PaidMediaPreview: Codable, Equatable, Hashable {

    /// Media duration, in seconds; 0 if unknown
    public let duration: Int

    /// Media height; 0 if unknown
    public let height: Int

    /// Media minithumbnail; may be null
    public let minithumbnail: Minithumbnail?

    /// Media width; 0 if unknown
    public let width: Int


    public init(
        duration: Int,
        height: Int,
        minithumbnail: Minithumbnail?,
        width: Int
    ) {
        self.duration = duration
        self.height = height
        self.minithumbnail = minithumbnail
        self.width = width
    }
}

/// The media is a photo
public struct PaidMediaPhoto: Codable, Equatable, Hashable {

    /// The photo
    public let photo: Photo

    /// The video representing the live photo; may be null if the photo is static
    public let video: Video?


    public init(
        photo: Photo,
        video: Video?
    ) {
        self.photo = photo
        self.video = video
    }
}

/// The media is a video
public struct PaidMediaVideo: Codable, Equatable, Hashable {

    /// Cover of the video; may be null if none
    public let cover: Photo?

    /// Timestamp from which the video playing must start, in seconds
    public let startTimestamp: Int

    /// The video
    public let video: Video


    public init(
        cover: Photo?,
        startTimestamp: Int,
        video: Video
    ) {
        self.cover = cover
        self.startTimestamp = startTimestamp
        self.video = video
    }
}

