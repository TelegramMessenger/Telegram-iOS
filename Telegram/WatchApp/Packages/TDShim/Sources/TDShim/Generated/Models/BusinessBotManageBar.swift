//
//  BusinessBotManageBar.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about a business bot that manages the chat
public struct BusinessBotManageBar: Codable, Equatable, Hashable {

    /// User identifier of the bot
    public let botUserId: Int64

    /// True, if the bot can reply
    public let canBotReply: Bool

    /// True, if the bot is paused. Use toggleBusinessConnectedBotChatIsPaused to change the value of the field
    public let isBotPaused: Bool

    /// URL to be opened to manage the bot
    public let manageUrl: String


    public init(
        botUserId: Int64,
        canBotReply: Bool,
        isBotPaused: Bool,
        manageUrl: String
    ) {
        self.botUserId = botUserId
        self.canBotReply = canBotReply
        self.isBotPaused = isBotPaused
        self.manageUrl = manageUrl
    }
}

