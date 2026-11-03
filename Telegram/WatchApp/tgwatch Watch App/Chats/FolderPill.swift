import TDShim

/// A single tab in the chat-list folder pill bar.
///
/// `id` is the folder identifier; the synthetic "All chats" pill uses `-1` (folder IDs are
/// positive). `chatList` is the value to pass to `loadChats(chatList:limit:)`. `unreadCount`
/// is summed across all chats whose `positions` include `chatList`.
struct FolderPill: Identifiable, Equatable, Hashable {
    static let allChatsId: Int = -1
    static let allChatsName = "All"

    let id: Int
    let chatList: ChatList
    let name: String
    let unreadCount: Int
    let isActive: Bool

    /// Projects pills from the store's state. Pure function (no TDLib calls).
    /// - parameter chats: the store's `chatCache`.
    /// - parameter folders: payload from `updateChatFolders.chatFolders`.
    /// - parameter mainChatListPosition: payload from `updateChatFolders.mainChatListPosition`.
    /// - parameter currentFolder: the currently-selected chat list (drives `isActive`).
    static func project(
        chats: [Int64: CachedChat],
        folders: [ChatFolderInfo],
        mainChatListPosition: Int,
        currentFolder: ChatList
    ) -> [FolderPill] {
        let currentKey = ChatListKey(currentFolder)

        // Start with the user folders in their natural order.
        var result: [FolderPill] = folders.map { info in
            let list: ChatList = .chatListFolder(ChatListFolder(chatFolderId: info.id))
            let unread = unreadSum(chats: chats, list: list)
            return FolderPill(
                id: info.id,
                chatList: list,
                name: info.name.text.text,
                unreadCount: unread,
                isActive: ChatListKey(list) == currentKey
            )
        }

        // Insert the "All chats" pill at the clamped main position.
        let allPill = FolderPill(
            id: allChatsId,
            chatList: .chatListMain,
            name: allChatsName,
            unreadCount: unreadSum(chats: chats, list: .chatListMain),
            isActive: currentKey == .main
        )
        let clampedPos = max(0, min(mainChatListPosition, result.count))
        result.insert(allPill, at: clampedPos)

        return result
    }

    private static func unreadSum(chats: [Int64: CachedChat], list: ChatList) -> Int {
        let targetKey = ChatListKey(list)
        return chats.values.reduce(0) { acc, chat in
            chat.positions.contains(where: { ChatListKey($0.list) == targetKey })
                ? acc + chat.unreadCount
                : acc
        }
    }
}
