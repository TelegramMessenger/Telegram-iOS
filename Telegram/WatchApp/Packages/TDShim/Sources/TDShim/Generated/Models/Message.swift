//
//  Message.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Describes a message
public struct Message: Codable, Equatable, Hashable, Identifiable {

    /// For channel posts and anonymous group messages, optional author signature
    public let authorSignature: String

    /// Time left before the message will be automatically deleted by message_auto_delete_time setting of the chat, in seconds; 0 if never
    public let autoDeleteIn: Double

    /// True, if content of the message can be saved locally
    public let canBeSaved: Bool

    /// Chat identifier
    public let chatId: Int64

    /// True, if the message contains an unread mention for the current user
    public let containsUnreadMention: Bool

    /// True, if the message is a poll message with unread votes
    public let containsUnreadPollVotes: Bool

    /// Content of the message
    public let content: MessageContent

    /// Point in time (Unix timestamp) when the message was sent; 0 for scheduled messages
    public let date: Int

    /// Point in time (Unix timestamp) when the message was last edited; 0 for scheduled messages
    public let editDate: Int

    /// Unique identifier of the effect added to the message; 0 if none
    public let effectId: TdInt64

    /// Information about fact-check added to the message; may be null if none
    public let factCheck: FactCheck?

    /// Information about the initial message sender; may be null if none or unknown
    public let forwardInfo: MessageForwardInfo?

    /// The identifier of the user or chat which used a guest bot to send the message; may be null if none
    public let guestBotCallerId: MessageSender?

    /// True, if media timestamp entities refers to a media in this message as opposed to a media in the replied message
    public let hasTimestampedMedia: Bool

    /// Message identifier; unique for the chat to which the message belongs
    public let id: Int64

    /// Information about the initial message for messages created with importMessages; may be null if the message isn't imported
    public let importInfo: MessageImportInfo?

    /// Information about interactions with the message; may be null if none
    public let interactionInfo: MessageInteractionInfo?

    /// True, if the message is a channel post. All messages to channels are channel posts, all other messages are not channel posts
    public let isChannelPost: Bool

    /// True, if the message was sent because of a scheduled action by the message sender, for example, as away, or greeting service message
    public let isFromOffline: Bool

    /// True, if the message is outgoing
    public let isOutgoing: Bool

    /// True, if the message is a suggested channel post which was paid in Telegram Stars; a warning must be shown if the message is deleted in less than getOption("suggested_post_lifetime_min") seconds after sending
    public let isPaidStarSuggestedPost: Bool

    /// True, if the message is a suggested channel post which was paid in Toncoins; a warning must be shown if the message is deleted in less than getOption("suggested_post_lifetime_min") seconds after sending
    public let isPaidTonSuggestedPost: Bool

    /// True, if the message is pinned
    public let isPinned: Bool

    /// Unique identifier of an album this message belongs to; 0 if none. Only audios, documents, photos and videos can be grouped together in albums
    public let mediaAlbumId: TdInt64

    /// The number of Telegram Stars the sender paid to send the message
    public let paidMessageStarCount: Int64

    /// Reply markup for the message; may be null if none
    public let replyMarkup: ReplyMarkup?

    /// Information about the message or the story this message is replying to; may be null if none
    public let replyTo: MessageReplyTo?

    /// Information about the restrictions that must be applied to the message content; may be null if none
    public let restrictionInfo: RestrictionInfo?

    /// The scheduling state of the message; may be null if the message isn't scheduled
    public let schedulingState: MessageSchedulingState?

    /// Time left before the message self-destruct timer expires, in seconds; 0 if self-destruction isn't scheduled yet
    public let selfDestructIn: Double

    /// The message's self-destruct type; may be null if none
    public let selfDestructType: MessageSelfDestructType?

    /// Number of times the sender of the message boosted the supergroup at the time the message was sent; 0 if none or unknown. For messages sent by the current user, supergroupFullInfo.my_boost_count must be used instead
    public let senderBoostCount: Int

    /// If non-zero, the user identifier of the business bot that sent this message
    public let senderBusinessBotUserId: Int64

    /// Identifier of the sender of the message
    public let senderId: MessageSender

