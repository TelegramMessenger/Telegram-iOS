import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class OperatorMappingTests: XCTestCase {
    func testMapTransformsValuesAndForwardsCompletionThenDisposesUpstream() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> map { $0 * 10 }, log)
        a.emit(1)
        a.emit(2)
        a.complete()
        a.emit(3)
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 10", "next 20", "completed", "a.dispose#1"])
    }

    func testMapForwardsErrorThenDisposesUpstream() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> map { $0 + 1 }, log)
        a.emit(1)
        a.fail("boom")
        a.emit(2)
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 2", "error boom", "a.dispose#1"])
    }

    func testMapDisposalDisposesUpstreamOnceAndStopsEvents() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> map { $0 }, log)
        a.emit(1)
        disposable.dispose()
        disposable.dispose()
        a.emit(2)
        a.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "a.dispose#1"])
    }

    func testMapOnSynchronousSourceDisposesSourceAfterDownstreamCompletion() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2, 3], terminal: OperatorTerminal<String>.complete)
        let disposable = operatorRecord(s.signal |> map { "v\($0)" }, log)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "next v1", "next v2", "next v3", "completed", "s.dispose#1"])
    }

    func testMapOnSingleCompleteAndFail() {
        let log = OperatorLog()
        operatorRecord(Signal<Int, String>.single(4) |> map { $0 * 2 }, log)
        operatorRecord(Signal<Int, String>.complete() |> map { $0 * 2 }, log)
        operatorRecord(Signal<Int, String>.fail("f") |> map { $0 * 2 }, log)
        operatorRecord(Signal<Int, String>.never() |> map { $0 * 2 }, log)
        XCTAssertEqual(log.events, ["next 8", "completed", "completed", "error f"])
    }

    func testMapIsEvaluatedPerSubscription() {
        let log = OperatorLog()
        let calls = OperatorCounter()
        let signal = Signal<Int, NoError>.single(1) |> map { value -> Int in
            calls.increment()
            return value
        }
        operatorRecord(signal, log)
        operatorRecord(signal, log)
        XCTAssertEqual(calls.value, 2)
        XCTAssertEqual(log.events, ["next 1", "completed", "next 1", "completed"])
    }

    func testFilterDropsRejectedValues() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> filter { $0 % 2 == 0 }, log)
        for value in 1 ... 6 {
            a.emit(value)
        }
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 2", "next 4", "next 6", "completed", "a.dispose#1"])
    }

    func testFilterForwardsErrorAndDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let first = operatorRecord(a.signal |> filter { _ in false }, log)
        a.emit(1)
        a.fail("e")
        let second = operatorRecord(b.signal |> filter { _ in true }, log)
        second.dispose()
        first.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "error e", "a.dispose#1", "b.subscribe#1", "b.dispose#1"])
    }

    func testFilterOnSynchronousSource() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [5, 6, 7], terminal: OperatorTerminal<String>.fail("x"))
        operatorRecord(s.signal |> filter { $0 != 6 }, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 5", "next 7", "error x", "s.dispose#1"])
    }

    func testFlatMapMapsSomeAndPassesNil() {
        let log = OperatorLog()
        let a = OperatorSource<Int?, String>("a", log)
        let disposable = (a.signal |> flatMap { (value: Int) -> String in "x\(value)" }).start(next: { value in
            log.add("next \(value ?? "nil")")
        }, error: { error in
            log.add("error \(error)")
        }, completed: {
            log.add("completed")
        })
        a.emit(1)
        a.emit(nil)
        a.emit(3)
        a.fail("e")
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next x1", "next nil", "next x3", "error e", "a.dispose#1"])
    }

    func testFlatMapCompletionAndDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int?, String>("a", log)
        let b = OperatorSource<Int?, String>("b", log)
        let first = (a.signal |> flatMap { $0 * 2 }).start(next: { log.add("next \(String(describing: $0))") }, completed: { log.add("completed") })
        a.emit(2)
        a.complete()
        let second = (b.signal |> flatMap { $0 * 2 }).start()
        second.dispose()
        first.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next Optional(4)", "completed", "a.dispose#1", "b.subscribe#1", "b.dispose#1"])
    }

    func testMapErrorTransformsErrorOnly() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> mapError { (error: String) -> Int in error.count }, log)
        a.emit(7)
        a.fail("four")
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 7", "error 4", "a.dispose#1"])
    }

    func testMapErrorForwardsCompletionAndDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> mapError { _ in 0 }, log)
        a.emit(1)
        a.complete()
        let second = operatorRecord(b.signal |> mapError { _ in 0 }, log)
        second.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "completed", "a.dispose#1", "b.subscribe#1", "b.dispose#1"])
    }

    func testMapErrorOnSynchronousFail() {
        let log = OperatorLog()
        operatorRecord(Signal<Int, String>.fail("abc") |> mapError { "mapped-\($0)" }, log)
        XCTAssertEqual(log.events, ["error mapped-abc"])
    }

    func testCastErrorForwardsValuesAndCompletion() {
        let log = OperatorLog()
        let a = OperatorSource<Int, NoError>("a", log)
        let signal: Signal<Int, String> = a.signal |> castError(String.self)
        let disposable = operatorRecord(signal, log)
        a.emit(1)
        a.emit(2)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "next 2", "completed", "a.dispose#1"])
    }

    func testCastErrorDisposalAndSynchronousSource() {
        let log = OperatorLog()
        let a = OperatorSource<Int, NoError>("a", log)
        let disposable = operatorRecord(a.signal |> castError(String.self), log)
        disposable.dispose()
        operatorRecord(Signal<Int, NoError>.single(9) |> castError(Int.self), log)
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.dispose#1", "next 9", "completed"])
    }

    func testDistinctUntilChangedEquatableSuppressesConsecutiveDuplicates() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> distinctUntilChanged, log)
        for value in [1, 1, 2, 2, 2, 1, 3, 3, 1] {
            a.emit(value)
        }
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "next 2", "next 1", "next 3", "next 1", "completed", "a.dispose#1"])
    }

    func testDistinctUntilChangedEquatableStateIsPerSubscription() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [4, 4, 5], terminal: OperatorTerminal<String>.complete)
        let signal = s.signal |> distinctUntilChanged
        operatorRecord(signal, log)
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, [
            "s.subscribe#1", "next 4", "next 5", "completed", "s.dispose#1",
            "s.subscribe#2", "next 4", "next 5", "completed", "s.dispose#2"
        ])
    }

    func testDistinctUntilChangedEquatableForwardsErrorAndDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> distinctUntilChanged, log)
        a.emit(1)
        a.emit(1)
        a.fail("e")
        let second = operatorRecord(b.signal |> distinctUntilChanged, log)
        b.emit(2)
        second.dispose()
        b.emit(3)
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "error e", "a.dispose#1", "b.subscribe#1", "next 2", "b.dispose#1"])
    }

    func testDistinctUntilChangedOptionalEquatableSuppressesRepeatedNil() {
        let log = OperatorLog()
        let a = OperatorSource<Int?, String>("a", log)
        let disposable = (a.signal |> distinctUntilChanged).start(next: { value in
            log.add("next \(String(describing: value))")
        })
        a.emit(nil)
        a.emit(nil)
        a.emit(1)
        a.emit(1)
        a.emit(nil)
        a.emit(nil)
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next nil", "next Optional(1)", "next nil", "a.dispose#1"])
    }

    func testDistinctUntilChangedWithIsEqualUsesPredicateAgainstLastEmitted() {
        let log = OperatorLog()
        let comparisons = OperatorBox<String>()
        let a = OperatorSource<Int, String>("a", log)
        let signal = a.signal |> distinctUntilChanged(isEqual: { (lhs: Int, rhs: Int) -> Bool in
            comparisons.append("\(lhs)~\(rhs)")
            return abs(lhs - rhs) < 2
        })
        let disposable = operatorRecord(signal, log)
        for value in [10, 11, 12, 13, 20, 19] {
            a.emit(value)
        }
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 10", "next 12", "next 20", "completed", "a.dispose#1"])
        XCTAssertEqual(comparisons.values, ["10~11", "10~12", "12~13", "12~20", "20~19"])
    }

    func testDistinctUntilChangedWithIsEqualForwardsErrorAndSynchronousSource() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 1, 2], terminal: OperatorTerminal<String>.fail("x"))
        operatorRecord(s.signal |> distinctUntilChanged(isEqual: { (lhs: Int, rhs: Int) in lhs == rhs }), log)
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> distinctUntilChanged(isEqual: { (lhs: Int, rhs: Int) in lhs == rhs }), log)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "next 2", "error x", "s.dispose#1", "a.subscribe#1", "a.dispose#1"])
    }

    func testIgnoreValuesForwardsOnlyTermination() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let c = OperatorSource<Int, String>("c", log)
        let nextCalls = OperatorCounter()
        let record: (Signal<Never, String>) -> Disposable = { signal in
            return signal.start(next: { _ in
                nextCalls.increment()
            }, error: { error in
                log.add("error \(error)")
            }, completed: {
                log.add("completed")
            })
        }
        let first = record(a.signal |> ignoreValues)
        a.emit(1)
        a.emit(2)
        a.complete()
        let second = record(b.signal |> ignoreValues)
        b.emit(3)
        b.fail("e")
        let third = record(c.signal |> ignoreValues)
        third.dispose()
        first.dispose()
        second.dispose()
        XCTAssertEqual(nextCalls.value, 0)
        XCTAssertEqual(log.events, ["a.subscribe#1", "completed", "a.dispose#1", "b.subscribe#1", "error e", "b.dispose#1", "c.subscribe#1", "c.dispose#1"])
    }

    func testIgnoreValuesOnSynchronousSource() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2], terminal: OperatorTerminal<String>.complete)
        let _ = (s.signal |> ignoreValues).start(error: { _ in
            log.add("error")
        }, completed: {
            log.add("completed")
        })
        XCTAssertEqual(log.events, ["s.subscribe#1", "completed", "s.dispose#1"])
    }

    func testFreeSingleFailCompleteAndNever() {
        let log = OperatorLog()
        operatorRecord(single(5, String.self), log)
        operatorRecord(fail(Int.self, "bad"), log)
        operatorRecord(complete(Int.self, String.self), log)
        let disposable = operatorRecord(never(Int.self, String.self), log)
        disposable.dispose()
        XCTAssertEqual(log.events, ["next 5", "completed", "error bad", "completed"])
    }

    func testStaticNeverEmitsNothing() {
        let log = OperatorLog()
        let disposable = operatorRecord(Signal<Int, String>.never(), log)
        disposable.dispose()
        XCTAssertEqual(log.events, [])
    }
}
