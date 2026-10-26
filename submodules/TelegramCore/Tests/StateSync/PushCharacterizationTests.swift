import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// Pushed update batches (`batchUpdates` / `processBatch`), pinned as they behave at
/// 171825ce49.
final class PushCharacterizationTests: StateSyncTestCase {
    /// Flow 4. An in-order pts push is applied with no request; pts advances, date stays.
    func testInOrderPushIsAppliedWithoutRequests() {
        let user = self.seedUserChat(200)
        self.launchIdle()

        self.server.push(StateSyncApi.updateShortMessage(id: 101, userId: 200, pts: 101, date: self.baseDate + 2))
        self.waitForNotification(of: self.messageId(user, 101))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 101, qts: 5, date: self.baseDate + 1, seq: 10))
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// G4 (fixed). An updateDialogPinned naming a folder (`dialogPeerFolder`, which has no peer id) is
    /// skipped; it was `preconditionFailure()`, which crashed the app (or the extension) on the batch,
    /// and on every launch when it came in a difference. The chat pinned in the same batch is pinned.
    func testDialogPinnedFolderIsSkippedAndTheRestOfTheBatchApplies() {
        let user = self.seedUserChat(200)
        self.fixture.storeMessage(peerId: user, id: 1, timestamp: self.baseDate, authorId: user, text: "stored")
        self.launchIdle()

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateDialogPinned(StateSyncApi.dialogPeerFolder(), pinned: true),
            StateSyncApi.updateDialogPinned(StateSyncApi.dialogPeerUser(200), pinned: true)
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        let pinned = self.fixture.transaction { transaction -> [PinnedItemId] in
            return transaction.getPinnedItemIds(groupId: .root)
        }
        XCTAssertEqual(pinned, [.peer(user)])
    }

    /// G4 (fixed). An updatePinnedDialogs order containing a folder is applied without it; it was
    /// `preconditionFailure()`. The chats are reordered as the rest of the order says.
    func testPinnedDialogsOrderWithAFolderReordersTheChats() {
        let first = self.seedUserChat(200)
        let second = self.seedUserChat(201)
        self.fixture.storeMessage(peerId: first, id: 1, timestamp: self.baseDate, authorId: first, text: "stored")
        self.fixture.storeMessage(peerId: second, id: 1, timestamp: self.baseDate, authorId: second, text: "stored")
        self.fixture.transaction { transaction -> Void in
            transaction.setPinnedItemIds(groupId: .root, itemIds: [.peer(first), .peer(second)])
        }
        let seeded = self.fixture.transaction { transaction -> [PinnedItemId] in
            return transaction.getPinnedItemIds(groupId: .root)
        }
        XCTAssertEqual(seeded, [.peer(first), .peer(second)])
        self.launchIdle()

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updatePinnedDialogs(order: [
                StateSyncApi.dialogPeerFolder(),
                StateSyncApi.dialogPeerUser(201),
                StateSyncApi.dialogPeerUser(200)
            ])
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        let pinned = self.fixture.transaction { transaction -> [PinnedItemId] in
            return transaction.getPinnedItemIds(groupId: .root)
        }
        XCTAssertEqual(pinned, [.peer(second), .peer(first)])
    }

    /// Flow 5, part 1. With a pts hole in a batch the in-order prefix is applied and dispatched; after the
    /// gap wait a getDifference runs from the prefix's pts. The update after the hole is not applied from the
    /// batch; the getDifference from the prefix's pts is what fetches it.
    func testCommonPtsHoleAppliesPrefixThenPollsAfterGapWait() {
        let user = self.seedUserChat(200)
        self.launchIdle()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            newMessages: [self.incomingMessage(103, from: 200)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            state: StateSyncApi.state(pts: 103, qts: 5, date: self.baseDate + 3, seq: 10)
        )))

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateNewMessage(self.incomingMessage(101, from: 200), pts: 101),
            StateSyncApi.updateNewMessage(self.incomingMessage(103, from: 200), pts: 103)
        ], date: self.baseDate + 2, seq: 0))

        self.isUpdating.wait { $0 == [true, false, true, false] }
        self.waitForNotification(of: self.messageId(user, 103))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(1, pts: 101, date: self.baseDate + 1, qts: 5)
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 103)))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 103)
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(user, 101)], [self.messageId(user, 103)]])
    }

    /// Flow 5, part 2, pins Q5. Update groups that arrive while the gap wait is the last queued operation
    /// are merged into it and dropped when it times out into a getDifference. Here: an in-order post for a
    /// channel whose state is known, which outside the wait is stored with no request
    /// (ChannelSyncCharacterizationTests.testInOrderChannelPushIsStored).
    func testGroupsArrivingDuringGapWaitAreDropped() {
        let user = self.seedUserChat(200)
        let channel = self.seedChannel(300, pts: 50, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 10)))

        // dispatchEvents for the prefix runs after the gap wait was queued behind it; its notification is
        // delivered on the manager's queue, where pushInline's groups join the queue at once.
        let prefixId = self.messageId(user, 101)
        let pushedIntoGap = Atomic<Bool>(value: false)
        let server: ScriptedServer = self.server
        let channelPost = StateSyncApi.updates([
            StateSyncApi.updateNewChannelMessage(StateSyncApi.channelPost(id: 11, channelId: 300, date: self.baseDate + 2), pts: 51)
        ], date: self.baseDate + 2, seq: 0)
        let trigger = self.stateManager.notificationMessages.start(next: { batch in
            let isPrefix = batch.contains(where: { entry in entry.0.contains(where: { $0.id == prefixId }) })
            if isPrefix && !pushedIntoGap.swap(true) {
                server.pushInline(channelPost)
            }
        })
        defer {
            trigger.dispose()
        }

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateNewMessage(self.incomingMessage(101, from: 200), pts: 101),
            StateSyncApi.updateNewMessage(self.incomingMessage(103, from: 200), pts: 103)
        ], date: self.baseDate + 2, seq: 0))

        self.isUpdating.wait { $0 == [true, false, true, false] }
        self.drainOperationQueue()

        XCTAssertTrue(pushedIntoGap.with { $0 })
        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        // Q5: the post is gone, and nothing asks the channel for it.
        XCTAssertNil(self.fixture.message(self.messageId(channel, 11)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 50)
    }

    /// Flow 6, G2 (qts, fixed). An exact duplicate of the last applied qts update is already applied and is
    /// skipped: no gap wait, no getDifference, the state is unchanged. The qts range of an update is
    /// `(qts, 1)`, skipped when `local >= qts`. Until G2 was fixed the skip test was `local >= qts + 1`, so the
    /// duplicate was a hole and cost the gap wait and a getDifference.
    func testQtsDuplicateIsSkipped() {
        self.launchIdle(state: self.state(pts: 100, qts: 5))
        // Only a regression sends it (after the gap wait); answered so that it fails on the log, not a hang.
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 10)))

        self.pushAndSettle(StateSyncApi.updates([
            StateSyncApi.updateNewEncryptedMessage(chatId: 1, randomId: 1, date: self.baseDate + 2, qts: 5)
        ], date: self.baseDate + 2, seq: 0))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10))
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// Flow 6, seq variant, G2 (updatesCombined, fixed). An in-order updatesCombined (seq_start == local + 1)
    /// is applied: seq and date move to the container's, with no request. Its range is
    /// `(seq, seq - seqStart + 1)`. Until G2 was fixed it was `(seq, seq - seqStart)`, so an in-order
    /// container was a hole and cost the gap wait and a getDifference.
    func testInOrderUpdatesCombinedIsApplied() {
        self.seedUserChat(200)
        self.launchIdle(state: self.state(pts: 100, seq: 10))
        // Only a regression sends it (after the gap wait); its date differs from the container's.
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 11)))

        self.pushAndSettle(StateSyncApi.updatesCombined([StateSyncApi.updateUserTyping(userId: 200)], date: self.baseDate + 2, seqStart: 11, seq: 11))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, date: self.baseDate + 2, seq: 11))
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// G2 (updatesCombined). A container covering two seq values from local + 1 is applied and moves seq to
    /// its end. With `seqStart == seq` (the test above) a count of 1 would also pass; this one needs
    /// `seq - seqStart + 1`.
    func testInOrderUpdatesCombinedSpanningTwoSeqIsApplied() {
        self.seedUserChat(200)
        self.launchIdle(state: self.state(pts: 100, seq: 10))
        // Only a regression sends it (after the gap wait); its date differs from the container's.
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 12)))

        self.pushAndSettle(StateSyncApi.updatesCombined([StateSyncApi.updateUserTyping(userId: 200)], date: self.baseDate + 2, seqStart: 11, seq: 12))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, date: self.baseDate + 2, seq: 12))
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// G2 (seq). A plain `updates` container with seq != 0 has range `(seq, 1)`. One that repeats the last
    /// applied seq is skipped: no gap wait, no getDifference, the state is unchanged. Until G2 was fixed the
    /// skip test was `local >= seq + 1`, so it was a hole.
    func testSeqDuplicateIsSkipped() {
        self.seedUserChat(200)
        self.launchIdle(state: self.state(pts: 100, seq: 10))
        // Only a regression sends it (after the gap wait); its date differs from the stored one.
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 10)))

        self.pushAndSettle(StateSyncApi.updates([StateSyncApi.updateUserTyping(userId: 200)], date: self.baseDate + 2, seq: 10))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10))
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// Control for G2. An in-order plain container (seq == local + 1) is applied: seq and date move to its
    /// own, with no request. Unchanged by the G2 fix.
    func testInOrderSeqContainerIsApplied() {
        self.seedUserChat(200)
        self.launchIdle(state: self.state(pts: 100, seq: 10))
        // Only a regression sends it (after the gap wait); its date differs from the container's.
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 11)))

        self.pushAndSettle(StateSyncApi.updates([StateSyncApi.updateUserTyping(userId: 200)], date: self.baseDate + 2, seq: 11))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, date: self.baseDate + 2, seq: 11))
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// Pushes `updates` and returns once the batch has run, and so has the gap wait and getDifference a hole
    /// would queue. The gap wait can land behind the first drain's barrier, so one drain is not enough to
    /// see it; the second drain's barrier runs only after the gap wait's getDifference
    /// (`replaceOperations` keeps custom operations behind the poll). A skipped or applied batch queues
    /// nothing, and both drains return at once.
    private func pushAndSettle(_ updates: Api.Updates, file: StaticString = #filePath, line: UInt = #line) {
        self.server.push(updates)
        self.drainOperationQueue(file: file, line: line)
        self.drainOperationQueue(file: file, line: line)
    }

    /// Flow 7, Q4 fixed. A session reset in the same batch as a real update: the batch is applied and
    /// committed, then a getDifference is forced, and the batch's events are delivered (the difference does
    /// not bring them again, pts already moved). They are queued before the forced poll replaces the queue,
    /// which keeps them behind the new poll, so they run after it.
    func testResetInBatchCommitsAndDeliversEvents() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .hold)
        self.fixture.resetStateManager()
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference))

        // Both land in one batch behind the running poll.
        self.server.push(StateSyncApi.updateShortMessage(id: 101, userId: 200, pts: 101, date: self.baseDate + 2))
        self.server.pushSessionReset()
        self.server.flush()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 10)))
        XCTAssertTrue(self.server.release(Name.getDifference, with: .result(StateSyncApi.differenceEmpty(date: self.baseDate + 1, seq: 10))))

        self.isUpdating.wait { $0 == [true, false, true, false] }
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(1, pts: 101, date: self.baseDate + 1, qts: 5)
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 101)
        // Q4: stored and notified once.
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(user, 101)]])
    }
}
