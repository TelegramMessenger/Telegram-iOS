import Foundation
import XCTest
@testable import Postbox

/// Which hole "contains" a message id. `Transaction.getHole(containing:)` answers exactly the hole whose range
/// contains the id, a hole that starts or ends at the id included. The hole indexes' own `containing` answers
/// the first hole whose upper bound is strictly above the id (the range query excludes its start key and the
/// lower bound is not checked): the read-state bookkeeping uses that answer, and so do the thread read paths
/// through `Transaction.getThreadIndexHole`, which keep a thread's unread count while a hole lies above its top
/// message.
final class HoleContainingTests: XCTestCase {
    private let peer: Int64 = 900

    /// The chat's holes are reshaped to the one hole 50...100 (the first touch of a peer seeds a hole over its
    /// whole history). Ids 10 and 101 lie outside it.
    func testGetHoleContainingAnswersOnlyAHoleThatHoldsTheId() {
        let fixture = PostboxFixture(name: "HoleContainingTests")
        defer {
            fixture.close()
        }
        let peerId = MessageHistoryTableFixture.peerId(self.peer)
        let namespace = PostboxFixture.messageNamespace
        fixture.transaction { transaction -> Void in
            transaction.removeHole(peerId: peerId, threadId: nil, namespace: namespace, space: .everywhere, range: 1 ... (Int32.max - 1))
            transaction.addHole(peerId: peerId, threadId: nil, namespace: namespace, space: .everywhere, range: 50 ... 100)
        }
        func hole(_ id: Int32) -> [MessageHistoryHoleSpace: ClosedRange<MessageId.Id>] {
            let messageId = MessageId(peerId: peerId, namespace: namespace, id: id)
            return fixture.transaction { transaction -> [MessageHistoryHoleSpace: ClosedRange<MessageId.Id>] in
                return transaction.getHole(containing: messageId)
            } ?? [:]
        }

        XCTAssertEqual(hole(10), [:], "10 lies below the hole 50...100")
        XCTAssertEqual(hole(50), [.everywhere: 50 ... 100])
        XCTAssertEqual(hole(75), [.everywhere: 50 ... 100])
        XCTAssertEqual(hole(100), [.everywhere: 50 ... 100])
        XCTAssertEqual(hole(101), [:])
    }

    /// Two holes, 20...40 and 50...100. The hole that ends exactly at 40 is the one that contains 40, not the
    /// next hole up (the index alone, asked from 40, skips it: its upper bound is not strictly above 40); the
    /// hole that starts exactly at 50 contains 50; nothing contains 45.
    func testGetHoleContainingFindsAHoleThatEndsOrStartsExactlyAtTheId() {
        let fixture = PostboxFixture(name: "HoleContainingTests.edges")
        defer {
            fixture.close()
        }
        let peerId = MessageHistoryTableFixture.peerId(self.peer)
        let namespace = PostboxFixture.messageNamespace
        fixture.transaction { transaction -> Void in
            transaction.removeHole(peerId: peerId, threadId: nil, namespace: namespace, space: .everywhere, range: 1 ... (Int32.max - 1))
            transaction.addHole(peerId: peerId, threadId: nil, namespace: namespace, space: .everywhere, range: 20 ... 40)
            transaction.addHole(peerId: peerId, threadId: nil, namespace: namespace, space: .everywhere, range: 50 ... 100)
        }
        func hole(_ id: Int32) -> [MessageHistoryHoleSpace: ClosedRange<MessageId.Id>] {
            let messageId = MessageId(peerId: peerId, namespace: namespace, id: id)
            return fixture.transaction { transaction -> [MessageHistoryHoleSpace: ClosedRange<MessageId.Id>] in
                return transaction.getHole(containing: messageId)
            } ?? [:]
        }

        XCTAssertEqual(hole(40), [.everywhere: 20 ... 40], "a hole ending exactly at the id contains it")
        XCTAssertEqual(hole(50), [.everywhere: 50 ... 100], "a hole starting exactly at the id contains it")
        XCTAssertEqual(hole(20), [.everywhere: 20 ... 40])
        XCTAssertEqual(hole(45), [:], "45 lies between the holes")
    }

