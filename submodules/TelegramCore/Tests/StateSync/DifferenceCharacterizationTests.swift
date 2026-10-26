import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// getDifference cycles of the main app (`fetchDifference`), pinned as they behave at 171825ce49.
final class DifferenceCharacterizationTests: StateSyncTestCase {
    /// Flow 1a. An empty difference stores its date and seq and keeps pts and qts. Nothing is dispatched.
    func testLaunchWithEmptyDifference() {
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 60, seq: 11)))
        self.fixture.resetStateManager()

        self.isUpdating.wait { $0 == [true, false] }
        self.significantUpdates.wait { $0.count == 1 }
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, date: self.baseDate + 60, seq: 11))
        XCTAssertEqual(self.notifiedMessageIds(), [])
    }

    /// Flow 1b. A difference with one incoming message stores it, advances the state and notifies once.
    func testLaunchWithMessageStoresAndNotifies() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            newMessages: [self.incomingMessage(101, from: 200)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            state: StateSyncApi.state(pts: 101, qts: 5, date: self.baseDate + 30, seq: 10)
        )))
        self.fixture.resetStateManager()

        self.isUpdating.wait { $0 == [true, false] }
        self.waitForNotification(of: self.messageId(user, 101))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 101, qts: 5, date: self.baseDate + 30, seq: 10))
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(user, 101)]])
    }

    /// Flow 1c. A differenceSlice is continued from its intermediate state (already stored when the second
    /// request is built); events of both slices are delivered once, after the final difference.
    func testSliceChainContinuesFromIntermediateState() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceSlice(
            newMessages: [self.incomingMessage(101, from: 200)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            intermediateState: StateSyncApi.state(pts: 150, qts: 5, date: self.baseDate + 10, seq: 10)
        )))
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            newMessages: [self.incomingMessage(102, from: 200)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            state: StateSyncApi.state(pts: 200, qts: 5, date: self.baseDate + 20, seq: 10)
        )))
        self.fixture.resetStateManager()

        self.isUpdating.wait { $0 == [true, false] }
        self.waitForNotification(of: self.messageId(user, 102))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(1, pts: 150, date: self.baseDate + 10, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 200, qts: 5, date: self.baseDate + 20, seq: 10))
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(user, 101), self.messageId(user, 102)]])
    }

    /// Flow 2. With no inner state the first poll bootstraps through updates.getState, stores it and polls
    /// again from it in the same cycle. How soon is not pinned: the 10 s wait would pass a backoff under 10 s.
    func testNoInnerStateBootstrapsWithGetState() {
        self.fixture.seedAccount(state: nil)
        self.makeStateManager()
        self.server.on(Name.getState, .result(StateSyncApi.state(pts: 300, qts: 7, date: self.baseDate, seq: 20)))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 5, seq: 20)))
        self.fixture.resetStateManager()

        self.isUpdating.wait { $0 == [true, false] }
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getState, Name.getDifference])
        self.assertGetDifference(1, pts: 300, date: self.baseDate, qts: 7)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 300, qts: 7, date: self.baseDate + 5, seq: 20))
    }

    /// Flow 3 (spec section 3 points 1 and 5; G10, Q1). differenceTooLong(pts 999) resets the account without
    /// updates.getState: the first dialogs page and the pinned dialogs are fetched, the stored pts becomes 999
    /// and qts, date and seq are kept. The same cycle then polls again from pts 999 with the old date and qts,
    /// and ends when that difference is final: isUpdating clears and significantStateUpdateCompleted fires once.
    func testDifferenceTooLongResetsAccountAndPollsAgainFromTheNewPts() {
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .hold)
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 9, date: self.baseDate + 100, seq: 30))))
        self.server.on(Name.getDifference, .hold)
        self.fixture.resetStateManager()

        // The answer is held until the manager queue has run the poll transaction's completion, as a real round
        // trip does; PollResultLossCharacterizationTests covers an answer that beats that hop (Q13).
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference))
        Postbox.sharedQueue.sync {}
        self.managerQueueRoundTrip()
        XCTAssertTrue(self.server.release(Name.getDifference, with: .result(StateSyncApi.differenceTooLong(pts: 999))))

        // The reset has stored its state by the time the follow-up getDifference is sent; the cycle still runs.
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference, count: 2))
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 999, qts: 5, date: self.baseDate, seq: 10))
        XCTAssertEqual(self.isUpdating.values, [true])
        XCTAssertEqual(self.significantUpdates.values.count, 0)
        XCTAssertTrue(self.server.release(Name.getDifference, with: .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 11))))

        // The barrier sits behind the running poll and completes once the follow-up ended the cycle.
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 4, "log: \(names)")
        XCTAssertEqual(names.first, Name.getDifference)
        XCTAssertEqual(Set(names.dropFirst().prefix(2)), [Name.getDialogs, Name.getPinnedDialogs])
        XCTAssertFalse(names.contains(Name.getState))
        self.assertGetDifference(3, pts: 999, date: self.baseDate, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 999, qts: 5, date: self.baseDate + 120, seq: 11))
        XCTAssertEqual(self.isUpdating.values, [true, false])
        XCTAssertEqual(self.significantUpdates.values.count, 1)
    }

    /// G10 (spec section 3 point 1). The getDifference after a differenceTooLong reset runs from the stored qts
    /// and date, so an encrypted message of the gap is fetched: it is queued for its secret chat (the incoming
    /// encrypted operation log; the harness seeds no SecretChatState, so nothing decrypts it or notifies) and
    /// qts advances to the difference's. Until the fix the reset took qts from updates.getState, and the
    /// message was never fetched.
    func testDifferenceTooLongFollowUpFetchesTheGapsEncryptedMessage() {
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 9, date: self.baseDate + 100, seq: 10))))
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            newEncryptedMessages: [StateSyncApi.encryptedServiceMessage(chatId: 77, randomId: 4242, date: self.baseDate + 50)],
            state: StateSyncApi.state(pts: 999, qts: 6, date: self.baseDate + 60, seq: 10)
        )))
        self.fixture.resetStateManager()

        // The barrier sits behind the running poll and completes once the follow-up ended the cycle.
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 4, "log: \(names)")
        XCTAssertFalse(names.contains(Name.getState))
        self.assertGetDifference(3, pts: 999, date: self.baseDate, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 999, qts: 6, date: self.baseDate + 60, seq: 10))
        let secretChatId = PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(77))
        let queued = self.fixture.transaction { transaction -> [Int64] in
            var randomIds: [Int64] = []
            transaction.operationLogEnumerateEntries(peerId: secretChatId, tag: OperationLogTags.SecretIncomingEncrypted, { entry in
                if let operation = entry.contents as? SecretChatIncomingEncryptedOperation {
                    randomIds.append(operation.globallyUniqueId)
                }
                return true
            })
            return randomIds
        }
        XCTAssertEqual(queued, [4242])
    }

    /// Q1. Events carried from a differenceSlice survive a differenceTooLong in the same chain: the reset does
    /// not end the chain, the cycle polls again from the reset's pts, and the slice's events are delivered
    /// once, when that difference ends the cycle. Before stage 7 they were dropped with the cycle.
    func testDifferenceTooLongAfterASliceDeliversTheSliceEvents() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceSlice(
            newMessages: [self.incomingMessage(101, from: 200)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            intermediateState: StateSyncApi.state(pts: 150, qts: 5, date: self.baseDate + 10, seq: 10)
        )))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 5, date: self.baseDate + 10, seq: 10))))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        self.fixture.resetStateManager()

        self.waitForNotification(of: self.messageId(user, 101))
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 5, "log: \(names)")
        XCTAssertEqual(Array(names.prefix(2)), [Name.getDifference, Name.getDifference])
        XCTAssertEqual(Set(names.dropFirst(2).prefix(2)), [Name.getDialogs, Name.getPinnedDialogs])
        XCTAssertFalse(names.contains(Name.getState))
        self.assertGetDifference(1, pts: 150, date: self.baseDate + 10, qts: 5)
        self.assertGetDifference(4, pts: 999, date: self.baseDate + 10, qts: 5)
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 999, qts: 5, date: self.baseDate + 120, seq: 10))
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(user, 101)]])
        XCTAssertEqual(self.isUpdating.values, [true, false])
        XCTAssertEqual(self.significantUpdates.values.count, 1)
    }

    /// Q2. A getDifference refused with AUTH_KEY_DUPLICATED is skipped, not retried, and the skip ends the
    /// poll cycle as a final difference does: isUpdating clears and significantStateUpdateCompleted fires
    /// once. The stored state is untouched. Until the fix the cycle was abandoned with isUpdating still true.
    func testAuthKeyDuplicatedEndsTheCycle() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .error(code: 406, text: "AUTH_KEY_DUPLICATED"))
        self.fixture.resetStateManager()

        // The barrier sits behind the running poll and completes once the skip removed it.
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100))
        XCTAssertEqual(self.isUpdating.values, [true, false])
        XCTAssertEqual(self.significantUpdates.values.count, 1)
    }

    /// Q6, pinned as it is. The stored account state changes while getDifference is in flight (the test writes
    /// pts 150 over the 100 the request was built from): `initialStateWithDifference` reads the new state, the
    /// poll applies nothing (`DifferenceOutcome.stateChangedMeanwhile`), and the restart arm ends the chain and
    /// replaces it by a fresh poll from the new state, in the same cycle: isUpdating stays true and
    /// significantStateUpdateCompleted waits until that second chain ends. How soon the fresh poll is sent is not
    /// pinned (the request wait's 5 s would pass a backoff under 5 s), and the chain carries no events yet, so the
    /// arm's `insertDispatchEvents(currentEvents)` is not reached. The poll also logs the mismatch (the log line
    /// "pollDifference initial state ... != current state ..."); the harness cannot read the log, so that line is
    /// not asserted.
    func testStateChangedDuringGetDifferenceAppliesNothingAndPollsAgainFromTheNewState() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .hold)
        self.server.on(Name.getDifference, .hold)
        self.fixture.resetStateManager()

        XCTAssertTrue(self.server.waitForRequest(Name.getDifference))
        Postbox.sharedQueue.sync {}
        self.managerQueueRoundTrip()
        let changedState = self.state(pts: 150)
        self.fixture.transaction { transaction -> Void in
            if let current = transaction.getState() as? AuthorizedAccountState {
                transaction.setState(current.changedState(changedState))
            }
        }
        XCTAssertEqual(self.fixture.accountState()?.state, changedState, "precondition: the state was written meanwhile")
        XCTAssertTrue(self.server.release(Name.getDifference, with: .result(StateSyncApi.difference(
            newMessages: [self.incomingMessage(101, from: 200)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            state: StateSyncApi.state(pts: 101, qts: 5, date: self.baseDate + 2, seq: 10)
        ))))

        // The fresh poll is sent from the state written meanwhile; the first answer was not applied, and the cycle
        // still runs.
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference, count: 2))
        self.assertGetDifference(1, pts: 150, date: self.baseDate, qts: 5)
        XCTAssertNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertEqual(self.fixture.accountState()?.state, changedState)
        XCTAssertEqual(self.isUpdating.values, [true])
        XCTAssertEqual(self.significantUpdates.values.count, 0)
        XCTAssertTrue(self.server.release(Name.getDifference, with: .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 10))))

        self.isUpdating.wait { $0 == [true, false] }
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 150, date: self.baseDate + 3))
        XCTAssertNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertEqual(self.notifiedMessageIds(), [])
        XCTAssertEqual(self.significantUpdates.values.count, 1)
    }

    /// Q11 (spec section 3 point 6). When the reset's messages.getDialogs answers messages.dialogsNotModified,
    /// the reset writes nothing, so pts stays 100 and the cycle's next poll meets differenceTooLong again. That
    /// second reset in a row waits consecutiveResetDelay(2) first, gets a chat list, and the cycle ends from
    /// pts 999. Stage 7 ended the cycle at the first dialogsNotModified; before stage 7 the reset never
    /// completed.
    func testDifferenceTooLongWithDialogsNotModifiedRetriesTheReset() {
        let delays = self.recordConsecutiveResetDelays()
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogsNotModified()))
        self.server.on(Name.getPinnedDialogs, .result(self.emptyPinnedDialogs()))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(self.emptyPinnedDialogs()))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        self.fixture.resetStateManager()

        // The barrier sits behind the running poll and completes once the cycle ended.
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 7, "log: \(names)")
        XCTAssertFalse(names.contains(Name.getState))
        XCTAssertEqual(names.indices.filter { names[$0] == Name.getDifference }, [0, 3, 6], "log: \(names)")
        // The reset that got dialogsNotModified wrote nothing: the second poll asks from pts 100 again.
        self.assertGetDifference(3, pts: 100, date: self.baseDate, qts: 5)
        self.assertGetDifference(6, pts: 999, date: self.baseDate, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 999, qts: 5, date: self.baseDate + 120, seq: 10))
        XCTAssertEqual(delays.with { $0 }, [1, 2])
        XCTAssertEqual(self.isUpdating.values, [true, false])
        XCTAssertEqual(self.significantUpdates.values.count, 1)
    }

    /// Spec section 3 point 5. A second differenceTooLong in the same cycle gets a second reset, which waits
    /// consecutiveResetDelay(2) first while the poll holds the head of the queue and isUpdating stays true;
    /// then the cycle polls from the second reset's pts and finishes.
    func testTwoDifferenceTooLongInARowResetTwiceThenFinish() {
        // Long enough that a stalled test thread does not reach the check below after a correct wait ended.
        let delays = self.recordConsecutiveResetDelays({ n in n >= 2 ? 1.0 : 0.0 })
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 500)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(self.emptyPinnedDialogs()))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(self.emptyPinnedDialogs()))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        self.fixture.resetStateManager()

        // The second answer is handed over and handled on the manager queue; its reset is now waiting 1 s.
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference, count: 2))
        self.server.flush()
        self.managerQueueRoundTrip()
        // A reset that did not wait would have sent its getDialogs from fetchChatList's Postbox hop by now.
        Postbox.sharedQueue.sync {}
        self.server.flush()
        XCTAssertEqual(self.server.requestNames.filter { $0 == Name.getDialogs }.count, 1, "the second reset did not wait: \(self.server.requestNames)")
        XCTAssertEqual(self.isUpdating.values, [true])

        XCTAssertTrue(self.server.waitForRequest(Name.getDifference, count: 3))
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 7, "log: \(names)")
        XCTAssertEqual(names.indices.filter { names[$0] == Name.getDifference }, [0, 3, 6], "log: \(names)")
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5)
        self.assertGetDifference(3, pts: 500, date: self.baseDate, qts: 5)
        self.assertGetDifference(6, pts: 999, date: self.baseDate, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 999, qts: 5, date: self.baseDate + 120, seq: 10))
        XCTAssertEqual(delays.with { $0 }, [1, 2])
        XCTAssertEqual(self.isUpdating.values, [true, false])
        XCTAssertEqual(self.significantUpdates.values.count, 1)
    }

    /// Spec section 3 point 5. The count of resets in a row starts over after a poll that needed no reset:
    /// differenceTooLong, a reset, a slice, differenceTooLong again. The second reset is a first one again
    /// (consecutiveResetDelay(1)), so it does not wait.
    func testConsecutiveResetCountStartsOverAfterAPollWithoutReset() {
        let delays = self.recordConsecutiveResetDelays()
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 500)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(self.emptyPinnedDialogs()))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceSlice(
            intermediateState: StateSyncApi.state(pts: 600, qts: 5, date: self.baseDate + 10, seq: 10)
        )))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(StateSyncApi.dialogs()))
        self.server.on(Name.getPinnedDialogs, .result(self.emptyPinnedDialogs()))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        self.fixture.resetStateManager()

        // The barrier sits behind the running poll and completes once the cycle ended.
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 8, "log: \(names)")
        XCTAssertEqual(names.indices.filter { names[$0] == Name.getDifference }, [0, 3, 4, 7], "log: \(names)")
        self.assertGetDifference(3, pts: 500, date: self.baseDate, qts: 5)
        self.assertGetDifference(4, pts: 600, date: self.baseDate + 10, qts: 5)
        self.assertGetDifference(7, pts: 999, date: self.baseDate + 10, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 999, qts: 5, date: self.baseDate + 120, seq: 10))
        XCTAssertEqual(delays.with { $0 }, [1, 1])
        XCTAssertEqual(self.isUpdating.values, [true, false])
        XCTAssertEqual(self.significantUpdates.values.count, 1)
    }

    /// The production backoff (spec section 3 point 5): the first reset of a cycle runs at once, then 1 s,
    /// doubling up to 60 s.
    func testConsecutiveResetDelayDefaultCurve() {
        let delay = AccountStateManager.consecutiveResetDelay
        XCTAssertEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 1000].map(delay), [0.0, 0.0, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 60.0, 60.0, 60.0])
    }

    /// The reset's messages.getPinnedDialogs answer: no pinned chats.
    private func emptyPinnedDialogs() -> Api.messages.PeerDialogs {
        return StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 5, date: self.baseDate, seq: 10))
    }

    /// Replaces `AccountStateManager.consecutiveResetDelay` for this test: records each `n` it is asked for
    /// and answers `delay(n)` (0 unless given, so the test does not sleep). Restored at teardown.
    private func recordConsecutiveResetDelays(_ delay: @escaping (Int) -> Double = { _ in 0.0 }) -> Atomic<[Int]> {
        let calls = Atomic<[Int]>(value: [])
        let original = AccountStateManager.consecutiveResetDelay
        self.addTeardownBlock {
            AccountStateManager.consecutiveResetDelay = original
        }
        AccountStateManager.consecutiveResetDelay = { n in
            let _ = calls.modify { $0 + [n] }
            return delay(n)
        }
        return calls
    }

    /// Flow 14, the ordering contract (spec section 3): a differenceSlice continuation runs BEFORE update
    /// groups pushed while the poll was in flight, so the push is applied against the final state. If the
    /// continuation were queued behind the push (a real dispatch instead of the inline Queue.async), the
    /// push would be checked against the slice's pts, found to be a hole, and a third getDifference would
    /// follow the gap wait.
    func testSliceContinuationRunsBeforeGroupsPushedMidPoll() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .hold)
        self.fixture.resetStateManager()
        XCTAssertTrue(self.server.waitForRequest(Name.getDifference))

        self.server.push(StateSyncApi.updateShortMessage(id: 201, userId: 200, pts: 201, date: self.baseDate + 30))
        self.server.flush()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(state: StateSyncApi.state(pts: 200, qts: 5, date: self.baseDate + 20, seq: 10))))
        XCTAssertTrue(self.server.release(Name.getDifference, with: .result(StateSyncApi.differenceSlice(
            intermediateState: StateSyncApi.state(pts: 150, qts: 5, date: self.baseDate + 10, seq: 10)
        ))))

        self.waitForNotification(of: self.messageId(user, 201))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(1, pts: 150, date: self.baseDate + 10, qts: 5)
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 201)))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 201)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// Flow 14 for the reset (spec section 3): the follow-up getDifference after a differenceTooLong reset
    /// runs BEFORE update groups pushed while the reset was in flight, as a slice continuation does. The
    /// push (pts 1006) is then applied against the follow-up's final state (pts 1005). Queued behind the
    /// push, the follow-up would leave it to meet the reset's pts 999, a hole, and a third getDifference
    /// would follow the gap wait.
    func testResetFollowUpRunsBeforeGroupsPushedDuringTheReset() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .hold)
        self.server.on(Name.getPinnedDialogs, .result(self.emptyPinnedDialogs()))
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(state: StateSyncApi.state(pts: 1005, qts: 5, date: self.baseDate + 20, seq: 10))))
        self.fixture.resetStateManager()
        XCTAssertTrue(self.server.waitForRequest(Name.getDialogs))

        self.server.push(StateSyncApi.updateShortMessage(id: 1006, userId: 200, pts: 1006, date: self.baseDate + 30))
        self.server.flush()
        self.managerQueueRoundTrip()
        // The chat stays in the chat list the reset rebuilds, so the push needs no messages.getPeerDialogs.
        XCTAssertTrue(self.server.release(Name.getDialogs, with: .result(StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerUser(200), topMessage: 10)],
            messages: [self.incomingMessage(10, from: 200, date: self.baseDate + 10)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")]
        ))))

        self.waitForNotification(of: self.messageId(user, 1006))
        self.drainOperationQueue()

        let names = self.server.requestNames
        XCTAssertEqual(names.count, 4, "log: \(names)")
        XCTAssertEqual(names.indices.filter { names[$0] == Name.getDifference }, [0, 3], "log: \(names)")
        self.assertGetDifference(3, pts: 999, date: self.baseDate, qts: 5)
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 1006)))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 1006)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// Flow 15, pins Q8. An RPC result handed to the manager before reset() is dropped: the update service
    /// that would parse it is created by reset().
    func testAddUpdatesBeforeResetIsDropped() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.fixture.addUpdates(StateSyncApi.updateShortMessage(id: 101, userId: 200, pts: 101, date: self.baseDate + 5))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 1, seq: 10)))
        self.fixture.resetStateManager()

        self.isUpdating.wait { $0 == [true, false] }
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: self.baseDate, qts: 5)
        XCTAssertNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 100)
    }
}

