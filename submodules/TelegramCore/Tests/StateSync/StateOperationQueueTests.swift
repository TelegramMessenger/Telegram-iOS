import Foundation
import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramCore

/// `StateOperationQueue` (Sync/StateOperationQueue.swift): the placement rules of `AccountStateManager`'s operation
/// queue, one test per rule, each asserting what the rule did when it was code in `AccountStateManager.Impl`. No
/// Postbox and no network: the entries hold inert contents. The queue end to end is the harness's
/// (PushCharacterizationTests, StateBarrierCharacterizationTests, EventDeliveryOrderTests,
/// DifferenceCharacterizationTests).
final class StateOperationQueueTests: XCTestCase {
    // MARK: - Contents

    private func poll(_ id: Int32) -> StateOperation {
        return .fetchDifference(id, AccountFinalStateEvents())
    }

    private func groups(_ pts: [Int32]) -> [UpdateGroup] {
        return pts.map { UpdateGroup.updatePts(pts: $0, ptsCount: 1) }
    }

    private func updates(_ pts: [Int32]) -> StateOperation {
        return .batchUpdates(self.groups(pts))
    }

    private func batch(_ pts: [Int32]) -> StateOperation {
        return .processBatch(self.groups(pts))
    }

    private func custom(_ id: Int32) -> StateOperation {
        return .custom(id, .complete())
    }

