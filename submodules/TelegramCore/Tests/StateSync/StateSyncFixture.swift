import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

enum StateSyncFixtureError: Error {
    case postboxDidNotOpen
}

/// Every value a signal has produced so far, oldest first. A port of `PostboxFixture.Recorder`
/// (Postbox's test target, not importable here) with a predicate wait.
final class SignalRecorder<Value> {
    private let lock = NSLock()
    private var recorded: [Value] = []
    private let semaphore = DispatchSemaphore(value: 0)

    func record(_ value: Value) {
        self.lock.lock()
        self.recorded.append(value)
        self.lock.unlock()
        self.semaphore.signal()
    }

    var values: [Value] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.recorded
    }

    /// Blocks until `predicate` holds for the values so far, or fails the test after `timeout`.
    /// Waiting returns on the first matching value; to see a duplicate that lands a turn later,
    /// drain first and then count.
    @discardableResult
    func wait(timeout: Double = 10.0, file: StaticString = #filePath, line: UInt = #line, until predicate: ([Value]) -> Bool) -> [Value] {
        let deadline = DispatchTime.now() + timeout
        while !predicate(self.values) {
            if self.semaphore.wait(timeout: deadline) == .timedOut {
                XCTFail("condition not met; recorded \(self.values.count) values", file: file, line: line)
                break
            }
        }
        return self.values
    }
}

/// A real `AccountStateManager` over a temporary on-disk Postbox, opened the way the app opens an
/// account's (the `openPostbox` call in `accountWithId`, Account.swift) with TelegramCore's seed configuration, and a
/// temporary `AccountManager`. The network is supplied by the caller.
final class StateSyncFixture {
    /// Which `openPostbox` call to reproduce. Only the flags differ; `isTemporary` is false in both.
    enum OpenProfile {
        /// `accountWithId`'s `openPostbox` call for the main app (`supplementary == false`), Account.swift.
        case mainApp
        /// `standaloneStateManager`'s `openPostbox` call (notification extension), Account.swift.
        case notificationExtension
    }

    static let accountPeerId = StateSyncFixture.userPeerId(1000)

    /// The gap wait of every manager the harness builds (`AccountStateManager.init`'s `gapWaitTimeout`), scaled down
    /// from production's `AccountStateManager.defaultGapWaitTimeout` (2 s) so a hole costs the tests 50 ms.
    static let gapWaitTimeout: Double = 0.05

