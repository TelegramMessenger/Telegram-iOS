//
//  MessageInteractionInfo.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains information about interactions with a message
public struct MessageInteractionInfo: Codable, Equatable, Hashable {

    /// Number of times the message was forwarded
    public let forwardCount: Int

    /// The list of reactions or tags added to the message; may be null
    public let reactions: MessageReactions?

    /// Information about direct or indirect replies to the message; may be null. Currently, available only in channels with a discussion supergroup and discussion supergroups for messages, which are not replies itself
    public let replyInfo: MessageReplyInfo?

    /// Number of times the message was viewed
    public let viewCount: Int


    public init(
        forwardCount: Int,
        reactions: MessageReactions?,
        replyInfo: MessageReplyInfo?,
        viewCount: Int
    ) {
        self.forwardCount = forwardCount
        self.reactions = reactions
        self.replyInfo = replyInfo
        self.viewCount = viewCount
    }
}

