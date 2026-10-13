import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class OperatorSwitchToLatestTests: XCTestCase {
    func testNewInnerIsSubscribedBeforePreviousInnerIsDisposed() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let disposable = operatorRecord(o.signal |> switchToLatest, log)
        o.emit(a.signal)
        a.emit(1)
        o.emit(b.signal)
        a.emit(2)
        b.emit(3)
        disposable.dispose()
        b.emit(4)
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "next 1", "b.subscribe#1", "a.dispose#1", "next 3", "b.dispose#1", "o.dispose#1"])
    }

    func testCompletesOnlyWhenInnerCompletesAfterOuterCompleted() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(o.signal |> switchToLatest, log)
        o.emit(a.signal)
        o.complete()
        a.emit(1)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "o.dispose#1", "next 1", "completed", "a.dispose#1"])
    }

    func testCompletesWhenOuterCompletesAfterInnerCompleted() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(o.signal |> switchToLatest, log)
        o.emit(a.signal)
        a.emit(1)
        a.complete()
        o.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "next 1", "a.dispose#1", "completed", "o.dispose#1"])
    }

    func testOuterCompletionWithoutInnerCompletesImmediately() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        operatorRecord(o.signal |> switchToLatest, log)
        o.complete()
        XCTAssertEqual(log.events, ["o.subscribe#1", "completed", "o.dispose#1"])
    }

    func testInnerErrorPropagatesAndDisposesInnerThenOuter() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        operatorRecord(o.signal |> switchToLatest, log)
        o.emit(a.signal)
        a.fail("inner")
        o.emit(a.signal)
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "error inner", "a.dispose#1", "o.dispose#1"])
    }

    func testOuterErrorPropagatesAndDisposesInnerThenOuter() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        operatorRecord(o.signal |> switchToLatest, log)
        o.emit(a.signal)
        o.fail("outer")
        a.emit(1)
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "error outer", "a.dispose#1", "o.dispose#1"])
    }

    func testSynchronousOuterAndInners() {
        let log = OperatorLog()
        let s1 = operatorSyncSource("s1", log, values: [1], terminal: OperatorTerminal<String>.complete)
        let s2 = operatorSyncSource("s2", log, values: [2], terminal: OperatorTerminal<String>.complete)
        let o = operatorSyncSource("o", log, values: [s1.signal, s2.signal], terminal: OperatorTerminal<String>.complete)
        let disposable = operatorRecord(o.signal |> switchToLatest, log)
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "s1.subscribe#1", "next 1", "s1.dispose#1", "s2.subscribe#1", "next 2", "s2.dispose#1", "completed", "o.dispose#1"])
    }

    func testSynchronousInnerWithoutCompletionReplacesAsyncInner() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let s = operatorSyncSource("s", log, values: [7], terminal: OperatorTerminal<String>.none)
        let disposable = operatorRecord(o.signal |> switchToLatest, log)
        o.emit(a.signal)
        o.emit(s.signal)
        o.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "s.subscribe#1", "next 7", "a.dispose#1", "o.dispose#1", "s.dispose#1"])
    }

    func testIgnoresEventsFromReplacedInnerThatKeepsEmitting() {
        let log = OperatorLog()
        let leaked = OperatorBox<Subscriber<Int, String>>()
        let leaky = Signal<Int, String> { subscriber in
            leaked.append(subscriber)
            return EmptyDisposable
        }
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let b = OperatorSource<Int, String>("b", log)
        let disposable = operatorRecord(o.signal |> switchToLatest, log)
        o.emit(leaky)
        leaked.values[0].putNext(1)
        o.emit(b.signal)
        leaked.values[0].putNext(2)
        leaked.values[0].putCompletion()
        leaked.values[0].putError("late")
        b.emit(3)
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "next 1", "b.subscribe#1", "next 3", "b.dispose#1", "o.dispose#1"])
    }

    func testDisposalWithoutInnerDisposesOuterOnly() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let disposable = operatorRecord(o.signal |> switchToLatest, log)
        disposable.dispose()
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "o.dispose#1"])
    }
}

