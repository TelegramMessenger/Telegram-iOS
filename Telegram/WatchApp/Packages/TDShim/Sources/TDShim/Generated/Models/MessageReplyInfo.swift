//
//  MessageReplyInfo.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about replies to a message
public struct MessageReplyInfo: Codable, Equatable, Hashable {

    /// Identifier of the last reply to the message
    public let lastMessageId: Int64

    /// Identifier of the last read incoming reply to the message
    public let lastReadInboxMessageId: Int64

    /// Identifier of the last read outgoing reply to the message
    public let lastReadOutboxMessageId: Int64

    /// Identifiers of at most 3 recent repliers to the message; available in channels with a discussion supergroup. The users and chats are expected to be inaccessible: only their photo and name will be available
    public let recentReplierIds: [MessageSender]

    /// Number of times the message was directly or indirectly replied
    public let replyCount: Int


    public init(
        lastMessageId: Int64,
        lastReadInboxMessageId: Int64,
        lastReadOutboxMessageId: Int64,
        recentReplierIds: [MessageSender],
        replyCount: Int
    ) {
        self.lastMessageId = lastMessageId
        self.lastReadInboxMessageId = lastReadInboxMessageId
        self.lastReadOutboxMessageId = lastReadOutboxMessageId
        self.recentReplierIds = recentReplierIds
        self.replyCount = replyCount
    }
}

