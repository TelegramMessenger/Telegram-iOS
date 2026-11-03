import Foundation
import Observation
import OSLog
import TDShim

enum LoadState: Equatable {
    case notStarted
    case loadingFirstPage
    case hasMore
    case loadingMore
    case loaded
    case failed(String)
}

@Observable
@MainActor
final class ChatListStore {

    private(set) var chats: [ChatRow] = []
    private(set) var folders: [ChatFolderInfo] = []
    private var mainChatListPosition: Int = 0
    private(set) var pills: [FolderPill] = []
    private(set) var currentFolder: ChatList = .chatListMain
    private var loadStates: [ChatListKey: LoadState] = [.main: .loadingFirstPage]

    /// Public accessor; folders never visited are `.notStarted`.
    func loadState(for list: ChatList) -> LoadState {
        loadStates[ChatListKey(list)] ?? .notStarted
    }

    private var chatCache: [Int64: CachedChat] = [:]
    /// Avatar (and future) file downloads. Mirrors `ChatHistoryStore` — the chat
    /// list was previously file-free.
    private var files: [Int: File] = [:]
    private var trackedFileIds: Set<Int> = []
    private let userNames: UserNamesStore
    /// May be unknown at construction time — `TDClient.fetchMe()` is async and
    /// resolves after the `.ready` transition that builds this store. The
    /// "Saved Messages" relabel in `ChatRow.project` depends on this being set,
    /// so `setSelfUserId` is the late-bind path.
    private var selfUserId: Int64?

    private var displayLimits: [ChatListKey: Int] = [:]

    private let loader: ChatListLoader
    private let logger = Logger(subsystem: "org.telegram.TelegramWatch", category: "chatlist")
    private var loadTasks: [ChatListKey: Task<Void, Never>] = [:]

    private let initialDisplayLimit = 30
    private let displayPageSize = 30
    private let scrollLookahead = 5

    /// When true, `handle(_:)` defers `reproject()` to the next main-runloop
    /// turn so a burst of TDLib updates collapses to a single projection.
    /// Production (TDClient) opts in; tests default to false for synchronous
    /// `handle → assert` ergonomics.
    private let coalesceUpdates: Bool
    private var reprojectPending = false

    #if DEBUG
    /// Number of times `reproject()` has actually run. Test-only hook for
    /// asserting that coalescing collapses a burst into one projection.
    private(set) var debugReprojectCount: Int = 0
    #endif

    init(
        loader: ChatListLoader,
        selfUserId: Int64? = nil,
        userNames: UserNamesStore? = nil,
        coalesceUpdates: Bool = false
    ) {
        self.loader = loader
        self.selfUserId = selfUserId
        self.userNames = userNames ?? UserNamesStore()
        self.coalesceUpdates = coalesceUpdates
        let mainList: ChatList = .chatListMain
        loadTasks[.main] = Task { [weak self] in
            await self?.loadOnePage(for: mainList)
        }
    }

    func retry() {
        let key = ChatListKey(currentFolder)
        guard case .failed = loadStates[key] ?? .notStarted else { return }
        let list = currentFolder
        loadTasks[key]?.cancel()
        loadTasks[key] = Task { [weak self] in
            await self?.loadOnePage(for: list)
        }
    }

    func ensureChatsLoaded(near index: Int) {
        let key = ChatListKey(currentFolder)
        // Threshold: index near the end of the rendered slice.
        guard index >= chats.count - scrollLookahead else { return }

        let currentLimit = displayLimits[key] ?? initialDisplayLimit
        let availableInList = countOfChatsInList(currentFolder)

        if currentLimit < availableInList {
            // Cache has more than we show. Grow the slice; no TDLib call needed.
            displayLimits[key] = currentLimit + displayPageSize
            reproject()
            return
        }

        // Cache is exhausted (limit >= available). Ask TDLib for more if it has any.
        guard case .hasMore = loadStates[key] ?? .notStarted else { return }
        // Mark .loadingMore synchronously so a same-turn burst collapses.
        loadStates[key] = .loadingMore
        // Bump the limit too so that when more chats stream in via updateNewChat,
        // they'll show up in the projection without another scroll trigger.
        displayLimits[key] = currentLimit + displayPageSize
        let list = currentFolder
        loadTasks[key]?.cancel()
        loadTasks[key] = Task { [weak self] in
            await self?.loadOnePage(for: list)
        }
    }