final class OperatorMapToSignalTests: XCTestCase {
    func testTransformIsCalledPerValueAndLatestInnerWins() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        let inners = [1: OperatorSource<String, String>("x1", log), 2: OperatorSource<String, String>("x2", log)]
        let signal = o.signal |> mapToSignal { (value: Int) -> Signal<String, String> in
            log.add("f \(value)")
            return inners[value]!.signal
        }
        let disposable = operatorRecord(signal, log)
        o.emit(1)
        inners[1]!.emit("a")
        o.emit(2)
        inners[1]!.emit("b")
        inners[2]!.emit("c")
        o.complete()
        inners[2]!.emit("d")
        inners[2]!.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "o.subscribe#1",
            "f 1", "x1.subscribe#1", "next a",
            "f 2", "x2.subscribe#1", "x1.dispose#1", "next c",
            "o.dispose#1", "next d", "completed", "x2.dispose#1"
        ])
    }

    func testDisposalDisposesInnerThenOuter() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        let x = OperatorSource<Int, String>("x", log)
        let disposable = operatorRecord(o.signal |> mapToSignal { _ in x.signal }, log)
        o.emit(1)
        disposable.dispose()
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "x.subscribe#1", "x.dispose#1", "o.dispose#1"])
    }

    func testInnerErrorPropagates() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        let x = OperatorSource<Int, String>("x", log)
        operatorRecord(o.signal |> mapToSignal { _ in x.signal }, log)
        o.emit(1)
        x.fail("inner")
        XCTAssertEqual(log.events, ["o.subscribe#1", "x.subscribe#1", "error inner", "x.dispose#1", "o.dispose#1"])
    }

    func testOuterErrorPropagates() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        let x = OperatorSource<Int, String>("x", log)
        operatorRecord(o.signal |> mapToSignal { _ in x.signal }, log)
        o.emit(1)
        o.fail("outer")
        XCTAssertEqual(log.events, ["o.subscribe#1", "x.subscribe#1", "error outer", "x.dispose#1", "o.dispose#1"])
    }

    func testSynchronousSourcesAndInners() {
        let log = OperatorLog()
        let o = operatorSyncSource("o", log, values: [1, 2, 3], terminal: OperatorTerminal<String>.complete)
        let signal = o.signal |> mapToSignal { (value: Int) -> Signal<Int, String> in
            if value == 2 {
                return .complete()
            }
            return .single(value * 10)
        }
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["o.subscribe#1", "next 10", "next 30", "completed", "o.dispose#1"])
    }

    func testSynchronousInnerErrorStopsSynchronousOuter() {
        let log = OperatorLog()
        let o = operatorSyncSource("o", log, values: [1, 2, 3], terminal: OperatorTerminal<String>.complete)
        let signal = o.signal |> mapToSignal { (value: Int) -> Signal<Int, String> in
            log.add("f \(value)")
            if value == 2 {
                return .fail("two")
            }
            return .single(value)
        }
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["o.subscribe#1", "f 1", "next 1", "f 2", "error two", "f 3", "o.dispose#1"])
    }

    func testMapToSignalPromotingErrorPropagatesInnerErrors() {
        let log = OperatorLog()
        let o = OperatorSource<Int, NoError>("o", log)
        let x = OperatorSource<Int, String>("x", log)
        let y = OperatorSource<Int, String>("y", log)
        let signal: Signal<Int, String> = o.signal |> mapToSignalPromotingError { (value: Int) -> Signal<Int, String> in
            log.add("f \(value)")
            return value == 1 ? x.signal : y.signal
        }
        operatorRecord(signal, log)
        o.emit(1)
        x.emit(10)
        o.emit(2)
        y.emit(20)
        y.fail("bad")
        XCTAssertEqual(log.events, ["o.subscribe#1", "f 1", "x.subscribe#1", "next 10", "f 2", "y.subscribe#1", "x.dispose#1", "next 20", "error bad", "y.dispose#1", "o.dispose#1"])
    }

    func testMapToSignalPromotingErrorCompletionAndDisposal() {
        let log = OperatorLog()
        let o = OperatorSource<Int, NoError>("o", log)
        let x = OperatorSource<Int, String>("x", log)
        operatorRecord(o.signal |> mapToSignalPromotingError { _ in x.signal }, log)
        o.emit(1)
        x.complete()
        o.complete()
        let p = OperatorSource<Int, NoError>("p", log)
        let disposable = operatorRecord(p.signal |> mapToSignalPromotingError { _ in x.signal }, log)
        p.emit(1)
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "o.subscribe#1", "x.subscribe#1", "x.dispose#1", "completed", "o.dispose#1",
            "p.subscribe#1", "x.subscribe#2", "x.dispose#2", "p.dispose#1"
        ])
    }
}

