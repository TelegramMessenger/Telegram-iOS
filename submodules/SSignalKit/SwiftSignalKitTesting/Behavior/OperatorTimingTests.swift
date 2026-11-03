import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class OperatorDelayTests: XCTestCase {
    func testDelaySubscribesToSourceOnQueueAfterTimeout() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.delay")
        let onQueue = OperatorBox<Bool>()
        let s = operatorSyncSource("s", log, values: [1, 2], terminal: OperatorTerminal<String>.complete)
        s.onSubscribe = { subscriber, _ in
            onQueue.append(timerQueue.isCurrent())
            subscriber.putNext(1)
            subscriber.putNext(2)
            subscriber.putCompletion()
        }
        let done = expectation(description: "completed")
        let gate = operatorBlock(timerQueue)
        let disposable = operatorRecord(s.signal |> delay(0.05, queue: timerQueue), log, completion: {
            done.fulfill()
        })
        XCTAssertEqual(log.events, [])
        let start = CFAbsoluteTimeGetCurrent()
        gate.signal()
        wait(for: [done], timeout: 5.0)
        operatorFlush(timerQueue)
        disposable.dispose()
        XCTAssertGreaterThanOrEqual(s.subscribeTimes[0] - start, 0.05 - 0.003)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "next 2", "completed", "s.dispose#1"])
        XCTAssertEqual(onQueue.values, [true])
    }

    func testDelayDisposalBeforeTimeoutPreventsSubscription() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.delay.cancel")
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> delay(0.1, queue: timerQueue), log)
        disposable.dispose()
        let waited = expectation(description: "waited")
        timerQueue.after(0.18) {
            waited.fulfill()
        }
        wait(for: [waited], timeout: 5.0)
        XCTAssertEqual(log.events, [])
        XCTAssertEqual(a.subscriptionCount, 0)
    }

    func testDelayDisposalAfterSubscriptionDisposesSource() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.delay.live")
        let subscribed = expectation(description: "subscribed")
        let a = OperatorSource<Int, String>("a", log, onSubscribe: { _, _ in
            subscribed.fulfill()
        })
        let disposable = operatorRecord(a.signal |> delay(0.01, queue: timerQueue), log)
        wait(for: [subscribed], timeout: 5.0)
        operatorFlush(timerQueue)
        a.emit(5)
        disposable.dispose()
        a.emit(6)
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 5", "a.dispose#1"])
    }

    func testDelayForwardsError() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.delay.error")
        let done = expectation(description: "error")
        let disposable = operatorRecord(Signal<Int, String>.fail("e") |> delay(0.01, queue: timerQueue), log, completion: {
            done.fulfill()
        })
        wait(for: [done], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(log.events, ["error e"])
    }

    func testSuspendAwareDelayShortTimeoutBehavesLikeDelay() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.suspend.short")
        let onQueue = OperatorBox<Bool>()
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, _ in
            onQueue.append(timerQueue.isCurrent())
            subscriber.putNext(1)
            subscriber.putCompletion()
        })
        let done = expectation(description: "completed")
        let gate = operatorBlock(timerQueue)
        let disposable = operatorRecord(s.signal |> suspendAwareDelay(0.03, granularity: 0.02, queue: timerQueue), log, completion: {
            done.fulfill()
        })
        XCTAssertEqual(log.events, [])
        let start = CFAbsoluteTimeGetCurrent()
        gate.signal()
        wait(for: [done], timeout: 5.0)
        operatorFlush(timerQueue)
        disposable.dispose()
        XCTAssertGreaterThanOrEqual(s.subscribeTimes[0] - start, 0.03 - 0.003)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "completed", "s.dispose#1"])
        XCTAssertEqual(onQueue.values, [true])
    }

    func testSuspendAwareDelayLongTimeoutUsesGranularityAndStillWaitsFullTimeout() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.suspend.long")
        let onQueue = OperatorBox<Bool>()
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, _ in
            onQueue.append(timerQueue.isCurrent())
            subscriber.putNext(1)
            subscriber.putCompletion()
        })
        let done = expectation(description: "completed")
        let gate = operatorBlock(timerQueue)
        let disposable = operatorRecord(s.signal |> suspendAwareDelay(0.1, granularity: 0.02, queue: timerQueue), log, completion: {
            done.fulfill()
        })
        XCTAssertEqual(log.events, [])
        let start = CFAbsoluteTimeGetCurrent()
        gate.signal()
        wait(for: [done], timeout: 5.0)
        operatorFlush(timerQueue)
        disposable.dispose()
        XCTAssertGreaterThanOrEqual(s.subscribeTimes[0] - start, 0.1 - 0.005)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "completed", "s.dispose#1"])
        XCTAssertEqual(onQueue.values, [true])
    }

    func testSuspendAwareDelayDisposalBeforeTimeoutPreventsSubscription() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.suspend.cancel")
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let short = operatorRecord(a.signal |> suspendAwareDelay(0.05, granularity: 0.05, queue: timerQueue), log)
        let long = operatorRecord(b.signal |> suspendAwareDelay(0.1, granularity: 0.02, queue: timerQueue), log)
        let waited = expectation(description: "waited")
        timerQueue.after(0.03) {
            long.dispose()
        }
        short.dispose()
        timerQueue.after(0.16) {
            waited.fulfill()
        }
        wait(for: [waited], timeout: 5.0)
        XCTAssertEqual(log.events, [])
    }
}

