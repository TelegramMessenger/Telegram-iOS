import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class OperatorCatchTests: XCTestCase {
    func testAlternativeIsSubscribedWithErrorBeforeFailedSourceIsDisposed() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, Int>("b", log)
        let signal = a.signal |> `catch` { (error: String) -> Signal<Int, Int> in
            log.add("catch \(error)")
            return b.signal
        }
        let disposable = operatorRecord(signal, log)
        a.emit(1)
        a.fail("e")
        b.emit(2)
        b.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "catch e", "b.subscribe#1", "a.dispose#1", "next 2", "completed", "b.dispose#1"])
    }

    func testCompletionWithoutErrorNeverSubscribesAlternative() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> `catch` { _ in b.signal }, log)
        a.emit(1)
        a.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "completed", "a.dispose#1"])
        XCTAssertEqual(b.subscriptionCount, 0)
    }

    func testAlternativeErrorPropagates() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, Int>("b", log)
        operatorRecord(a.signal |> `catch` { _ in b.signal }, log)
        a.fail("e")
        b.fail(42)
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "a.dispose#1", "error 42", "b.dispose#1"])
    }

    func testDisposalDisposesSourceAndAlternative() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let first = operatorRecord(a.signal |> `catch` { _ in b.signal }, log)
        first.dispose()
        first.dispose()
        a.fail("late")
        let second = operatorRecord(a.signal |> `catch` { _ in b.signal }, log)
        a.fail("e")
        second.dispose()
        second.dispose()
        b.emit(1)
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.dispose#1", "a.subscribe#2", "b.subscribe#1", "a.dispose#2", "b.dispose#1"])
        XCTAssertEqual(b.subscriptionCount, 1)
    }

    func testSynchronousFailureAndSynchronousAlternative() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1], terminal: OperatorTerminal<String>.fail("e"))
        let t = operatorSyncSource("t", log, values: [2, 3], terminal: OperatorTerminal<String>.complete)
        operatorRecord(s.signal |> `catch` { _ in t.signal }, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "t.subscribe#1", "next 2", "next 3", "completed", "t.dispose#1", "s.dispose#1"])
    }

    func testChainedCatchWithSingleAndFail() {
        let log = OperatorLog()
        let signal = Signal<Int, String>.fail("first")
            |> `catch` { (error: String) -> Signal<Int, String> in .fail(error + "-again") }
            |> `catch` { (error: String) -> Signal<Int, NoError> in .single(error.count) }
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["next 11", "completed"])
    }
}

