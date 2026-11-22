import Foundation
import TDShim

/// Local discriminator for outgoing-message lifecycle. Incoming messages are always `.sent`.
enum SendingState: Equatable, Hashable {
    case sent
    case pending
    case failed
}

extension SendingState {
    init(tdLibState: MessageSendingState?) {
        switch tdLibState {
        case nil, .unsupported:
            self = .sent
        case .messageSendingStatePending:
            self = .pending
        case .messageSendingStateFailed:
            self = .failed
        }
    }
}

/// Cache shape for a chat in `ChatListStore`. Holds only what the chat-list view renders
/// plus the fields the store mutates as TDLib updates arrive.
struct CachedChat: Equatable {
    let id: Int64
    var title: String
    var lastMessage: CachedMessage?
    var unreadCount: Int
    var lastReadInboxMessageId: Int64
    var lastReadOutboxMessageId: Int64
    /// Seconds until unmute. `0` = unmuted; large value = muted.
    var muteFor: Int
    var positions: [ChatPosition]
    /// Plain-text body of the local draft, if any. Non-text drafts collapse to `""`.
    var draftText: String?
    let type: ChatType
    var permissions: ChatPermissions
    /// `ChatPhotoInfo.small` file id (160px). nil when the chat has no photo.
    var avatarSmallFileId: Int? = nil
    /// `ChatPhotoInfo.minithumbnail` JPEG bytes — instant placeholder, no download.
    var avatarMini: Data? = nil
}

/// Reduced shape of `Message` carrying the fields the chat-list preview reads
/// plus the fields the message-history view needs (id for cache key + sort, date for
/// timestamps + day separators, editDate captured for a future "edited" indicator).
struct CachedMessage: Equatable {
    let id: Int64
    let date: Int
    let editDate: Int
    let isOutgoing: Bool
    let senderId: MessageSender
    let content: MessageContent
    let sendingState: SendingState
    let replyTo: MessageReplyTo?
}

extension CachedChat {
    /// Snapshots a TDLib `Chat` into a `CachedChat`.
    init(_ chat: Chat) {
        self.id = chat.id
        self.title = chat.title
        self.lastMessage = chat.lastMessage.map(CachedMessage.init)
        self.unreadCount = chat.unreadCount
        self.lastReadInboxMessageId = chat.lastReadInboxMessageId
        self.lastReadOutboxMessageId = chat.lastReadOutboxMessageId
        self.muteFor = chat.notificationSettings.muteFor
        self.positions = chat.positions
        self.draftText = CachedChat.extractDraftText(chat.draftMessage)
        self.type = chat.type
        self.permissions = chat.permissions
        self.avatarSmallFileId = chat.photo?.small.id
        self.avatarMini = chat.photo?.minithumbnail?.data
    }

    static func extractDraftText(_ draft: DraftMessage?) -> String? {
        guard let draft else { return nil }
        if case .inputMessageText(let inputText) = draft.inputMessageText {
            return inputText.text.text
        }
        return ""
    }
}

extension CachedMessage {
    init(_ message: Message) {
        self.id = message.id
        self.date = message.date
        self.editDate = message.editDate
        self.isOutgoing = message.isOutgoing
        self.senderId = message.senderId
        self.content = message.content
        self.sendingState = SendingState(tdLibState: message.sendingState)
        self.replyTo = message.replyTo
    }
}