    /// What StateReplay does with a basic group's first message (`.groupCreated`, `.channelMigratedFromGroup`):
    /// it stores the message with `.UpperHistoryBlock`, which removes the `.everywhere` hole from the message's
    /// id up, then asks `getHole(containing: id - 1)` and removes `1 ... id` from every space answered. The hole
    /// left below the message ends exactly at `id - 1`, which the index alone (strictly above) never answered,
    /// so the trim did not fire for `.everywhere`; now the hole below the group's first message is found and
    /// removed. Nothing of the group can exist below its first message.
    func testGroupCreatedTrimFindsTheHoleEndingBelowTheFirstMessage() {
        let fixture = PostboxFixture(name: "HoleContainingTests.groupCreated")
        defer {
            fixture.close()
        }
        let peerId = MessageHistoryTableFixture.peerId(self.peer)
        let namespace = PostboxFixture.messageNamespace
        let firstId: Int32 = 10
        let message = StoreMessage(id: MessageId(peerId: peerId, namespace: namespace, id: firstId), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: 1000, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "created", attributes: [], media: [])

        let holesBelow = fixture.transaction { transaction -> [MessageHistoryHoleSpace: ClosedRange<MessageId.Id>] in
            let _ = transaction.addMessages([message], location: .UpperHistoryBlock)
            return transaction.getHole(containing: MessageId(peerId: peerId, namespace: namespace, id: firstId - 1))
        } ?? [:]
        XCTAssertEqual(holesBelow, [.everywhere: 1 ... (firstId - 1)], "the hole below the group's first message was not found")

        let remaining = fixture.transaction { transaction -> IndexSet in
            for (space, _) in holesBelow {
                transaction.removeHole(peerId: peerId, threadId: nil, namespace: namespace, space: MessageHistoryHoleOperationSpace(space), range: 1 ... firstId)
            }
            return transaction.getHoles(peerId: peerId, namespace: namespace)
        }
        XCTAssertEqual(remaining, IndexSet(), "a hole was left below the group's first message")
    }

    /// Pin: the hole index's `containing` and `Transaction.getThreadIndexHole` still answer the first hole whose
    /// upper bound is strictly above the id: 50...100 for id 10 (a hole wholly above the id), and nothing for
    /// id 100 (a hole ending exactly at the id is not returned).
    func testHoleIndexesStillAnswerTheFirstHoleStrictlyAboveTheId() {
        let peerId = MessageHistoryTableFixture.peerId(self.peer)
        let namespace = PostboxFixture.messageNamespace

        let tableFixture = MessageHistoryTableFixture(name: "HoleContainingTests.index")
        defer {
            tableFixture.close()
        }
        let indexAnswers = tableFixture.transaction { table, _ -> [[MessageHistoryHoleSpace: ClosedRange<MessageId.Id>]] in
            var operations: [MessageHistoryIndexHoleOperationKey: [MessageHistoryIndexHoleOperation]] = [:]
            table.messageHistoryHoleIndexTable.remove(peerId: peerId, namespace: namespace, space: .everywhere, range: 1 ... (Int32.max - 1), operations: &operations)
            table.messageHistoryHoleIndexTable.add(peerId: peerId, namespace: namespace, space: .everywhere, range: 50 ... 100, operations: &operations)
            return [
                table.messageHistoryHoleIndexTable.containing(id: MessageId(peerId: peerId, namespace: namespace, id: 10)),
                table.messageHistoryHoleIndexTable.containing(id: MessageId(peerId: peerId, namespace: namespace, id: 100))
            ]
        }
        XCTAssertEqual(indexAnswers, [[.everywhere: 50 ... 100], [:]])

        let fixture = PostboxFixture(name: "HoleContainingTests.thread")
        defer {
            fixture.close()
        }
        fixture.transaction { transaction -> Void in
            transaction.addHole(peerId: peerId, threadId: 7, namespace: namespace, space: .everywhere, range: 50 ... 100)
        }
        let threadAnswers = fixture.transaction { transaction -> [[MessageHistoryHoleSpace: ClosedRange<MessageId.Id>]] in
            return [
                transaction.getThreadIndexHole(peerId: peerId, threadId: 7, namespace: namespace, containing: 10),
                transaction.getThreadIndexHole(peerId: peerId, threadId: 7, namespace: namespace, containing: 100)
            ]
        } ?? []
        XCTAssertEqual(threadAnswers, [[.everywhere: 50 ... 100], [:]])
    }
}
