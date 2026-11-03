//
//  Update.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Contains notifications about data changes
public indirect enum Update: Codable, Equatable, Hashable {

    /// The user authorization state has changed
    case updateAuthorizationState(UpdateAuthorizationState)

    /// A new message was received; can also be an outgoing message
    case updateNewMessage(UpdateNewMessage)

    /// A request to send a message has reached the Telegram server. This doesn't mean that the message will be sent successfully. This update is sent only if the option "use_quick_ack" is set to true. This update may be sent multiple times for the same message
    case updateMessageSendAcknowledged(UpdateMessageSendAcknowledged)

    /// A message has been successfully sent
    case updateMessageSendSucceeded(UpdateMessageSendSucceeded)

    /// A message failed to send. Be aware that some messages being sent can be irrecoverably deleted, in which case updateDeleteMessages will be received instead of this update
    case updateMessageSendFailed(UpdateMessageSendFailed)

    /// The message content has changed
    case updateMessageContent(UpdateMessageContent)

    /// A new chat has been loaded/created. This update is guaranteed to come before the chat identifier is returned to the application. The chat field changes will be reported through separate updates
    case updateNewChat(UpdateNewChat)

    /// The title of a chat was changed
    case updateChatTitle(UpdateChatTitle)

    /// A chat photo was changed
    case updateChatPhoto(UpdateChatPhoto)

    /// Chat permissions were changed
    case updateChatPermissions(UpdateChatPermissions)

    /// The last message of a chat was changed
    case updateChatLastMessage(UpdateChatLastMessage)

    /// The position of a chat in a chat list has changed. An updateChatLastMessage or updateChatDraftMessage update might be sent instead of the update
    case updateChatPosition(UpdateChatPosition)

    /// A chat was added to a chat list
    case updateChatAddedToList(UpdateChatAddedToList)

    /// A chat was removed from a chat list
    case updateChatRemovedFromList(UpdateChatRemovedFromList)

    /// Incoming messages were read or the number of unread messages has been changed
    case updateChatReadInbox(UpdateChatReadInbox)

    /// Outgoing messages were read
    case updateChatReadOutbox(UpdateChatReadOutbox)

    /// A chat draft has changed. Be aware that the update may come in the currently opened chat but with old content of the draft. If the user has changed the content of the draft, this update mustn't be applied
    case updateChatDraftMessage(UpdateChatDraftMessage)

    /// Notification settings for a chat were changed
    case updateChatNotificationSettings(UpdateChatNotificationSettings)

    /// The list of chat folders or a chat folder has changed
    case updateChatFolders(UpdateChatFolders)

    /// Some messages were deleted
    case updateDeleteMessages(UpdateDeleteMessages)

    /// Some data of a user has changed. This update is guaranteed to come before the user identifier is returned to the application
    case updateUser(UpdateUser)

    /// Information about a file was updated
    case updateFile(UpdateFile)

    /// A poll was updated; for bots only
    case updatePoll(UpdatePoll)

    /// Decoded when the @type is not one of the known cases (forward-compatible).
    case unsupported

    private enum Kind: String, Codable {
        case updateAuthorizationState
        case updateNewMessage
        case updateMessageSendAcknowledged
        case updateMessageSendSucceeded
        case updateMessageSendFailed
        case updateMessageContent
        case updateNewChat
        case updateChatTitle
        case updateChatPhoto
        case updateChatPermissions
        case updateChatLastMessage
        case updateChatPosition
        case updateChatAddedToList
        case updateChatRemovedFromList
        case updateChatReadInbox
        case updateChatReadOutbox
        case updateChatDraftMessage
        case updateChatNotificationSettings
        case updateChatFolders
        case updateDeleteMessages
        case updateUser
        case updateFile
        case updatePoll
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DtoCodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        guard let type = Kind(rawValue: typeString) else {
            self = .unsupported
            return
        }
        switch type {
        case .updateAuthorizationState:
            let value = try UpdateAuthorizationState(from: decoder)
            self = .updateAuthorizationState(value)
        case .updateNewMessage:
            let value = try UpdateNewMessage(from: decoder)
            self = .updateNewMessage(value)
        case .updateMessageSendAcknowledged:
            let value = try UpdateMessageSendAcknowledged(from: decoder)
            self = .updateMessageSendAcknowledged(value)
        case .updateMessageSendSucceeded:
            let value = try UpdateMessageSendSucceeded(from: decoder)
            self = .updateMessageSendSucceeded(value)
        case .updateMessageSendFailed:
            let value = try UpdateMessageSendFailed(from: decoder)
            self = .updateMessageSendFailed(value)
        case .updateMessageContent:
            let value = try UpdateMessageContent(from: decoder)
            self = .updateMessageContent(value)
        case .updateNewChat:
            let value = try UpdateNewChat(from: decoder)
            self = .updateNewChat(value)
        case .updateChatTitle:
            let value = try UpdateChatTitle(from: decoder)
            self = .updateChatTitle(value)
        case .updateChatPhoto:
            let value = try UpdateChatPhoto(from: decoder)
            self = .updateChatPhoto(value)
        case .updateChatPermissions:
            let value = try UpdateChatPermissions(from: decoder)
            self = .updateChatPermissions(value)
        case .updateChatLastMessage:
            let value = try UpdateChatLastMessage(from: decoder)
            self = .updateChatLastMessage(value)
        case .updateChatPosition:
            let value = try UpdateChatPosition(from: decoder)
            self = .updateChatPosition(value)
        case .updateChatAddedToList:
            let value = try UpdateChatAddedToList(from: decoder)
            self = .updateChatAddedToList(value)
        case .updateChatRemovedFromList:
            let value = try UpdateChatRemovedFromList(from: decoder)
            self = .updateChatRemovedFromList(value)
        case .updateChatReadInbox:
            let value = try UpdateChatReadInbox(from: decoder)
            self = .updateChatReadInbox(value)
        case .updateChatReadOutbox:
            let value = try UpdateChatReadOutbox(from: decoder)
            self = .updateChatReadOutbox(value)
        case .updateChatDraftMessage:
            let value = try UpdateChatDraftMessage(from: decoder)
            self = .updateChatDraftMessage(value)
        case .updateChatNotificationSettings:
            let value = try UpdateChatNotificationSettings(from: decoder)
            self = .updateChatNotificationSettings(value)
        case .updateChatFolders:
            let value = try UpdateChatFolders(from: decoder)
            self = .updateChatFolders(value)
        case .updateDeleteMessages:
            let value = try UpdateDeleteMessages(from: decoder)
            self = .updateDeleteMessages(value)
        case .updateUser:
            let value = try UpdateUser(from: decoder)
            self = .updateUser(value)
        case .updateFile:
            let value = try UpdateFile(from: decoder)
            self = .updateFile(value)
        case .updatePoll:
            let value = try UpdatePoll(from: decoder)
            self = .updatePoll(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DtoCodingKeys.self)
        switch self {
        case .updateAuthorizationState(let value):
            try container.encode(Kind.updateAuthorizationState, forKey: .type)
            try value.encode(to: encoder)
        case .updateNewMessage(let value):
            try container.encode(Kind.updateNewMessage, forKey: .type)
            try value.encode(to: encoder)
        case .updateMessageSendAcknowledged(let value):
            try container.encode(Kind.updateMessageSendAcknowledged, forKey: .type)
            try value.encode(to: encoder)
        case .updateMessageSendSucceeded(let value):
            try container.encode(Kind.updateMessageSendSucceeded, forKey: .type)
            try value.encode(to: encoder)
        case .updateMessageSendFailed(let value):
            try container.encode(Kind.updateMessageSendFailed, forKey: .type)
            try value.encode(to: encoder)
        case .updateMessageContent(let value):
            try container.encode(Kind.updateMessageContent, forKey: .type)
            try value.encode(to: encoder)
        case .updateNewChat(let value):
            try container.encode(Kind.updateNewChat, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatTitle(let value):
            try container.encode(Kind.updateChatTitle, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatPhoto(let value):
            try container.encode(Kind.updateChatPhoto, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatPermissions(let value):
            try container.encode(Kind.updateChatPermissions, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatLastMessage(let value):
            try container.encode(Kind.updateChatLastMessage, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatPosition(let value):
            try container.encode(Kind.updateChatPosition, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatAddedToList(let value):
            try container.encode(Kind.updateChatAddedToList, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatRemovedFromList(let value):
            try container.encode(Kind.updateChatRemovedFromList, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatReadInbox(let value):
            try container.encode(Kind.updateChatReadInbox, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatReadOutbox(let value):
            try container.encode(Kind.updateChatReadOutbox, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatDraftMessage(let value):
            try container.encode(Kind.updateChatDraftMessage, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatNotificationSettings(let value):
            try container.encode(Kind.updateChatNotificationSettings, forKey: .type)
            try value.encode(to: encoder)
        case .updateChatFolders(let value):
            try container.encode(Kind.updateChatFolders, forKey: .type)
            try value.encode(to: encoder)
        case .updateDeleteMessages(let value):
            try container.encode(Kind.updateDeleteMessages, forKey: .type)
            try value.encode(to: encoder)
        case .updateUser(let value):
            try container.encode(Kind.updateUser, forKey: .type)
            try value.encode(to: encoder)
        case .updateFile(let value):
            try container.encode(Kind.updateFile, forKey: .type)
            try value.encode(to: encoder)
        case .updatePoll(let value):
            try container.encode(Kind.updatePoll, forKey: .type)
            try value.encode(to: encoder)
        case .unsupported:
            try container.encode("unsupported", forKey: .type)
        }
    }
}

/// The user authorization state has changed
public struct UpdateAuthorizationState: Codable, Equatable, Hashable {

    /// New authorization state
    public let authorizationState: AuthorizationState


    public init(authorizationState: AuthorizationState) {
        self.authorizationState = authorizationState
    }
}

/// A new message was received; can also be an outgoing message
public struct UpdateNewMessage: Codable, Equatable, Hashable {

    /// The new message
    public let message: Message


    public init(message: Message) {
        self.message = message
    }
}

/// A request to send a message has reached the Telegram server. This doesn't mean that the message will be sent successfully. This update is sent only if the option "use_quick_ack" is set to true. This update may be sent multiple times for the same message
public struct UpdateMessageSendAcknowledged: Codable, Equatable, Hashable {

    /// The chat identifier of the sent message
    public let chatId: Int64

    /// A temporary message identifier
    public let messageId: Int64


    public init(
        chatId: Int64,
        messageId: Int64
    ) {
        self.chatId = chatId
        self.messageId = messageId
    }
}

/// A message has been successfully sent
public struct UpdateMessageSendSucceeded: Codable, Equatable, Hashable {

    /// The sent message. Almost any field of the new message can be different from the corresponding field of the original message. For example, the field scheduling_state may change, making the message scheduled, or non-scheduled
    public let message: Message

    /// The previous temporary message identifier
    public let oldMessageId: Int64


    public init(
        message: Message,
        oldMessageId: Int64
    ) {
        self.message = message
        self.oldMessageId = oldMessageId
    }
}

/// A message failed to send. Be aware that some messages being sent can be irrecoverably deleted, in which case updateDeleteMessages will be received instead of this update
public struct UpdateMessageSendFailed: Codable, Equatable, Hashable {

    /// The cause of the message sending failure
    public let error: TDError

    /// The failed to send message
    public let message: Message

    /// The previous temporary message identifier
    public let oldMessageId: Int64


    public init(
        error: TDError,
        message: Message,
        oldMessageId: Int64
    ) {
        self.error = error
        self.message = message
        self.oldMessageId = oldMessageId
    }
}

/// The message content has changed
public struct UpdateMessageContent: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// Message identifier
    public let messageId: Int64

    /// New message content
    public let newContent: MessageContent


    public init(
        chatId: Int64,
        messageId: Int64,
        newContent: MessageContent
    ) {
        self.chatId = chatId
        self.messageId = messageId
        self.newContent = newContent
    }
}

/// A new chat has been loaded/created. This update is guaranteed to come before the chat identifier is returned to the application. The chat field changes will be reported through separate updates
public struct UpdateNewChat: Codable, Equatable, Hashable {

    /// The chat
    public let chat: Chat


    public init(chat: Chat) {
        self.chat = chat
    }
}

/// The title of a chat was changed
public struct UpdateChatTitle: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// The new chat title
    public let title: String


    public init(
        chatId: Int64,
        title: String
    ) {
        self.chatId = chatId
        self.title = title
    }
}

/// A chat photo was changed
public struct UpdateChatPhoto: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// The new chat photo; may be null
    public let photo: ChatPhotoInfo?


    public init(
        chatId: Int64,
        photo: ChatPhotoInfo?
    ) {
        self.chatId = chatId
        self.photo = photo
    }
}

/// Chat permissions were changed
public struct UpdateChatPermissions: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// The new chat permissions
    public let permissions: ChatPermissions


    public init(
        chatId: Int64,
        permissions: ChatPermissions
    ) {
        self.chatId = chatId
        self.permissions = permissions
    }
}

/// The last message of a chat was changed
public struct UpdateChatLastMessage: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// The new last message in the chat; may be null if the last message became unknown. While the last message is unknown, new messages can be added to the chat without corresponding updateNewMessage update
    public let lastMessage: Message?

    /// The new chat positions in the chat lists
    public let positions: [ChatPosition]


    public init(
        chatId: Int64,
        lastMessage: Message?,
        positions: [ChatPosition]
    ) {
        self.chatId = chatId
        self.lastMessage = lastMessage
        self.positions = positions
    }
}

/// The position of a chat in a chat list has changed. An updateChatLastMessage or updateChatDraftMessage update might be sent instead of the update
public struct UpdateChatPosition: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// New chat position. If new order is 0, then the chat needs to be removed from the list
    public let position: ChatPosition


    public init(
        chatId: Int64,
        position: ChatPosition
    ) {
        self.chatId = chatId
        self.position = position
    }
}

/// A chat was added to a chat list
public struct UpdateChatAddedToList: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// The chat list to which the chat was added
    public let chatList: ChatList


    public init(
        chatId: Int64,
        chatList: ChatList
    ) {
        self.chatId = chatId
        self.chatList = chatList
    }
}

/// A chat was removed from a chat list
public struct UpdateChatRemovedFromList: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// The chat list from which the chat was removed
    public let chatList: ChatList


    public init(
        chatId: Int64,
        chatList: ChatList
    ) {
        self.chatId = chatId
        self.chatList = chatList
    }
}

/// Incoming messages were read or the number of unread messages has been changed
public struct UpdateChatReadInbox: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// Identifier of the last read incoming message
    public let lastReadInboxMessageId: Int64

    /// The number of unread messages left in the chat
    public let unreadCount: Int


    public init(
        chatId: Int64,
        lastReadInboxMessageId: Int64,
        unreadCount: Int
    ) {
        self.chatId = chatId
        self.lastReadInboxMessageId = lastReadInboxMessageId
        self.unreadCount = unreadCount
    }
}

/// Outgoing messages were read
public struct UpdateChatReadOutbox: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// Identifier of last read outgoing message
    public let lastReadOutboxMessageId: Int64


    public init(
        chatId: Int64,
        lastReadOutboxMessageId: Int64
    ) {
        self.chatId = chatId
        self.lastReadOutboxMessageId = lastReadOutboxMessageId
    }
}

/// A chat draft has changed. Be aware that the update may come in the currently opened chat but with old content of the draft. If the user has changed the content of the draft, this update mustn't be applied
public struct UpdateChatDraftMessage: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// The new draft message; may be null if none
    public let draftMessage: DraftMessage?

    /// The new chat positions in the chat lists
    public let positions: [ChatPosition]


    public init(
        chatId: Int64,
        draftMessage: DraftMessage?,
        positions: [ChatPosition]
    ) {
        self.chatId = chatId
        self.draftMessage = draftMessage
        self.positions = positions
    }
}

/// Notification settings for a chat were changed
public struct UpdateChatNotificationSettings: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// The new notification settings
    public let notificationSettings: ChatNotificationSettings


    public init(
        chatId: Int64,
        notificationSettings: ChatNotificationSettings
    ) {
        self.chatId = chatId
        self.notificationSettings = notificationSettings
    }
}

