import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class OperatorTakeTests: XCTestCase {
    func testTakeCompletesRightAfterNthValueAndDisposesUpstream() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> take(2), log)
        a.emit(1)
        a.emit(2)
        a.emit(3)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "next 2", "completed", "a.dispose#1"])
    }

    func testTakeForwardsEarlyCompletionAndError() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> take(3), log)
        a.emit(1)
        a.complete()
        operatorRecord(b.signal |> take(3), log)
        b.emit(1)
        b.fail("e")
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "completed", "a.dispose#1", "b.subscribe#1", "next 1", "error e", "b.dispose#1"])
    }

    func testTakeZeroNeverCompletesOnValuesOnlyOnUpstreamCompletion() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> take(0), log)
        a.emit(1)
        a.emit(2)
        XCTAssertEqual(log.events, ["a.subscribe#1"])
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "completed", "a.dispose#1"])
    }

    func testTakeZeroOnSingleCompletesWithoutValue() {
        let log = OperatorLog()
        operatorRecord(Signal<Int, String>.single(1) |> take(0), log)
        let disposable = operatorRecord(Signal<Int, String>.never() |> take(0), log)
        disposable.dispose()
        XCTAssertEqual(log.events, ["completed"])
    }

    func testTakeOnSynchronousSourceWithoutCompletionDisposesSourceAfterGeneratorReturns() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2, 3, 4], terminal: OperatorTerminal<String>.none)
        let disposable = operatorRecord(s.signal |> take(2), log)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "next 2", "completed", "s.dispose#1"])
    }

    func testTakeOnSynchronousSourceIgnoresLaterErrorAfterCompleting() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2], terminal: OperatorTerminal<String>.fail("late"))
        operatorRecord(s.signal |> take(1), log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "completed", "s.dispose#1"])
    }

    func testTakeDisposalBeforeCountReached() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> take(5), log)
        a.emit(1)
        disposable.dispose()
        a.emit(2)
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "a.dispose#1"])
    }

    func testTakeCounterIsPerSubscription() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal = a.signal |> take(1)
        operatorRecord(signal, log)
        operatorRecord(signal, log)
        a.emit(9)
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.subscribe#2", "next 9", "completed", "a.dispose#1", "next 9", "completed", "a.dispose#2"])
    }

    func testTakeUntilPassthroughAndCompleteActions() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal = a.signal |> take(until: { (value: Int) -> SignalTakeAction in
            return SignalTakeAction(passthrough: value % 2 == 1, complete: value >= 5)
        })
        let disposable = operatorRecord(signal, log)
        for value in 1 ... 7 {
            a.emit(value)
        }
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "next 3", "next 5", "completed", "a.dispose#1"])
    }

    func testTakeUntilCompleteWithoutPassthrough() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal = a.signal |> take(until: { (value: Int) -> SignalTakeAction in
            return SignalTakeAction(passthrough: value < 3, complete: value == 3)
        })
        operatorRecord(signal, log)
        a.emit(1)
        a.emit(3)
        a.emit(2)
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "completed", "a.dispose#1"])
    }

    func testTakeUntilForwardsUpstreamTerminationAndDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let c = OperatorSource<Int, String>("c", log)
        let never = { (_: Int) in SignalTakeAction(passthrough: true, complete: false) }
        operatorRecord(a.signal |> take(until: never), log)
        a.emit(1)
        a.complete()
        operatorRecord(b.signal |> take(until: never), log)
        b.fail("e")
        let third = operatorRecord(c.signal |> take(until: never), log)
        third.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "completed", "a.dispose#1", "b.subscribe#1", "error e", "b.dispose#1", "c.subscribe#1", "c.dispose#1"])
    }

    func testTakeUntilOnSynchronousSource() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2, 3], terminal: OperatorTerminal<String>.none)
        let evaluated = OperatorBox<Int>()
        let signal = s.signal |> take(until: { (value: Int) -> SignalTakeAction in
            evaluated.append(value)
            return SignalTakeAction(passthrough: true, complete: value == 2)
        })
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "next 2", "completed", "s.dispose#1"])
        XCTAssertEqual(evaluated.values, [1, 2, 3])
    }

    func testTakeLastEmitsLastValueOnCompletion() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> takeLast, log)
        a.emit(1)
        a.emit(2)
        a.emit(3)
        XCTAssertEqual(log.events, ["a.subscribe#1"])
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 3", "completed", "a.dispose#1"])
    }

    func testTakeLastWithoutValuesOnlyCompletes() {
        let log = OperatorLog()
        operatorRecord(Signal<Int, String>.complete() |> takeLast, log)
        XCTAssertEqual(log.events, ["completed"])
    }

    func testTakeLastErrorDropsValues() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2], terminal: OperatorTerminal<String>.fail("e"))
        operatorRecord(s.signal |> takeLast, log)
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> takeLast, log)
        a.emit(5)
        disposable.dispose()
        a.complete()
        XCTAssertEqual(log.events, ["s.subscribe#1", "error e", "s.dispose#1", "a.subscribe#1", "a.dispose#1"])
    }

    func testTakeLastOnSynchronousSource() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [7, 8, 9], terminal: OperatorTerminal<String>.complete)
        operatorRecord(s.signal |> takeLast, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 9", "completed", "s.dispose#1"])
    }

    func testLastEmitsOptionalLastValueOnCompletion() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> last, log)
        a.emit(1)
        a.emit(2)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next Optional(2)", "completed", "a.dispose#1"])
    }

    func testLastEmitsNilWhenNoValues() {
        let log = OperatorLog()
        operatorRecord(Signal<Int, String>.complete() |> last, log)
        XCTAssertEqual(log.events, ["next nil", "completed"])
    }

    func testLastForwardsErrorWithoutValueAndDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> last, log)
        a.emit(1)
        a.fail("e")
        let disposable = operatorRecord(b.signal |> last, log)
        b.emit(1)
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "error e", "a.dispose#1", "b.subscribe#1", "b.dispose#1"])
    }
}
