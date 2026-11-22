import TDShim

struct ChatRow: Identifiable, Equatable, Hashable {
    let id: Int64
    let title: String
    let preview: String
    let unreadCount: Int
    let isMuted: Bool
    let order: TdInt64
    let chatType: ChatType
    let canSend: Bool
    let draftText: String
    let lastReadInboxMessageId: Int64
    let lastReadOutboxMessageId: Int64
    let lastMessageId: Int64?
    let lastMessageDate: Int?
    let avatar: AvatarVisual
    /// True when the chat's last message is a sent outgoing message the recipient
    /// hasn't read yet (`id > lastReadOutboxMessageId`). Mirrors `MessageRow.isUnreadOutgoing`.
    var isUnreadOutgoing: Bool = false

    /// Compacts the store's chat cache into a sorted `[ChatRow]`. Chats without a position
    /// in `currentFolder` are dropped. Sort: highest `order` first, which naturally puts
    /// pinned chats above unpinned via TDLib's order encoding.
    ///
    /// `limit` caps the returned count. The slice is applied BEFORE `chatPreview` runs,
    /// so a folder with thousands of cached chats only pays preview cost for the top K.
    /// The default `.max` preserves "return everything" for tests.
    static func project(
        chats: [Int64: CachedChat],
        userNames: [Int64: String],
        selfUserId: Int64?,
        currentFolder: ChatList,
        limit: Int = .max,
        fileLocals: [Int: File] = [:]
    ) -> [ChatRow] {
        let currentKey = ChatListKey(currentFolder)
        var candidates: [(chat: CachedChat, order: TdInt64)] = []
        candidates.reserveCapacity(chats.count)
        for chat in chats.values {
            guard let position = chat.positions.first(where: { ChatListKey($0.list) == currentKey }) else {
                continue
            }
            candidates.append((chat, position.order))
        }
        candidates.sort { $0.order > $1.order }
        let top = limit == .max ? candidates : Array(candidates.prefix(limit))
        return top.map { entry in
            let lm = entry.chat.lastMessage
            let isUnreadOutgoing = !isSavedMessages(chat: entry.chat, selfUserId: selfUserId)
                && lm?.isOutgoing == true
                && lm?.sendingState == .sent
                && (lm?.id ?? 0) > entry.chat.lastReadOutboxMessageId
            return ChatRow(
                id: entry.chat.id,
                title: displayTitle(for: entry.chat, selfUserId: selfUserId),
                preview: chatPreview(entry.chat, userNames: userNames, selfUserId: selfUserId),
                unreadCount: entry.chat.unreadCount,
                isMuted: entry.chat.muteFor > 0,
                order: entry.order,
                chatType: entry.chat.type,
                canSend: deriveCanSend(entry.chat),
                draftText: entry.chat.draftText ?? "",
                lastReadInboxMessageId: entry.chat.lastReadInboxMessageId,
                lastReadOutboxMessageId: entry.chat.lastReadOutboxMessageId,
                lastMessageId: entry.chat.lastMessage?.id,
                lastMessageDate: entry.chat.lastMessage?.date,
                avatar: avatarVisual(for: entry.chat, fileLocals: fileLocals, selfUserId: selfUserId),
                isUnreadOutgoing: isUnreadOutgoing
            )
        }
    }
}

/// A private chat with our own user id is the "Saved Messages" chat.
private func isSavedMessages(chat: CachedChat, selfUserId: Int64?) -> Bool {
    guard let selfUserId, case .chatTypePrivate(let p) = chat.type else { return false }
    return p.userId == selfUserId
}

/// A private chat with our own user id is the "Saved Messages" chat — TDLib stores
/// the title as the user's own first name, but Telegram clients universally relabel it.
private func displayTitle(for chat: CachedChat, selfUserId: Int64?) -> String {
    if isSavedMessages(chat: chat, selfUserId: selfUserId) {
        return "Saved Messages"
    }
    return chat.title
}

/// Private chats and secret chats are always sendable (no group permissions apply).
/// Basic groups and supergroups (including channels) gate on `canSendBasicMessages`.
private func deriveCanSend(_ chat: CachedChat) -> Bool {
    switch chat.type {
    case .chatTypePrivate, .chatTypeSecret:
        return true
    case .chatTypeBasicGroup, .chatTypeSupergroup:
        return chat.permissions.canSendBasicMessages
    case .unsupported:
        return false
    }
}