final class OperatorRestartTests: XCTestCase {
    func testRestartResubscribesOnCompletionBeforeDisposingPrevious() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(restart(a.signal), log)
        a.emit(1)
        a.complete()
        a.emit(2)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "a.subscribe#2", "a.dispose#1", "next 2", "a.subscribe#3", "a.dispose#2", "a.dispose#3"])
    }

    func testRestartForwardsErrorAndStops() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        operatorRecord(restart(a.signal), log)
        a.complete()
        a.fail("e")
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.subscribe#2", "a.dispose#1", "error e", "a.dispose#2"])
        XCTAssertEqual(a.subscriptionCount, 2)
    }

    func testRestartWithSynchronouslyCompletingSourceDisposesTheLiveResubscription() {
        let log = OperatorLog()
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, id in
            if id <= 2 {
                subscriber.putNext(id)
                subscriber.putCompletion()
            }
        })
        let disposable = operatorRecord(s.signal |> restart, log)
        s.emit(99)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "s.subscribe#2", "next 2", "s.subscribe#3", "s.dispose#2", "s.dispose#3", "s.dispose#1"])
        XCTAssertEqual(s.liveCount, 0)
    }

    func testRecurseBehavesLikeRestartAndIgnoresLatestValue() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> recurse(100), log)
        a.emit(1)
        a.complete()
        a.emit(2)
        disposable.dispose()
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(b.signal |> recurse(nil), log)
        b.complete()
        b.fail("e")
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "next 1", "a.subscribe#2", "a.dispose#1", "next 2", "a.dispose#2",
            "b.subscribe#1", "b.subscribe#2", "b.dispose#1", "error e", "b.dispose#2"
        ])
    }

    func testRestartIfErrorResubscribesImmediatelyOnError() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal: Signal<Int, NoError> = restartIfError(a.signal)
        let disposable = operatorRecord(signal, log)
        a.emit(1)
        a.fail("e1")
        a.emit(2)
        a.fail("e2")
        a.emit(3)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "next 1", "a.subscribe#2", "a.dispose#1", "next 2",
            "a.subscribe#3", "a.dispose#2", "next 3", "completed", "a.dispose#3"
        ])
    }

    func testRestartIfErrorDisposalStopsResubscription() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> restartIfError, log)
        a.fail("e")
        disposable.dispose()
        a.fail("late")
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.subscribe#2", "a.dispose#1", "a.dispose#2"])
    }

    func testRestartIfErrorWithSynchronouslyFailingSourceDisposesTheLiveResubscription() {
        let log = OperatorLog()
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, id in
            if id <= 2 {
                subscriber.putError("e\(id)")
            }
        })
        let disposable = operatorRecord(s.signal |> restartIfError, log)
        s.emit(5)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "s.subscribe#2", "s.subscribe#3", "s.dispose#2", "s.dispose#3", "s.dispose#1"])
    }

    func testRestartIfErrorWithSynchronousEventualSuccess() {
        let log = OperatorLog()
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, id in
            if id <= 2 {
                subscriber.putError("e\(id)")
            } else {
                subscriber.putNext(id)
                subscriber.putCompletion()
            }
        })
        operatorRecord(s.signal |> restartIfError, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "s.subscribe#2", "s.subscribe#3", "next 3", "completed", "s.dispose#3", "s.dispose#2", "s.dispose#1"])
    }

    func testRestartOrMapErrorRestartsOrMapsByCondition() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal = a.signal |> restartOrMapError(condition: { (error: String) -> RestartOrMapErrorCondition<Int> in
            log.add("condition \(error)")
            if error == "retry" {
                return .restart
            }
            return .error(error.count)
        })
        let disposable = operatorRecord(signal, log)
        a.emit(1)
        a.fail("retry")
        a.emit(2)
        a.fail("fatal")
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "next 1", "condition retry", "a.subscribe#2", "a.dispose#1",
            "next 2", "condition fatal", "error 5", "a.dispose#2"
        ])
    }

    func testRestartOrMapErrorCompletionAndDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let condition = { (_: String) -> RestartOrMapErrorCondition<String> in .restart }
        operatorRecord(a.signal |> restartOrMapError(condition: condition), log)
        a.complete()
        let disposable = operatorRecord(b.signal |> restartOrMapError(condition: condition), log)
        b.fail("x")
        disposable.dispose()
        b.fail("y")
        XCTAssertEqual(log.events, ["a.subscribe#1", "completed", "a.dispose#1", "b.subscribe#1", "b.subscribe#2", "b.dispose#1", "b.dispose#2"])
    }
}

