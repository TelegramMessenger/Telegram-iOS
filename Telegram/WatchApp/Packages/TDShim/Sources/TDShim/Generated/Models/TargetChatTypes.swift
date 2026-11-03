//
//  TargetChatTypes.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes allowed types for the target chat
public struct TargetChatTypes: Codable, Equatable, Hashable {

    /// True, if private chats with other bots are allowed
    public let allowBotChats: Bool

    /// True, if channel chats are allowed
    public let allowChannelChats: Bool

    /// True, if basic group and supergroup chats are allowed
    public let allowGroupChats: Bool

    /// True, if private chats with ordinary users are allowed
    public let allowUserChats: Bool


    public init(
        allowBotChats: Bool,
        allowChannelChats: Bool,
        allowGroupChats: Bool,
        allowUserChats: Bool
    ) {
        self.allowBotChats = allowBotChats
        self.allowChannelChats = allowChannelChats
        self.allowGroupChats = allowGroupChats
        self.allowUserChats = allowUserChats
    }
}

