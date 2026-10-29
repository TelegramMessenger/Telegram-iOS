import Foundation
import XCTest
import SwiftSignalKit
@testable import IntentsExtensionLib

/// Two intents arriving together opened the account twice (two accounts on one database, both
/// syncing); the search intent ran the app's own sync, account reset included.
final class IntentAccountSyncTests: XCTestCase {
    /// An open that answers only when `answer` is called, counting how often it was started.
    private final class ManualOpen {
        var starts = 0
        private var subscribers: [(Int?) -> Void] = []

        func signal() -> Signal<Int?, NoError> {
            return Signal { [weak self] subscriber in
                self?.starts += 1
                self?.subscribers.append({ value in
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                })
                return EmptyDisposable
            }
        }

        func answer(_ value: Int?) {
            let subscribers = self.subscribers
            self.subscribers = []
            for subscriber in subscribers {
                subscriber(value)
            }
        }
    }

    private func drainMainQueue() {
        let done = expectation(description: "main queue")
        DispatchQueue.main.async {
            done.fulfill()
        }
        wait(for: [done], timeout: 2.0)
    }

    func testRequestsDuringAnOpenShareIt() {
        let opening = SharedOpening<Int, Int>()
        let open = ManualOpen()
        var first: [Int?] = []
        var second: [Int?] = []

        let a = opening.value(for: 1, open: { open.signal() }).start(next: { first.append($0) })
        let b = opening.value(for: 1, open: { open.signal() }).start(next: { second.append($0) })
        XCTAssertEqual(open.starts, 1, "the second request started its own open")

        open.answer(42)
        XCTAssertEqual(first, [42])
        XCTAssertEqual(second, [42])

        // Later requests for the key get the opened value without opening again.
        var third: [Int?] = []
        let c = opening.value(for: 1, open: { open.signal() }).start(next: { third.append($0) })
        XCTAssertEqual(third, [42])
        XCTAssertEqual(open.starts, 1)
        a.dispose()
        b.dispose()
        c.dispose()
    }

    func testANilOpenIsNotKept() {
        let opening = SharedOpening<Int, Int>()
        let open = ManualOpen()
        var values: [Int?] = []

        let a = opening.value(for: 1, open: { open.signal() }).start(next: { values.append($0) })
        open.answer(nil)
        XCTAssertEqual(values, [nil])
        self.drainMainQueue()

        let b = opening.value(for: 1, open: { open.signal() }).start(next: { values.append($0) })
        XCTAssertEqual(open.starts, 2, "a logged-out or upgrading record's open was kept")
        open.answer(7)
        XCTAssertEqual(values, [nil, 7])
        a.dispose()
        b.dispose()
    }

    func testAnotherKeyOpensAnew() {
        let opening = SharedOpening<Int, Int>()
        let open = ManualOpen()
        var values: [Int?] = []

        let a = opening.value(for: 1, open: { open.signal() }).start(next: { values.append($0) })
        open.answer(1)
        let b = opening.value(for: 2, open: { open.signal() }).start(next: { values.append($0) })
        open.answer(2)
        XCTAssertEqual(open.starts, 2)
        XCTAssertEqual(values, [1, 2])
        a.dispose()
        b.dispose()
    }

    func testThePollIsAskedAgainUntilDone() {
        var answers = [false, false, true]
        var polls = 0
        var completions = 0
        var values = 0

        let disposable = pollUntilDone({
            polls += 1
            return .single(answers.removeFirst())
        }).start(next: { _ in
            values += 1
        }, completed: {
            completions += 1
        })

        XCTAssertEqual(polls, 3)
        XCTAssertEqual(values, 1)
        XCTAssertEqual(completions, 1)
        disposable.dispose()
    }
}
