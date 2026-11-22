//
//  MessageOrigin.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about the origin of a message
public indirect enum MessageOrigin: Codable, Equatable, Hashable {

    /// The message was originally sent by a known user
    case messageOriginUser(MessageOriginUser)

    /// The message was originally sent by a user, which is hidden by their privacy settings
    case messageOriginHiddenUser(MessageOriginHiddenUser)

    /// The message was originally sent on behalf of a chat
    case messageOriginChat(MessageOriginChat)

    /// The message was originally a post in a channel
    case messageOriginChannel(MessageOriginChannel)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case messageOriginUser
        case messageOriginHiddenUser
        case messageOriginChat
        case messageOriginChannel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .messageOriginUser:
            let value = try MessageOriginUser(from: decoder)
            self = .messageOriginUser(value)
        case .messageOriginHiddenUser:
            let value = try MessageOriginHiddenUser(from: decoder)
            self = .messageOriginHiddenUser(value)
        case .messageOriginChat:
            let value = try MessageOriginChat(from: decoder)
            self = .messageOriginChat(value)
        case .messageOriginChannel:
            let value = try MessageOriginChannel(from: decoder)
            self = .messageOriginChannel(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .messageOriginUser(let value):
            try container.encode(Kind.messageOriginUser, forKey: .type)
            try value.encode(to: encoder)
        case .messageOriginHiddenUser(let value):
            try container.encode(Kind.messageOriginHiddenUser, forKey: .type)
            try value.encode(to: encoder)
        case .messageOriginChat(let value):
            try container.encode(Kind.messageOriginChat, forKey: .type)
            try value.encode(to: encoder)
        case .messageOriginChannel(let value):
            try container.encode(Kind.messageOriginChannel, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The message was originally sent by a known user
public struct MessageOriginUser: Codable, Equatable, Hashable {

    /// Identifier of the user who originally sent the message
    public let senderUserId: Int64


    public init(senderUserId: Int64) {
        self.senderUserId = senderUserId
    }
}

/// The message was originally sent by a user, which is hidden by their privacy settings
public struct MessageOriginHiddenUser: Codable, Equatable, Hashable {

    /// Name of the sender
    public let senderName: String


    public init(senderName: String) {
        self.senderName = senderName
    }
}

/// The message was originally sent on behalf of a chat
public struct MessageOriginChat: Codable, Equatable, Hashable {

    /// For messages originally sent by an anonymous chat administrator, original message author signature
    public let authorSignature: String

    /// Identifier of the chat that originally sent the message
    public let senderChatId: Int64


    public init(
        authorSignature: String,
        senderChatId: Int64
    ) {
        self.authorSignature = authorSignature
        self.senderChatId = senderChatId
    }
}

/// The message was originally a post in a channel
public struct MessageOriginChannel: Codable, Equatable, Hashable {

    /// Original post author signature
    public let authorSignature: String

    /// Identifier of the channel chat to which the message was originally sent
    public let chatId: Int64

    /// Message identifier of the original message
    public let messageId: Int64


    public init(
        authorSignature: String,
        chatId: Int64,
        messageId: Int64
    ) {
        self.authorSignature = authorSignature
        self.chatId = chatId
        self.messageId = messageId
    }
}

