//
//  ViewMessages.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Informs TDLib that messages are being viewed by the user. Sponsored messages must be marked as viewed only when the entire text of the message is shown on the screen (excluding the button). Many useful activities depend on whether the messages are currently being viewed or not (e.g., marking messages as read, incrementing a view counter, updating a view counter, removing deleted messages in supergroups and channels)
public struct ViewMessages: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64?

    /// Pass true to mark as read the specified messages even if the chat is closed
    public let forceRead: Bool?

    /// The identifiers of the messages being viewed
    public let messageIds: [Int64]?

    /// Source of the message view; pass null to guess the source based on chat open state
    public let source: MessageSource?


    public init(
        chatId: Int64?,
        forceRead: Bool?,
        messageIds: [Int64]?,
        source: MessageSource?
    ) {
        self.chatId = chatId
        self.forceRead = forceRead
        self.messageIds = messageIds
        self.source = source
    }
}

