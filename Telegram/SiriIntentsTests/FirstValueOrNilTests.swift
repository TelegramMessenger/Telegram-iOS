import Foundation
import XCTest
import SwiftSignalKit
@testable import IntentsExtensionLib

/// The extension's account signal completes without a value when the account record is
/// logged out or upgrading. Every handler takes its first value, so without one the intent's
/// completion never ran and Siri spun until the extension timed out.
final class FirstValueOrNilTests: XCTestCase {
    private func collect<T>(_ signal: Signal<T, NoError>) -> (values: [T], completed: Bool) {
        let done = DispatchSemaphore(value: 0)
        var values: [T] = []
        var completed = false
        let disposable = signal.start(next: { value in
            values.append(value)
        }, completed: {
            completed = true
            done.signal()
        })
        XCTAssertEqual(done.wait(timeout: .now() + 5.0), .success, "did not complete")
        disposable.dispose()
        return (values, completed)
    }

    func testPassesTheFirstValueThrough() {
        let signal = Signal<Int?, NoError> { subscriber in
            subscriber.putNext(7)
            subscriber.putNext(8)
            subscriber.putCompletion()
            return EmptyDisposable
        }

        let result = self.collect(firstValueOrNil(signal))

        XCTAssertEqual(result.values, [7])
        XCTAssertTrue(result.completed)
    }

    func testAnEmptyCompletionBecomesNil() {
        let signal = Signal<Int?, NoError> { subscriber in
            subscriber.putCompletion()
            return EmptyDisposable
        }

        let result = self.collect(firstValueOrNil(signal))

        XCTAssertEqual(result.values.count, 1)
        XCTAssertNil(result.values.first ?? nil)
        XCTAssertTrue(result.completed)
    }
}