    /// Tag of the sender of the message in the supergroup at the time the message was sent; may be empty if none or unknown. For messages sent in basic groups or supergroup administrators, the current custom title or tag must be used instead
    public let senderTag: String

    /// The sending state of the message; may be null if the message isn't being sent and didn't fail to be sent
    public let sendingState: MessageSendingState?

    /// Information about the suggested post; may be null if the message isn't a suggested post
    public let suggestedPostInfo: SuggestedPostInfo?

    /// IETF language tag of the message language on which it can be summarized; empty if summary isn't available for the message
    public let summaryLanguageCode: String

    /// Identifier of the topic within the chat to which the message belongs; may be null if none; may change when the chat is converted to a forum or back
    public let topicId: MessageTopic?

    /// Information about unread reactions added to the message
    public let unreadReactions: [UnreadReaction]

    /// If non-zero, the user identifier of the inline bot through which this message was sent
    public let viaBotUserId: Int64


    public init(
        authorSignature: String,
        autoDeleteIn: Double,
        canBeSaved: Bool,
        chatId: Int64,
        containsUnreadMention: Bool,
        containsUnreadPollVotes: Bool,
        content: MessageContent,
        date: Int,
        editDate: Int,
        effectId: TdInt64,
        factCheck: FactCheck?,
        forwardInfo: MessageForwardInfo?,
        guestBotCallerId: MessageSender?,
        hasTimestampedMedia: Bool,
        id: Int64,
        importInfo: MessageImportInfo?,
        interactionInfo: MessageInteractionInfo?,
        isChannelPost: Bool,
        isFromOffline: Bool,
        isOutgoing: Bool,
        isPaidStarSuggestedPost: Bool,
        isPaidTonSuggestedPost: Bool,
        isPinned: Bool,
        mediaAlbumId: TdInt64,
        paidMessageStarCount: Int64,
        replyMarkup: ReplyMarkup?,
        replyTo: MessageReplyTo?,
        restrictionInfo: RestrictionInfo?,
        schedulingState: MessageSchedulingState?,
        selfDestructIn: Double,
        selfDestructType: MessageSelfDestructType?,
        senderBoostCount: Int,
        senderBusinessBotUserId: Int64,
        senderId: MessageSender,
        senderTag: String,
        sendingState: MessageSendingState?,
        suggestedPostInfo: SuggestedPostInfo?,
        summaryLanguageCode: String,
        topicId: MessageTopic?,
        unreadReactions: [UnreadReaction],
        viaBotUserId: Int64
    ) {
        self.authorSignature = authorSignature
        self.autoDeleteIn = autoDeleteIn
        self.canBeSaved = canBeSaved
        self.chatId = chatId
        self.containsUnreadMention = containsUnreadMention
        self.containsUnreadPollVotes = containsUnreadPollVotes
        self.content = content
        self.date = date
        self.editDate = editDate
        self.effectId = effectId
        self.factCheck = factCheck
        self.forwardInfo = forwardInfo
        self.guestBotCallerId = guestBotCallerId
        self.hasTimestampedMedia = hasTimestampedMedia
        self.id = id
        self.importInfo = importInfo
        self.interactionInfo = interactionInfo
        self.isChannelPost = isChannelPost
        self.isFromOffline = isFromOffline
        self.isOutgoing = isOutgoing
        self.isPaidStarSuggestedPost = isPaidStarSuggestedPost
        self.isPaidTonSuggestedPost = isPaidTonSuggestedPost
        self.isPinned = isPinned
        self.mediaAlbumId = mediaAlbumId
        self.paidMessageStarCount = paidMessageStarCount
        self.replyMarkup = replyMarkup
        self.replyTo = replyTo
        self.restrictionInfo = restrictionInfo
        self.schedulingState = schedulingState
        self.selfDestructIn = selfDestructIn
        self.selfDestructType = selfDestructType
        self.senderBoostCount = senderBoostCount
        self.senderBusinessBotUserId = senderBusinessBotUserId
        self.senderId = senderId
        self.senderTag = senderTag
        self.sendingState = sendingState
        self.suggestedPostInfo = suggestedPostInfo
        self.summaryLanguageCode = summaryLanguageCode
        self.topicId = topicId
        self.unreadReactions = unreadReactions
        self.viaBotUserId = viaBotUserId
    }
}

