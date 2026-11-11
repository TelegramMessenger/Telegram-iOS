import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// Pushed batches, pinned before the seam work rewrites how a batch is sequenced and how its events are built:
/// the in-batch pts and qts order (the sort lives only in `ptsUpdates()` / `qtsUpdates()`, UpdateGroup.swift),
/// the events term that queues a `dispatchEvents` for an own-presence-only batch, and the qts acknowledgement
/// (`messages.receivedQueue`).
final class PushOrderingPinTests: StateSyncTestCase {
    /// Pushes `updates` and returns once the batch has run, and so has the gap wait and getDifference a hole
    /// would queue (PushCharacterizationTests.pushAndSettle explains why two drains). A batch that is applied
    /// queues nothing after it, and both drains return at once.
    private func pushAndSettle(_ updates: Api.Updates, file: StaticString = #filePath, line: UInt = #line) {
        self.server.push(updates)
        self.drainOperationQueue(file: file, line: line)
        self.drainOperationQueue(file: file, line: line)
    }

    /// The random ids queued for secret chat `chatId` (the incoming encrypted operation log), in queue order.
    /// The harness seeds no SecretChatState, so nothing decrypts them.
    private func queuedEncryptedRandomIds(chatId: Int64) -> [Int64] {
        let secretChatId = PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(chatId))
        return self.fixture.transaction { transaction -> [Int64] in
            var randomIds: [Int64] = []
            transaction.operationLogEnumerateEntries(peerId: secretChatId, tag: OperationLogTags.SecretIncomingEncrypted, { entry in
                if let operation = entry.contents as? SecretChatIncomingEncryptedOperation {
                    randomIds.append(operation.globallyUniqueId)
                }
                return true
            })
            return randomIds
        } ?? []
    }

    private var accountUserId: Int64 {
        return StateSyncFixture.accountPeerId.id._internalGetInt64Value()
    }

    /// One batch carrying its pts updates out of order, `[pts 102, pts 101]` with local pts 100, is applied in
    /// pts order: both messages are stored and notified in one batch, pts ends at 102 and nothing is requested.
    /// The order comes from the sort in `ptsUpdates()` alone; without it 102 meets local 100 as a hole, 101 is
    /// held behind it, and the batch costs the gap wait and a getDifference.
    func testOutOfOrderPtsUpdatesInOneBatchAreAppliedInPtsOrder() {
        let user = self.seedUserChat(200)
        self.launchIdle()
        // Only a regression sends it (after the gap wait); answered so that it fails on the log, not a hang.
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 10)))

        self.pushAndSettle(StateSyncApi.updates([
            StateSyncApi.updateNewMessage(self.incomingMessage(102, from: 200), pts: 102),
            StateSyncApi.updateNewMessage(self.incomingMessage(101, from: 200), pts: 101)
        ], date: self.baseDate + 2, seq: 0))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference], "the out-of-order batch was treated as a pts hole")
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 102)))
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 102, qts: 5, date: self.baseDate + 1, seq: 10))
        let notified = self.notifiedMessageIds()
        XCTAssertEqual(notified.count, 1, "notified: \(notified)")
        XCTAssertEqual(Set(notified.flatMap { $0 }), Set([self.messageId(user, 101), self.messageId(user, 102)]))
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// The qts twin: `[qts 7, qts 6]` with local qts 5 is applied in qts order (the sort in `qtsUpdates()`):
    /// both encrypted messages are queued for their secret chat, 6 first, qts ends at 7 and nothing is
    /// requested. With `shouldKeepOnlinePresence` false (the harness default) the applied qts is not
    /// acknowledged either: no messages.receivedQueue.
    func testOutOfOrderQtsUpdatesInOneBatchAreAppliedInQtsOrder() {
        self.launchIdle(state: self.state(pts: 100, qts: 5))
        // Only a regression sends it (after the gap wait); answered so that it fails on the log, not a hang.
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 10)))

        self.pushAndSettle(StateSyncApi.updates([
            StateSyncApi.updateNewEncryptedMessage(chatId: 1, randomId: 7, date: self.baseDate + 2, qts: 7),
            StateSyncApi.updateNewEncryptedMessage(chatId: 1, randomId: 6, date: self.baseDate + 2, qts: 6)
        ], date: self.baseDate + 2, seq: 0))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference], "the out-of-order batch was treated as a qts hole, or acknowledged without online presence")
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 7, date: self.baseDate + 1, seq: 10))
        XCTAssertEqual(self.queuedEncryptedRandomIds(chatId: 1), [6, 7])
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// A batch whose only content is the account's own presence (`updateUserStatus` for the account user) still
    /// queues a `dispatchEvents` operation: the replay turns it into `delayNotificatonsUntil`, which today is
    /// read only by `AccountFinalStateEvents.isEmpty`. The operation is visible as one empty notification
    /// delivery. Whoever rewrites the events init must keep that term (or its replacement) in `isEmpty`.
    func testOwnPresenceOnlyBatchStillQueuesProcessEvents() {
        self.launchIdle()
        let deliveriesBefore = self.notifications.values.count

        self.pushAndSettle(StateSyncApi.updates([
            .updateUserStatus(.init(userId: self.accountUserId, status: .userStatusOnline(.init(expires: self.baseDate + 300))))
        ], date: self.baseDate + 2, seq: 0))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.notifications.values.count, deliveriesBefore + 1, "an own-presence-only batch queued no processEvents")
        XCTAssertEqual(self.notifications.values.last?.count, 0, "the delivery carries no messages")
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// Control for the test above: another user's presence alone produces empty events, so no `dispatchEvents`
    /// is queued and nothing is delivered.
    func testAnotherUsersPresenceOnlyBatchQueuesNoProcessEvents() {
        self.seedUserChat(200)
        self.launchIdle()
        let deliveriesBefore = self.notifications.values.count

        self.pushAndSettle(StateSyncApi.updates([
            .updateUserStatus(.init(userId: 200, status: .userStatusOnline(.init(expires: self.baseDate + 300))))
        ], date: self.baseDate + 2, seq: 0))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.notifications.values.count, deliveriesBefore)
    }

    /// The qts acknowledgement: with `shouldKeepOnlinePresence` true, the batch's `dispatchEvents` hands the
    /// applied qts to the ack pipeline (`appliedQtsPromise` in `AccountStateManager.Impl`), which sends exactly
    /// one `messages.receivedQueue(max_qts: 6)`. A duplicate of the same qts afterwards is skipped by the
    /// sequencer, so it acknowledges nothing again; the launch's empty difference applied no qts and
    /// acknowledged nothing.
    func testAppliedQtsIsAcknowledgedWithOneReceivedQueue() {
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5))
        self.makeStateManager(shouldKeepOnlinePresence: .single(true))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 1, seq: 10)))
        // `messages.receivedQueue` returns `Vector<long>`; every one is answered, so a repeat shows in the log.
        self.server.always(Name.receivedQueue, { _ in
            return .result([Int64]())
        })
        self.fixture.resetStateManager()
        self.isUpdating.wait { $0.last == false }
        self.drainOperationQueue()
        XCTAssertEqual(self.server.requestNames, [Name.getDifference], "precondition: the launch applied no qts")

        self.pushAndSettle(StateSyncApi.updates([
            StateSyncApi.updateNewEncryptedMessage(chatId: 1, randomId: 6, date: self.baseDate + 2, qts: 6)
        ], date: self.baseDate + 2, seq: 0))
        XCTAssertTrue(self.server.waitForRequest(Name.receivedQueue), "the applied qts was not acknowledged: \(self.server.requestNames)")
        // The same qts again: already applied, skipped, nothing new to acknowledge. The acknowledgement runs
        // through `appliedQtsPromise`, off the operation queue that `pushAndSettle` drains, so a second one is
        // waited for over a short window.
        self.pushAndSettle(StateSyncApi.updates([
            StateSyncApi.updateNewEncryptedMessage(chatId: 1, randomId: 6, date: self.baseDate + 2, qts: 6)
        ], date: self.baseDate + 2, seq: 0))
        XCTAssertFalse(self.server.waitForRequest(Name.receivedQueue, count: 2, timeout: 0.5), "the duplicate qts was acknowledged again: \(self.server.requestNames)")

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.receivedQueue])
        XCTAssertEqual(self.server.requests.last?.payload, Api.functions.messages.receivedQueue(maxQts: 6).1.makeData(), "arguments: \(self.server.requests.last?.arguments ?? "none")")
        XCTAssertEqual(self.fixture.accountState()?.state?.qts, 6)
    }
}