final class OperatorRetryTests: XCTestCase {
    func testRetryResubscribesAfterGrowingDelaysCappedByMaxDelayAndNeverPropagatesErrors() {
        let log = OperatorLog()
        let retryQueue = Queue(name: "operator.retry")
        let threadOnQueue = OperatorBox<Bool>()
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, id in
            threadOnQueue.append(retryQueue.isCurrent())
            if id <= 4 {
                subscriber.putError("e\(id)")
            } else {
                subscriber.putNext(id)
                subscriber.putCompletion()
            }
        })
        let done = expectation(description: "completed")
        let signal: Signal<Int, NoError> = s.signal |> retry(0.01, maxDelay: 0.025, onQueue: retryQueue)
        let disposable = operatorRecord(signal, log, completion: {
            done.fulfill()
        })
        wait(for: [done], timeout: 5.0)
        operatorFlush(retryQueue)
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "s.subscribe#1", "s.dispose#1", "s.subscribe#2", "s.dispose#2", "s.subscribe#3", "s.dispose#3",
            "s.subscribe#4", "s.dispose#4", "s.subscribe#5", "next 5", "completed", "s.dispose#5"
        ])
        XCTAssertEqual(threadOnQueue.values, [false, true, true, true, true])
        let times = s.subscribeTimes
        let gaps = (1 ..< times.count).map { times[$0] - times[$0 - 1] }
        let expected = [0.01, 0.02, 0.025, 0.025]
        for (gap, minimum) in zip(gaps, expected) {
            XCTAssertGreaterThanOrEqual(gap, minimum - 0.003, "gaps \(gaps)")
        }
    }

    func testRetryDisposalDuringBackoffPreventsResubscription() {
        let log = OperatorLog()
        let retryQueue = Queue(name: "operator.retry.dispose")
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, _ in
            subscriber.putError("e")
        })
        let disposable = operatorRecord(s.signal |> retry(0.1, maxDelay: 0.1, onQueue: retryQueue), log)
        disposable.dispose()
        let waited = expectation(description: "waited")
        retryQueue.after(0.18) {
            waited.fulfill()
        }
        wait(for: [waited], timeout: 5.0)
        XCTAssertEqual(log.events, ["s.subscribe#1", "s.dispose#1"])
    }

    func testRetryDisposalDisposesLiveSubscription() {
        let log = OperatorLog()
        let retryQueue = Queue(name: "operator.retry.live")
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> retry(0.01, maxDelay: 0.01, onQueue: retryQueue), log)
        a.emit(1)
        disposable.dispose()
        a.emit(2)
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "a.dispose#1"])
    }

    func testRetryWithConditionPropagatesNonRetryableErrorImmediately() {
        let log = OperatorLog()
        let retryQueue = Queue(name: "operator.retry.condition")
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, _ in
            subscriber.putNext(1)
            subscriber.putError("fatal")
        })
        let signal = s.signal |> retry(retryOnError: { (error: String) -> Bool in
            log.add("check \(error)")
            return error != "fatal"
        }, delayIncrement: 0.01, maxDelay: 0.1, maxRetries: nil, onQueue: retryQueue)
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "check fatal", "error fatal", "s.dispose#1"])
    }

    func testRetryWithMaxRetriesStopsAndPropagatesError() {
        let log = OperatorLog()
        let retryQueue = Queue(name: "operator.retry.max")
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, id in
            subscriber.putError("e\(id)")
        })
        let done = expectation(description: "error")
        let signal = s.signal |> retry(retryOnError: { _ in true }, delayIncrement: 0.01, maxDelay: 0.05, maxRetries: 3, onQueue: retryQueue)
        let disposable = operatorRecord(signal, log, completion: {
            done.fulfill()
        })
        wait(for: [done], timeout: 5.0)
        operatorFlush(retryQueue)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "s.dispose#1", "s.subscribe#2", "s.dispose#2", "s.subscribe#3", "error e3", "s.dispose#3"])
        let times = s.subscribeTimes
        XCTAssertEqual(times.count, 3)
        XCTAssertGreaterThanOrEqual(times[1] - times[0], 0.01 - 0.003)
        XCTAssertGreaterThanOrEqual(times[2] - times[1], 0.02 - 0.003)
    }

    func testRetryWithZeroMaxRetriesFailsOnFirstError() {
        let log = OperatorLog()
        let retryQueue = Queue(name: "operator.retry.zero")
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, _ in
            subscriber.putError("e")
        })
        operatorRecord(s.signal |> retry(retryOnError: { _ in true }, delayIncrement: 0.01, maxDelay: 0.05, maxRetries: 0, onQueue: retryQueue), log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "error e", "s.dispose#1"])
    }

    func testRetryWithConditionRetriesUntilSuccessAndCompletes() {
        let log = OperatorLog()
        let retryQueue = Queue(name: "operator.retry.success")
        let a = OperatorSource<Int, String>("a", log)
        let done = expectation(description: "completed")
        let resubscribed = expectation(description: "resubscribed")
        a.onSubscribe = { _, id in
            if id == 2 {
                resubscribed.fulfill()
            }
        }
        let signal = a.signal |> retry(retryOnError: { _ in true }, delayIncrement: 0.01, maxDelay: 0.05, maxRetries: nil, onQueue: retryQueue)
        let disposable = operatorRecord(signal, log, completion: {
            done.fulfill()
        })
        a.emit(1)
        a.fail("e")
        wait(for: [resubscribed], timeout: 5.0)
        operatorFlush(retryQueue)
        a.emit(2)
        a.complete()
        wait(for: [done], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "a.dispose#1", "a.subscribe#2", "next 2", "completed", "a.dispose#2"])
    }

    func testRetryWithConditionDisposalDuringBackoffPreventsResubscription() {
        let log = OperatorLog()
        let retryQueue = Queue(name: "operator.retry.condition.dispose")
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, _ in
            subscriber.putError("e")
        })
        let disposable = operatorRecord(s.signal |> retry(retryOnError: { _ in true }, delayIncrement: 0.1, maxDelay: 0.1, maxRetries: nil, onQueue: retryQueue), log)
        disposable.dispose()
        let waited = expectation(description: "waited")
        retryQueue.after(0.18) {
            waited.fulfill()
        }
        wait(for: [waited], timeout: 5.0)
        XCTAssertEqual(log.events, ["s.subscribe#1", "s.dispose#1"])
    }
}
