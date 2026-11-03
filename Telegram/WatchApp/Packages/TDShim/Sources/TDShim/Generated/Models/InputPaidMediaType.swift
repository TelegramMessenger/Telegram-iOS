//
//  InputPaidMediaType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes type of paid media to sent
public indirect enum InputPaidMediaType: Codable, Equatable, Hashable {

    /// The media is a photo. The photo must be at most 10 MB in size. The photo's width and height must not exceed 10000 in total. Width and height ratio must be at most 20
    case inputPaidMediaTypePhoto(InputPaidMediaTypePhoto)

    /// The media is a video
    case inputPaidMediaTypeVideo(InputPaidMediaTypeVideo)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case inputPaidMediaTypePhoto
        case inputPaidMediaTypeVideo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .inputPaidMediaTypePhoto:
            let value = try InputPaidMediaTypePhoto(from: decoder)
            self = .inputPaidMediaTypePhoto(value)
        case .inputPaidMediaTypeVideo:
            let value = try InputPaidMediaTypeVideo(from: decoder)
            self = .inputPaidMediaTypeVideo(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .inputPaidMediaTypePhoto(let value):
            try container.encode(Kind.inputPaidMediaTypePhoto, forKey: .type)
            try value.encode(to: encoder)
        case .inputPaidMediaTypeVideo(let value):
            try container.encode(Kind.inputPaidMediaTypeVideo, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The media is a photo. The photo must be at most 10 MB in size. The photo's width and height must not exceed 10000 in total. Width and height ratio must be at most 20
public struct InputPaidMediaTypePhoto: Codable, Equatable, Hashable {

    /// Video of the live photo; pass null if the photo isn't a live photo
    public let video: InputFile?


    public init(video: InputFile?) {
        self.video = video
    }
}

/// The media is a video
public struct InputPaidMediaTypeVideo: Codable, Equatable, Hashable {

    /// Cover of the video; pass null to skip cover uploading
    public let cover: InputFile?

    /// Duration of the video, in seconds
    public let duration: Int

    /// Timestamp from which the video playing must start, in seconds
    public let startTimestamp: Int

    /// True, if the video is expected to be streamed
    public let supportsStreaming: Bool


    public init(
        cover: InputFile?,
        duration: Int,
        startTimestamp: Int,
        supportsStreaming: Bool
    ) {
        self.cover = cover
        self.duration = duration
        self.startTimestamp = startTimestamp
        self.supportsStreaming = supportsStreaming
    }
}

