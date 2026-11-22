import Foundation
import XCTest
import Postbox
@testable import TelegramCore

/// `batchContentAndDeferStateOperations` (stage 5, task B1), the pure split `replayFinalState` applies a final state's
/// operations by: the content operations, in order, with adjacent message additions batched, and the account and
/// channel state they advance, the last value of each winning. Content is compared through `describe`, which names
/// each operation with the ids of the messages it carries.
final class ReplayBatchingTests: XCTestCase {
    private let peerId = StateSyncFixture.userPeerId(2000)

    /// Cloud messages with these ids in one user chat, in the shape `StateSyncFixture.storeMessage` stores.
    private func messages(_ ids: [Int32]) -> [StoreMessage] {
        return ids.map { id -> StoreMessage in
            return StoreMessage(id: MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: 1_700_000_000 + id, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: self.peerId, text: "m\(id)", attributes: [], media: [])
        }
    }

    private func state(pts: Int32) -> AuthorizedAccountState.State {
        return AuthorizedAccountState.State(pts: pts, qts: 5, date: 1_700_000_000, seq: 10)
    }

    private func ids(_ messages: [StoreMessage]) -> [Int32] {
        return messages.map { message -> Int32 in
            if case let .Id(id) = message.id {
                return id.id
            } else {
                return -1
            }
        }
    }

    /// `"AddMessages([1, 2], .UpperHistoryBlock)"`, `"AddScheduledMessages([3])"`, `"AddQuickReplyMessages([4])"`,
    /// `"UpdateAttachMenuBots"`; `"state"` for the four state operations and `"other"` for every other operation.
    private func describe(_ operations: [AccountStateMutationOperation]) -> [String] {
        return operations.map { operation -> String in
            switch operation {
            case let .AddMessages(messages, location):
                return "AddMessages(\(self.ids(messages)), \(location == .UpperHistoryBlock ? ".UpperHistoryBlock" : ".Random"))"
            case let .AddScheduledMessages(messages):
                return "AddScheduledMessages(\(self.ids(messages)))"
            case let .AddQuickReplyMessages(messages):
                return "AddQuickReplyMessages(\(self.ids(messages)))"
            case .UpdateAttachMenuBots:
                return "UpdateAttachMenuBots"
            case .UpdateState, .UpdateChannelState, .UpdateChannelInvalidationPts, .UpdateChannelSynchronizedUntilMessage:
                return "state"
            default:
                return "other"
            }
        }
    }

    func testAdjacentAddMessagesAtOneLocationAreMerged() {
        let batched = batchContentAndDeferStateOperations([
            .AddMessages(self.messages([1, 2]), .UpperHistoryBlock),
            .AddMessages(self.messages([3]), .UpperHistoryBlock)
        ])

        XCTAssertEqual(self.describe(batched.content), ["AddMessages([1, 2, 3], .UpperHistoryBlock)"])
    }

    func testAddMessagesAtAnotherLocationStartANewBatch() {
        let batched = batchContentAndDeferStateOperations([
            .AddScheduledMessages(self.messages([10])),
            .AddMessages(self.messages([1]), .UpperHistoryBlock),
            .AddMessages(self.messages([2]), .Random),
            .AddMessages(self.messages([3]), .Random),
            .AddMessages(self.messages([4]), .UpperHistoryBlock)
        ])

        // A new location ends the pending AddMessages only: the scheduled messages stay pending to the end.
        XCTAssertEqual(self.describe(batched.content), [
            "AddMessages([1], .UpperHistoryBlock)",
            "AddMessages([2, 3], .Random)",
            "AddMessages([4], .UpperHistoryBlock)",
            "AddScheduledMessages([10])"
        ])
    }

    func testAnyOtherContentOperationEndsThePendingBatchesInOrder() {
        let batched = batchContentAndDeferStateOperations([
            .AddQuickReplyMessages(self.messages([3])),
            .AddScheduledMessages(self.messages([2])),
            .AddMessages(self.messages([1]), .UpperHistoryBlock),
            .UpdateAttachMenuBots,
            .AddMessages(self.messages([4]), .UpperHistoryBlock),
            .AddQuickReplyMessages(self.messages([6])),
            .AddScheduledMessages(self.messages([5]))
        ])

        // The three batches come out in a fixed order, whatever order they were started in, then the barrier; the
        // three still pending at the end close the content in the same order.
        XCTAssertEqual(self.describe(batched.content), [
            "AddMessages([1], .UpperHistoryBlock)",
            "AddScheduledMessages([2])",
            "AddQuickReplyMessages([3])",
            "UpdateAttachMenuBots",
            "AddMessages([4], .UpperHistoryBlock)",
            "AddScheduledMessages([5])",
            "AddQuickReplyMessages([6])"
        ])
    }

