//
//  ChatActionBar.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes actions which must be possible to do through a chat action bar
public indirect enum ChatActionBar: Codable, Equatable, Hashable {

    /// The chat can be reported as spam using the method reportChat with an empty option_id and message_ids. If the chat is a private chat with a user with an emoji status, then a notice about emoji status usage must be shown
    case chatActionBarReportSpam(ChatActionBarReportSpam)

    /// The chat is a recently created group chat to which new members can be invited
    case chatActionBarInviteMembers

    /// The chat is a private or secret chat, which can be reported using the method reportChat, or the other user can be blocked using the method setMessageSenderBlockList, or the other user can be added to the contact list using the method addContact. If the chat is a private chat with a user with an emoji status, then a notice about emoji status usage must be shown
    case chatActionBarReportAddBlock(ChatActionBarReportAddBlock)

    /// The chat is a private or secret chat and the other user can be added to the contact list using the method addContact
    case chatActionBarAddContact

    /// The chat is a private or secret chat with a mutual contact and the user's phone number can be shared with the other user using the method sharePhoneNumber
    case chatActionBarSharePhoneNumber

    /// The chat is a private chat with an administrator of a chat to which the user sent join request
    case chatActionBarJoinRequest(ChatActionBarJoinRequest)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case chatActionBarReportSpam
        case chatActionBarInviteMembers
        case chatActionBarReportAddBlock
        case chatActionBarAddContact
        case chatActionBarSharePhoneNumber
        case chatActionBarJoinRequest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .chatActionBarReportSpam:
            let value = try ChatActionBarReportSpam(from: decoder)
            self = .chatActionBarReportSpam(value)
        case .chatActionBarInviteMembers:
            self = .chatActionBarInviteMembers
        case .chatActionBarReportAddBlock:
            let value = try ChatActionBarReportAddBlock(from: decoder)
            self = .chatActionBarReportAddBlock(value)
        case .chatActionBarAddContact:
            self = .chatActionBarAddContact
        case .chatActionBarSharePhoneNumber:
            self = .chatActionBarSharePhoneNumber
        case .chatActionBarJoinRequest:
            let value = try ChatActionBarJoinRequest(from: decoder)
            self = .chatActionBarJoinRequest(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .chatActionBarReportSpam(let value):
            try container.encode(Kind.chatActionBarReportSpam, forKey: .type)
            try value.encode(to: encoder)
        case .chatActionBarInviteMembers:
            try container.encode(Kind.chatActionBarInviteMembers, forKey: .type)
        case .chatActionBarReportAddBlock(let value):
            try container.encode(Kind.chatActionBarReportAddBlock, forKey: .type)
            try value.encode(to: encoder)
        case .chatActionBarAddContact:
            try container.encode(Kind.chatActionBarAddContact, forKey: .type)
        case .chatActionBarSharePhoneNumber:
            try container.encode(Kind.chatActionBarSharePhoneNumber, forKey: .type)
        case .chatActionBarJoinRequest(let value):
            try container.encode(Kind.chatActionBarJoinRequest, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The chat can be reported as spam using the method reportChat with an empty option_id and message_ids. If the chat is a private chat with a user with an emoji status, then a notice about emoji status usage must be shown
public struct ChatActionBarReportSpam: Codable, Equatable, Hashable {

    /// If true, the chat was automatically archived and can be moved back to the main chat list using addChatToList simultaneously with setting chat notification settings to default using setChatNotificationSettings
    public let canUnarchive: Bool


    public init(canUnarchive: Bool) {
        self.canUnarchive = canUnarchive
    }
}

/// The chat is a private or secret chat, which can be reported using the method reportChat, or the other user can be blocked using the method setMessageSenderBlockList, or the other user can be added to the contact list using the method addContact. If the chat is a private chat with a user with an emoji status, then a notice about emoji status usage must be shown
public struct ChatActionBarReportAddBlock: Codable, Equatable, Hashable {

    /// Basic information about the other user in the chat; may be null if unknown
    public let accountInfo: AccountInfo?

    /// If true, the chat was automatically archived and can be moved back to the main chat list using addChatToList simultaneously with setting chat notification settings to default using setChatNotificationSettings
    public let canUnarchive: Bool


    public init(
        accountInfo: AccountInfo?,
        canUnarchive: Bool
    ) {
        self.accountInfo = accountInfo
        self.canUnarchive = canUnarchive
    }
}

/// The chat is a private chat with an administrator of a chat to which the user sent join request
public struct ChatActionBarJoinRequest: Codable, Equatable, Hashable {

    /// True, if the join request was sent to a channel chat
    public let isChannel: Bool

    /// Point in time (Unix timestamp) when the join request was sent
    public let requestDate: Int

    /// Title of the chat to which the join request was sent
    public let title: String


    public init(
        isChannel: Bool,
        requestDate: Int,
        title: String
    ) {
        self.isChannel = isChannel
        self.requestDate = requestDate
        self.title = title
    }
}