    private func messageId(_ id: Int32) -> MessageId {
        return MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1)), namespace: Namespaces.Message.Cloud, id: id)
    }

    private func barrier(_ id: Int32, messageIds: [Int32] = [], subscribers: [Int32] = []) -> StateOperation {
        return .stateBarrier(id, messageIds.map { self.messageId($0) }, subscribers.map { subscriberId -> (Int32, ([MessageId]) -> Void) in
            return (subscriberId, { _ in })
        })
    }

    private func events(_ id: Int32) -> StateOperation {
        return .dispatchEvents(id, AccountFinalStateEvents())
    }

    private func replay(pts: Int32) -> StateOperation {
        let initialState = AccountInitialState(state: AuthorizedAccountState.State(pts: pts, qts: 5, date: 1_700_000_000, seq: 10), peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: [:], peerChatInfos: [:], locallyGeneratedMessageTimestamps: [:], channelsToPollExplicitely: Set())
        let state = AccountMutableState(initialState: initialState, initialPeers: [:], initialReferencedReplyMessageIds: ReferencedReplyMessageIds(), initialReferencedGeneralMessageIds: Set(), initialStoredMessages: Set(), initialStoredStories: [:], initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:], initialSentScheduledMessageIds: Set())
        return .replayPrebuilt(AccountFinalState(state: state, shouldPoll: false, incomplete: false, discard: false), {})
    }

    /// A queue holding `contents` in order, its head started when `headRunning`.
    private func queue(_ contents: [StateOperation], headRunning: Bool) -> StateOperationQueue {
        var queue = StateOperationQueue()
        for content in contents {
            _ = queue.add(content, at: .last)
        }
        if headRunning {
            XCTAssertNotNil(queue.startHead())
        }
        return queue
    }

    private func pts(_ groups: [UpdateGroup]) -> [Int32] {
        return groups.map { group -> Int32 in
            if case let .updatePts(pts, _) = group {
                return pts
            } else {
                return -1
            }
        }
    }

    /// One string per entry: its kind with what it carries (ids, the groups' pts, a barrier's message ids and
    /// subscriber ids), and `*` while it runs.
    private func describe(_ queue: StateOperationQueue) -> [String] {
        return queue.entries.map { entry -> String in
            let text: String
            switch entry.content {
            case let .fetchDifference(id, _):
                text = "poll#\(id)"
            case let .batchUpdates(groups):
                text = "updates\(self.pts(groups))"
            case .gapWait:
                text = "gapWait"
            case let .processBatch(groups):
                text = "batch\(self.pts(groups))"
            case let .custom(id, _):
                text = "custom#\(id)"
            case let .stateBarrier(id, messageIds, subscribers):
                text = "barrier#\(id)\(messageIds.map { $0.id })\(subscribers.map { $0.0 })"
            case let .dispatchEvents(id, _):
                text = "events#\(id)"
            case let .replayPrebuilt(finalState, _):
                text = "replay@\(finalState.state.state.pts)"
            }
            return entry.isRunning ? text + "*" : text
        }
    }

    // MARK: - The head

    /// `startFirstOperation`'s guard: only a head that does not run yet starts, and it is marked running.
    func testStartHeadStartsTheHeadOnce() {
        var queue = StateOperationQueue()
        XCTAssertNil(queue.startHead())
        _ = queue.add(self.poll(1), at: .last)
        _ = queue.add(self.custom(2), at: .last)
        guard case .fetchDifference(1, _)? = queue.startHead()?.content else {
            return XCTFail("the head did not start")
        }
        XCTAssertEqual(self.describe(queue), ["poll#1*", "custom#2"])
        XCTAssertNil(queue.startHead())
        XCTAssertTrue(queue.popFetchDifference())
        guard case .custom(2, _)? = queue.startHead()?.content else {
            return XCTFail("the next head did not start")
        }
        XCTAssertEqual(self.describe(queue), ["custom#2*"])
    }

    // MARK: - Placement

    /// `addOperation(.first)`: at the head, which the caller then starts, unless the head runs; then right behind it.
    func testAddFirstGoesBehindARunningHead() {
        var queue = StateOperationQueue()
        XCTAssertTrue(queue.add(self.poll(1), at: .first))
        XCTAssertEqual(self.describe(queue), ["poll#1"])
        XCTAssertTrue(queue.add(self.custom(2), at: .first))
        XCTAssertEqual(self.describe(queue), ["custom#2", "poll#1"])
        _ = queue.startHead()
        XCTAssertFalse(queue.add(self.poll(3), at: .first))
        XCTAssertEqual(self.describe(queue), ["custom#2*", "poll#3", "poll#1"])
    }

    /// `addOperation(.last)`: at the end; the caller starts the head only when the queue was empty.
    func testAddLastStartsOnlyAnEmptyQueue() {
        var queue = StateOperationQueue()
        XCTAssertTrue(queue.add(self.custom(1), at: .last))
        XCTAssertFalse(queue.add(self.custom(2), at: .last))
        XCTAssertEqual(self.describe(queue), ["custom#1", "custom#2"])
        _ = queue.startHead()
        XCTAssertFalse(queue.add(self.custom(3), at: .last))
        XCTAssertEqual(self.describe(queue), ["custom#1*", "custom#2", "custom#3"])
    }

    /// `addUpdateGroups`: groups join a `batchUpdates` that is the last entry, running or not, after its own groups,
    /// and the entry keeps `isRunning`; with anything else last, or nothing queued, nothing changes.
    func testUpdateGroupsJoinATrailingBatch() {
        var queue = StateOperationQueue()
        XCTAssertFalse(queue.absorbUpdateGroups(self.groups([1])))
        XCTAssertTrue(queue.isEmpty)

        _ = queue.add(self.poll(1), at: .last)
        _ = queue.startHead()
        XCTAssertFalse(queue.absorbUpdateGroups(self.groups([101])))
        XCTAssertEqual(self.describe(queue), ["poll#1*"])
        _ = queue.add(self.updates([101]), at: .last)
        XCTAssertTrue(queue.absorbUpdateGroups(self.groups([102, 103])))
        XCTAssertEqual(self.describe(queue), ["poll#1*", "updates[101, 102, 103]"])

        var running = self.queue([self.updates([201])], headRunning: true)
        XCTAssertTrue(running.absorbUpdateGroups(self.groups([202])))
        XCTAssertEqual(self.describe(running), ["updates[201, 202]*"])

        var notLast = self.queue([self.updates([301]), self.custom(2)], headRunning: false)
        XCTAssertFalse(notLast.absorbUpdateGroups(self.groups([302])))
        XCTAssertEqual(self.describe(notLast), ["updates[301]", "custom#2"])
    }

    /// Q5, as the queue has it: groups pushed while a `gapWait` is the last entry, running or not, are taken and
    /// dropped; the gap wait holds nothing, and nothing is queued for them.
    func testUpdateGroupsAreDroppedByATrailingGapWait() {
        var queue = self.queue([.gapWait], headRunning: true)
        XCTAssertTrue(queue.absorbUpdateGroups(self.groups([101])))
        XCTAssertEqual(self.describe(queue), ["gapWait*"])

        var queued = self.queue([self.events(1), .gapWait], headRunning: true)
        XCTAssertTrue(queued.absorbUpdateGroups(self.groups([102, 103])))
        XCTAssertEqual(self.describe(queued), ["events#1*", "gapWait"])
    }

    /// `replaceOperations`: the running head stays; behind it the queued batches, the new poll, one barrier with every
    /// queued barrier's message ids and subscribers under a new id, the replays, the event deliveries and the custom
    /// operations, each in queue order; queued polls, `batchUpdates` and gap waits are dropped.
    func testReplaceKeepsTheRunningHeadAndOrdersTheRest() {
        var queue = self.queue([
            self.poll(1),
            self.updates([101]),
            self.batch([102]),
            self.barrier(3, messageIds: [10], subscribers: [7]),
            self.replay(pts: 100),
            self.events(4),
            self.custom(5),
            self.batch([103]),
            self.poll(6),
            self.barrier(8, messageIds: [11], subscribers: [9]),
            self.events(12),
            self.replay(pts: 200),
            .gapWait
        ], headRunning: true)
        var nextIdCalls = 0
        queue.replace(with: self.poll(20), nextId: {
            nextIdCalls += 1
            return 21
        })
        XCTAssertEqual(nextIdCalls, 1)
        XCTAssertEqual(self.describe(queue), [
            "poll#1*",
            "batch[102]",
            "batch[103]",
            "poll#20",
            "barrier#21[10, 11][7, 9]",
            "replay@100",
            "replay@200",
            "events#4",
            "events#12",
            "custom#5"
        ])
    }

    /// The merged barrier is queued, and `nextId()` called, only when a queued barrier holds a message id or a
    /// subscriber; one that holds neither is dropped, and a running barrier stays where it is. With nothing running,
    /// the batches come first.
    func testReplaceQueuesABarrierOnlyWithSomethingToCarry() {
        var empty = self.queue([self.custom(1), self.barrier(2), self.batch([101])], headRunning: false)
        empty.replace(with: self.poll(3), nextId: {
            XCTFail("no barrier to carry")
            return 0
        })
        XCTAssertEqual(self.describe(empty), ["batch[101]", "poll#3", "custom#1"])

        var idsOnly = self.queue([self.barrier(2, messageIds: [10])], headRunning: false)
        idsOnly.replace(with: self.poll(3), nextId: { 4 })
        XCTAssertEqual(self.describe(idsOnly), ["poll#3", "barrier#4[10][]"])

        var subscribersOnly = self.queue([self.barrier(2, subscribers: [7])], headRunning: false)
        subscribersOnly.replace(with: self.poll(3), nextId: { 4 })
        XCTAssertEqual(self.describe(subscribersOnly), ["poll#3", "barrier#4[][7]"])

        var running = self.queue([self.barrier(2, messageIds: [10], subscribers: [7]), self.custom(5)], headRunning: true)
        running.replace(with: self.poll(3), nextId: {
            XCTFail("the running barrier is not merged")
            return 0
        })
        XCTAssertEqual(self.describe(running), ["barrier#2[10][7]*", "poll#3", "custom#5"])
    }

    /// `insertDispatchEvents`: in front of the first entry that is neither running nor an event delivery, so ahead of a
    /// queued poll or barrier; with none, at the end.
    func testEventsGoBehindTheRunningHeadAndQueuedEvents() {
        var queue = self.queue([self.poll(1), self.events(2), self.poll(3), self.barrier(4, subscribers: [7])], headRunning: true)
        queue.insertEvents(id: 5, events: AccountFinalStateEvents())
        XCTAssertEqual(self.describe(queue), ["poll#1*", "events#2", "events#5", "poll#3", "barrier#4[][7]"])

        var onlyEvents = self.queue([self.custom(1), self.events(2)], headRunning: true)
        onlyEvents.insertEvents(id: 5, events: AccountFinalStateEvents())
        XCTAssertEqual(self.describe(onlyEvents), ["custom#1*", "events#2", "events#5"])

        var idle = self.queue([self.custom(1)], headRunning: false)
        idle.insertEvents(id: 5, events: AccountFinalStateEvents())
        XCTAssertEqual(self.describe(idle), ["events#5", "custom#1"])

        var empty = StateOperationQueue()
        empty.insertEvents(id: 5, events: AccountFinalStateEvents())
        XCTAssertEqual(self.describe(empty), ["events#5"])
    }

    // MARK: - The barrier

    /// A barrier that starts with entries behind it leaves the head, and `postponeStateBarrier` queues it
    /// at the end under a new id, where it is the last entry; alone, it stays and runs.
    func testBarrierStepsAsideToTheEnd() {
        var queue = self.queue([self.barrier(1, messageIds: [10], subscribers: [7]), self.custom(2)], headRunning: true)
        XCTAssertTrue(queue.barrierStepsAside())
        XCTAssertEqual(self.describe(queue), ["custom#2"])
        XCTAssertFalse(queue.add(self.barrier(3, messageIds: [10], subscribers: [7]), at: .last))
        queue.assertBarrierIsLast()
        XCTAssertEqual(self.describe(queue), ["custom#2", "barrier#3[10][7]"])

        var alone = self.queue([self.barrier(1)], headRunning: true)
        XCTAssertFalse(alone.barrierStepsAside())
        XCTAssertEqual(self.describe(alone), ["barrier#1[][]*"])
    }

    /// `addPollCompletion`: a subscriber joins the first queued barrier, running or not, after its subscribers; with no
    /// barrier queued nothing changes, and the caller queues one.
    func testSubscriberJoinsTheFirstBarrier() {
        var queue = self.queue([self.barrier(1, subscribers: [7]), self.custom(2), self.barrier(3)], headRunning: true)
        XCTAssertTrue(queue.addBarrierSubscriber(id: 8, { _ in }))
        XCTAssertEqual(self.describe(queue), ["barrier#1[][7, 8]*", "custom#2", "barrier#3[][]"])

        var none = self.queue([self.custom(2)], headRunning: false)
        XCTAssertFalse(none.addBarrierSubscriber(id: 8, { _ in }))
        XCTAssertEqual(self.describe(none), ["custom#2"])
    }

    /// `removePollCompletion`: in every queued barrier, the first subscriber with the id leaves; the entry keeps
    /// `isRunning`.
    func testRemovedSubscriberLeavesEveryBarrier() {
        var queue = self.queue([self.barrier(1, messageIds: [10], subscribers: [7, 8, 7]), self.barrier(2, subscribers: [7])], headRunning: true)
        queue.removeBarrierSubscriber(id: 7)
        XCTAssertEqual(self.describe(queue), ["barrier#1[10][8, 7]*", "barrier#2[][]"])
    }

    /// A finished event delivery appends its incoming message ids to the queued barrier, after the ones it holds.
    func testIncomingMessageIdsJoinTheBarrier() {
        var queue = self.queue([self.events(1), self.barrier(2, messageIds: [10], subscribers: [7])], headRunning: true)
        queue.addIncomingMessageIdsToBarriers([self.messageId(11), self.messageId(12)])
        XCTAssertEqual(self.describe(queue), ["events#1*", "barrier#2[10, 11, 12][7]"])

        var none = self.queue([self.events(1)], headRunning: true)
        none.addIncomingMessageIdsToBarriers([self.messageId(11)])
        XCTAssertEqual(self.describe(none), ["events#1*"])
    }

    // MARK: - Completion

    /// Each completion pops the head and acts only when it is the operation it started. The poll's pop also pops a
    /// head of another kind, and only reports it; the other pops assert on a mismatch, which a test cannot run.
    func testCompletionPopsTheHeadThenChecksIt() {
        var queue = self.queue([
            self.poll(1),
            self.updates([101, 102]),
            .gapWait,
            self.batch([103]),
            self.custom(2),
            self.events(3),
            self.barrier(4, messageIds: [10], subscribers: [7]),
            self.replay(pts: 100),
            self.custom(5)
        ], headRunning: true)
        XCTAssertTrue(queue.popFetchDifference())
        XCTAssertEqual(queue.popBatchUpdates().map { self.pts($0) }, [101, 102])
        XCTAssertTrue(queue.popGapWait())
        XCTAssertTrue(queue.popProcessBatch())
        XCTAssertTrue(queue.popCustom(id: 2))
        XCTAssertTrue(queue.popDispatchEvents(id: 3))
        guard case let (messageIds, subscribers)? = queue.popStateBarrier(id: 4) else {
            return XCTFail("no barrier")
        }
        XCTAssertEqual(messageIds, [self.messageId(10)])
        XCTAssertEqual(subscribers.map { $0.0 }, [7])
        XCTAssertTrue(queue.popReplayPrebuilt())
        XCTAssertEqual(self.describe(queue), ["custom#5"])
        // A poll's completion finding another head: it is popped all the same.
        XCTAssertFalse(queue.popFetchDifference())
        XCTAssertTrue(queue.isEmpty)
    }
}
