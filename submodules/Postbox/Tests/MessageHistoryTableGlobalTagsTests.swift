import Foundation
import XCTest
@testable import Postbox

/// The global-tags view (calls list, missed-calls list) learns about changes only from
/// the global-tag operations a transaction reports. Every write path that changes a
/// message's row in the global-tags table must report a matching operation.
final class MessageHistoryTableGlobalTagsTests: XCTestCase {
    private var fixture: MessageHistoryTableFixture!

    private let peer: Int64 = 300
    private let calls = GlobalMessageTags(rawValue: 1 << 0)
    private let missedCalls = GlobalMessageTags(rawValue: 1 << 1)

    override func setUp() {
        super.setUp()
        self.fixture = MessageHistoryTableFixture(name: "MessageHistoryTableGlobalTagsTests")
        self.fixture.fillGlobalTagHole(self.calls)
        self.fixture.fillGlobalTagHole(self.missedCalls)
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func messageId(_ id: Int32) -> MessageId {
        return MessageHistoryTableFixture.messageId(peer: self.peer, id: id)
    }

    private func message(_ id: Int32, timestamp: Int32? = nil, text: String, globalTags: GlobalMessageTags) -> StoreMessage {
        return MessageHistoryTableFixture.storeMessage(id: self.messageId(id), timestamp: timestamp ?? (1000 + id), text: text, globalTags: globalTags)
    }

    /// The view applies operations in order: an insert before the remove would be undone.
    private func assertRemoveComesFirst(_ operations: [GlobalMessageHistoryTagsOperation], file: StaticString = #file, line: UInt = #line) {
        guard case .remove? = operations.first else {
            return XCTFail("expected the remove first, got \(operations)", file: file, line: line)
        }
    }

    private func removed(in operations: [GlobalMessageHistoryTagsOperation]) -> [(GlobalMessageTags, MessageIndex)] {
        return operations.flatMap { operation -> [(GlobalMessageTags, MessageIndex)] in
            if case let .remove(entries) = operation {
                return entries
            }
            return []
        }
    }

    private func inserted(in operations: [GlobalMessageHistoryTagsOperation]) -> [(GlobalMessageTags, IntermediateMessage)] {
        return operations.compactMap { operation in
            if case let .insertMessage(tag, message) = operation {
                return (tag, message)
            }
            return nil
        }
    }

    // MARK: - Tests

    func testEditingATaggedMessageInPlaceReportsRemoveThenInsert() {
        let added = self.fixture.addMessages([self.message(1, text: "call", globalTags: self.calls)])
        XCTAssertEqual(self.inserted(in: added.globalTagsOperations).map { $0.0 }, [self.calls])

        // The server marks the call as missed: same id and index, one more global tag.
        let edited = self.fixture.updateMessage(self.messageId(1), message: self.message(1, text: "missed call", globalTags: [self.calls, self.missedCalls]))

        self.assertRemoveComesFirst(edited.globalTagsOperations)
        let removed = self.removed(in: edited.globalTagsOperations)
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(removed.first?.0, self.calls)
        XCTAssertEqual(removed.first?.1.id, self.messageId(1))

        let inserted = self.inserted(in: edited.globalTagsOperations)
        XCTAssertEqual(Set(inserted.map { $0.0.rawValue }), Set([self.calls.rawValue, self.missedCalls.rawValue]))
        XCTAssertEqual(Set(inserted.map { $0.1.text }), Set(["missed call"]))

        // The table itself was already right; the view just never heard about it.
        XCTAssertEqual(self.fixture.globalTagIndices(self.calls).map { $0.id }, [self.messageId(1)])
        XCTAssertEqual(self.fixture.globalTagIndices(self.missedCalls).map { $0.id }, [self.messageId(1)])
    }

    func testReAddingATaggedMessageWithChangedTagsReportsRemoveThenInsert() {
        self.fixture.addMessages([self.message(2, text: "call", globalTags: self.calls)])

        // An overlapping history fetch re-delivers the message with the missed tag.
        let readded = self.fixture.addMessages([self.message(2, text: "call", globalTags: [self.calls, self.missedCalls])])

        self.assertRemoveComesFirst(readded.globalTagsOperations)
        XCTAssertEqual(self.removed(in: readded.globalTagsOperations).map { $0.1.id }, [self.messageId(2)])
        XCTAssertEqual(Set(self.inserted(in: readded.globalTagsOperations).map { $0.0.rawValue }), Set([self.calls.rawValue, self.missedCalls.rawValue]))
    }

    func testDroppingEveryGlobalTagReportsOnlyARemove() {
        self.fixture.addMessages([self.message(3, text: "call", globalTags: self.calls)])

        let edited = self.fixture.updateMessage(self.messageId(3), message: self.message(3, text: "not a call", globalTags: []))

        XCTAssertEqual(self.removed(in: edited.globalTagsOperations).map { $0.1.id }, [self.messageId(3)])
        XCTAssertTrue(self.inserted(in: edited.globalTagsOperations).isEmpty)
        XCTAssertTrue(self.fixture.globalTagIndices(self.calls).isEmpty)
    }

    func testEditingATaggedMessageWithANewTimestampRemovesTheOldIndexAndInsertsTheNew() {
        self.fixture.addMessages([self.message(6, text: "call", globalTags: self.calls)])

        let edited = self.fixture.updateMessage(self.messageId(6), message: self.message(6, timestamp: 5000, text: "missed call", globalTags: [self.calls, self.missedCalls]))

        self.assertRemoveComesFirst(edited.globalTagsOperations)
        XCTAssertEqual(self.removed(in: edited.globalTagsOperations).map { $0.1.timestamp }, [1006])
        XCTAssertEqual(Set(self.inserted(in: edited.globalTagsOperations).map { $0.1.timestamp }), Set([5000]))
        XCTAssertEqual(self.fixture.globalTagIndices(self.calls).map { $0.timestamp }, [5000])
    }

    func testUpdatingAnUntaggedMessageReportsNothing() {
        self.fixture.addMessages([self.message(4, text: "hello", globalTags: [])])

        let edited = self.fixture.updateMessage(self.messageId(4), message: self.message(4, text: "hello again", globalTags: []))

        XCTAssertTrue(edited.globalTagsOperations.isEmpty)
    }

    // MARK: - Guard: the timestamp path already reports, and must not report twice

    func testChangingATaggedMessagesTimestampReportsASingleTimestampUpdate() {
        self.fixture.addMessages([self.message(5, text: "call", globalTags: self.calls)])

        let moved = self.fixture.updateMessageTimestamp(self.messageId(5), timestamp: 5000)

        XCTAssertEqual(moved.globalTagsOperations.count, 1)
        guard case .updateTimestamp(let tags, let index, let timestamp)? = moved.globalTagsOperations.first else {
            return XCTFail("expected a timestamp update, got \(moved.globalTagsOperations)")
        }
        XCTAssertEqual(tags, self.calls)
        XCTAssertEqual(index.id, self.messageId(5))
        XCTAssertEqual(timestamp, 5000)
        XCTAssertEqual(self.fixture.globalTagIndices(self.calls).map { $0.timestamp }, [5000])
    }

    func testMovingATaggedMessageBelowAHoleReportsOnlyTheRemove() {
        self.fixture.addMessages([self.message(7, text: "call", globalTags: self.calls)])
        // The region below timestamp 500 is not loaded for the calls tag.
        self.fixture.addGlobalTagHole(self.calls, index: MessageIndex(id: self.messageId(0), timestamp: 500))

        let moved = self.fixture.updateMessageTimestamp(self.messageId(7), timestamp: 400)

        // The table refuses to index the message under the hole, so the view must drop
        // its entry rather than move it to a timestamp the table does not list.
        XCTAssertEqual(moved.globalTagsOperations.count, 1)
        XCTAssertEqual(self.removed(in: moved.globalTagsOperations).map { $0.1.timestamp }, [1007])
        XCTAssertTrue(self.inserted(in: moved.globalTagsOperations).isEmpty)
        XCTAssertTrue(self.fixture.globalTagIndices(self.calls).isEmpty)
    }
}
