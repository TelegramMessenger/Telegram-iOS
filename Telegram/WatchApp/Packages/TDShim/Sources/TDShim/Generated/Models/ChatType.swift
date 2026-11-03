//
//  ChatType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes the type of chat
public indirect enum ChatType: Codable, Equatable, Hashable {

    /// An ordinary chat with a user
    case chatTypePrivate(ChatTypePrivate)

    /// A basic group (a chat with 0-200 other users)
    case chatTypeBasicGroup(ChatTypeBasicGroup)

    /// A supergroup or channel (with unlimited members)
    case chatTypeSupergroup(ChatTypeSupergroup)

    /// A secret chat with a user
    case chatTypeSecret(ChatTypeSecret)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case chatTypePrivate
        case chatTypeBasicGroup
        case chatTypeSupergroup
        case chatTypeSecret
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .chatTypePrivate:
            let value = try ChatTypePrivate(from: decoder)
            self = .chatTypePrivate(value)
        case .chatTypeBasicGroup:
            let value = try ChatTypeBasicGroup(from: decoder)
            self = .chatTypeBasicGroup(value)
        case .chatTypeSupergroup:
            let value = try ChatTypeSupergroup(from: decoder)
            self = .chatTypeSupergroup(value)
        case .chatTypeSecret:
            let value = try ChatTypeSecret(from: decoder)
            self = .chatTypeSecret(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .chatTypePrivate(let value):
            try container.encode(Kind.chatTypePrivate, forKey: .type)
            try value.encode(to: encoder)
        case .chatTypeBasicGroup(let value):
            try container.encode(Kind.chatTypeBasicGroup, forKey: .type)
            try value.encode(to: encoder)
        case .chatTypeSupergroup(let value):
            try container.encode(Kind.chatTypeSupergroup, forKey: .type)
            try value.encode(to: encoder)
        case .chatTypeSecret(let value):
            try container.encode(Kind.chatTypeSecret, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// An ordinary chat with a user
public struct ChatTypePrivate: Codable, Equatable, Hashable {

    /// User identifier
    public let userId: Int64


    public init(userId: Int64) {
        self.userId = userId
    }
}

/// A basic group (a chat with 0-200 other users)
public struct ChatTypeBasicGroup: Codable, Equatable, Hashable {

    /// Basic group identifier
    public let basicGroupId: Int64


    public init(basicGroupId: Int64) {
        self.basicGroupId = basicGroupId
    }
}

/// A supergroup or channel (with unlimited members)
public struct ChatTypeSupergroup: Codable, Equatable, Hashable {

    /// True, if the supergroup is a channel
    public let isChannel: Bool

    /// Supergroup or channel identifier
    public let supergroupId: Int64


    public init(
        isChannel: Bool,
        supergroupId: Int64
    ) {
        self.isChannel = isChannel
        self.supergroupId = supergroupId
    }
}

/// A secret chat with a user
public struct ChatTypeSecret: Codable, Equatable, Hashable {

    /// Secret chat identifier
    public let secretChatId: Int

    /// User identifier of the other user in the secret chat
    public let userId: Int64


    public init(
        secretChatId: Int,
        userId: Int64
    ) {
        self.secretChatId = secretChatId
        self.userId = userId
    }
}

