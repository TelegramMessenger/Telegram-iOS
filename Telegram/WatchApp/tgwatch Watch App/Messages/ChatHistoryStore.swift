import Foundation
import Observation
import OSLog
import TDShim

@Observable
@MainActor
final class ChatHistoryStore {

    private(set) var rows: [MessageRow] = []
    private(set) var loadState: LoadState = .notStarted
    private(set) var lastSendError: String? = nil
    private(set) var draftText: String = ""
    private(set) var unseenNewerCount: Int = 0
    /// Live mutable window — populated by start() and pagination methods.
    /// View reads from this for `initialScrollTargetId`, `reachesChatTail`, etc.
    private(set) var window: MessageWindow

    /// Frozen `lastReadInboxMessageId` from chat-metadata at construction. Always
    /// set (may be 0 for a brand-new chat). Used as the mark-as-read gate.
    /// Distinct from `window.unreadDividerAfterId` which is nil when no unreads.
    let unreadDividerAfterIdSnapshot: Int64

    /// Highest message id the recipient has read on the outgoing side. Drives the
    /// unread-outgoing dot. Updated live via `updateChatReadOutbox`.
    private(set) var lastReadOutboxMessageId: Int64

    private let chatId: Int64
    private let chatType: ChatType
    private let chatTailIdAtOpen: Int64?
    private let loader: ChatHistoryLoader
    private let selfUserId: Int64?
    private let logger = Logger(subsystem: "org.telegram.TelegramWatch", category: "chathistory")

    let voicePlayback: VoicePlaybackController
    let audioPlayback: AudioPlaybackController

    private let userNames: UserNamesStore
    private var files: [Int: File] = [:]
    private var trackedFileIds: Set<Int> = []
    private var openChatSent: Bool = false
    private var closePending: Bool = false
    private var isLoading: Bool = false

    private static let halfLimit: Int = 15

    /// See `ChatListStore.coalesceUpdates` for rationale. Production
    /// (MessageListView) opts in; tests default to false.
    private let coalesceUpdates: Bool
    private var reprojectPending = false

    #if DEBUG
    private(set) var debugReprojectCount: Int = 0
    #endif

    init(
        chatId: Int64,
        chatType: ChatType,
        lastReadInboxMessageId: Int64,
        lastReadOutboxMessageId: Int64 = 0,
        unreadCount: Int,
        lastMessageId: Int64?,
        loader: ChatHistoryLoader,
        selfUserId: Int64? = nil,
        userNames: UserNamesStore? = nil,
        draftText: String = "",
        coalesceUpdates: Bool = false,
        voicePlayback: VoicePlaybackController? = nil,
        audioPlayback: AudioPlaybackController? = nil
    ) {
        self.chatId = chatId
        self.chatType = chatType
        self.chatTailIdAtOpen = lastMessageId
        self.loader = loader
        self.selfUserId = selfUserId
        self.userNames = userNames ?? UserNamesStore()
        self.voicePlayback = voicePlayback ?? VoicePlaybackController(
            backend: AVEngineBackend(),
            decoder: OpusDecoderAdapter()
        )
        self.audioPlayback = audioPlayback ?? AudioPlaybackController(backend: AVPlayerBackend())
        self.draftText = draftText
        self.coalesceUpdates = coalesceUpdates
        self.unreadDividerAfterIdSnapshot = lastReadInboxMessageId
        self.lastReadOutboxMessageId = lastReadOutboxMessageId
        let anchor: MessageWindow.Anchor
        let dividerAfter: Int64?
        if unreadCount > 0 {
            anchor = .messageId(lastReadInboxMessageId)
            dividerAfter = lastReadInboxMessageId
        } else {
            anchor = .tail
            dividerAfter = nil
        }
        self.window = MessageWindow(
            anchor: anchor,
            halfLimit: Self.halfLimit,
            unreadDividerAfterId: dividerAfter
        )
        self.loadState = .loadingFirstPage
    }

    func start() async {
        guard !isLoading else { return }
        isLoading = true
        loadState = .loadingFirstPage
        lastSendError = nil
        unseenNewerCount = 0
        defer { isLoading = false }
        do {
            if !openChatSent {
                try await loader.openChat(chatId: chatId)
                openChatSent = true
            }
            try await loadInitialWindow()
            loadState = .loaded
        } catch is CancellationError {
            return
        } catch {
            // Dump the full error description for DecodingError diagnostics —
            // the default `localizedDescription` collapses to a generic
            // "The data couldn't be read" string that hides the key/path.
            logger.warning("loadInitialWindow failed chatId=\(self.chatId, privacy: .public) error=\(String(describing: error), privacy: .public)")
            loadState = .failed(humanMessage(error))
        }
    }

