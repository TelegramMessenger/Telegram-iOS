//
//  VerificationStatus.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about verification status of a chat or a user
public struct VerificationStatus: Codable, Equatable, Hashable {

    /// Identifier of the custom emoji to be shown as verification sign provided by a bot for the user; 0 if none
    public let botVerificationIconCustomEmojiId: TdInt64

    /// True, if the chat or the user is marked as fake by Telegram
    public let isFake: Bool

    /// True, if the chat or the user is marked as scam by Telegram
    public let isScam: Bool

    /// True, if the chat or the user is verified by Telegram
    public let isVerified: Bool


    public init(
        botVerificationIconCustomEmojiId: TdInt64,
        isFake: Bool,
        isScam: Bool,
        isVerified: Bool
    ) {
        self.botVerificationIconCustomEmojiId = botVerificationIconCustomEmojiId
        self.isFake = isFake
        self.isScam = isScam
        self.isVerified = isVerified
    }
}

