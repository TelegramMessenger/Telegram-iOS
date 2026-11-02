import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// Where a replay's events land in the operation queue, pinned as it is today for the stages that move event
/// delivery (audit Q4 and Q9; parked review findings of the 2026-10-15 fixes).
final class EventDeliveryOrderTests: StateSyncTestCase {
    /// Q4 delivery order, today. A pushed batch that forces a poll (here a session reset) commits its replay and
    /// queues its events BEFORE the forced poll's `replaceOperations`, which puts the queued `stateBarrier`
    /// barrier before them. When the poll ends, its own events are inserted in front of the barrier, the barrier
    /// is postponed behind the batch's events, and so the newer events (the poll's 102) are delivered before
    /// the older ones (the batch's 101); the barrier, queued before the push, completes after both and carries
    /// their ids in delivery order. Without a barrier the batch's events run first (PushCharacterizationTests,
    /// flow 7). Pinned so that stage 4 changes the order on purpose.
    func testForcedPollEventsOvertakeTheBatchEventsWhenABarrierIsQueued() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .hold)
        self.fixture.resetStateManager()
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference))

        // The barrier is queued behind the running launch poll, before the push.
        self.server.on(Name.helpTest, .result(StateSyncApi.boolTrue()))
        let barrier = self.fixture.observe(self.stateManager.pollStateUpdateCompletion())
        self.managerQueueRoundTrip()

        // One batch behind the barrier: a message and a session reset, which forces a poll once the batch is
        // committed.
        self.server.push(StateSyncApi.updateShortMessage(id: 101, userId: 200, pts: 101, date: self.baseDate + 2))
        self.server.pushSessionReset()
        self.server.flush()
        self.managerQueueRoundTrip()
        // The forced poll brings a newer message.
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            newMessages: [self.incomingMessage(102, from: 200, date: self.baseDate + 3)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            state: StateSyncApi.state(pts: 102, qts: 5, date: self.baseDate + 3, seq: 10)
        )))
        XCTAssertTrue(self.server.release(Name.getDifference, with: .result(StateSyncApi.differenceEmpty(date: self.baseDate + 1, seq: 10))))

        barrier.wait { $0.count == 1 }
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference, Name.helpTest])
        self.assertGetDifference(1, pts: 101, date: self.baseDate + 1, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 102)
        // Q4, today: the poll's newer event first, the batch's older one after it, each delivered once.
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(user, 102)], [self.messageId(user, 101)]])
        XCTAssertEqual(barrier.values.first, [self.messageId(user, 102), self.messageId(user, 101)])
        XCTAssertEqual(self.isUpdating.values, [true, false, true, false])
    }

    /// Q9's window. While an asynchronous channel reset (the context `addAsyncResetChannels` builds) is pending,
    /// two more polls run: `reset()` twice, so one runs while the other waits. The first names the same channel
    /// again, which the pending context already has (no second messages.getPeerDialogs); neither ends the
    /// cycle, isUpdating stays true. When the reset answers, its replay runs once: one event batch for the
    /// channel's post, one significantStateUpdateCompleted, isUpdating false, the invalidated-channel record
    /// cleared. The poll that would make the context replay twice ends between its replay transaction and that
    /// transaction's delivery, which the harness cannot place deterministically (see the task page).
    func testPollsQueuedWhileAChannelResetIsPendingReplayItOnce() {
        let channel = self.seedChannel(302, pts: 50, storedMessageId: 10)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        let channelTooLong = StateSyncApi.difference(
            otherUpdates: [StateSyncApi.updateChannelTooLong(channelId: 302, pts: 60)],
            chats: [StateSyncApi.broadcastChannel(id: 302, title: "C302")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )
        self.server.on(Name.getDifference, .result(channelTooLong))
        self.server.on(Name.getPeerDialogs, .hold)
        self.fixture.resetStateManager()
        XCTAssertTrue(self.server.waitForRequest(Name.getPeerDialogs))
        // The launch poll has ended into the pending context.
        self.drainOperationQueue()
        XCTAssertEqual(self.isUpdating.values, [true])

        self.server.on(Name.getDifference, .result(channelTooLong))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 1, seq: 10)))
        self.fixture.resetStateManager()
        self.fixture.resetStateManager()
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference, count: 3))
        // The third poll is running at the head of the operation queue. The drain's custom operation is queued
        // behind it and starts only once that poll's answer has been handled and the poll has left the queue, so
        // the checks below read the state after both queued polls ended.
        self.drainOperationQueue()
        // A second reset of the pending channel would send its messages.getPeerDialogs from a Postbox hop, which
        // can land after its poll ended: a short window for it.
        XCTAssertFalse(self.server.waitForRequest(Name.getPeerDialogs, count: 2, timeout: 0.5), "the pending channel was reset again: \(self.server.requestNames)")
        XCTAssertEqual(self.isUpdating.values, [true], "a poll ended the cycle while the reset was pending")
        XCTAssertEqual(self.server.requestNames.filter { $0 == Name.getPeerDialogs }.count, 1, "log: \(self.server.requestNames)")
        XCTAssertEqual(self.significantUpdates.values.count, 0)

        XCTAssertTrue(self.server.release(Name.getPeerDialogs, with: .result(StateSyncApi.peerDialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(302), topMessage: 15, pts: 60)],
            messages: [StateSyncApi.channelPost(id: 15, channelId: 302, date: self.baseDate + 3)],
            chats: [StateSyncApi.broadcastChannel(id: 302, title: "C302")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        ))))
        self.isUpdating.wait { $0 == [true, false] }
        self.waitForNotification(of: self.messageId(channel, 15))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getPeerDialogs, Name.getDifference, Name.getDifference])
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(channel, 15)]], "the reset's events were delivered more than once")
        XCTAssertEqual(self.significantUpdates.values.count, 1)
        XCTAssertEqual(self.isUpdating.values, [true, false])
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 60)
        XCTAssertEqual(self.fixture.accountState()?.invalidatedChannels.count, 0)
    }
}