    /// Late-bind for `me?.id` once `TDClient.fetchMe()` returns. Triggers a
    /// reproject so the "Saved Messages" relabel takes effect on existing rows.
    func setSelfUserId(_ id: Int64?) {
        guard selfUserId != id else { return }
        selfUserId = id
        reproject()
    }

    func requestFileDownload(fileId: Int, priority: Int = 1) {
        trackedFileIds.insert(fileId)
        logger.info("requestFileDownload fileId=\(fileId, privacy: .public) priority=\(priority, privacy: .public)")
        Task { [logger, loader] in
            do {
                _ = try await loader.downloadFile(fileId: fileId, priority: priority)
            } catch {
                logger.warning("downloadFile fileId=\(fileId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func cancelFileDownload(fileId: Int) {
        trackedFileIds.remove(fileId)
        logger.info("cancelFileDownload fileId=\(fileId, privacy: .public)")
        Task { [logger, loader] in
            do {
                try await loader.cancelDownloadFile(fileId: fileId)
            } catch {
                logger.warning("cancelDownloadFile fileId=\(fileId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Seeds the files map from an avatar's `small` file without downgrading an
    /// already-completed entry — TDLib re-emits `updateNewChat` on reconnect, and a
    /// stale (incomplete) File there would otherwise clobber a resolved local path.
    /// Mirrors `ChatHistoryStore.primeFile`.
    private func seedAvatarFile(_ file: File) {
        if files[file.id]?.local.isDownloadingCompleted == true { return }
        files[file.id] = file
    }

    func setCurrentFolder(_ list: ChatList) {
        let key = ChatListKey(list)
        currentFolder = list
        reproject()
        let state = loadStates[key] ?? .notStarted
        if case .notStarted = state {
            loadStates[key] = .loadingFirstPage
            loadTasks[key] = Task { [weak self] in
                await self?.loadOnePage(for: list)
            }
        }
    }

    func handle(_ update: Update) {
        diagnosticLog(update)
        switch update {
        case .updateNewChat(let upd):
            chatCache[upd.chat.id] = CachedChat(upd.chat)
            if let photo = upd.chat.photo {
                seedAvatarFile(photo.small)
            }
            scheduleReproject()
        case .updateChatLastMessage(let upd):
            guard var cached = chatCache[upd.chatId] else { return }
            cached.lastMessage = upd.lastMessage.map(CachedMessage.init)
            applyPositions(upd.positions, to: &cached)
            chatCache[upd.chatId] = cached
            scheduleReproject()
        case .updateChatPosition(let upd):
            guard var cached = chatCache[upd.chatId] else { return }
            applyPositions([upd.position], to: &cached)
            chatCache[upd.chatId] = cached
            scheduleReproject()
        case .updateChatReadInbox(let upd):
            guard var cached = chatCache[upd.chatId] else { return }
            cached.unreadCount = upd.unreadCount
            cached.lastReadInboxMessageId = upd.lastReadInboxMessageId
            chatCache[upd.chatId] = cached
            scheduleReproject()
        case .updateChatReadOutbox(let upd):
            guard var cached = chatCache[upd.chatId] else { return }
            cached.lastReadOutboxMessageId = upd.lastReadOutboxMessageId
            chatCache[upd.chatId] = cached
            scheduleReproject()
        case .updateChatTitle(let upd):
            guard var cached = chatCache[upd.chatId] else { return }
            cached.title = upd.title
            chatCache[upd.chatId] = cached
            scheduleReproject()
        case .updateChatNotificationSettings(let upd):
            guard var cached = chatCache[upd.chatId] else { return }
            cached.muteFor = upd.notificationSettings.muteFor
            chatCache[upd.chatId] = cached
            scheduleReproject()
        case .updateChatPermissions(let upd):
            if var c = chatCache[upd.chatId] {
                c.permissions = upd.permissions
                chatCache[upd.chatId] = c
                scheduleReproject()
            }
        case .updateChatDraftMessage(let upd):
            guard var cached = chatCache[upd.chatId] else { return }
            cached.draftText = CachedChat.extractDraftText(upd.draftMessage)
            applyPositions(upd.positions, to: &cached)
            chatCache[upd.chatId] = cached
            scheduleReproject()
        case .updateUser:
            // UserNamesStore (owned by TDClient) absorbed the update before
            // it reached us. Just repaint with the new cache snapshot.
            scheduleReproject()
        case .updateChatFolders(let upd):
            folders = upd.chatFolders
            mainChatListPosition = upd.mainChatListPosition
            // If the currently-selected folder no longer exists, fall back to Main.
            if case .chatListFolder(let f) = currentFolder,
               !folders.contains(where: { $0.id == f.chatFolderId }) {
                currentFolder = .chatListMain
            }
            scheduleReproject()
        case .updateChatAddedToList(let upd):
            guard var cached = chatCache[upd.chatId] else { return }
            let key = ChatListKey(upd.chatList)
            if !cached.positions.contains(where: { ChatListKey($0.list) == key }) {
                // Seed with order 0 and DO NOT reproject — the follow-up updateChatPosition
                // (which TDLib always emits right after) overwrites the order via applyPositions
                // and triggers the projection. Publishing the order-0 state here would briefly
                // sort the chat last before it jumps to its real position.
                cached.positions.append(ChatPosition(isPinned: false, list: upd.chatList, order: TdInt64(0), source: nil))
                chatCache[upd.chatId] = cached
            }
        case .updateChatRemovedFromList(let upd):
            guard var cached = chatCache[upd.chatId] else { return }
            let key = ChatListKey(upd.chatList)
            cached.positions.removeAll(where: { ChatListKey($0.list) == key })
            chatCache[upd.chatId] = cached
            scheduleReproject()
        case .updateChatPhoto(let upd):
            guard var cached = chatCache[upd.chatId] else { return }
            cached.avatarSmallFileId = upd.photo?.small.id
            cached.avatarMini = upd.photo?.minithumbnail?.data
            chatCache[upd.chatId] = cached
            if let photo = upd.photo {
                seedAvatarFile(photo.small)
            }
            scheduleReproject()
        case .updateFile(let upd):
            files[upd.file.id] = upd.file
            if trackedFileIds.contains(upd.file.id) { scheduleReproject() }
        default:
            break
        }
    }

    /// Defers `reproject()` to the next main-runloop turn when
    /// `coalesceUpdates` is on, collapsing a burst of TDLib updates into a
    /// single projection. With coalescing off (the test default) this runs
    /// `reproject()` synchronously, matching pre-coalescing behavior.
    ///
    /// Any synchronous `reproject()` (e.g. from `setCurrentFolder` or
    /// `ensureChatsLoaded`) clears the pending flag, so the deferred job
    /// no-ops if it loses the race.
    private func scheduleReproject() {
        guard coalesceUpdates else {
            reproject()
            return
        }
        guard !reprojectPending else { return }
        reprojectPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.reprojectPending else { return }
            self.reproject()
        }
    }

    #if DEBUG
    /// Synchronously runs any pending coalesced reproject. Test hook.
    func flushPendingReproject() {
        guard reprojectPending else { return }
        reproject()
    }
    #endif

    private func reproject() {
        reprojectPending = false
        #if DEBUG
        debugReprojectCount += 1
        #endif
        let limit = displayLimits[ChatListKey(currentFolder)] ?? initialDisplayLimit
        chats = ChatRow.project(
            chats: chatCache,
            userNames: userNames.names,
            selfUserId: selfUserId,
            currentFolder: currentFolder,
            limit: limit,
            fileLocals: files
        )
        pills = FolderPill.project(
            chats: chatCache,
            folders: folders,
            mainChatListPosition: mainChatListPosition,
            currentFolder: currentFolder
        )
    }

    /// Count of cached chats with a position in `folder`. Used to decide whether the
    /// display limit can grow against existing cache vs. needs more from TDLib.
    private func countOfChatsInList(_ folder: ChatList) -> Int {
        let key = ChatListKey(folder)
        return chatCache.values.reduce(0) { acc, cached in
            cached.positions.contains(where: { ChatListKey($0.list) == key }) ? acc + 1 : acc
        }
    }

    private func applyPositions(_ updates: [ChatPosition], to cached: inout CachedChat) {
        var next = cached.positions
        for incoming in updates {
            next.removeAll(where: { ChatListKey($0.list) == ChatListKey(incoming.list) })
            if incoming.order != 0 {
                next.append(incoming)
            }
        }
        cached.positions = next
    }

    private func loadOnePage(for chatList: ChatList) async {
        let key = ChatListKey(chatList)
        let pageSize = 30
        let isFirstPage = chatCache.isEmpty || hasNoChatsInList(chatList)
        loadStates[key] = isFirstPage ? .loadingFirstPage : .loadingMore
        logger.info("loadChats key=\(self.describeList(chatList), privacy: .public) phase=\(isFirstPage ? "first" : "more", privacy: .public) calling")
        do {
            try await loader.loadChats(chatList: chatList, limit: pageSize)
            logger.info("loadChats key=\(self.describeList(chatList), privacy: .public) ok cacheCount=\(self.chatCache.count, privacy: .public)")
            loadStates[key] = .hasMore
        } catch let error as TDError where error.code == 404 {
            logger.info("loadChats key=\(self.describeList(chatList), privacy: .public) terminated (404)")
            loadStates[key] = .loaded
        } catch {
            logger.warning("loadChats key=\(self.describeList(chatList), privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            loadStates[key] = .failed(humanMessage(error))
        }
    }

    /// True when nothing in `chatCache` has a non-zero position in `chatList`.
    /// Used by `loadOnePage` to pick `.loadingFirstPage` vs `.loadingMore` —
    /// the projection (`chats`) only reflects the active folder, but we want
    /// the flag to be per-list.
    private func hasNoChatsInList(_ chatList: ChatList) -> Bool {
        let key = ChatListKey(chatList)
        for cached in chatCache.values {
            if cached.positions.contains(where: { ChatListKey($0.list) == key }) {
                return false
            }
        }
        return true
    }

    private func diagnosticLog(_ update: Update) {
        switch update {
        case .updateNewChat(let upd):
            let lists = upd.chat.positions.map { describeList($0.list) + "@\($0.order.rawValue)" }.joined(separator: ",")
            logger.info("upd.newChat id=\(upd.chat.id, privacy: .public) title=\(upd.chat.title, privacy: .public) positions=[\(lists, privacy: .public)]")
        case .updateChatPosition(let upd):
            logger.info("upd.chatPosition id=\(upd.chatId, privacy: .public) list=\(self.describeList(upd.position.list), privacy: .public) order=\(upd.position.order.rawValue, privacy: .public)")
        case .updateChatAddedToList(let upd):
            logger.info("upd.chatAddedToList id=\(upd.chatId, privacy: .public) list=\(self.describeList(upd.chatList), privacy: .public)")
        case .updateChatRemovedFromList(let upd):
            logger.info("upd.chatRemovedFromList id=\(upd.chatId, privacy: .public) list=\(self.describeList(upd.chatList), privacy: .public)")
        case .updateChatLastMessage(let upd):
            let lists = upd.positions.map { describeList($0.list) + "@\($0.order.rawValue)" }.joined(separator: ",")
            logger.info("upd.chatLastMessage id=\(upd.chatId, privacy: .public) positions=[\(lists, privacy: .public)]")
        case .updateChatFolders:
            logger.info("upd.chatFolders")
        default:
            break
        }
    }

    private func describeList(_ list: ChatList) -> String {
        switch list {
        case .chatListMain: return "main"
        case .chatListArchive: return "archive"
        case .chatListFolder(let f): return "folder/\(f.chatFolderId)"
        case .unsupported: return "unsupported"
        }
    }
}
