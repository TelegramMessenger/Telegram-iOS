import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class OperatorReentrancyTests: XCTestCase {
    func testDisposingFromNextCallbackStopsFurtherEventsThroughMap() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let holder = MetaDisposable()
        holder.set((a.signal |> map { $0 * 2 }).start(next: { value in
            log.add("next \(value)")
            holder.dispose()
        }, completed: {
            log.add("completed")
        }))
        a.emit(1)
        a.emit(2)
        a.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 2", "a.dispose#1"])
    }

    func testDisposingFromSynchronousNextCallbackDisposesSourceAfterGeneratorReturns() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2, 3], terminal: OperatorTerminal<String>.none)
        let holder = MetaDisposable()
        holder.set((s.signal |> map { $0 }).start(next: { value in
            log.add("next \(value)")
            holder.dispose()
        }))
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "next 2", "next 3", "s.dispose#1"])
    }

    func testDisposingFromInnerNextCallbackOfSwitchToLatest() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let x = OperatorSource<Int, String>("x", log)
        let y = OperatorSource<Int, String>("y", log)
        let holder = MetaDisposable()
        holder.set((o.signal |> switchToLatest).start(next: { value in
            log.add("next \(value)")
            holder.dispose()
        }))
        o.emit(x.signal)
        x.emit(1)
        x.emit(2)
        o.emit(y.signal)
        XCTAssertEqual(log.events, ["o.subscribe#1", "x.subscribe#1", "next 1", "x.dispose#1", "o.dispose#1"])
        XCTAssertEqual(y.subscriptionCount, 0)
    }

    func testOuterEmittingNewInnerFromInsideInnerCallbackOfSwitchToLatest() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let x = OperatorSource<Int, String>("x", log)
        let y = OperatorSource<Int, String>("y", log)
        let disposable = (o.signal |> switchToLatest).start(next: { value in
            log.add("next \(value)")
            if value == 1 {
                o.emit(y.signal)
                log.add("switched")
            }
        })
        o.emit(x.signal)
        x.emit(1)
        x.emit(2)
        y.emit(3)
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "x.subscribe#1", "next 1", "y.subscribe#1", "x.dispose#1", "switched", "next 3", "y.dispose#1", "o.dispose#1"])
    }

    func testTakeOneAfterSwitchToLatestWithSynchronousInnerDisposesInnerAfterItsGeneratorReturns() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let s = operatorSyncSource("s", log, values: [1, 2], terminal: OperatorTerminal<String>.none)
        operatorRecord(o.signal |> switchToLatest |> take(1), log)
        o.emit(s.signal)
        XCTAssertEqual(log.events, ["o.subscribe#1", "s.subscribe#1", "next 1", "completed", "o.dispose#1", "s.dispose#1"])
    }

    func testTakeOneAfterQueueWithSynchronousInner() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        let s = operatorSyncSource("s", log, values: [1, 2], terminal: OperatorTerminal<String>.none)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(o.signal |> queue |> take(1), log)
        o.emit(s.signal)
        o.emit(b.signal)
        XCTAssertEqual(log.events, ["o.subscribe#1", "s.subscribe#1", "next 1", "completed", "o.dispose#1", "s.dispose#1"])
        XCTAssertEqual(b.subscriptionCount, 0)
    }

    func testTakeOneAfterCombineLatestWithSynchronousSources() {
        let log = OperatorLog()
        let s1 = operatorSyncSource("s1", log, values: [1, 2], terminal: OperatorTerminal<String>.none)
        let s2 = operatorSyncSource("s2", log, values: [10, 20], terminal: OperatorTerminal<String>.none)
        operatorRecord(combineLatest(s1.signal, s2.signal) |> take(1), log)
        XCTAssertEqual(log.events, ["s1.subscribe#1", "s2.subscribe#1", "next (2, 10)", "completed", "s1.dispose#1", "s2.dispose#1"])
    }

    func testTakeOneAfterThenStillSubscribesSecondWhenFirstCompletesSynchronously() {
        let log = OperatorLog()
        let a = operatorSyncSource("a", log, values: [1], terminal: OperatorTerminal<String>.complete)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> then(b.signal) |> take(1), log)
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "completed", "b.subscribe#1", "a.dispose#1", "b.dispose#1"])
    }

    func testTakeOneAfterCatchWithSynchronousAlternative() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let t = operatorSyncSource("t", log, values: [1, 2], terminal: OperatorTerminal<String>.none)
        operatorRecord(a.signal |> `catch` { _ in t.signal } |> take(1), log)
        a.fail("e")
        XCTAssertEqual(log.events, ["a.subscribe#1", "t.subscribe#1", "next 1", "completed", "a.dispose#1", "t.dispose#1"])
    }

    func testTakeOneAfterRestartWithSynchronousFirstIteration() {
        let log = OperatorLog()
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, id in
            if id == 1 {
                subscriber.putNext(1)
                subscriber.putCompletion()
            }
        })
        operatorRecord(s.signal |> restart |> take(1), log)
        s.complete()
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "completed", "s.subscribe#2", "s.dispose#1", "s.dispose#2"])
        XCTAssertEqual(s.subscriptionCount, 2)
    }

    func testTakeOneAfterRestartWithAsynchronousSourceStopsRestarting() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        operatorRecord(a.signal |> restart |> take(1), log)
        a.emit(1)
        a.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "completed", "a.dispose#1"])
        XCTAssertEqual(a.subscriptionCount, 1)
    }

    func testUpstreamEventsEmittedDuringDisposalAreDeliveredThroughMap() {
        let log = OperatorLog()
        let source = Signal<Int, String> { subscriber in
            log.add("subscribe")
            return ActionDisposable {
                log.add("disposing")
                subscriber.putNext(99)
                subscriber.putCompletion()
            }
        }
        let disposable = operatorRecord(source |> map { $0 + 1 }, log)
        disposable.dispose()
        disposable.dispose()
        XCTAssertEqual(log.events, ["subscribe", "disposing", "next 100", "completed"])
    }

    func testUpstreamEventsEmittedDuringDisposalAreDeliveredThroughCombineLatest() {
        let log = OperatorLog()
        let source = Signal<Int, String> { subscriber in
            log.add("subscribe")
            return ActionDisposable {
                log.add("disposing")
                subscriber.putNext(7)
            }
        }
        let disposable = operatorRecord(combineLatest(source, Signal<Int, String>.single(1)), log)
        disposable.dispose()
        XCTAssertEqual(log.events, ["subscribe", "disposing", "next (7, 1)"])
    }
}