/// The notification extension's poll (`standalonePollDifference`), over a Postbox opened with the
/// extension's flags. The extension never calls reset(): no update sink, no operation queue.
final class NotificationExtensionPollCharacterizationTests: StateSyncTestCase {
    override var fixtureProfile: StateSyncFixture.OpenProfile {
        return .notificationExtension
    }

    /// Flow 12. Each call fetches one difference with `date: Int32.max` and replays it keeping the stored
    /// date; it returns false after a slice and true after the final difference. Events are dropped and
    /// isUpdating is never touched.
    func testStandalonePollSendsMaxDateAndKeepsStoredDate() {
        let user = self.seedUserChat(200)
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceSlice(
            newMessages: [self.incomingMessage(101, from: 200)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            intermediateState: StateSyncApi.state(pts: 150, qts: 6, date: self.baseDate + 10, seq: 11)
        )))
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            newMessages: [self.incomingMessage(102, from: 200)],
            users: [StateSyncApi.user(id: 200, firstName: "U200")],
            state: StateSyncApi.state(pts: 200, qts: 7, date: self.baseDate + 20, seq: 12)
        )))

        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), false)
        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), true)

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: Int32.max, qts: 5)
        self.assertGetDifference(1, pts: 150, date: Int32.max, qts: 6)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 200, qts: 7, date: self.baseDate, seq: 12))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 102)))
        XCTAssertEqual(self.notifiedMessageIds(), [])
        XCTAssertEqual(self.isUpdating.values, [true])
    }

    /// Q3 (fixed). differenceTooLong ends the extension's poll as done (true) and changes nothing: no reset
    /// request and the stored state untouched, so the next poll asks again from the same pts, and the main
    /// app resets the account on its own next poll. It was `preconditionFailure()`, which crashed the
    /// extension on every non-channel push until the app was opened.
    func testDifferenceTooLongEndsThePollAndLeavesTheResetToTheApp() {
        self.fixture.seedAccount(state: self.state(pts: 100, qts: 5, seq: 10))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))

        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), true)
        XCTAssertEqual(self.fixture.wait(self.stateManager.standalonePollDifference()), true)

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getDifference])
        self.assertGetDifference(0, pts: 100, date: Int32.max, qts: 5)
        self.assertGetDifference(1, pts: 100, date: Int32.max, qts: 5)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 100, qts: 5, seq: 10))
        XCTAssertEqual(self.isUpdating.values, [true])
    }
}
