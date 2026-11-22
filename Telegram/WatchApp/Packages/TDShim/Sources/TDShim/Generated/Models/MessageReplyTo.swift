//
//  MessageReplyTo.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about the message or the story a message is replying to
public indirect enum MessageReplyTo: Codable, Equatable, Hashable {

    /// Describes a message replied by a given message
    case messageReplyToMessage(MessageReplyToMessage)

    /// Describes a story replied by a given message
    case messageReplyToStory(MessageReplyToStory)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case messageReplyToMessage
        case messageReplyToStory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .messageReplyToMessage:
            let value = try MessageReplyToMessage(from: decoder)
            self = .messageReplyToMessage(value)
        case .messageReplyToStory:
            let value = try MessageReplyToStory(from: decoder)
            self = .messageReplyToStory(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .messageReplyToMessage(let value):
            try container.encode(Kind.messageReplyToMessage, forKey: .type)
            try value.encode(to: encoder)
        case .messageReplyToStory(let value):
            try container.encode(Kind.messageReplyToStory, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// Describes a message replied by a given message
public struct MessageReplyToMessage: Codable, Equatable, Hashable {

    /// The identifier of the chat to which the message belongs; may be 0 if the replied message is in unknown chat
    public let chatId: Int64

    /// Identifier of the checklist task in the original message that was replied; 0 if none
    public let checklistTaskId: Int

    /// Media content of the message if the message was from another chat or topic; may be null for messages from the same chat and messages without media. Can be only one of the following types: messageAnimation, messageAudio, messageChecklist, messageContact, messageDice, messageDocument, messageGame, messageGiveaway, messageGiveawayWinners, messageInvoice, messageLocation, messagePaidMedia, messagePhoto, messagePoll, messageStakeDice, messageSticker, messageStory, messageText (for link preview), messageVenue, messageVideo, messageVideoNote, or messageVoiceNote
    public let content: MessageContent?

    /// The identifier of the message; may be 0 if the replied message is in unknown chat
    public let messageId: Int64

    /// Information about origin of the message if the message was from another chat or topic; may be null for messages from the same chat
    public let origin: MessageOrigin?

    /// Point in time (Unix timestamp) when the message was sent if the message was from another chat or topic; 0 for messages from the same chat
    public let originSendDate: Int

    /// Identifier of the poll option in the original message that was replied; empty if none
    public let pollOptionId: String

    /// Chosen quote from the replied message; may be null if none
    public let quote: TextQuote?


    public init(
        chatId: Int64,
        checklistTaskId: Int,
        content: MessageContent?,
        messageId: Int64,
        origin: MessageOrigin?,
        originSendDate: Int,
        pollOptionId: String,
        quote: TextQuote?
    ) {
        self.chatId = chatId
        self.checklistTaskId = checklistTaskId
        self.content = content
        self.messageId = messageId
        self.origin = origin
        self.originSendDate = originSendDate
        self.pollOptionId = pollOptionId
        self.quote = quote
    }
}

/// Describes a story replied by a given message
public struct MessageReplyToStory: Codable, Equatable, Hashable {

    /// The identifier of the story
    public let storyId: Int

    /// The identifier of the poster of the story
    public let storyPosterChatId: Int64


    public init(
        storyId: Int,
        storyPosterChatId: Int64
    ) {
        self.storyId = storyId
        self.storyPosterChatId = storyPosterChatId
    }
}

