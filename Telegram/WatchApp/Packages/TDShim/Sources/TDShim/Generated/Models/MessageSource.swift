//
//  MessageSource.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes source of a message
public indirect enum MessageSource: Codable, Equatable, Hashable {

    /// The message is from a chat history
    case messageSourceChatHistory

    /// The message is from history of a message thread
    case messageSourceMessageThreadHistory

    /// The message is from history of a forum topic
    case messageSourceForumTopicHistory

    /// The message is from history of a topic in a channel direct messages chat administered by the current user
    case messageSourceDirectMessagesChatTopicHistory

    /// The message is from chat, message thread or forum topic history preview
    case messageSourceHistoryPreview

    /// The message is from a chat list or a forum topic list
    case messageSourceChatList

    /// The message is from search results, including file downloads, local file list, outgoing document messages, calendar
    case messageSourceSearch

    /// The message is from a chat event log
    case messageSourceChatEventLog

    /// The message is from a notification
    case messageSourceNotification

    /// The message was screenshotted; the source must be used only if the message content was visible during the screenshot
    case messageSourceScreenshot

    /// The message is from some other source
    case messageSourceOther

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case messageSourceChatHistory
        case messageSourceMessageThreadHistory
        case messageSourceForumTopicHistory
        case messageSourceDirectMessagesChatTopicHistory
        case messageSourceHistoryPreview
        case messageSourceChatList
        case messageSourceSearch
        case messageSourceChatEventLog
        case messageSourceNotification
        case messageSourceScreenshot
        case messageSourceOther
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .messageSourceChatHistory:
            self = .messageSourceChatHistory
        case .messageSourceMessageThreadHistory:
            self = .messageSourceMessageThreadHistory
        case .messageSourceForumTopicHistory:
            self = .messageSourceForumTopicHistory
        case .messageSourceDirectMessagesChatTopicHistory:
            self = .messageSourceDirectMessagesChatTopicHistory
        case .messageSourceHistoryPreview:
            self = .messageSourceHistoryPreview
        case .messageSourceChatList:
            self = .messageSourceChatList
        case .messageSourceSearch:
            self = .messageSourceSearch
        case .messageSourceChatEventLog:
            self = .messageSourceChatEventLog
        case .messageSourceNotification:
            self = .messageSourceNotification
        case .messageSourceScreenshot:
            self = .messageSourceScreenshot
        case .messageSourceOther:
            self = .messageSourceOther
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .messageSourceChatHistory:
            try container.encode(Kind.messageSourceChatHistory, forKey: .type)
        case .messageSourceMessageThreadHistory:
            try container.encode(Kind.messageSourceMessageThreadHistory, forKey: .type)
        case .messageSourceForumTopicHistory:
            try container.encode(Kind.messageSourceForumTopicHistory, forKey: .type)
        case .messageSourceDirectMessagesChatTopicHistory:
            try container.encode(Kind.messageSourceDirectMessagesChatTopicHistory, forKey: .type)
        case .messageSourceHistoryPreview:
            try container.encode(Kind.messageSourceHistoryPreview, forKey: .type)
        case .messageSourceChatList:
            try container.encode(Kind.messageSourceChatList, forKey: .type)
        case .messageSourceSearch:
            try container.encode(Kind.messageSourceSearch, forKey: .type)
        case .messageSourceChatEventLog:
            try container.encode(Kind.messageSourceChatEventLog, forKey: .type)
        case .messageSourceNotification:
            try container.encode(Kind.messageSourceNotification, forKey: .type)
        case .messageSourceScreenshot:
            try container.encode(Kind.messageSourceScreenshot, forKey: .type)
        case .messageSourceOther:
            try container.encode(Kind.messageSourceOther, forKey: .type)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

