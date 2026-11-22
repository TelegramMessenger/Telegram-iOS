import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// Base class of the state-sync characterization tests: the real `AccountStateManager` over a temporary
/// Postbox, talking to a `ScriptedServer` through a real `Network` (`Network.makeForTesting`).
///
/// These tests pin the behaviour of the code, by the ids in `docs/state-sync-audit-2026-10.md`. The
/// tests of the ids fixed in stage 7 (Q1, Q2, Q3, Q4, Q11, Q12, Q13, G1, G2, G4, R1, R2, R6, C2, C3,
/// C11) pin the FIXED behaviour; the ids still pinned as defects are Q5 and Q8. The refactor must keep
/// every test green unchanged; a later fix commit changes the one assertion its defect pins, in that commit.
class StateSyncTestCase: XCTestCase {
    typealias Name = StateSyncRequestName
    typealias NotificationBatch = [([Message], PeerGroupId, Bool, MessageHistoryThreadData?)]

    /// An arbitrary epoch for message and state dates.
    let baseDate: Int32 = 1_700_000_000

    var fixture: StateSyncFixture!
    var server: ScriptedServer!
    var network: Network!
    var stateManager: AccountStateManager!
    var isUpdating: SignalRecorder<Bool>!
    var notifications: SignalRecorder<NotificationBatch>!
    var significantUpdates: SignalRecorder<Void>!

    /// Why this test may end with its Postbox still retained, or nil (the default): then tearDown fails
    /// when the Postbox outlives `close()`. A request left unanswered keeps its subscriber chain, and the
    /// Postbox that chain captured, alive for good: the scripted server's disposable holds the request,
    /// the request's completion holds the subscriber, and the subscriber holds the disposable until it
    /// terminates. A test that leaves work in flight on purpose names it here.
    var retainedPostboxAtCloseReason: String?

    /// Which `openPostbox` flags the fixture reproduces; the notification-extension tests override it.
    var fixtureProfile: StateSyncFixture.OpenProfile {
        return .mainApp
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.fixture = try StateSyncFixture(name: "sync", profile: self.fixtureProfile)
        self.server = ScriptedServer()
        self.network = Network.makeForTesting(engine: self.server, basePath: self.fixture.basePath + "/network", encryptionProvider: UnusedEncryptionProvider())
        // A foreground app. The scripted server does not model pause, but this keeps the network's own
        // state the same as in the app.
        self.network.shouldKeepConnection.set(.single(true))
    }

    override func tearDown() {
        // Read before they are dropped: what a retained Postbox most likely hangs on.
        let heldAtEnd = self.server?.heldNames ?? []
        self.server?.dropHeld()
        self.isUpdating = nil
        self.notifications = nil
        self.significantUpdates = nil
        self.stateManager = nil
        self.network = nil
        if let fixture = self.fixture {
            let released = fixture.close()
            if !released && self.retainedPostboxAtCloseReason == nil {
                XCTFail("the Postbox was still retained 5 s after close(); requests held when the test ended: \(heldAtEnd). Answer what the test leaves in flight, or set retainedPostboxAtCloseReason if it does so on purpose")
            }
        }
        self.fixture = nil
        self.server = nil
        super.tearDown()
    }

    // MARK: - Building

    /// Builds the manager and subscribes the recorders BEFORE `reset()`, so `isUpdating` records its
    /// initial `true` and no event can be missed. Does not call `reset()`.
    func makeStateManager(shouldKeepOnlinePresence: Signal<Bool, NoError> = .single(false), ignoresShortSentMessages: Bool = false) {
        let stateManager = self.fixture.makeStateManager(network: self.network, shouldKeepOnlinePresence: shouldKeepOnlinePresence, ignoresShortSentMessages: ignoresShortSentMessages)
        self.stateManager = stateManager
        self.isUpdating = self.fixture.observe(stateManager.isUpdating)
        self.notifications = self.fixture.observe(stateManager.notificationMessages)
        self.significantUpdates = self.fixture.observe(stateManager.significantStateUpdateCompleted)
    }

    func state(pts: Int32, qts: Int32 = 5, date: Int32? = nil, seq: Int32 = 10) -> AuthorizedAccountState.State {
        return AuthorizedAccountState.State(pts: pts, qts: qts, date: date ?? self.baseDate, seq: seq)
    }