/// The list of chat folders or a chat folder has changed
public struct UpdateChatFolders: Codable, Equatable, Hashable {

    /// True, if folder tags are enabled
    public let areTagsEnabled: Bool

    /// The new list of chat folders
    public let chatFolders: [ChatFolderInfo]

    /// Position of the main chat list among chat folders, 0-based
    public let mainChatListPosition: Int


    public init(
        areTagsEnabled: Bool,
        chatFolders: [ChatFolderInfo],
        mainChatListPosition: Int
    ) {
        self.areTagsEnabled = areTagsEnabled
        self.chatFolders = chatFolders
        self.mainChatListPosition = mainChatListPosition
    }
}

/// Some messages were deleted
public struct UpdateDeleteMessages: Codable, Equatable, Hashable {

    /// Chat identifier
    public let chatId: Int64

    /// True, if the messages are deleted only from the cache and can possibly be retrieved again in the future
    public let fromCache: Bool

    /// True, if the messages are permanently deleted by a user (as opposed to just becoming inaccessible)
    public let isPermanent: Bool

    /// Identifiers of the deleted messages
    public let messageIds: [Int64]


    public init(
        chatId: Int64,
        fromCache: Bool,
        isPermanent: Bool,
        messageIds: [Int64]
    ) {
        self.chatId = chatId
        self.fromCache = fromCache
        self.isPermanent = isPermanent
        self.messageIds = messageIds
    }
}

/// Some data of a user has changed. This update is guaranteed to come before the user identifier is returned to the application
public struct UpdateUser: Codable, Equatable, Hashable {

    /// New data about the user
    public let user: User


    public init(user: User) {
        self.user = user
    }
}

/// Information about a file was updated
public struct UpdateFile: Codable, Equatable, Hashable {

    /// New data about the file
    public let file: File


    public init(file: File) {
        self.file = file
    }
}

/// A poll was updated; for bots only
public struct UpdatePoll: Codable, Equatable, Hashable {

    /// New data about the poll
    public let poll: Poll


    public init(poll: Poll) {
        self.poll = poll
    }
}

