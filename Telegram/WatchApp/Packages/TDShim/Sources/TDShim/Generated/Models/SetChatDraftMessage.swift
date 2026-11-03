//
//  SetChatDraftMessage.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Changes the draft message in a chat or a topic
public struct SetChatDraftMessage: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64?

    /// New draft message; pass null to remove the draft. All files in draft message content must be of the type inputFileLocal. Media thumbnails and captions are ignored
    public let draftMessage: DraftMessage?

    /// Topic in which the draft will be changed; pass null to change the draft for the chat itself
    public let topicId: MessageTopic?


    public init(
        chatId: Int64?,
        draftMessage: DraftMessage?,
        topicId: MessageTopic?
    ) {
        self.chatId = chatId
        self.draftMessage = draftMessage
        self.topicId = topicId
    }
}