final class OperatorDisposeCallCountTests: XCTestCase {
    private func countingSource(_ name: String, _ log: OperatorLog) -> OperatorSource<Int, String> {
        let source = OperatorSource<Int, String>(name, log)
        source.logsEveryDisposeCall = true
        return source
    }

    func testPlainStartDisposesGeneratorDisposableOnceOnAsynchronousCompletion() {
        let log = OperatorLog()
        let a = countingSource("a", log)
        let b = countingSource("b", log)
        let first = a.signal.start()
        a.complete()
        first.dispose()
        let second = b.signal.start()
        second.dispose()
        second.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.dispose#1", "b.subscribe#1", "b.dispose#1"])
    }

    func testMapDisposesUpstreamTwiceOnAsynchronousTermination() {
        let log = OperatorLog()
        let a = countingSource("a", log)
        let b = countingSource("b", log)
        let first = operatorRecord(a.signal |> map { $0 }, log)
        a.complete()
        first.dispose()
        let second = operatorRecord(b.signal |> map { $0 }, log)
        b.fail("e")
        second.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "completed", "a.dispose#1", "a.dispose#1", "b.subscribe#1", "error e", "b.dispose#1", "b.dispose#1"])
    }

    func testMapDisposesUpstreamOnceOnExplicitDisposalAndOnSynchronousCompletion() {
        let log = OperatorLog()
        let a = countingSource("a", log)
        let first = operatorRecord(a.signal |> map { $0 }, log)
        first.dispose()
        first.dispose()
        a.complete()
        let s = OperatorSource<Int, String>("s", log, onSubscribe: { subscriber, _ in
            subscriber.putCompletion()
        })
        s.logsEveryDisposeCall = true
        let second = operatorRecord(s.signal |> map { $0 }, log)
        second.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.dispose#1", "s.subscribe#1", "completed", "s.dispose#1"])
    }

    func testTakeDisposesUpstreamOnceWhenCountReached() {
        let log = OperatorLog()
        let a = countingSource("a", log)
        let disposable = operatorRecord(a.signal |> take(1), log)
        a.emit(1)
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "completed", "a.dispose#1"])
    }

    func testSwitchToLatestDisposeCounts() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        o.logsEveryDisposeCall = true
        let a = countingSource("a", log)
        let b = countingSource("b", log)
        let disposable = operatorRecord(o.signal |> switchToLatest, log)
        o.emit(a.signal)
        o.emit(b.signal)
        o.complete()
        b.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "o.subscribe#1", "a.subscribe#1", "b.subscribe#1", "a.dispose#1",
            "o.dispose#1", "completed", "b.dispose#1", "b.dispose#1"
        ])
    }

    func testSwitchToLatestExplicitDisposalCounts() {
        let log = OperatorLog()
        let o = OperatorSource<Signal<Int, String>, String>("o", log)
        o.logsEveryDisposeCall = true
        let a = countingSource("a", log)
        let disposable = operatorRecord(o.signal |> switchToLatest, log)
        o.emit(a.signal)
        a.complete()
        disposable.dispose()
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "a.subscribe#1", "a.dispose#1", "o.dispose#1"])
    }

    func testCombineLatestDisposeCounts() {
        let log = OperatorLog()
        let a = countingSource("a", log)
        let b = countingSource("b", log)
        let disposable = operatorRecord(combineLatest(a.signal, b.signal), log)
        a.emit(1)
        a.complete()
        b.emit(2)
        b.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "b.subscribe#1", "a.dispose#1", "a.dispose#1",
            "next (1, 2)", "completed", "b.dispose#1", "b.dispose#1"
        ])
    }

    func testThenDisposeCounts() {
        let log = OperatorLog()
        let a = countingSource("a", log)
        let b = countingSource("b", log)
        let disposable = operatorRecord(a.signal |> then(b.signal), log)
        a.complete()
        b.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "a.dispose#1", "completed", "b.dispose#1", "b.dispose#1"])
    }

    func testCatchDisposeCounts() {
        let log = OperatorLog()
        let a = countingSource("a", log)
        let b = countingSource("b", log)
        let disposable = operatorRecord(a.signal |> `catch` { _ in b.signal }, log)
        a.fail("e")
        disposable.dispose()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "a.dispose#1", "b.dispose#1"])
    }

    func testRestartDisposeCounts() {
        let log = OperatorLog()
        let a = countingSource("a", log)
        let disposable = operatorRecord(a.signal |> restart, log)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.subscribe#2", "a.dispose#1", "a.dispose#1", "a.dispose#2"])
    }

    func testDeliverOnInlineCompletionDisposesUpstreamTwiceAndDeferredOnce() {
        let log = OperatorLog()
        let deliveryQueue = Queue(name: "operator.count.deliver")
        let a = countingSource("a", log)
        let b = countingSource("b", log)
        let first = operatorRecord(a.signal |> deliverOn(deliveryQueue), log)
        deliveryQueue.sync {
            a.complete()
        }
        first.dispose()
        let gate = operatorBlock(deliveryQueue)
        let second = operatorRecord(b.signal |> deliverOn(deliveryQueue), log)
        b.complete()
        gate.signal()
        operatorFlush(deliveryQueue)
        second.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "completed", "a.dispose#1", "a.dispose#1", "b.subscribe#1", "b.dispose#1", "completed"])
    }
}

