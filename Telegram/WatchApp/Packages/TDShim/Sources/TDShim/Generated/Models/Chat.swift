//
//  Chat.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// A chat. (Can be a private chat, basic group, supergroup, or secret chat)
public struct Chat: Codable, Equatable, Hashable, Identifiable {

    /// Identifier of the accent color for message sender name, and backgrounds of chat photo, reply header, and link preview
    public let accentColorId: Int

    /// Information about actions which must be possible to do through the chat action bar; may be null if none
    public let actionBar: ChatActionBar?

    /// Types of reaction, available in the chat
    public let availableReactions: ChatAvailableReactions

    /// Background set for the chat; may be null if none
    public let background: ChatBackground?

    /// Identifier of a custom emoji to be shown on the reply header and link preview background for messages sent by the chat; 0 if none
    public let backgroundCustomEmojiId: TdInt64

    /// Block list to which the chat is added; may be null if none
    public let blockList: BlockList?

    /// Information about bar for managing a business bot in the chat; may be null if none
    public let businessBotManageBar: BusinessBotManageBar?

    /// True, if the chat messages can be deleted for all users
    public let canBeDeletedForAllUsers: Bool

    /// True, if the chat messages can be deleted only for the current user while other users will continue to see the messages
    public let canBeDeletedOnlyForSelf: Bool

    /// True, if the chat can be reported to Telegram moderators through reportChat or reportChatPhoto
    public let canBeReported: Bool

    /// Chat lists to which the chat belongs. A chat can have a non-zero position in a chat list even if it doesn't belong to the chat list and have no position in a chat list even if it belongs to the chat list
    public let chatLists: [ChatList]

    /// Application-specific data associated with the chat. (For example, the chat scroll position or local chat notification settings can be stored here.) Persistent if the message database is used
    public let clientData: String

    /// Default value of the disable_notification parameter, used when a message is sent to the chat
    public let defaultDisableNotification: Bool

    /// A draft of a message in the chat; may be null if none
    public let draftMessage: DraftMessage?

    /// Emoji status to be shown along with chat title; may be null
    public let emojiStatus: EmojiStatus?

    /// True, if chat content can't be saved locally, forwarded, or copied
    public let hasProtectedContent: Bool

    /// True, if the chat has scheduled messages
    public let hasScheduledMessages: Bool

    /// Chat unique identifier
    public let id: Int64

    /// True, if the chat is marked as unread
    public let isMarkedAsUnread: Bool

    /// True, if translation of all messages in the chat must be suggested to the user
    public let isTranslatable: Bool

    /// Last message in the chat; may be null if none or unknown
    public let lastMessage: Message?

    /// Identifier of the last read incoming message
    public let lastReadInboxMessageId: Int64

    /// Identifier of the last read outgoing message
    public let lastReadOutboxMessageId: Int64

    /// Current message auto-delete or self-destruct timer setting for the chat, in seconds; 0 if disabled. Self-destruct timer in secret chats starts after the message or its content is viewed. Auto-delete timer in other chats starts from the send date
    public let messageAutoDeleteTime: Int

    /// Identifier of a user or chat that is selected to send messages in the chat; may be null if the user can't change message sender
    public let messageSenderId: MessageSender?

    /// Notification settings for the chat
    public let notificationSettings: ChatNotificationSettings

    /// Information about pending join requests; may be null if none
    public let pendingJoinRequests: ChatJoinRequestsInfo?

    /// Actions that non-administrator chat members are allowed to take in the chat
    public let permissions: ChatPermissions

    /// Chat photo; may be null
    public let photo: ChatPhotoInfo?

    /// Positions of the chat in chat lists
    public let positions: [ChatPosition]

    /// Identifier of the profile accent color for the chat's profile; -1 if none
    public let profileAccentColorId: Int

    /// Identifier of a custom emoji to be shown on the background of the chat's profile; 0 if none
    public let profileBackgroundCustomEmojiId: TdInt64

    /// Identifier of the message from which reply markup needs to be used; 0 if there is no reply markup in the chat
    public let replyMarkupMessageId: Int64

    /// Theme set for the chat; may be null if none
    public let theme: ChatTheme?

    /// Chat title
    public let title: String

    /// Type of the chat
    public let type: ChatType

    /// Number of unread messages in the chat
    public let unreadCount: Int

    /// Number of unread messages with a mention/reply in the chat
    public let unreadMentionCount: Int