    /// History-only initial load with NO side effects (no `openChat`). Safe to run
    /// before the user has committed to the chat (e.g. pre-warm on tap). Mirrors the
    /// load half of `start()`; `activate()` performs the `openChat` half separately.
    func warm() async {
        guard !isLoading else { return }
        isLoading = true
        loadState = .loadingFirstPage
        lastSendError = nil
        unseenNewerCount = 0
        defer { isLoading = false }
        do {
            try await loadInitialWindow()
            loadState = .loaded
        } catch is CancellationError {
            return
        } catch {
            logger.warning("warm failed chatId=\(self.chatId, privacy: .public) error=\(String(describing: error), privacy: .public)")
            loadState = .failed(humanMessage(error))
        }
    }

    /// Notifies TDLib the chat is being viewed (`openChat`), guarded to run once.
    /// Called from the view's `.task` once the user actually lands on the chat.
    /// An `openChat` failure is logged but does NOT blank already-loaded history —
    /// the worst case is delayed supergroup/channel live updates, not a dead screen.
    func activate() async {
        guard !openChatSent, !closePending else { return }
        do {
            try await loader.openChat(chatId: chatId)
            openChatSent = true
            // If stop() landed while openChat was in flight (the view popped during the
            // round-trip), honor the close now so the chat doesn't leak open on TDLib.
            if closePending {
                try? await loader.closeChat(chatId: chatId)
                openChatSent = false
                closePending = false
            }
        } catch {
            logger.warning("openChat chatId=\(self.chatId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Anchored initial fill: when `unreadDividerAfterId != nil`, we call
    /// `getChatHistory(fromMessageId: divider, offset: -(halfLimit+1), limit: 2*halfLimit)`
    /// → up to (halfLimit+1) newer + divider + ~(halfLimit-1) older. Otherwise we
    /// fetch from the tail with offset 0. Loop retries on the same anchor up to
    /// 10× (TDLib returns < requested on cold cache).
    private func loadInitialWindow() async throws {
        let targetCount = 2 * Self.halfLimit
        let maxIterations = 10
        var iter = 0
        while !Task.isCancelled, iter < maxIterations, window.cache.count < targetCount {
            iter += 1
            let from: Int64
            let offset: Int
            switch window.anchor {
            case .tail:
                from = window.loadedLowestId ?? 0
                offset = 0
            case .messageId(let anchorId):
                if window.loadedHighestId == nil {
                    from = anchorId
                    offset = -(Self.halfLimit + 1)
                } else if let highest = window.loadedHighestId, highest <= anchorId {
                    // Still missing newer side; pull from anchor with negative offset.
                    from = anchorId
                    offset = -(Self.halfLimit + 1)
                } else {
                    from = window.loadedLowestId ?? anchorId
                    offset = 0
                }
            }
            let limit = max(1, targetCount - window.cache.count)
            let messages = try await loader.loadHistory(
                chatId: chatId, fromMessageId: from, offset: offset, limit: limit
            )
            logger.info("loadInitialWindow iter=\(iter, privacy: .public) returned=\(messages.count, privacy: .public)")
            if messages.isEmpty {
                // Empty terminator. For a `.tail`-anchored initial fill, an empty
                // batch on `fromMessageId = loadedHighestId` means TDLib has nothing
                // newer than what we already have — i.e. we are at the chat tail.
                if case .tail = window.anchor { window.markReachesChatTail() }
                break
            }
            let cached = messages.map(CachedMessage.init)
            for m in messages { primeFiles(from: m.content) }
            window.extendInitial(cached, chatTailId: chatTailIdAtOpen)
            // For a `.tail`-anchored fill, the very first batch (`from == 0`) is
            // by definition anchored at the chat tail — TDLib returns the latest
            // messages in descending id order. Mark `reachesChatTail` so live
            // `updateNewMessage` can extend the window without spurious gap probes.
            if case .tail = window.anchor, from == 0 { window.markReachesChatTail() }
            reproject()
        }
    }

    func stop() async {
        voicePlayback.tearDown()
        audioPlayback.tearDown()
        // Drain task was scheduled by markVisible during scroll; cancel so it
        // doesn't fire viewMessages against a soon-to-be-closed chat.
        viewDrainTask?.cancel()
        viewDrainTask = nil
        pendingViewIds.removeAll()
        guard openChatSent else {
            // activate() may have openChat in flight (the view popped before it
            // returned). Mark so activate() closes the chat once openChat completes —
            // otherwise it leaks open on TDLib.
            closePending = true
            return
        }
        do {
            try await loader.closeChat(chatId: chatId)
        } catch {
            logger.warning("closeChat chatId=\(self.chatId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Pagination

    private(set) var lastPaginationError: String? = nil
    private var isLoadingOlder = false
    private var isLoadingNewer = false
    private var olderFailureStreak = 0
    private var newerFailureStreak = 0
    private static let paginationLimit = 30
    private static let failureStreakCap = 3

    func loadOlder() async {
        guard !isLoadingOlder, window.hasOlder, let from = window.loadedLowestId else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let messages = try await loader.loadHistory(
                chatId: chatId, fromMessageId: from, offset: 0, limit: Self.paginationLimit
            )
            for m in messages { primeFiles(from: m.content) }
            window.extendOlder(messages.map(CachedMessage.init))
            olderFailureStreak = 0
            logger.info("loadOlder chatId=\(self.chatId, privacy: .public) returned=\(messages.count, privacy: .public)")
            reproject()
        } catch {
            olderFailureStreak += 1
            logger.warning("loadOlder failure streak=\(self.olderFailureStreak, privacy: .public): \(error.localizedDescription, privacy: .public)")
            if olderFailureStreak >= Self.failureStreakCap {
                window.markHasOlderFalse()
                lastPaginationError = humanMessage(error)
            }
        }
    }

    func loadNewer() async {
        guard !isLoadingNewer, !window.reachesChatTail, let from = window.loadedHighestId else { return }
        isLoadingNewer = true
        defer { isLoadingNewer = false }
        do {
            let messages = try await loader.loadHistory(
                chatId: chatId, fromMessageId: from, offset: -Self.paginationLimit, limit: Self.paginationLimit
            )
            for m in messages { primeFiles(from: m.content) }
            window.extendNewer(messages.map(CachedMessage.init), chatTailId: chatTailIdAtOpen)
            newerFailureStreak = 0
            reproject()
        } catch {
            newerFailureStreak += 1
            logger.warning("loadNewer failure streak=\(self.newerFailureStreak, privacy: .public): \(error.localizedDescription, privacy: .public)")
            if newerFailureStreak >= Self.failureStreakCap {
                window.markReachesChatTail()
                lastPaginationError = humanMessage(error)
            }
        }
    }

    func dismissPaginationError() {
        lastPaginationError = nil
        olderFailureStreak = 0
        newerFailureStreak = 0
    }

    // MARK: - Mark-as-read

    private var pendingViewIds: Set<Int64> = []
    private var viewDrainTask: Task<Void, Never>? = nil
    private static let viewDrainDelayNs: UInt64 = 300_000_000  // 300ms

    func markVisible(messageId: Int64) {
        pendingViewIds.insert(messageId)
        viewDrainTask?.cancel()
        viewDrainTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.viewDrainDelayNs)
            if Task.isCancelled { return }
            await self?.drainPendingViews()
        }
    }

    private func drainPendingViews() async {
        let ids = pendingViewIds.sorted()
        pendingViewIds.removeAll()
        guard !ids.isEmpty else { return }
        do {
            try await loader.viewMessages(chatId: chatId, messageIds: ids, forceRead: false)
        } catch {
            logger.warning("viewMessages chatId=\(self.chatId, privacy: .public) ids=\(ids.count, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Jump-to-bottom

    private var isJumpingToBottom = false

    /// Caller (the view) is responsible for the actual `proxy.scrollTo` after this
    /// returns. Two paths:
    ///   - `reachesChatTail` already true: cheap; just zero the counter.
    ///   - else: clear window, re-build at the tail, then return.
    func jumpToBottom() async {
        if window.reachesChatTail {
            unseenNewerCount = 0
            return
        }
        guard !isJumpingToBottom else { return }
        isJumpingToBottom = true
        defer { isJumpingToBottom = false }

        // Rebuild window with anchor=.tail and no divider.
        window = MessageWindow(anchor: .tail, halfLimit: Self.halfLimit, unreadDividerAfterId: nil)
        unseenNewerCount = 0

        do {
            try await loadInitialWindow()
            loadState = .loaded
        } catch is CancellationError {
            return
        } catch {
            loadState = .failed(humanMessage(error))
        }
    }

    // MARK: - Send / draft

    func sendText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastSendError = nil
        // Pull-to-tail: sending implicitly means "user is at the bottom".
        // Anything beyond the current loaded window is no longer a "gap" from the
        // user's perspective, so we flip reachesChatTail and clear the counter
        // BEFORE the optimistic updateNewMessage from sendMessage lands.
        window.markReachesChatTail()
        unseenNewerCount = 0
        do {
            _ = try await loader.sendText(chatId: chatId, text: trimmed)
        } catch {
            lastSendError = humanMessage(error)
            logger.warning("sendText chatId=\(self.chatId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func sendVoiceNote(_ draft: VoiceRecordingDraft) async -> Bool {
        lastSendError = nil
        window.markReachesChatTail()
        unseenNewerCount = 0
        do {
            _ = try await loader.sendVoiceNote(
                chatId: chatId,
                fileURL: draft.fileURL,
                duration: draft.duration,
                waveform: draft.waveform
            )
            return true
        } catch {
            lastSendError = humanMessage(error)
            logger.warning("sendVoiceNote chatId=\(self.chatId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Sends an installed sticker (chosen in the picker) by remote file id.
    /// Mirrors `sendVoiceNote`: pull-to-tail, clear unseen, capture error.
    func sendSticker(_ sticker: PickerSticker) async -> Bool {
        lastSendError = nil
        window.markReachesChatTail()
        unseenNewerCount = 0
        do {
            _ = try await loader.sendSticker(
                chatId: chatId,
                remoteFileId: sticker.remoteFileId,
                emoji: sticker.emoji,
                width: sticker.width,
                height: sticker.height
            )
            return true
        } catch {
            lastSendError = humanMessage(error)
            logger.warning("sendSticker chatId=\(self.chatId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Sends the user's current coordinate as a static location.
    /// Mirrors `sendSticker`: pull-to-tail, clear unseen, capture error.
    func sendLocation(latitude: Double, longitude: Double) async -> Bool {
        lastSendError = nil
        window.markReachesChatTail()
        unseenNewerCount = 0
        do {
            _ = try await loader.sendLocation(chatId: chatId, latitude: latitude, longitude: longitude)
            return true
        } catch {
            lastSendError = humanMessage(error)
            logger.warning("sendLocation chatId=\(self.chatId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Casts the user's poll answer. `optionIds` are 0-based option positions.
    /// Mirrors `sendText`'s error capture; returns success. Result refresh comes
    /// asynchronously via `updatePoll`.
    func setPollAnswer(messageId: Int64, optionIds: [Int]) async -> Bool {
        lastSendError = nil
        do {
            try await loader.setPollAnswer(chatId: chatId, messageId: messageId, optionIds: optionIds)
            return true
        } catch {
            lastSendError = humanMessage(error)
            logger.warning("setPollAnswer chatId=\(self.chatId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Looks up the currently-projected poll for a message id (for the Vote
    /// screen's post-vote quiz reveal — reads the latest `updatePoll`-patched state).
    func poll(forMessageId id: Int64) -> PollVisual? {
        for row in rows {
            if case .bubble(let b) = row, b.messageId == id { return b.poll }
        }
        return nil
    }

    func dismissSendError() { lastSendError = nil }

    func saveDraft(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == draftText { return }
        draftText = trimmed
        do {
            try await loader.setChatDraftMessage(chatId: chatId, draftText: trimmed)
        } catch {
            logger.warning("setChatDraftMessage chatId=\(self.chatId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func fileSnapshot(fileId: Int) -> File? { files[fileId] }

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

    func togglePlayback(_ note: VoiceNoteVisual) {
        audioPlayback.tearDown()
        if note.localPath == nil {
            requestFileDownload(fileId: note.voiceFileId, priority: 2)
        }
        voicePlayback.toggle(note: note)
    }

    func toggleAudioPlayback(_ audio: AudioVisual) {
        voicePlayback.tearDown()
        if audio.localPath == nil {
            requestFileDownload(fileId: audio.audioFileId, priority: 2)
        }
        audioPlayback.toggle(audio: audio)
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

    // MARK: - Update dispatch

    func handle(_ update: Update) {
        switch update {
        case .updateNewMessage(let upd) where upd.message.chatId == chatId:
            let cached = CachedMessage(upd.message)
            let inserted = window.tryInsertLive(cached)
            if inserted {
                primeFiles(from: upd.message.content)
                scheduleReproject()
            } else {
                unseenNewerCount += 1
            }
        case .updateMessageSendSucceeded(let upd) where upd.message.chatId == chatId:
            guard window.cache[upd.oldMessageId] != nil else { return }
            window.applySendSucceeded(oldId: upd.oldMessageId, message: CachedMessage(upd.message))
            primeFiles(from: upd.message.content)
            scheduleReproject()
        case .updateMessageSendFailed(let upd) where upd.message.chatId == chatId:
            guard window.cache[upd.oldMessageId] != nil else { return }
            window.applySendFailed(oldId: upd.oldMessageId, message: CachedMessage(upd.message))
            scheduleReproject()
            logger.warning("send failed chatId=\(self.chatId, privacy: .public) errorCode=\(upd.error.code, privacy: .public) error=\(upd.error.message, privacy: .public)")
        case .updateMessageContent(let upd) where upd.chatId == chatId:
            window.applyContentUpdate(id: upd.messageId, newContent: upd.newContent)
            primeFiles(from: upd.newContent)
            scheduleReproject()
        case .updateDeleteMessages(let upd) where upd.chatId == chatId && upd.isPermanent:
            window.applyDelete(ids: upd.messageIds)
            scheduleReproject()
        case .updateUser:
            // UserNamesStore (owned by TDClient) absorbed the update before
            // it reached us. Just repaint with the new cache snapshot.
            scheduleReproject()
        case .updatePoll(let upd):
            window.applyPollUpdate(poll: upd.poll)
            scheduleReproject()
        case .updateFile(let upd):
            files[upd.file.id] = upd.file
            if trackedFileIds.contains(upd.file.id) { scheduleReproject() }
        case .updateChatReadOutbox(let upd) where upd.chatId == chatId:
            lastReadOutboxMessageId = upd.lastReadOutboxMessageId
            scheduleReproject()
        default:
            break
        }
    }

    // MARK: - File priming (unchanged from prior implementation)

    private func primeFiles(from content: MessageContent) {
        switch content {
        case .messagePhoto(let m):
            guard let size = selectPhotoSize(m.photo.sizes) else { return }
            primeFile(size.photo)
        case .messageVideo(let m):
            let chosen = selectVideoQuality(primary: m.video, alternatives: m.alternativeVideos)
            primeFile(chosen.file)
            if let cover = m.cover, let s = selectVideoCoverSize(cover.sizes) {
                primeFile(s.photo)
            } else if let thumb = m.video.thumbnail {
                primeFile(thumb.file)
            }
        case .messageVideoNote(let m):
            primeFile(m.videoNote.video)
            if let thumb = m.videoNote.thumbnail {
                primeFile(thumb.file)
            }
        case .messageSticker(let m):
            primeFile(m.sticker.sticker)
            if let thumb = m.sticker.thumbnail,
               thumbnailFormatKind(thumb.format) != .unsupported {
                primeFile(thumb.file)
            }
        case .messageVoiceNote(let m):
            primeFile(m.voiceNote.voice)
        case .messageAudio(let m):
            primeFile(m.audio.audio)
        default:
            break
        }
    }

    private func primeFile(_ file: File) {
        if files[file.id]?.local.isDownloadingCompleted == true { return }
        files[file.id] = file
    }

    /// See `ChatListStore.scheduleReproject`. Tail-of-runloop deferral for
    /// production; passthrough for tests (default).
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
        rows = messageRows(
            messages: Array(window.cache.values),
            userNames: userNames.names,
            fileLocals: files,
            chatType: chatType,
            chatId: chatId,
            today: Foundation.Date(),
            calendar: Calendar.current,
            selfUserId: selfUserId,
            unreadDividerAfterId: window.unreadDividerAfterId,
            lastReadOutboxMessageId: lastReadOutboxMessageId
        )
        // If a voice playback is awaiting its file, advance it now that the
        // projection has the freshest `localPath`.
        if case .preparing(let pendingId, _) = voicePlayback.state {
            for row in rows {
                if case .bubble(let b) = row, let v = b.voiceNote, v.voiceFileId == pendingId {
                    voicePlayback.resumeIfReady(note: v)
                    break
                }
            }
        }
        // Same resume-on-file-arrival hook for music playback.
        if case .preparing(let pendingId) = audioPlayback.state {
            for row in rows {
                if case .bubble(let b) = row, let a = b.audio, a.audioFileId == pendingId {
                    audioPlayback.resumeIfReady(audio: a)
                    break
                }
            }
        }
    }
}

#if DEBUG
extension ChatHistoryStore {
    /// Test-only: prime the window's `reachesChatTail` so `updateNewMessage`
    /// inserts without a prior `start()` call. Never call from production code.
    func testHook_markReachesChatTail() { window.markReachesChatTail() }
}
#endif
