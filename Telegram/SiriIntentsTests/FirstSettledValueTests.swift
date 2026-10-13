import Foundation
import XCTest
import SwiftSignalKit
@testable import IntentsExtensionLib

/// The unread scan reads the account's hole-filling views. Their first emission is empty
/// whenever a hole sits at the top (the chat list before it is fetched, a chat whose newest
/// messages are not loaded), so the scan waits for a settled emission and, if none comes in
/// time, uses what it has rather than nothing.
final class FirstSettledValueTests: XCTestCase {
    private func wait<T>(_ signal: Signal<T, NoError>, seconds: Double = 5.0) -> T? {
        let done = DispatchSemaphore(value: 0)
        var result: T?
        let disposable = signal.start(next: { value in
            result = value
            done.signal()
        })
        XCTAssertEqual(done.wait(timeout: .now() + seconds), .success, "signal did not emit")
        disposable.dispose()
        return result
    }

    func testSkipsUnsettledEmissionsUntilASettledOne() {
        let values = Signal<Int, NoError> { subscriber in
            subscriber.putNext(1)
            subscriber.putNext(2)
            subscriber.putNext(30)
            subscriber.putNext(40)
            return EmptyDisposable
        }

        let result = self.wait(firstSettledValue(values, isSettled: { $0 >= 10 }, timeout: 5.0))

        XCTAssertEqual(result, 30)
    }

    func testFallsBackToTheLatestEmissionWhenNothingSettlesInTime() {
        let latest = Atomic<Int>(value: 0)
        let values = Signal<Int, NoError> { subscriber in
            subscriber.putNext(1)
            subscriber.putNext(2)
            let _ = latest.swap(2)
            return EmptyDisposable
        }

        let result = self.wait(firstSettledValue(values, isSettled: { $0 >= 10 }, timeout: 0.2))

        XCTAssertEqual(result, 2)
    }

    func testCompletesAfterTheSettledValue() {
        let values = Signal<Int, NoError> { subscriber in
            subscriber.putNext(10)
            subscriber.putNext(11)
            return EmptyDisposable
        }
        let done = DispatchSemaphore(value: 0)
        var received: [Int] = []
        let disposable = firstSettledValue(values, isSettled: { $0 >= 10 }, timeout: 5.0).start(next: { value in
            received.append(value)
        }, completed: {
            done.signal()
        })
        XCTAssertEqual(done.wait(timeout: .now() + 5.0), .success, "did not complete")
        disposable.dispose()

        XCTAssertEqual(received, [10])
    }
}