    static func userPeerId(_ id: Int64) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
    }

    static func channelPeerId(_ id: Int64) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))
    }

    /// `Logger.shared` asserts when no logger is installed, and Postbox logs through it while it
    /// opens. A replaced shared logger must outlive every queue that may still log through it, so
    /// it is a process-lifetime constant, as in `NetworkEngineStateStoreTests`. Set
    /// `STATE_SYNC_LOG=1` in the test environment to see TelegramCore's log on the console.
    private static let logger: Logger = {
        let path = NSTemporaryDirectory() + "state-sync-fixture-logs-\(getpid())"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        let logger = Logger(rootPath: path, basePath: path)
        logger.logToFile = false
        logger.logToConsole = ProcessInfo.processInfo.environment["STATE_SYNC_LOG"] != nil
        return logger
    }()

    /// The shape SiriIntents and `Authorization.swift:1637-1645` use for an account that fetches
    /// nothing.
    static func makeAuxiliaryMethods() -> AccountAuxiliaryMethods {
        return AccountAuxiliaryMethods(fetchResource: { _, _, _, _ in
            return nil
        }, fetchResourceMediaReferenceHash: { _ in
            return .single(nil)
        }, prepareSecretThumbnailData: { _ in
            return nil
        }, backgroundUpload: { _, _, _ in
            return .single(nil)
        })
    }

    let basePath: String
    private(set) var postbox: Postbox!
    private(set) var accountManager: AccountManager<TelegramAccountManagerTypes>!
    private(set) var stateManager: AccountStateManager?
    private var disposables: [Disposable] = []

    init(name: String, profile: OpenProfile = .mainApp) throws {
        Logger.setSharedLogger(StateSyncFixture.logger)
        // Declares AuthorizedAccountState, TelegramUser, TelegramChannel, ChannelState, the message
        // attributes and media (AccountManager.swift:88-257). Without it every read-back decodes to nil.
        // Idempotent: it touches the global `let declaredEncodables`, which runs once per process, so
        // declareEncodable's duplicate-hash assertion cannot fire for a second fixture.
        initializeAccountManagement()

        self.basePath = NSTemporaryDirectory() + "state-sync-\(name)-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)

        self.accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: self.basePath + "/accounts-metadata", isTemporary: true, isReadOnly: false, useCaches: false, removeDatabaseOnError: true, accessChallenge: AccountManagerAccessChallenge(prepare: { _ in
        }, resolve: { current, _ in
            return current
        }, finishInitialization: {
        }))

        let isMainProcess: Bool
        let useCaches: Bool
        let removeDatabaseOnError: Bool
        switch profile {
        case .mainApp:
            isMainProcess = true
            useCaches = true
            removeDatabaseOnError = true
        case .notificationExtension:
            isMainProcess = false
            useCaches = false
            removeDatabaseOnError = false
        }

        // forceEncryptionIfNoSet: false leaves a fresh database unencrypted
        // (SqliteValueBox.swift:541); the key is never applied.
        let encryptionParameters = ValueBoxEncryptionParameters(
            forceEncryptionIfNoSet: false,
            key: ValueBoxEncryptionParameters.Key(data: Data(count: 32))!,
            salt: ValueBoxEncryptionParameters.Salt(data: Data(count: 16))!
        )

        let opened = Atomic<Postbox?>(value: nil)
        let done = DispatchSemaphore(value: 0)
        let disposable = openPostbox(
            basePath: self.basePath + "/postbox",
            seedConfiguration: telegramPostboxSeedConfiguration,
            encryptionParameters: encryptionParameters,
            timestampForAbsoluteTimeBasedOperations: Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970),
            isMainProcess: isMainProcess,
            isTemporary: false,
            isReadOnly: false,
            useCopy: false,
            useCaches: useCaches,
            removeDatabaseOnError: removeDatabaseOnError
        ).start(next: { result in
            switch result {
            case let .postbox(postbox):
                let _ = opened.swap(postbox)
                done.signal()
            case .error:
                done.signal()
            case .upgrading:
                // A fresh directory never upgrades; keep waiting rather than end like
                // standaloneStateManager's take(1) would.
                break
            }
        })
        let _ = done.wait(timeout: .now() + 10.0)
        disposable.dispose()
        guard let postbox = opened.with({ $0 }) else {
            throw StateSyncFixtureError.postboxDidNotOpen
        }
        self.postbox = postbox
    }

    // MARK: - Waiting

    /// Runs `f` as a Postbox transaction and waits for it. Nil, with the test failed, if it did not
    /// finish in time.
    @discardableResult
    func transaction<T>(_ f: @escaping (Transaction) -> T, timeout: Double = 10.0, file: StaticString = #filePath, line: UInt = #line) -> T? {
        let result = Atomic<T?>(value: nil)
        let done = DispatchSemaphore(value: 0)
        let disposable = self.postbox.transaction(f).start(next: { value in
            let _ = result.swap(value)
            done.signal()
        })
        if done.wait(timeout: .now() + timeout) == .timedOut {
            XCTFail("Postbox transaction did not complete", file: file, line: line)
        }
        disposable.dispose()
        return result.with { $0 }
    }

    /// The first value of `signal`, or nil (test failed) after `timeout`.
    func wait<T>(_ signal: Signal<T, NoError>, timeout: Double = 10.0, file: StaticString = #filePath, line: UInt = #line) -> T? {
        let result = Atomic<T?>(value: nil)
        let done = DispatchSemaphore(value: 0)
        let disposable = (signal |> take(1)).start(next: { value in
            let _ = result.swap(value)
            done.signal()
        }, completed: {
            done.signal()
        })
        if done.wait(timeout: .now() + timeout) == .timedOut {
            XCTFail("signal produced nothing in \(timeout) s", file: file, line: line)
        }
        disposable.dispose()
        return result.with { $0 }
    }

    /// Re-evaluates `predicate` every 10 ms until it holds; fails the test after `timeout`. For state
    /// that a fire-and-forget transaction writes (no signal to wait on), e.g. `invalidatedChannels`.
    func eventually(timeout: Double = 10.0, file: StaticString = #filePath, line: UInt = #line, _ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() {
            if Date() > deadline {
                XCTFail("condition not met in \(timeout) s", file: file, line: line)
                return
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    /// Records every value of `signal` until `close()`.
    func observe<T>(_ signal: Signal<T, NoError>) -> SignalRecorder<T> {
        let recorder = SignalRecorder<T>()
        self.disposables.append(signal.start(next: { value in
            recorder.record(value)
        }))
        return recorder
    }

    // MARK: - Seeding

    static func makeUser(id: PeerId, accessHash: Int64? = nil, firstName: String) -> TelegramUser {
        return TelegramUser(
            id: id,
            accessHash: accessHash.map { TelegramPeerAccessHash.personal($0) },
            firstName: firstName, lastName: nil, username: nil, phone: nil, photo: [],
            botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [],
            storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil,
            profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil
        )
    }

    /// `accessHash: nil` makes a channel no input channel can be built for (`apiInputChannel` returns nil).
    static func makeChannel(id: PeerId, accessHash: Int64?, title: String, participationStatus: TelegramChannelParticipationStatus = .member, isBroadcast: Bool = true, adminRights: TelegramChatAdminRights? = nil) -> TelegramChannel {
        let info: TelegramChannelInfo
        if isBroadcast {
            info = TelegramChannelInfo.broadcast(TelegramChannelBroadcastInfo(flags: []))
        } else {
            info = TelegramChannelInfo.group(TelegramChannelGroupInfo(flags: []))
        }
        return TelegramChannel(
            id: id,
            accessHash: accessHash.map { TelegramPeerAccessHash.personal($0) },
            title: title,
            username: nil,
            photo: [],
            creationDate: 0,
            version: 0,
            participationStatus: participationStatus,
            info: info,
            flags: [],
            restrictionInfo: nil,
            adminRights: adminRights,
            bannedRights: nil,
            defaultBannedRights: nil,
            usernames: [],
            storiesHidden: nil,
            nameColor: nil,
            backgroundEmojiId: nil,
            profileColor: nil,
            profileBackgroundEmojiId: nil,
            emojiStatus: nil,
            approximateBoostLevel: nil,
            subscriptionUntilDate: nil,
            verificationIconFileId: nil,
            sendPaidMessageStars: nil,
            linkedMonoforumId: nil
        )
    }

    /// The account record the manager reads at every poll. `state: nil` is "no inner state",
    /// which makes the first poll bootstrap with `updates.getState`.
    func seedAccount(state: AuthorizedAccountState.State?, invalidatedChannels: [AuthorizedAccountState.InvalidatedChannel] = []) {
        let accountPeerId = StateSyncFixture.accountPeerId
        let user = StateSyncFixture.makeUser(id: accountPeerId, firstName: "Account")
        self.transaction { transaction -> Void in
            transaction.setState(AuthorizedAccountState(isTestingEnvironment: false, masterDatacenterId: 2, peerId: accountPeerId, state: state, invalidatedChannels: invalidatedChannels))
            updatePeersCustom(transaction: transaction, peers: [user], update: { _, updated in
                return updated
            })
        }
    }

    /// Stores `peers` the way the sync code does (`updatePeersCustom`; its channel-membership hook
    /// does nothing while `storiesHidden` is nil).
    func seedPeers(_ peers: [Peer]) {
        self.transaction { transaction -> Void in
            updatePeersCustom(transaction: transaction, peers: peers, update: { _, updated in
                return updated
            })
        }
    }

    /// A channel and, when given, its stored `ChannelState`. `state: nil` is a channel the account
    /// knows but has no pts for.
    func seedChannel(_ channel: TelegramChannel, state: ChannelState?) {
        self.transaction { transaction -> Void in
            updatePeersCustom(transaction: transaction, peers: [channel], update: { _, updated in
                return updated
            })
            if let state = state {
                transaction.setPeerChatState(channel.id, state: state)
            }
        }
    }

    /// The local chat state a message update requires for its peer: a chat-list inclusion and
    /// notification settings. Without both, `initialStateWithPeerIds` leaves the peer's chat info
    /// nil and the batch asks `messages.getPeerDialogs` for it (`initialStateWithPeerIds` in Sync/SyncSnapshot.swift and `resolveMissingPeerChatInfos` in Sync/SyncResolve.swift).
    func seedChat(peerId: PeerId, groupId: PeerGroupId = .root) {
        self.transaction { transaction -> Void in
            let minTimestamp = transaction.getPeer(peerId).flatMap(minTimestampForPeerInclusion)
            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: nil, minTimestamp: minTimestamp))
            transaction.updateCurrentPeerNotificationSettings([peerId: TelegramPeerNotificationSettings.defaultSettings])
        }
    }

    func seedReadState(peerId: PeerId, maxIncomingReadId: Int32, maxOutgoingReadId: Int32, maxKnownId: Int32, count: Int32) {
        let state = PeerReadState.idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: maxOutgoingReadId, maxKnownId: maxKnownId, count: count, markedUnread: false)
        self.transaction { transaction -> Void in
            transaction.resetIncomingReadStates([peerId: [Namespaces.Message.Cloud: state]])
        }
    }

    /// A stored cloud message. Channel posts carry `threadId = 1`, as every channel message the
    /// server sends is stored (StoreMessage_Telegram.swift:1207-1209). `.UpperHistoryBlock` also
    /// removes the hole from `id` upward, as a live sync leaves it (Postbox.swift:2204-2219);
    /// `.Random` leaves the holes alone.
    func storeMessage(peerId: PeerId, id: Int32, timestamp: Int32, authorId: PeerId?, text: String, incoming: Bool = true, location: AddMessagesLocation = .UpperHistoryBlock, media: [Media] = []) {
        let threadId: Int64? = peerId.namespace == Namespaces.Peer.CloudChannel ? 1 : nil
        let flags: StoreMessageFlags = incoming ? [.Incoming] : []
        let message = StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: timestamp, flags: flags, tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: text, attributes: [], media: media)
        self.transaction { transaction -> Void in
            let _ = transaction.addMessages([message], location: location)
        }
    }

    /// Clears every cloud hole of `peerId` (all tag spaces too): a fully loaded history.
    func removeAllHoles(peerId: PeerId) {
        self.transaction { transaction -> Void in
            transaction.removeHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
        }
    }

    /// Writes the app configuration the manager consults (e.g. `ios_disable_parallel_channel_reset_v2`).
    func seedAppConfiguration(_ dictionary: [String: Any]) {
        let configuration = AppConfiguration(data: JSON(dictionary: dictionary), hash: 1)
        self.transaction { transaction -> Void in
            updateAppConfiguration(transaction: transaction, { _ in
                return configuration
            })
        }
    }

    // MARK: - Reading back

    func accountState() -> AuthorizedAccountState? {
        return self.transaction { transaction -> AuthorizedAccountState? in
            return transaction.getState() as? AuthorizedAccountState
        } ?? nil
    }

    func channelState(_ peerId: PeerId) -> ChannelState? {
        return self.transaction { transaction -> ChannelState? in
            return transaction.getPeerChatState(peerId) as? ChannelState
        } ?? nil
    }

    func peer(_ peerId: PeerId) -> Peer? {
        return self.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        } ?? nil
    }

    func message(_ id: MessageId) -> Message? {
        return self.transaction { transaction -> Message? in
            return transaction.getMessage(id)
        } ?? nil
    }

    /// The raw cloud holes of `peerId` (space `.everywhere`). NB: the first touch of a CloudUser /
    /// CloudGroup / CloudChannel peer initializes it with `1...Int32.max-1`
    /// (MessageHistoryHoleIndexTable.swift:178-202), so this read WRITES that hole for a peer the
    /// sync never touched.
    func holes(peerId: PeerId) -> IndexSet {
        return self.transaction { transaction -> IndexSet in
            return transaction.getHoles(peerId: peerId, namespace: Namespaces.Message.Cloud)
        } ?? IndexSet()
    }

    func combinedReadState(_ peerId: PeerId) -> CombinedPeerReadState? {
        return self.transaction { transaction -> CombinedPeerReadState? in
            return transaction.getCombinedPeerReadState(peerId)
        } ?? nil
    }

    // MARK: - The manager

    /// Builds the real manager with what `standaloneStateManager` passes to `AccountStateManager(...)` (Account.swift)
    /// but the given network and, unless asked, `ignoresShortSentMessages: false`, as the app's own account has it
    /// (`Account` passes `supplementary`). `MessagesRemovedContext` is owned by the manager itself.
    /// `shouldKeepOnlinePresence: true` makes `reset()` send `messages.receivedQueue` acks
    /// (the applied-qts pipeline in `AccountStateManager.Impl`); the default keeps the request log free of them.
    /// Does not call `reset()`: updates added before it are dropped (Q8), which a test checks.
    @discardableResult
    func makeStateManager(network: Network, shouldKeepOnlinePresence: Signal<Bool, NoError> = .single(false), ignoresShortSentMessages: Bool = false) -> AccountStateManager {
        precondition(self.stateManager == nil)
        let stateManager = AccountStateManager(
            accountPeerId: StateSyncFixture.accountPeerId,
            accountManager: self.accountManager,
            postbox: self.postbox,
            network: network,
            callSessionManager: nil,
            shouldKeepOnlinePresence: shouldKeepOnlinePresence,
            peerInputActivityManager: nil,
            auxiliaryMethods: StateSyncFixture.makeAuxiliaryMethods(),
            ignoresShortSentMessages: ignoresShortSentMessages,
            gapWaitTimeout: StateSyncFixture.gapWaitTimeout
        )
        self.stateManager = stateManager
        return stateManager
    }

    /// An app restart (the truth server's sessions): releases the manager `makeStateManager` built, so the next
    /// `makeStateManager` builds the relaunched app's. Drop the old manager's update sink first
    /// (`ScriptedServer.dropUpdateSinks`), or pushes still reach it.
    func releaseStateManager() {
        self.stateManager = nil
    }

    /// Subscribe to whatever the test observes (`isUpdating` first: it starts `true`) before this.
    func resetStateManager() {
        self.stateManager!.reset()
    }

    /// The RPC-result path (`stateManager.addUpdates`), as ~155 call sites use it. Server pushes go
    /// through `ScriptedServer.push` instead.
    func addUpdates(_ updates: Api.Updates) {
        self.stateManager!.addUpdates(updates)
    }

    // MARK: - Teardown

    /// Releases everything and removes the directory. Returns whether the Postbox was released
    /// within 5 s. False has three ordinary causes this cannot tell apart: the test still holds the
    /// manager `makeStateManager` returned; the network still holds an unanswered request (its
    /// closures capture the postbox strongly); a `retryRequest` loop is mid-backoff.
    /// `StateSyncTestCase.tearDown` fails the test on false unless it set `retainedPostboxAtCloseReason`,
    /// which a test that leaves a request stalled on purpose does. The directory is removed either way.
    @discardableResult
    func close() -> Bool {
        for disposable in self.disposables {
            disposable.dispose()
        }
        self.disposables = []
        // The manager's Impl is released on its own private queue (QueueLocalObject); in-flight
        // signals capture the manager weakly but the postbox and network strongly.
        self.stateManager = nil

        // Each media box opens its storage databases lazily on StorageBox's queue; removing the
        // directory while that open is in flight trips an assertion in SQLite setup (see
        // PostboxFixture.close). One round trip per storage box makes sure the opens finished.
        if let postbox = self.postbox {
            self.waitForStorage(postbox.mediaBox)
        }
        if let accountManager = self.accountManager {
            self.waitForStorage(accountManager.mediaBox)
        }

        weak var weakPostbox: Postbox? = self.postbox
        self.postbox = nil
        let deadline = Date().addingTimeInterval(5.0)
        while weakPostbox != nil && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.005)
        }
        let released = weakPostbox == nil
        // PostboxImpl and its value box are released on Postbox.sharedQueue; this drains it.
        Postbox.sharedQueue.sync {
        }

        self.accountManager = nil
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        return released
    }

    private func waitForStorage(_ mediaBox: MediaBox) {
        for storageBox in [mediaBox.storageBox, mediaBox.cacheStorageBox] {
            let ready = DispatchSemaphore(value: 0)
            let disposable = storageBox.totalSize().start(next: { _ in
                ready.signal()
            })
            let _ = ready.wait(timeout: .now() + 10.0)
            disposable.dispose()
        }
    }
}
