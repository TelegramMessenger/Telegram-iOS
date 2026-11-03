//
//  ChatAvailableReactions.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes reactions available in the chat
public indirect enum ChatAvailableReactions: Codable, Equatable, Hashable {

    /// All reactions are available in the chat, excluding the paid reaction and custom reactions in channel chats
    case chatAvailableReactionsAll(ChatAvailableReactionsAll)

    /// Only specific reactions are available in the chat
    case chatAvailableReactionsSome(ChatAvailableReactionsSome)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case chatAvailableReactionsAll
        case chatAvailableReactionsSome
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .chatAvailableReactionsAll:
            let value = try ChatAvailableReactionsAll(from: decoder)
            self = .chatAvailableReactionsAll(value)
        case .chatAvailableReactionsSome:
            let value = try ChatAvailableReactionsSome(from: decoder)
            self = .chatAvailableReactionsSome(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .chatAvailableReactionsAll(let value):
            try container.encode(Kind.chatAvailableReactionsAll, forKey: .type)
            try value.encode(to: encoder)
        case .chatAvailableReactionsSome(let value):
            try container.encode(Kind.chatAvailableReactionsSome, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// All reactions are available in the chat, excluding the paid reaction and custom reactions in channel chats
public struct ChatAvailableReactionsAll: Codable, Equatable, Hashable {

    /// The maximum allowed number of reactions per message; 1-11
    public let maxReactionCount: Int


    public init(maxReactionCount: Int) {
        self.maxReactionCount = maxReactionCount
    }
}

/// Only specific reactions are available in the chat
public struct ChatAvailableReactionsSome: Codable, Equatable, Hashable {

    /// The maximum allowed number of reactions per message; 1-11
    public let maxReactionCount: Int

    /// The list of reactions
    public let reactions: [ReactionType]


    public init(
        maxReactionCount: Int,
        reactions: [ReactionType]
    ) {
        self.maxReactionCount = maxReactionCount
        self.reactions = reactions
    }
}

