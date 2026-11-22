//
//  DraftMessage.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about a message draft
public struct DraftMessage: Codable, Equatable, Hashable {

    /// Point in time (Unix timestamp) when the draft was created
    public let date: Int

    /// Identifier of the effect to apply to the message when it is sent; 0 if none
    public let effectId: TdInt64

    /// Content of the message draft; must be of the type inputMessageText, inputMessageVideoNote, or inputMessageVoiceNote
    public let inputMessageText: InputMessageContent

    /// Information about the message to be replied; inputMessageReplyToStory is unsupported; may be null if none
    public let replyTo: InputMessageReplyTo?

    /// Information about the suggested post; may be null if none
    public let suggestedPostInfo: InputSuggestedPostInfo?


    public init(
        date: Int,
        effectId: TdInt64,
        inputMessageText: InputMessageContent,
        replyTo: InputMessageReplyTo?,
        suggestedPostInfo: InputSuggestedPostInfo?
    ) {
        self.date = date
        self.effectId = effectId
        self.inputMessageText = inputMessageText
        self.replyTo = replyTo
        self.suggestedPostInfo = suggestedPostInfo
    }
}