final class OperatorTimeoutTests: XCTestCase {
    func testTimeoutSubscribesAlternateBeforeDisposingSource() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.timeout")
        let alternateSubscribed = expectation(description: "alternate")
        let onQueue = OperatorBox<Bool>()
        let a = OperatorSource<Int, String>("a", log)
        let alternate = OperatorSource<Int, String>("alt", log, onSubscribe: { _, _ in
            onQueue.append(timerQueue.isCurrent())
            alternateSubscribed.fulfill()
        })
        let start = CFAbsoluteTimeGetCurrent()
        let disposable = operatorRecord(a.signal |> timeout(0.04, queue: timerQueue, alternate: alternate.signal), log)
        wait(for: [alternateSubscribed], timeout: 5.0)
        operatorFlush(timerQueue)
        XCTAssertGreaterThanOrEqual(alternate.subscribeTimes[0] - start, 0.04 - 0.003)
        a.emit(1)
        alternate.emit(2)
        alternate.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "alt.subscribe#1", "a.dispose#1", "next 2", "completed", "alt.dispose#1"])
        XCTAssertEqual(onQueue.values, [true])
    }

    func testTimeoutDoesNotFireWhenSourceEmitsFirst() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.timeout.emit")
        let a = OperatorSource<Int, String>("a", log)
        let alternate = OperatorSource<Int, String>("alt", log)
        let disposable = operatorRecord(a.signal |> timeout(0.15, queue: timerQueue, alternate: alternate.signal), log)
        a.emit(1)
        let waited = expectation(description: "waited")
        timerQueue.after(0.25) {
            waited.fulfill()
        }
        wait(for: [waited], timeout: 5.0)
        a.emit(2)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "next 2", "completed", "a.dispose#1"])
        XCTAssertEqual(alternate.subscriptionCount, 0)
    }

    func testTimeoutDoesNotFireWhenSourceCompletesOrFailsFirst() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.timeout.complete")
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let alternate = OperatorSource<Int, String>("alt", log)
        let first = operatorRecord(a.signal |> timeout(0.15, queue: timerQueue, alternate: alternate.signal), log)
        let second = operatorRecord(b.signal |> timeout(0.15, queue: timerQueue, alternate: alternate.signal), log)
        a.complete()
        b.fail("e")
        let waited = expectation(description: "waited")
        timerQueue.after(0.25) {
            waited.fulfill()
        }
        wait(for: [waited], timeout: 5.0)
        first.dispose()
        second.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "completed", "a.dispose#1", "error e", "b.dispose#1"])
        XCTAssertEqual(alternate.subscriptionCount, 0)
    }

    func testTimeoutDisposalCancelsTimerAndDisposesSource() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.timeout.dispose")
        let a = OperatorSource<Int, String>("a", log)
        let alternate = OperatorSource<Int, String>("alt", log)
        let disposable = operatorRecord(a.signal |> timeout(0.15, queue: timerQueue, alternate: alternate.signal), log)
        disposable.dispose()
        let waited = expectation(description: "waited")
        timerQueue.after(0.25) {
            waited.fulfill()
        }
        wait(for: [waited], timeout: 5.0)
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.dispose#1"])
        XCTAssertEqual(alternate.subscriptionCount, 0)
    }

    func testTimeoutWithSynchronouslyCompletingSourceNeverFires() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.timeout.sync")
        let alternate = OperatorSource<Int, String>("alt", log)
        let s = operatorSyncSource("s", log, values: [1], terminal: OperatorTerminal<String>.complete)
        let disposable = operatorRecord(s.signal |> timeout(0.02, queue: timerQueue, alternate: alternate.signal), log)
        let waited = expectation(description: "waited")
        timerQueue.after(0.08) {
            waited.fulfill()
        }
        wait(for: [waited], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "completed", "s.dispose#1"])
        XCTAssertEqual(alternate.subscriptionCount, 0)
    }

    func testTimeoutStillFiresWhenSourceEmitsSynchronouslyWithoutCompleting() {
        let log = OperatorLog()
        let timerQueue = Queue(name: "operator.timeout.syncvalue")
        let alternateSubscribed = expectation(description: "alternate")
        let alternate = OperatorSource<Int, String>("alt", log, onSubscribe: { subscriber, _ in
            subscriber.putNext(9)
            alternateSubscribed.fulfill()
        })
        let s = operatorSyncSource("s", log, values: [1], terminal: OperatorTerminal<String>.none)
        let disposable = operatorRecord(s.signal |> timeout(0.02, queue: timerQueue, alternate: alternate.signal), log)
        wait(for: [alternateSubscribed], timeout: 5.0)
        operatorFlush(timerQueue)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "alt.subscribe#1", "next 9", "s.dispose#1", "alt.dispose#1"])
    }
}