    /// Seeds `state` (default pts 100, qts 5, date baseDate, seq 10), builds the manager, answers the launch
    /// getDifference with an empty difference and waits until the operation queue is idle. Afterwards the
    /// stored state is `(state.pts, state.qts, baseDate + 1, state.seq)` and the request log holds exactly
    /// one `updates.getDifference`.
    func launchIdle(state: AuthorizedAccountState.State? = nil, ignoresShortSentMessages: Bool = false) {
        let state = state ?? self.state(pts: 100)
        self.fixture.seedAccount(state: state)
        self.makeStateManager(ignoresShortSentMessages: ignoresShortSentMessages)
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 1, seq: state.seq)))
        self.fixture.resetStateManager()
        self.isUpdating.wait { $0.last == false }
        self.drainOperationQueue()
    }

    // MARK: - Peers

    /// A user the account chats with, stored with chat-list inclusion and notification settings so that a
    /// batch mentioning it sends no `messages.getPeerDialogs` (StateSyncFixture.seedChat).
    @discardableResult
    func seedUserChat(_ id: Int64) -> PeerId {
        let peerId = StateSyncFixture.userPeerId(id)
        self.fixture.seedPeers([StateSyncFixture.makeUser(id: peerId, accessHash: 1, firstName: "U\(id)")])
        self.fixture.seedChat(peerId: peerId)
        return peerId
    }

    /// A member broadcast channel (access hash 1 by default, as `StateSyncApi.broadcastChannel`; nil stores it
    /// without one, so no input channel can be built for it), stored with chat-list inclusion and notification
    /// settings, a `ChannelState` when `pts` is given and one stored cloud message when `storedMessageId` is given.
    @discardableResult
    func seedChannel(_ id: Int64, pts: Int32?, storedMessageId: Int32?, accessHash: Int64? = 1) -> PeerId {
        let peerId = StateSyncFixture.channelPeerId(id)
        let channel = StateSyncFixture.makeChannel(id: peerId, accessHash: accessHash, title: "C\(id)")
        self.fixture.seedChannel(channel, state: pts.map { ChannelState(pts: $0, invalidatedPts: nil, synchronizedUntilMessageId: nil) })
        self.fixture.seedChat(peerId: peerId)
        if let storedMessageId = storedMessageId {
            self.fixture.storeMessage(peerId: peerId, id: storedMessageId, timestamp: self.baseDate, authorId: nil, text: "stored")
        }
        return peerId
    }

    func messageId(_ peerId: PeerId, _ id: Int32) -> MessageId {
        return MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)
    }

    /// An incoming private message from user `userId` in the chat with them.
    func incomingMessage(_ id: Int32, from userId: Int64, date: Int32? = nil) -> Api.Message {
        return StateSyncApi.privateMessage(id: id, peerUserId: userId, fromUserId: userId, date: date ?? (self.baseDate + 2))
    }

    // MARK: - Waiting and observing

    /// Returns once every operation queued on the manager so far has finished: everything the scripted
    /// server already scheduled is handed over first, then a no-op custom operation is appended and
    /// awaited. Do not call it while a request the queue waits on is held. Do not use it in a test that
    /// observes where pushes land in the queue: a custom operation at the tail stops a push from merging
    /// into a trailing update batch.
    func drainOperationQueue(file: StaticString = #filePath, line: UInt = #line) {
        self.server.flush()
        let _ = self.fixture.wait(self.stateManager.addCustomOperation(Signal<Void, NoError>.single(Void())), file: file, line: line)
    }

    /// Returns after the manager queue has run every block already queued on it (a subscription to
    /// `isUpdating` runs there via `QueueLocalObject`); does not touch the operation queue.
    func managerQueueRoundTrip(file: StaticString = #filePath, line: UInt = #line) {
        let _ = self.fixture.wait(self.stateManager.isUpdating |> take(1), file: file, line: line)
    }

    /// Message ids of every notification batch delivered so far, one array per non-empty delivery
    /// (`dispatchEvents` also delivers empty batches, which are left out).
    func notifiedMessageIds() -> [[MessageId]] {
        return self.notifications.values.map { batch in
            return batch.flatMap { entry in entry.0.map { $0.id } }
        }.filter { !$0.isEmpty }
    }

    func waitForNotification(of id: MessageId, file: StaticString = #filePath, line: UInt = #line) {
        self.notifications.wait(file: file, line: line, until: { batches in
            return batches.contains(where: { batch in batch.contains(where: { entry in entry.0.contains(where: { $0.id == id }) }) })
        })
    }

    /// Asserts that request `index` is `updates.getDifference` with exactly these arguments. `ptsTotalLimit`
    /// defaults to what both pollers send when the app configuration has no `pts_total_limit` (10000); nil
    /// asserts a request without the limit.
    func assertGetDifference(_ index: Int, pts: Int32, date: Int32, qts: Int32, ptsTotalLimit: Int32? = 10000, file: StaticString = #filePath, line: UInt = #line) {
        let requests = self.server.requests
        guard index < requests.count else {
            XCTFail("no request \(index); log: \(requests.map { $0.name })", file: file, line: line)
            return
        }
        XCTAssertEqual(requests[index].name, Name.getDifference, file: file, line: line)
        XCTAssertEqual(requests[index].payload, StateSyncApi.getDifferencePayload(pts: pts, date: date, qts: qts, ptsTotalLimit: ptsTotalLimit), "arguments: \(requests[index].arguments)", file: file, line: line)
    }
}