final class OperatorOptionalValueTests: XCTestCase {
    func testCombineLatestTreatsNilValuesAsProducedValues() {
        let log = OperatorLog()
        let a = OperatorSource<Int?, String>("a", log)
        let b = OperatorSource<String?, String>("b", log)
        let disposable = operatorRecord(combineLatest(a.signal, b.signal), log)
        a.emit(nil)
        b.emit(nil)
        a.emit(1)
        b.emit("x")
        a.emit(nil)
        a.complete()
        b.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "b.subscribe#1",
            "next (nil, nil)", "next (Optional(1), nil)", "next (Optional(1), Optional(\"x\"))", "next (nil, Optional(\"x\"))",
            "a.dispose#1", "completed", "b.dispose#1"
        ])
    }

    func testCombineLatestWithNilInitialValuesEmitsImmediately() {
        let log = OperatorLog()
        let a = OperatorSource<Int?, String>("a", log)
        let b = OperatorSource<Int?, String>("b", log)
        let disposable = operatorRecord(combineLatest(a.signal, nil, b.signal, nil), log)
        b.emit(nil)
        a.emit(2)
        disposable.dispose()
        XCTAssertEqual(log.events, ["next (nil, nil)", "a.subscribe#1", "b.subscribe#1", "next (nil, nil)", "next (Optional(2), nil)", "a.dispose#1", "b.dispose#1"])
    }

    func testCombineLatestThreeArityWithOptionalAndAnyValues() {
        let log = OperatorLog()
        let signal = combineLatest(Signal<Int?, NoError>.single(nil), Signal<Any?, NoError>.single(nil), Signal<Any, NoError>.single(Optional<Int>.none as Any))
        let _ = signal.start(next: { value in
            log.add("next \(value.0 == nil) \(value.1 == nil) \(String(describing: value.2))")
        }, completed: {
            log.add("completed")
        })
        XCTAssertEqual(log.events, ["next true true nil", "completed"])
    }

    func testCombineLatestArrayTreatsNilValuesAsProducedValues() {
        let log = OperatorLog()
        let a = OperatorSource<Int?, String>("a", log)
        let b = OperatorSource<Int?, String>("b", log)
        let disposable = operatorRecord(combineLatest([a.signal, b.signal]), log)
        a.emit(nil)
        b.emit(nil)
        b.emit(nil)
        a.emit(3)
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "next [nil, nil]", "next [nil, nil]", "next [Optional(3), nil]", "a.dispose#1", "b.dispose#1"])
    }

    func testCombineLatestArrayOfDoubleOptionals() {
        let log = OperatorLog()
        let signal = combineLatest([Signal<Int??, NoError>.single(.some(nil)), .single(nil), .single(5)])
        let _ = signal.start(next: { values in
            log.add("next \(values.map { String(describing: $0) })")
        }, completed: {
            log.add("completed")
        })
        XCTAssertEqual(log.events, ["next [\"Optional(nil)\", \"nil\", \"Optional(Optional(5))\"]", "completed"])
    }

    func testTakeLastAndLastWithNilValues() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [Int?.some(1), nil], terminal: OperatorTerminal<String>.complete)
        let _ = (s.signal |> takeLast).start(next: { value in
            log.add("takeLast \(String(describing: value))")
        })
        let _ = (s.signal |> last).start(next: { value in
            log.add("last \(String(describing: value))")
        })
        XCTAssertEqual(log.events, ["s.subscribe#1", "takeLast nil", "s.dispose#1", "s.subscribe#2", "last Optional(nil)", "s.dispose#2"])
    }

    func testDistinctUntilChangedWithIsEqualOnOptionalValues() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [Int?.none, nil, 1, 1, nil], terminal: OperatorTerminal<String>.complete)
        let _ = (s.signal |> distinctUntilChanged(isEqual: { (lhs: Int?, rhs: Int?) in lhs == rhs })).start(next: { value in
            log.add("next \(String(describing: value))")
        })
        XCTAssertEqual(log.events, ["s.subscribe#1", "next nil", "next Optional(1)", "next nil", "s.dispose#1"])
    }
}