final class OperatorQueueTests: XCTestCase {
    func testInnersRunStrictlyOneAfterAnother() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let c = OperatorSource<Int, String>("c", log)
        let disposable = operatorRecord(o.signal |> queue, log)
        o.emit(a.signal)
        o.emit(b.signal)
        o.emit(c.signal)
        a.emit(1)
        a.complete()
        b.emit(2)
        o.complete()
        b.complete()
        c.emit(3)
        c.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "o.subscribe#1", "a.subscribe#1", "next 1",
            "b.subscribe#1", "a.dispose#1", "next 2",
            "o.dispose#1",
            "c.subscribe#1", "b.dispose#1", "next 3",
            "completed", "c.dispose#1"
        ])
    }

    func testQueuedSynchronousInnersDrainIteratively() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let s2 = operatorSyncSource("s2", log, values: [2], terminal: OperatorTerminal<String>.complete)
        let s3 = operatorSyncSource("s3", log, values: [3], terminal: OperatorTerminal<String>.complete)
        let disposable = operatorRecord(o.signal |> queue, log)
        o.emit(a.signal)
        o.emit(s2.signal)
        o.emit(s3.signal)
        a.complete()
        o.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "o.subscribe#1", "a.subscribe#1",
            "s2.subscribe#1", "next 2", "s2.dispose#1", "a.dispose#1",
            "s3.subscribe#1", "next 3", "s3.dispose#1",
            "completed", "o.dispose#1"
        ])
    }

    func testManyQueuedSynchronousInnersDoNotRecurse() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, NoError>, NoError>("o", log)
        let a = OperatorSource<Int, NoError>("a", log)
        let values = OperatorBox<Int>()
        let completed = OperatorFlag()
        let disposable = (o.signal |> queue).start(next: { value in
            values.append(value)
        }, completed: {
            completed.set()
        })
        o.emit(a.signal)
        for index in 0 ..< 5000 {
            o.emit(.single(index))
        }
        a.complete()
        o.complete()
        disposable.dispose()
        XCTAssertEqual(values.values, Array(0 ..< 5000))
        XCTAssertTrue(completed.value)
    }

    func testSynchronousOuterWithSynchronousInners() {
        let log = OperatorLog()
        let o = operatorSyncSource("o", log, values: [Signal<Int, String>.single(1), .single(2), .complete(), .single(3)], terminal: OperatorTerminal<String>.complete)
        operatorRecord(o.signal |> queue, log)
        XCTAssertEqual(log.events, ["o.subscribe#1", "next 1", "next 2", "next 3", "completed", "o.dispose#1"])
    }

    func testInnerErrorStopsQueueAndSkipsQueuedInners() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(o.signal |> queue, log)
        o.emit(a.signal)
        o.emit(b.signal)
        a.fail("e")
        o.emit(b.signal)
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "error e", "a.dispose#1", "o.dispose#1"])
        XCTAssertEqual(b.subscriptionCount, 0)
    }

    func testOuterErrorStopsQueue() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(o.signal |> queue, log)
        o.emit(a.signal)
        o.emit(b.signal)
        o.fail("outer")
        a.complete()
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "error outer", "a.dispose#1", "o.dispose#1"])
        XCTAssertEqual(b.subscriptionCount, 0)
    }

    func testDisposalDisposesCurrentThenOuterAndDropsQueued() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let disposable = operatorRecord(o.signal |> queue, log)
        o.emit(a.signal)
        o.emit(b.signal)
        disposable.dispose()
        a.complete()
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "a.dispose#1", "o.dispose#1"])
        XCTAssertEqual(b.subscriptionCount, 0)
    }

    func testOuterCompletionWhileIdleCompletesImmediately() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        operatorRecord(o.signal |> queue, log)
        o.emit(a.signal)
        a.complete()
        o.complete()
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "a.dispose#1", "completed", "o.dispose#1"])
    }

    func testMapToQueueCallsTransformEagerlyAndRunsSequentially() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        let inners = (1 ... 3).map { OperatorSource<Int, String>("x\($0)", log) }
        let signal = o.signal |> mapToQueue { (value: Int) -> Signal<Int, String> in
            log.add("f \(value)")
            return inners[value - 1].signal
        }
        let disposable = operatorRecord(signal, log)
        o.emit(1)
        o.emit(2)
        o.emit(3)
        inners[0].emit(10)
        inners[0].complete()
        inners[1].complete()
        o.complete()
        inners[2].emit(30)
        inners[2].complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "o.subscribe#1", "f 1", "x1.subscribe#1", "f 2", "f 3",
            "next 10", "x2.subscribe#1", "x1.dispose#1",
            "x3.subscribe#1", "x2.dispose#1",
            "o.dispose#1", "next 30", "completed", "x3.dispose#1"
        ])
    }

    func testMapToQueueErrorAndDisposal() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        let x = OperatorSource<Int, String>("x", log)
        operatorRecord(o.signal |> mapToQueue { _ in x.signal }, log)
        o.emit(1)
        o.emit(2)
        x.fail("e")
        let p = OperatorSource<Int, String>("p", log)
        let disposable = operatorRecord(p.signal |> mapToQueue { _ in x.signal }, log)
        p.emit(1)
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "x.subscribe#1", "error e", "x.dispose#1", "o.dispose#1", "p.subscribe#1", "x.subscribe#2", "x.dispose#2", "p.dispose#1"])
    }
}

