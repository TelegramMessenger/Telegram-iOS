//
//  UpgradedGiftOriginalDetails.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes the original details about the gift
public struct UpgradedGiftOriginalDetails: Codable, Equatable, Hashable {

    /// Point in time (Unix timestamp) when the gift was sent
    public let date: Int

    /// Identifier of the user or the chat that received the gift
    public let receiverId: MessageSender

    /// Identifier of the user or the chat that sent the gift; may be null if the gift was private
    public let senderId: MessageSender?

    /// Message added to the gift
    public let text: FormattedText


    public init(
        date: Int,
        receiverId: MessageSender,
        senderId: MessageSender?,
        text: FormattedText
    ) {
        self.date = date
        self.receiverId = receiverId
        self.senderId = senderId
        self.text = text
    }
}

