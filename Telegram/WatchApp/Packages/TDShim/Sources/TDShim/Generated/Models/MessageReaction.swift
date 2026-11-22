//
//  MessageReaction.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about a reaction to a message
public struct MessageReaction: Codable, Equatable, Hashable {

    /// True, if the reaction is chosen by the current user
    public let isChosen: Bool

    /// Identifiers of at most 3 recent message senders, added the reaction; available in private, basic group and supergroup chats
    public let recentSenderIds: [MessageSender]

    /// Number of times the reaction was added
    public let totalCount: Int

    /// Type of the reaction
    public let type: ReactionType

    /// Identifier of the message sender used by the current user to add the reaction; may be null if unknown or the reaction isn't chosen
    public let usedSenderId: MessageSender?


    public init(
        isChosen: Bool,
        recentSenderIds: [MessageSender],
        totalCount: Int,
        type: ReactionType,
        usedSenderId: MessageSender?
    ) {
        self.isChosen = isChosen
        self.recentSenderIds = recentSenderIds
        self.totalCount = totalCount
        self.type = type
        self.usedSenderId = usedSenderId
    }
}

