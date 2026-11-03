//
//  StoryContentType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains the type of the content of a story
public indirect enum StoryContentType: Codable, Equatable, Hashable {

    /// A photo story
    case storyContentTypePhoto

    /// A video story
    case storyContentTypeVideo

    /// A live story
    case storyContentTypeLive

    /// A story of unknown content type
    case storyContentTypeUnsupported

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case storyContentTypePhoto
        case storyContentTypeVideo
        case storyContentTypeLive
        case storyContentTypeUnsupported
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .storyContentTypePhoto:
            self = .storyContentTypePhoto
        case .storyContentTypeVideo:
            self = .storyContentTypeVideo
        case .storyContentTypeLive:
            self = .storyContentTypeLive
        case .storyContentTypeUnsupported:
            self = .storyContentTypeUnsupported
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .storyContentTypePhoto:
            try container.encode(Kind.storyContentTypePhoto, forKey: .type)
        case .storyContentTypeVideo:
            try container.encode(Kind.storyContentTypeVideo, forKey: .type)
        case .storyContentTypeLive:
            try container.encode(Kind.storyContentTypeLive, forKey: .type)
        case .storyContentTypeUnsupported:
            try container.encode(Kind.storyContentTypeUnsupported, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