    func testStateOperationsNeitherEndABatchNorReachTheContent() {
        let channel = StateSyncFixture.channelPeerId(300)
        let batched = batchContentAndDeferStateOperations([
            .AddMessages(self.messages([1]), .UpperHistoryBlock),
            .UpdateState(self.state(pts: 101)),
            .UpdateChannelState(channel, 41),
            .UpdateChannelInvalidationPts(channel, 42),
            .UpdateChannelSynchronizedUntilMessage(channel, 43),
            .AddMessages(self.messages([2]), .UpperHistoryBlock)
        ])

        // None of the four state operations ends the pending batch.
        XCTAssertEqual(self.describe(batched.content), ["AddMessages([1, 2], .UpperHistoryBlock)"])
        XCTAssertEqual(batched.stateAdvance.accountState, self.state(pts: 101))
        XCTAssertEqual(batched.stateAdvance.channelStates, [channel: AccountStateChannelState(pts: 41)])
        XCTAssertEqual(batched.stateAdvance.invalidatedChannelPts, [channel: 42])
        XCTAssertEqual(batched.stateAdvance.channelSynchronizedUntilMessageIds, [channel: 43])
    }

    func testTheLastValueOfEachStateOperationWins() {
        let c = StateSyncFixture.channelPeerId(300)
        let d = StateSyncFixture.channelPeerId(301)
        let batched = batchContentAndDeferStateOperations([
            .UpdateState(self.state(pts: 101)),
            .UpdateChannelState(c, 10),
            .UpdateChannelInvalidationPts(c, 20),
            .UpdateChannelSynchronizedUntilMessage(c, 30),
            .UpdateChannelState(d, 40),
            .UpdateChannelInvalidationPts(d, 50),
            .UpdateChannelSynchronizedUntilMessage(d, 60),
            .UpdateState(self.state(pts: 102)),
            .UpdateChannelState(c, 11),
            .UpdateChannelInvalidationPts(c, 21),
            .UpdateChannelSynchronizedUntilMessage(c, 31),
            .UpdateChannelState(d, 41),
            .UpdateChannelInvalidationPts(d, 51),
            .UpdateChannelSynchronizedUntilMessage(d, 61)
        ])

        XCTAssertTrue(batched.content.isEmpty)
        // Contents and values only: a dictionary's order is not pinned.
        XCTAssertEqual(batched.stateAdvance.accountState, self.state(pts: 102))
        XCTAssertEqual(batched.stateAdvance.channelStates, [c: AccountStateChannelState(pts: 11), d: AccountStateChannelState(pts: 41)])
        XCTAssertEqual(batched.stateAdvance.invalidatedChannelPts, [c: 21, d: 51])
        XCTAssertEqual(batched.stateAdvance.channelSynchronizedUntilMessageIds, [c: 31, d: 61])
    }

    func testEmptyBatchesAreDroppedAndPendingBatchesCloseTheContent() {
        let nothing = batchContentAndDeferStateOperations([])
        XCTAssertTrue(nothing.content.isEmpty)
        XCTAssertNil(nothing.stateAdvance.accountState)
        XCTAssertTrue(nothing.stateAdvance.channelStates.isEmpty)
        XCTAssertTrue(nothing.stateAdvance.invalidatedChannelPts.isEmpty)
        XCTAssertTrue(nothing.stateAdvance.channelSynchronizedUntilMessageIds.isEmpty)

        let batched = batchContentAndDeferStateOperations([
            .AddMessages([], .UpperHistoryBlock),
            .AddScheduledMessages([]),
            .UpdateAttachMenuBots,
            .AddQuickReplyMessages(self.messages([5])),
            .AddScheduledMessages([]),
            .AddMessages(self.messages([6]), .Random),
            .UpdateState(self.state(pts: 101))
        ])

        // The empty batches the barrier ends, and the empty scheduled batch still pending at the end, are dropped; the
        // pending batches close the content in the fixed order.
        XCTAssertEqual(self.describe(batched.content), [
            "UpdateAttachMenuBots",
            "AddMessages([6], .Random)",
            "AddQuickReplyMessages([5])"
        ])

        // Each of the other emptiness checks, one call each: a barrier ends an empty quick-reply batch, a new location
        // an empty AddMessages, and the end of the operations an empty AddMessages and an empty quick-reply batch.
        let atBarrier = batchContentAndDeferStateOperations([
            .AddMessages([], .UpperHistoryBlock),
            .AddScheduledMessages([]),
            .AddQuickReplyMessages([]),
            .UpdateAttachMenuBots
        ])
        XCTAssertEqual(self.describe(atBarrier.content), ["UpdateAttachMenuBots"])

        let atNewLocation = batchContentAndDeferStateOperations([
            .AddMessages([], .UpperHistoryBlock),
            .AddMessages(self.messages([7]), .Random)
        ])
        XCTAssertEqual(self.describe(atNewLocation.content), ["AddMessages([7], .Random)"])

        let atEnd = batchContentAndDeferStateOperations([
            .UpdateAttachMenuBots,
            .AddMessages([], .UpperHistoryBlock),
            .AddScheduledMessages([]),
            .AddQuickReplyMessages([])
        ])
        XCTAssertEqual(self.describe(atEnd.content), ["UpdateAttachMenuBots"])
    }
}