final class OperatorThrottledTests: XCTestCase {
    func testKeepsOnlyLatestPendingInnerWhileOneIsExecuting() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let c = OperatorSource<Int, String>("c", log)
        let d = OperatorSource<Int, String>("d", log)
        let e = OperatorSource<Int, String>("e", log)
        let disposable = operatorRecord(o.signal |> throttled, log)
        o.emit(a.signal)
        o.emit(b.signal)
        o.emit(c.signal)
        o.emit(d.signal)
        a.emit(1)
        a.complete()
        o.emit(e.signal)
        d.emit(4)
        d.complete()
        o.complete()
        e.emit(5)
        e.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "o.subscribe#1", "a.subscribe#1", "next 1",
            "d.subscribe#1", "a.dispose#1", "next 4",
            "e.subscribe#1", "d.dispose#1",
            "o.dispose#1", "next 5", "completed", "e.dispose#1"
        ])
        XCTAssertEqual(b.subscriptionCount, 0)
        XCTAssertEqual(c.subscriptionCount, 0)
    }

    func testIdleThrottledStartsInnerImmediately() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(o.signal |> throttled, log)
        o.emit(a.signal)
        a.complete()
        o.emit(b.signal)
        b.fail("e")
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "a.dispose#1", "b.subscribe#1", "error e", "b.dispose#1", "o.dispose#1"])
    }

    func testSynchronousInnersAreAllExecuted() {
        let log = OperatorLog()
        let o = operatorSyncSource("o", log, values: [Signal<Int, String>.single(1), .single(2), .single(3)], terminal: OperatorTerminal<String>.complete)
        operatorRecord(o.signal |> throttled, log)
        XCTAssertEqual(log.events, ["o.subscribe#1", "next 1", "next 2", "next 3", "completed", "o.dispose#1"])
    }

    func testDisposalDropsPendingInner() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let disposable = operatorRecord(o.signal |> throttled, log)
        o.emit(a.signal)
        o.emit(b.signal)
        disposable.dispose()
        a.complete()
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "a.dispose#1", "o.dispose#1"])
        XCTAssertEqual(b.subscriptionCount, 0)
    }

    func testMapToThrottledCallsTransformForEveryValueButRunsOnlyLatest() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        let inners = (1 ... 4).map { OperatorSource<Int, String>("x\($0)", log) }
        let signal = o.signal |> mapToThrottled { (value: Int) -> Signal<Int, String> in
            log.add("f \(value)")
            return inners[value - 1].signal
        }
        let disposable = operatorRecord(signal, log)
        o.emit(1)
        o.emit(2)
        o.emit(3)
        o.emit(4)
        inners[0].complete()
        o.complete()
        inners[3].emit(40)
        inners[3].complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "o.subscribe#1", "f 1", "x1.subscribe#1", "f 2", "f 3", "f 4",
            "x4.subscribe#1", "x1.dispose#1",
            "o.dispose#1", "next 40", "completed", "x4.dispose#1"
        ])
        XCTAssertEqual(inners[1].subscriptionCount, 0)
        XCTAssertEqual(inners[2].subscriptionCount, 0)
    }
}