    /// Number of messages with unread poll votes in the chat
    public let unreadPollVoteCount: Int

    /// Number of messages with unread reactions in the chat
    public let unreadReactionCount: Int

    /// Color scheme based on an upgraded gift to be used for the chat instead of accent_color_id and background_custom_emoji_id; may be null if none
    public let upgradedGiftColors: UpgradedGiftColors?

    /// Information about video chat of the chat
    public let videoChat: VideoChat

    /// True, if the chat is a forum supergroup that must be shown in the "View as topics" mode, or Saved Messages chat that must be shown in the "View as chats"
    public let viewAsTopics: Bool


    public init(
        accentColorId: Int,
        actionBar: ChatActionBar?,
        availableReactions: ChatAvailableReactions,
        background: ChatBackground?,
        backgroundCustomEmojiId: TdInt64,
        blockList: BlockList?,
        businessBotManageBar: BusinessBotManageBar?,
        canBeDeletedForAllUsers: Bool,
        canBeDeletedOnlyForSelf: Bool,
        canBeReported: Bool,
        chatLists: [ChatList],
        clientData: String,
        defaultDisableNotification: Bool,
        draftMessage: DraftMessage?,
        emojiStatus: EmojiStatus?,
        hasProtectedContent: Bool,
        hasScheduledMessages: Bool,
        id: Int64,
        isMarkedAsUnread: Bool,
        isTranslatable: Bool,
        lastMessage: Message?,
        lastReadInboxMessageId: Int64,
        lastReadOutboxMessageId: Int64,
        messageAutoDeleteTime: Int,
        messageSenderId: MessageSender?,
        notificationSettings: ChatNotificationSettings,
        pendingJoinRequests: ChatJoinRequestsInfo?,
        permissions: ChatPermissions,
        photo: ChatPhotoInfo?,
        positions: [ChatPosition],
        profileAccentColorId: Int,
        profileBackgroundCustomEmojiId: TdInt64,
        replyMarkupMessageId: Int64,
        theme: ChatTheme?,
        title: String,
        type: ChatType,
        unreadCount: Int,
        unreadMentionCount: Int,
        unreadPollVoteCount: Int,
        unreadReactionCount: Int,
        upgradedGiftColors: UpgradedGiftColors?,
        videoChat: VideoChat,
        viewAsTopics: Bool
    ) {
        self.accentColorId = accentColorId
        self.actionBar = actionBar
        self.availableReactions = availableReactions
        self.background = background
        self.backgroundCustomEmojiId = backgroundCustomEmojiId
        self.blockList = blockList
        self.businessBotManageBar = businessBotManageBar
        self.canBeDeletedForAllUsers = canBeDeletedForAllUsers
        self.canBeDeletedOnlyForSelf = canBeDeletedOnlyForSelf
        self.canBeReported = canBeReported
        self.chatLists = chatLists
        self.clientData = clientData
        self.defaultDisableNotification = defaultDisableNotification
        self.draftMessage = draftMessage
        self.emojiStatus = emojiStatus
        self.hasProtectedContent = hasProtectedContent
        self.hasScheduledMessages = hasScheduledMessages
        self.id = id
        self.isMarkedAsUnread = isMarkedAsUnread
        self.isTranslatable = isTranslatable
        self.lastMessage = lastMessage
        self.lastReadInboxMessageId = lastReadInboxMessageId
        self.lastReadOutboxMessageId = lastReadOutboxMessageId
        self.messageAutoDeleteTime = messageAutoDeleteTime
        self.messageSenderId = messageSenderId
        self.notificationSettings = notificationSettings
        self.pendingJoinRequests = pendingJoinRequests
        self.permissions = permissions
        self.photo = photo
        self.positions = positions
        self.profileAccentColorId = profileAccentColorId
        self.profileBackgroundCustomEmojiId = profileBackgroundCustomEmojiId
        self.replyMarkupMessageId = replyMarkupMessageId
        self.theme = theme
        self.title = title
        self.type = type
        self.unreadCount = unreadCount
        self.unreadMentionCount = unreadMentionCount
        self.unreadPollVoteCount = unreadPollVoteCount
        self.unreadReactionCount = unreadReactionCount
        self.upgradedGiftColors = upgradedGiftColors
        self.videoChat = videoChat
        self.viewAsTopics = viewAsTopics
    }
}

