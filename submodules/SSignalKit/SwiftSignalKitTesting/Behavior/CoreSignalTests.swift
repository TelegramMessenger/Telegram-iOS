import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class CoreSignalTests: XCTestCase {
    private func record<T, E>(_ signal: Signal<T, E>, into log: CoreEventLog) -> Disposable {
        return signal.start(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
    }

    func testSingleDeliversValueThenCompletion() {
        let log = CoreEventLog()
        let handle = self.record(Signal<Int, NoError>.single(7), into: log)
        XCTAssertEqual(log.events, ["next 7", "completed"])
        handle.dispose()
        XCTAssertEqual(log.events, ["next 7", "completed"])
    }

    func testCompleteDeliversOnlyCompletion() {
        let log = CoreEventLog()
        let handle = self.record(Signal<Int, NoError>.complete(), into: log)
        XCTAssertEqual(log.events, ["completed"])
        handle.dispose()
    }

    func testFailDeliversOnlyError() {
        let log = CoreEventLog()
        let handle = self.record(Signal<Int, String>.fail("boom"), into: log)
        XCTAssertEqual(log.events, ["error boom"])
        handle.dispose()
        XCTAssertEqual(log.events, ["error boom"])
    }

    func testNeverDeliversNothing() {
        let log = CoreEventLog()
        let handle = self.record(Signal<Int, NoError>.never(), into: log)
        XCTAssertEqual(log.events, [])
        handle.dispose()
        XCTAssertEqual(log.events, [])
    }

    func testFreeSingleFunction() {
        let log = CoreEventLog()
        let signal: Signal<String, NoError> = single("a", NoError.self)
        let handle = self.record(signal, into: log)
        XCTAssertEqual(log.events, ["next a", "completed"])
        handle.dispose()
    }

    func testFreeFailFunction() {
        let log = CoreEventLog()
        let signal: Signal<Int, String> = fail(Int.self, "bad")
        let handle = self.record(signal, into: log)
        XCTAssertEqual(log.events, ["error bad"])
        handle.dispose()
    }

    func testFreeCompleteFunction() {
        let log = CoreEventLog()
        let signal: Signal<Int, String> = complete(Int.self, String.self)
        let handle = self.record(signal, into: log)
        XCTAssertEqual(log.events, ["completed"])
        handle.dispose()
    }

    func testFreeNeverFunction() {
        let log = CoreEventLog()
        let signal: Signal<Int, String> = never(Int.self, String.self)
        let handle = self.record(signal, into: log)
        XCTAssertEqual(log.events, [])
        handle.dispose()
        XCTAssertEqual(log.events, [])
    }

    func testStartWithoutCallbacksDoesNotCrash() {
        Signal<Int, String>.single(1).start().dispose()
        Signal<Int, String>.fail("e").start().dispose()
        Signal<Int, String>.complete().start().dispose()
        Signal<Int, String>.never().start().dispose()
        Signal<Int, String>.single(1).startStandalone().dispose()
        Signal<Int, String>.fail("e").startStrict().dispose()
    }

    func testGeneratorRunsSynchronouslyInsideStartOnCallerThread() {
        let log = CoreEventLog()
        let callerThread = Thread.current
        let signal = Signal<Int, NoError> { subscriber in
            log.append("generator sameThread=\(Thread.current == callerThread)")
            subscriber.putNext(1)
            log.append("generator end")
            return EmptyDisposable
        }
        log.append("before start")
        let handle = signal.start(next: { value in
            log.append("next \(value)")
        })
        log.append("after start")
        XCTAssertEqual(log.events, ["before start", "generator sameThread=true", "next 1", "generator end", "after start"])
        handle.dispose()
    }

    func testSignalIsColdAndRunsGeneratorOncePerStart() {
        let starts = CoreCounter()
        let signal = Signal<Int, NoError> { subscriber in
            let count = starts.increment()
            subscriber.putNext(count)
            return EmptyDisposable
        }
        let log = CoreEventLog()
        XCTAssertEqual(starts.value, 0)
        let first = self.record(signal, into: log)
        let second = self.record(signal, into: log)
        let third = signal.startStandalone(next: { value in
            log.append("standalone \(value)")
        })
        let fourth = signal.startStrict(next: { value in
            log.append("strict \(value)")
        })
        XCTAssertEqual(starts.value, 4)
        XCTAssertEqual(log.events, ["next 1", "next 2", "standalone 3", "strict 4"])
        first.dispose()
        second.dispose()
        third.dispose()
        fourth.dispose()
    }

    func testStartStandaloneHasSameSemanticsAsStart() {
        let log = CoreEventLog()
        let holder = CoreSubscriberHolder<Int, String>()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, String> { subscriber in
            holder.subscriber = subscriber
            return inner
        }.startStandalone(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
        holder.subscriber?.putNext(1)
        holder.subscriber?.putCompletion()
        holder.subscriber?.putNext(2)
        handle.dispose()
        XCTAssertEqual(log.events, ["next 1", "completed", "dispose"])
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testStartStrictReturnsStrictDisposableThatForwardsDispose() {
        let log = CoreEventLog()
        let inner = CoreCountingDisposable(log: log)
        let handle = Signal<Int, NoError> { subscriber in
            subscriber.putNext(3)
            return inner
        }.startStrict(next: { value in
            log.append("next \(value)")
        })
        XCTAssertTrue(handle is StrictDisposable)
        XCTAssertEqual(log.events, ["next 3"])
        handle.dispose()
        XCTAssertEqual(log.events, ["next 3", "dispose"])
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testStartStrictOnSynchronouslyCompletedSignal() {
        let log = CoreEventLog()
        let handle = self.recordStrict(Signal<Int, NoError>.single(1), into: log)
        XCTAssertEqual(log.events, ["next 1", "completed"])
        handle.dispose()
        XCTAssertEqual(log.events, ["next 1", "completed"])
    }

    private func recordStrict<T, E>(_ signal: Signal<T, E>, into log: CoreEventLog) -> Disposable {
        return signal.startStrict(next: { value in
            log.append("next \(value)")
        }, error: { error in
            log.append("error \(error)")
        }, completed: {
            log.append("completed")
        })
    }

    func testPipeOperatorAppliesFunction() {
        let result = 3 |> { $0 * 2 }
        XCTAssertEqual(result, 6)
        let chained = 1 |> { $0 + 1 } |> { $0 * 10 }
        XCTAssertEqual(chained, 20)
    }

    func testIdentityReturnsArgument() {
        XCTAssertEqual(identity(a: 5), 5)
        let object = CoreObject()
        XCTAssertTrue(identity(a: object) === object)
    }

    @available(macOS 10.15, iOS 13.0, *)
    func testGetAsyncReturnsSynchronousValue() async {
        let value = await Signal<Int, NoError>.single(42).get()
        XCTAssertEqual(value, 42)
    }

    @available(macOS 10.15, iOS 13.0, *)
    func testGetAsyncReturnsFirstOfSeveralValues() async {
        let signal = Signal<Int, NoError> { subscriber in
            subscriber.putNext(1)
            subscriber.putNext(2)
            subscriber.putNext(3)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let value = await signal.get()
        XCTAssertEqual(value, 1)
    }

    @available(macOS 10.15, iOS 13.0, *)
    func testGetAsyncReturnsValueEmittedLaterOnAnotherQueue() async {
        let queue = Queue(name: "CoreSignalTests.get")
        let signal = Signal<String, NoError> { subscriber in
            queue.after(0.02) {
                subscriber.putNext("late")
                subscriber.putNext("ignored")
            }
            return EmptyDisposable
        }
        let value = await signal.get()
        XCTAssertEqual(value, "late")
    }
}
