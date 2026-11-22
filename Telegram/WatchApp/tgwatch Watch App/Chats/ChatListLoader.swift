import TDShim

/// Abstraction over the TDLib requests `ChatListStore` needs, so the store
/// can be exercised in tests with a no-op or scripted loader.
protocol ChatListLoader: Sendable {
    /// Asks TDLib to surface up to `limit` more chats from `chatList`. TDLib responds by
    /// emitting `updateNewChat` or `updateChatAddedToList` events for any newly-surfaced
    /// chats. When TDLib has nothing more to surface, this method throws
    /// `TDError` with `code == 404`.
    func loadChats(chatList: ChatList, limit: Int) async throws
    /// Asks TDLib to download `fileId`. Returns immediately (synchronous=false);
    /// progress + completion stream back via `updateFile`.
    func downloadFile(fileId: Int, priority: Int) async throws -> File
    /// Cancels an in-flight or pending download.
    func cancelDownloadFile(fileId: Int) async throws
}

struct TDLibChatListLoader: ChatListLoader {
    let client: TDLibClient

    func loadChats(chatList: ChatList, limit: Int) async throws {
        _ = try await client.loadChats(chatList: chatList, limit: limit)
    }

    func downloadFile(fileId: Int, priority: Int) async throws -> File {
        // synchronous=false → TDLib returns immediately and streams progress via updateFile.
        try await client.downloadFile(
            fileId: fileId, limit: 0, offset: 0, priority: priority, synchronous: false
        )
    }

    func cancelDownloadFile(fileId: Int) async throws {
        // onlyIfPending=false → cancel even if active.
        _ = try await client.cancelDownloadFile(fileId: fileId, onlyIfPending: false)
    }
}
