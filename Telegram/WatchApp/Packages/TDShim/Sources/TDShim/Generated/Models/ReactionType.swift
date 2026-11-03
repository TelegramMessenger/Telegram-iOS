//
//  ReactionType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes type of message reaction
public indirect enum ReactionType: Codable, Equatable, Hashable {

    /// A reaction with an emoji
    case reactionTypeEmoji(ReactionTypeEmoji)

    /// A reaction with a custom emoji
    case reactionTypeCustomEmoji(ReactionTypeCustomEmoji)

    /// The paid reaction in a channel chat
    case reactionTypePaid

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case reactionTypeEmoji
        case reactionTypeCustomEmoji
        case reactionTypePaid
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .reactionTypeEmoji:
            let value = try ReactionTypeEmoji(from: decoder)
            self = .reactionTypeEmoji(value)
        case .reactionTypeCustomEmoji:
            let value = try ReactionTypeCustomEmoji(from: decoder)
            self = .reactionTypeCustomEmoji(value)
        case .reactionTypePaid:
            self = .reactionTypePaid
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .reactionTypeEmoji(let value):
            try container.encode(Kind.reactionTypeEmoji, forKey: .type)
            try value.encode(to: encoder)
        case .reactionTypeCustomEmoji(let value):
            try container.encode(Kind.reactionTypeCustomEmoji, forKey: .type)
            try value.encode(to: encoder)
        case .reactionTypePaid:
            try container.encode(Kind.reactionTypePaid, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A reaction with an emoji
public struct ReactionTypeEmoji: Codable, Equatable, Hashable {

    /// Text representation of the reaction
    public let emoji: String


    public init(emoji: String) {
        self.emoji = emoji
    }
}

/// A reaction with a custom emoji
public struct ReactionTypeCustomEmoji: Codable, Equatable, Hashable {

    /// Unique identifier of the custom emoji
    public let customEmojiId: TdInt64


    public init(customEmojiId: TdInt64) {
        self.customEmojiId = customEmojiId
    }
}

