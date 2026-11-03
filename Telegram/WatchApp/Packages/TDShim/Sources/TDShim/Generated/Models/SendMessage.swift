//
//  SendMessage.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Sends a message. Returns the sent message
public struct SendMessage: Codable, Equatable, Hashable {

    /// Target chat
    public let chatId: Int64?

    /// The content of the message to be sent
    public let inputMessageContent: InputMessageContent?

    /// Options to be used to send the message; pass null to use default options
    public let options: MessageSendOptions?

    /// Markup for replying to the message; pass null if none; for bots only
    public let replyMarkup: ReplyMarkup?

    /// Information about the message or story to be replied; pass null if none
    public let replyTo: InputMessageReplyTo?

    /// Topic in which the message will be sent; pass null if none
    public let topicId: MessageTopic?


    public init(
        chatId: Int64?,
        inputMessageContent: InputMessageContent?,
        options: MessageSendOptions?,
        replyMarkup: ReplyMarkup?,
        replyTo: InputMessageReplyTo?,
        topicId: MessageTopic?
    ) {
        self.chatId = chatId
        self.inputMessageContent = inputMessageContent
        self.options = options
        self.replyMarkup = replyMarkup
        self.replyTo = replyTo
        self.topicId = topicId
    }
}

