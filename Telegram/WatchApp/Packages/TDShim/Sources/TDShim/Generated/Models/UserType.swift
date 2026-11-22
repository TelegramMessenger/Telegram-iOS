//
//  UserType.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Represents the type of user. The following types are possible: regular users, deleted users and bots
public indirect enum UserType: Codable, Equatable, Hashable {

    /// A regular user
    case userTypeRegular

    /// A deleted user or deleted bot. No information on the user besides the user identifier is available. It is not possible to perform any active actions on this type of user
    case userTypeDeleted

    /// A bot (see https://core.telegram.org/bots)
    case userTypeBot(UserTypeBot)

    /// No information on the user besides the user identifier is available, yet this user has not been deleted. This object is extremely rare and must be handled like a deleted user. It is not possible to perform any actions on users of this type
    case userTypeUnknown

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case userTypeRegular
        case userTypeDeleted
        case userTypeBot
        case userTypeUnknown
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .userTypeRegular:
            self = .userTypeRegular
        case .userTypeDeleted:
            self = .userTypeDeleted
        case .userTypeBot:
            let value = try UserTypeBot(from: decoder)
            self = .userTypeBot(value)
        case .userTypeUnknown:
            self = .userTypeUnknown
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .userTypeRegular:
            try container.encode(Kind.userTypeRegular, forKey: .type)
        case .userTypeDeleted:
            try container.encode(Kind.userTypeDeleted, forKey: .type)
        case .userTypeBot(let value):
            try container.encode(Kind.userTypeBot, forKey: .type)
            try value.encode(to: encoder)
        case .userTypeUnknown:
            try container.encode(Kind.userTypeUnknown, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// A bot (see https://core.telegram.org/bots)
public struct UserTypeBot: Codable, Equatable, Hashable {

    /// The number of recently active users of the bot
    public let activeUserCount: Int

    /// True, if users can create and delete topics in the chat with the bot
    public let allowsUsersToCreateTopics: Bool

    /// True, if the bot can be added to attachment or side menu
    public let canBeAddedToAttachmentMenu: Bool

    /// True, if the bot is owned by the current user and can be edited using the methods toggleBotUsernameIsActive, reorderBotActiveUsernames, setBotProfilePhoto, setBotName, setBotInfoDescription, and setBotInfoShortDescription
    public let canBeEdited: Bool

    /// True, if the bot supports connection to user accounts for chat automation
    public let canConnectToBusiness: Bool

    /// True, if the bot can be invited to basic group and supergroup chats
    public let canJoinGroups: Bool

    /// True, if the bot can manage other bots
    public let canManageBots: Bool

    /// True, if the bot can read all messages in basic group or supergroup chats and not just those addressed to the bot. In private and channel chats a bot can always read all messages
    public let canReadAllGroupMessages: Bool

    /// True, if the bot has the main Web App
    public let hasMainWebApp: Bool

    /// True, if the bot has topics
    public let hasTopics: Bool

    /// Placeholder for inline queries (displayed on the application input field)
    public let inlineQueryPlaceholder: String

    /// True, if the bot supports inline queries
    public let isInline: Bool

    /// True, if the location of the user is expected to be sent with every inline query to this bot
    public let needLocation: Bool

    /// True, if the bot can be queried by username from any non-secret chat
    public let supportsGuestQueries: Bool


    public init(
        activeUserCount: Int,
        allowsUsersToCreateTopics: Bool,
        canBeAddedToAttachmentMenu: Bool,
        canBeEdited: Bool,
        canConnectToBusiness: Bool,
        canJoinGroups: Bool,
        canManageBots: Bool,
        canReadAllGroupMessages: Bool,
        hasMainWebApp: Bool,
        hasTopics: Bool,
        inlineQueryPlaceholder: String,
        isInline: Bool,
        needLocation: Bool,
        supportsGuestQueries: Bool
    ) {
        self.activeUserCount = activeUserCount
        self.allowsUsersToCreateTopics = allowsUsersToCreateTopics
        self.canBeAddedToAttachmentMenu = canBeAddedToAttachmentMenu
        self.canBeEdited = canBeEdited
        self.canConnectToBusiness = canConnectToBusiness
        self.canJoinGroups = canJoinGroups
        self.canManageBots = canManageBots
        self.canReadAllGroupMessages = canReadAllGroupMessages
        self.hasMainWebApp = hasMainWebApp
        self.hasTopics = hasTopics
        self.inlineQueryPlaceholder = inlineQueryPlaceholder
        self.isInline = isInline
        self.needLocation = needLocation
        self.supportsGuestQueries = supportsGuestQueries
    }
}

