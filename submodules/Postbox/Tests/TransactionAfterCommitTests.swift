import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// `Transaction.afterCommit`: an action runs once its transaction has committed, after the transaction's body
/// and before its result is delivered, on the Postbox queue, in the order the actions were added. TelegramCore
/// fires a stored-message confirmation's deletion events from one, so that no receiver hears of a deletion it
/// cannot read yet (owner decision D1).
final class TransactionAfterCommitTests: XCTestCase {
    /// What happened, in order, from any queue.
    private final class EventLog {
        private let lock = NSLock()
        private var events: [String] = []

        func append(_ event: String) {
            self.lock.lock()
            self.events.append(event)
            self.lock.unlock()
        }

        var all: [String] {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            return self.events
        }
    }

    private var fixture: PostboxFixture?

    override func tearDown() {
        self.fixture?.close()
        self.fixture = nil
        super.tearDown()
    }

    /// The actions run after the body, with the transaction closed (`disposed` is set right before the commit),
    /// in the order they were added, before the transaction's result reaches its subscriber; the next
    /// transaction runs none of them again.
    func testActionsRunAfterTheCommitInOrderAndBeforeTheResult() {
        let fixture = PostboxFixture(name: "TransactionAfterCommitTests")
        self.fixture = fixture
        let log = EventLog()

        fixture.transaction { transaction -> Void in
            transaction.afterCommit {
                log.append(transaction.disposed ? "first action, transaction closed" : "first action, transaction open")
            }
            transaction.afterCommit {
                log.append("second action")
            }
            log.append("body")
        }
        log.append("result")
        fixture.transaction { _ -> Void in
            log.append("next transaction")
        }

        XCTAssertEqual(log.all, ["body", "first action, transaction closed", "second action", "result", "next transaction"])
    }
}
