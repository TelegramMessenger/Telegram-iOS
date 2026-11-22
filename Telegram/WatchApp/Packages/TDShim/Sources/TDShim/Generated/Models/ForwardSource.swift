//
//  ForwardSource.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about the last message from which a new message was forwarded last time
public struct ForwardSource: Codable, Equatable, Hashable {

    /// Identifier of the chat to which the message that was forwarded belonged; may be 0 if unknown
    public let chatId: Int64

    /// Point in time (Unix timestamp) when the message is sent; 0 if unknown
    public let date: Int

    /// True, if the message that was forwarded is outgoing; always false if sender is unknown
    public let isOutgoing: Bool

    /// Identifier of the message; may be 0 if unknown
    public let messageId: Int64

    /// Identifier of the sender of the message; may be null if unknown or the new message was forwarded not to Saved Messages
    public let senderId: MessageSender?

    /// Name of the sender of the message if the sender is hidden by their privacy settings
    public let senderName: String


    public init(
        chatId: Int64,
        date: Int,
        isOutgoing: Bool,
        messageId: Int64,
        senderId: MessageSender?,
        senderName: String
    ) {
        self.chatId = chatId
        self.date = date
        self.isOutgoing = isOutgoing
        self.messageId = messageId
        self.senderId = senderId
        self.senderName = senderName
    }
}

