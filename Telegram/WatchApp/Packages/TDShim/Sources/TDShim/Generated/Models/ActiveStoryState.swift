//
//  ActiveStoryState.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes state of active stories posted by a chat
public indirect enum ActiveStoryState: Codable, Equatable, Hashable {

    /// The chat has an active live story
    case activeStoryStateLive(ActiveStoryStateLive)

    /// The chat has some unread active stories
    case activeStoryStateUnread

    /// The chat has active stories, all of which were read
    case activeStoryStateRead

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case activeStoryStateLive
        case activeStoryStateUnread
        case activeStoryStateRead
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .activeStoryStateLive:
            let value = try ActiveStoryStateLive(from: decoder)
            self = .activeStoryStateLive(value)
        case .activeStoryStateUnread:
            self = .activeStoryStateUnread
        case .activeStoryStateRead:
            self = .activeStoryStateRead
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .activeStoryStateLive(let value):
            try container.encode(Kind.activeStoryStateLive, forKey: .type)
            try value.encode(to: encoder)
        case .activeStoryStateUnread:
            try container.encode(Kind.activeStoryStateUnread, forKey: .type)
        case .activeStoryStateRead:
            try container.encode(Kind.activeStoryStateRead, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The chat has an active live story
public struct ActiveStoryStateLive: Codable, Equatable, Hashable {

    /// Identifier of the active live story
    public let storyId: Int


    public init(storyId: Int) {
        self.storyId = storyId
    }
}