final class OperatorThenTests: XCTestCase {
    func testSecondIsSubscribedOnlyAfterFirstCompletes() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let disposable = operatorRecord(a.signal |> then(b.signal), log)
        a.emit(1)
        XCTAssertEqual(b.subscriptionCount, 0)
        a.complete()
        b.emit(2)
        b.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "b.subscribe#1", "a.dispose#1", "next 2", "completed", "b.dispose#1"])
    }

    func testErrorOfFirstSkipsSecond() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> then(b.signal), log)
        a.emit(1)
        a.fail("first")
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "error first", "a.dispose#1"])
        XCTAssertEqual(b.subscriptionCount, 0)
    }

    func testErrorOfSecondPropagates() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> then(b.signal), log)
        a.complete()
        b.fail("second")
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "a.dispose#1", "error second", "b.dispose#1"])
    }

    func testDisposalDuringFirstNeverSubscribesSecond() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let disposable = operatorRecord(a.signal |> then(b.signal), log)
        disposable.dispose()
        disposable.dispose()
        a.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.dispose#1"])
        XCTAssertEqual(b.subscriptionCount, 0)
    }

    func testDisposalDuringSecondDisposesSecond() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let disposable = operatorRecord(a.signal |> then(b.signal), log)
        a.complete()
        disposable.dispose()
        b.emit(1)
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "a.dispose#1", "b.dispose#1"])
    }

    func testSynchronousFirstAndSecond() {
        let log = OperatorLog()
        let s1 = operatorSyncSource("s1", log, values: [1], terminal: OperatorTerminal<String>.complete)
        let s2 = operatorSyncSource("s2", log, values: [2], terminal: OperatorTerminal<String>.complete)
        operatorRecord(s1.signal |> then(s2.signal), log)
        XCTAssertEqual(log.events, ["s1.subscribe#1", "next 1", "s2.subscribe#1", "next 2", "completed", "s2.dispose#1", "s1.dispose#1"])
    }

    func testChainedThenWithSingleAndComplete() {
        let log = OperatorLog()
        let signal = Signal<Int, String>.single(1) |> then(.complete()) |> then(.single(2)) |> then(.fail("end")) |> then(.single(3))
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["next 1", "next 2", "error end"])
    }
}

final class OperatorDeferredTests: XCTestCase {
    func testGeneratorIsCalledLazilyPerSubscription() {
        let log = OperatorLog()
        let calls = OperatorCounter()
        let a = OperatorSource<Int, String>("a", log)
        let signal = deferred { () -> Signal<Int, String> in
            log.add("generator \(calls.increment())")
            return a.signal
        }
        XCTAssertEqual(calls.value, 0)
        let first = operatorRecord(signal, log)
        let second = operatorRecord(signal, log)
        a.emit(1)
        first.dispose()
        a.complete()
        second.dispose()
        XCTAssertEqual(log.events, [
            "generator 1", "a.subscribe#1", "generator 2", "a.subscribe#2",
            "next 1", "next 1", "a.dispose#1", "completed", "a.dispose#2"
        ])
    }

    func testForwardsErrorAndSynchronousSignals() {
        let log = OperatorLog()
        operatorRecord(deferred { Signal<Int, String>.fail("e") }, log)
        operatorRecord(deferred { Signal<Int, String>.single(4) }, log)
        let a = OperatorSource<Int, String>("a", log)
        operatorRecord(deferred { a.signal }, log)
        a.fail("late")
        XCTAssertEqual(log.events, ["error e", "next 4", "completed", "a.subscribe#1", "error late", "a.dispose#1"])
    }
}

final class OperatorMeasureTimeTests: XCTestCase {
    func testDebugMeasureTimeToFirstEventPassesEventsThrough() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> debug_measureTimeToFirstEvent(label: "operator-test"), log)
        a.emit(1)
        a.emit(2)
        a.complete()
        disposable.dispose()
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(b.signal |> debug_measureTimeToFirstEvent(label: "operator-test"), log)
        b.fail("e")
        let c = OperatorSource<Int, String>("c", log)
        let third = operatorRecord(c.signal |> debug_measureTimeToFirstEvent(label: "operator-test"), log)
        third.dispose()
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "next 1", "next 2", "completed", "a.dispose#1",
            "b.subscribe#1", "error e", "b.dispose#1",
            "c.subscribe#1", "c.dispose#1"
        ])
    }
}
