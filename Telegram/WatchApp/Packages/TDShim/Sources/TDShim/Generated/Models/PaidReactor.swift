//
//  PaidReactor.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about a user who added paid reactions
public struct PaidReactor: Codable, Equatable, Hashable {

    /// True, if the reactor is anonymous
    public let isAnonymous: Bool

    /// True, if the paid reaction was added by the current user
    public let isMe: Bool

    /// True, if the reactor is one of the most active reactors; may be false if the reactor is the current user
    public let isTop: Bool

    /// Identifier of the user or chat that added the reactions; may be null for anonymous reactors that aren't the current user
    public let senderId: MessageSender?

    /// Number of Telegram Stars added
    public let starCount: Int64


    public init(
        isAnonymous: Bool,
        isMe: Bool,
        isTop: Bool,
        senderId: MessageSender?,
        starCount: Int64
    ) {
        self.isAnonymous = isAnonymous
        self.isMe = isMe
        self.isTop = isTop
        self.senderId = senderId
        self.starCount = starCount
    }
}

