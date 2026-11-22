//
//  MessageTopic.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a topic of messages in a chat
public indirect enum MessageTopic: Codable, Equatable, Hashable {

    /// A topic in a non-forum supergroup chat
    case messageTopicThread(MessageTopicThread)

    /// A topic in a forum supergroup chat or a chat with a bot
    case messageTopicForum(MessageTopicForum)

    /// A topic in a channel direct messages chat administered by the current user
    case messageTopicDirectMessages(MessageTopicDirectMessages)

    /// A topic in Saved Messages chat
    case messageTopicSavedMessages(MessageTopicSavedMessages)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case messageTopicThread
        case messageTopicForum
        case messageTopicDirectMessages
        case messageTopicSavedMessages
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .messageTopicThread:
            let value = try MessageTopicThread(from: decoder)
            self = .messageTopicThread(value)
        case .messageTopicForum:
            let value = try MessageTopicForum(from: decoder)
            self = .messageTopicForum(value)
        case .messageTopicDirectMessages:
            let value = try MessageTopicDirectMessages(from: decoder)
            self = .messageTopicDirectMessages(value)
        case .messageTopicSavedMessages:
            let value = try MessageTopicSavedMessages(from: decoder)
            self = .messageTopicSavedMessages(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .messageTopicThread(let value):
            try container.encode(Kind.messageTopicThread, forKey: .type)
            try value.encode(to: encoder)
        case .messageTopicForum(let value):
            try container.encode(Kind.messageTopicForum, forKey: .type)
            try value.encode(to: encoder)
        case .messageTopicDirectMessages(let value):
            try container.encode(Kind.messageTopicDirectMessages, forKey: .type)
            try value.encode(to: encoder)
        case .messageTopicSavedMessages(let value):
            try container.encode(Kind.messageTopicSavedMessages, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A topic in a non-forum supergroup chat
public struct MessageTopicThread: Codable, Equatable, Hashable {

    /// Unique identifier of the message thread
    public let messageThreadId: Int64


    public init(messageThreadId: Int64) {
        self.messageThreadId = messageThreadId
    }
}

/// A topic in a forum supergroup chat or a chat with a bot
public struct MessageTopicForum: Codable, Equatable, Hashable {

    /// Unique identifier of the forum topic
    public let forumTopicId: Int


    public init(forumTopicId: Int) {
        self.forumTopicId = forumTopicId
    }
}

/// A topic in a channel direct messages chat administered by the current user
public struct MessageTopicDirectMessages: Codable, Equatable, Hashable {

    /// Unique identifier of the topic
    public let directMessagesChatTopicId: Int64


    public init(directMessagesChatTopicId: Int64) {
        self.directMessagesChatTopicId = directMessagesChatTopicId
    }
}

/// A topic in Saved Messages chat
public struct MessageTopicSavedMessages: Codable, Equatable, Hashable {

    /// Unique identifier of the Saved Messages topic
    public let savedMessagesTopicId: Int64


    public init(savedMessagesTopicId: Int64) {
        self.savedMessagesTopicId = savedMessagesTopicId
    }
}

