import Foundation
import XCTest
@testable import Postbox

/// The in-memory record of recent message edits (`RecentlyEditedMessages`, read through `Transaction.recentMessageEdit`).
/// A fetch whose request went out before an edit can bring the message with its old content, so TelegramCore stores
/// the recorded edit in its place. The record keeps each message's latest edit, returns it only for a fetch that went
/// out before it was recorded, and expires and drops entries.
final class RecentlyEditedMessagesTests: XCTestCase {
    /// A clock the test moves by hand.
    private final class TestClock {
        var time: Double = 1000.0
    }

    private let peer: Int64 = 900
    private var fixture: PostboxFixture?

    override func tearDown() {
        self.fixture?.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func id(_ id: Int32, peer: Int64? = nil) -> MessageId {
        return MessageHistoryTableFixture.messageId(peer: peer ?? self.peer, id: id)
    }

    private func edit(_ id: Int32, _ text: String, peer: Int64? = nil) -> StoreMessage {
        return MessageHistoryTableFixture.storeMessage(id: self.id(id, peer: peer), timestamp: 1000 + id, text: text)
    }

    private func makeRecord(_ clock: TestClock, capacity: Int = 100) -> RecentlyEditedMessages {
        return RecentlyEditedMessages(lifetime: 300.0, capacity: capacity, now: {
            return clock.time
        })
    }

    // MARK: - The record

    /// Each message keeps its latest edit; an edit is per chat.
    func testKeepsTheLatestEditOfEachMessage() {
        let record = self.makeRecord(TestClock())
        record.add(self.edit(5, "first"))
        record.add(self.edit(5, "second"))

        XCTAssertEqual(record.edit(of: self.id(5), since: 0.0)?.text, "second")
        XCTAssertNil(record.edit(of: self.id(6), since: 0.0))
        XCTAssertNil(record.edit(of: self.id(5, peer: 901), since: 0.0), "an edit is per chat")
    }

    /// An edit recorded before the fetch went out is in the fetch's answer: it is returned only for a fetch that
    /// went out at or before it was recorded.
    func testAnEditIsReturnedOnlyForAFetchThatWentOutBeforeIt() {
        let clock = TestClock()
        let record = self.makeRecord(clock)
        record.add(self.edit(5, "edited"))

        XCTAssertEqual(record.edit(of: self.id(5), since: 999.0)?.text, "edited")
        XCTAssertEqual(record.edit(of: self.id(5), since: 1000.0)?.text, "edited")
        XCTAssertNil(record.edit(of: self.id(5), since: 1000.5), "a fetch that went out after the edit has it in its answer")
    }

    /// An edit lives `lifetime` seconds (300 here) from when it was recorded.
    func testEditsExpireAfterTheLifetime() {
        let clock = TestClock()
        let record = self.makeRecord(clock)
        record.add(self.edit(5, "edited"))

        clock.time += 299.0
        XCTAssertNotNil(record.edit(of: self.id(5), since: 0.0))

        clock.time += 1.0
        XCTAssertNil(record.edit(of: self.id(5), since: 0.0))

        // A later recording prunes what expired and lives its own lifetime.
        record.add(self.edit(6, "edited"))
        XCTAssertNotNil(record.edit(of: self.id(6), since: 0.0))
        XCTAssertNil(record.edit(of: self.id(5), since: 0.0))
    }

    /// Past the capacity the oldest recordings are dropped; a message edited again counts from its newest edit.
    func testOldestEditsAreDroppedPastTheCapacity() {
        let record = self.makeRecord(TestClock(), capacity: 3)
        record.add(self.edit(1, "a"))
        record.add(self.edit(2, "a"))
        record.add(self.edit(3, "a"))
        record.add(self.edit(1, "b"))
        record.add(self.edit(4, "a"))

        XCTAssertEqual(record.edit(of: self.id(1), since: 0.0)?.text, "b", "edited again, 1 is newer than 2")
        XCTAssertNil(record.edit(of: self.id(2), since: 0.0))
        XCTAssertNotNil(record.edit(of: self.id(3), since: 0.0))
        XCTAssertNotNil(record.edit(of: self.id(4), since: 0.0))
    }

    /// Through a transaction, on the system uptime clock (TelegramCore's `FetchedAnswerAge.now()`).
    func testTransactionRecordsAnEditAndReturnsItForAnEarlierFetch() {
        let fixture = PostboxFixture(name: "RecentlyEditedMessagesTests")
        self.fixture = fixture
        let fetchWentOutAt = ProcessInfo.processInfo.systemUptime
        let edit = self.edit(5, "edited")
        let id = self.id(5)
        fixture.transaction { transaction -> Void in
            transaction.recordMessageEdit(edit)
        }
        let after = ProcessInfo.processInfo.systemUptime + 1.0

        let found = fixture.transaction { transaction -> (String?, String?) in
            return (transaction.recentMessageEdit(id, since: fetchWentOutAt)?.text, transaction.recentMessageEdit(id, since: after)?.text)
        }
        XCTAssertEqual(found?.0, "edited")
        XCTAssertNil(found?.1 ?? nil)
    }
}
