import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class OperatorReduceLeftTests: XCTestCase {
    func testReduceLeftEmitsAccumulatedValueOnCompletion() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> reduceLeft(value: 100, f: { $0 + $1 }), log)
        a.emit(1)
        a.emit(2)
        a.emit(3)
        XCTAssertEqual(log.events, ["a.subscribe#1"])
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 106", "completed", "a.dispose#1"])
    }

    func testReduceLeftWithoutValuesEmitsInitialValue() {
        let log = OperatorLog()
        operatorRecord(Signal<Int, String>.complete() |> reduceLeft(value: 7, f: { $0 + $1 }), log)
        XCTAssertEqual(log.events, ["next 7", "completed"])
    }

    func testReduceLeftErrorDropsAccumulatedValue() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> reduceLeft(value: 0, f: { $0 + $1 }), log)
        a.emit(1)
        a.fail("e")
        let disposable = operatorRecord(b.signal |> reduceLeft(value: 0, f: { $0 + $1 }), log)
        b.emit(1)
        disposable.dispose()
        b.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "error e", "a.dispose#1", "b.subscribe#1", "b.dispose#1"])
    }

    func testReduceLeftAccumulatorIsPerSubscription() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2, 3], terminal: OperatorTerminal<String>.complete)
        let signal = s.signal |> reduceLeft(value: 10, f: { $0 * $1 })
        operatorRecord(signal, log)
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 60", "completed", "s.dispose#1", "s.subscribe#2", "next 60", "completed", "s.dispose#2"])
    }

    func testReduceLeftWithEmitCanEmitIntermediateValues() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal = a.signal |> reduceLeft(value: 0, f: { (current: Int, next: Int, emit: (Int) -> Void) -> Int in
            log.add("reduce \(current) \(next)")
            if next % 2 == 0 {
                emit(current)
            }
            return current + next
        })
        let disposable = operatorRecord(signal, log)
        a.emit(1)
        a.emit(2)
        a.emit(3)
        a.emit(4)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "reduce 0 1", "reduce 1 2", "next 1", "reduce 3 3", "reduce 6 4", "next 6",
            "next 10", "completed", "a.dispose#1"
        ])
    }

    func testReduceLeftWithEmitErrorAndDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let reducer = { (current: Int, next: Int, emit: (Int) -> Void) -> Int in
            emit(next)
            return current + next
        }
        operatorRecord(a.signal |> reduceLeft(value: 0, f: reducer), log)
        a.emit(5)
        a.fail("e")
        let disposable = operatorRecord(b.signal |> reduceLeft(value: 0, f: reducer), log)
        b.emit(6)
        disposable.dispose()
        b.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 5", "error e", "a.dispose#1", "b.subscribe#1", "next 6", "b.dispose#1"])
    }

    func testReduceLeftWithEmitOnSynchronousSource() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2], terminal: OperatorTerminal<String>.complete)
        operatorRecord(s.signal |> reduceLeft(value: 0, f: { (current: Int, next: Int, emit: (Int) -> Void) -> Int in
            emit(-next)
            return current + next
        }), log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next -1", "next -2", "next 3", "completed", "s.dispose#1"])
    }

    func testReduceLeftPassthroughRunsGeneratorsSequentiallyWithUpdatedValue() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        let generated = OperatorBox<OperatorSource<(Int, Passthrough<Int>), String>>()
        let signal = o.signal |> reduceLeft(0, generator: { (current: Int, next: Int) -> Signal<(Int, Passthrough<Int>), String> in
            log.add("generator \(current) \(next)")
            let source = OperatorSource<(Int, Passthrough<Int>), String>("g\(next)", log)
            generated.append(source)
            return source.signal
        })
        let disposable = operatorRecord(signal, log)
        o.emit(1)
        o.emit(2)
        o.emit(3)
        generated.values[0].emit((10, .Some(100)))
        generated.values[0].emit((11, .None))
        generated.values[0].complete()
        generated.values[1].emit((20, .Some(200)))
        o.complete()
        generated.values[1].complete()
        generated.values[2].complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "o.subscribe#1", "generator 0 1", "g1.subscribe#1",
            "next 100",
            "generator 11 2", "g2.subscribe#1", "g1.dispose#1",
            "next 200",
            "o.dispose#1",
            "generator 20 3", "g3.subscribe#1", "g2.dispose#1",
            "next 20", "completed", "g3.dispose#1"
        ])
    }

    func testReduceLeftPassthroughWithSynchronousGenerators() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2, 3], terminal: OperatorTerminal<String>.complete)
        let signal = s.signal |> reduceLeft(0, generator: { (current: Int, next: Int) -> Signal<(Int, Passthrough<Int>), String> in
            let sum = current + next
            return .single((sum, next == 2 ? .None : .Some(sum * 10)))
        })
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 10", "next 60", "next 6", "completed", "s.dispose#1"])
    }

    func testReduceLeftPassthroughCompletionWhileIdleEmitsCurrentValue() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        operatorRecord(o.signal |> reduceLeft(5, generator: { (current: Int, next: Int) -> Signal<(Int, Passthrough<Int>), String> in
            return .single((current + next, .None))
        }), log)
        o.complete()
        let p = OperatorSource<Int, String>("p", log)
        operatorRecord(p.signal |> reduceLeft(5, generator: { (current: Int, next: Int) -> Signal<(Int, Passthrough<Int>), String> in
            return .single((current + next, .None))
        }), log)
        p.emit(1)
        p.emit(2)
        p.complete()
        XCTAssertEqual(log.events, ["o.subscribe#1", "next 5", "completed", "o.dispose#1", "p.subscribe#1", "next 8", "completed", "p.dispose#1"])
    }

    func testReduceLeftPassthroughGeneratorErrorPropagatesAndSkipsQueued() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        let g = OperatorSource<(Int, Passthrough<Int>), String>("g", log)
        let calls = OperatorCounter()
        operatorRecord(o.signal |> reduceLeft(0, generator: { (_: Int, _: Int) -> Signal<(Int, Passthrough<Int>), String> in
            calls.increment()
            return g.signal
        }), log)
        o.emit(1)
        o.emit(2)
        g.fail("gen")
        XCTAssertEqual(log.events, ["o.subscribe#1", "g.subscribe#1", "error gen", "g.dispose#1", "o.dispose#1"])
        XCTAssertEqual(calls.value, 1)
    }

    func testReduceLeftPassthroughOuterErrorAndDisposal() {
        let log = OperatorLog()
        let o = OperatorSource<Int, String>("o", log)
        let g = OperatorSource<(Int, Passthrough<Int>), String>("g", log)
        operatorRecord(o.signal |> reduceLeft(0, generator: { (_: Int, _: Int) in g.signal }), log)
        o.emit(1)
        o.fail("outer")
        let p = OperatorSource<Int, String>("p", log)
        let disposable = operatorRecord(p.signal |> reduceLeft(0, generator: { (_: Int, _: Int) in g.signal }), log)
        p.emit(1)
        disposable.dispose()
        XCTAssertEqual(log.events, ["o.subscribe#1", "g.subscribe#1", "error outer", "g.dispose#1", "o.dispose#1", "p.subscribe#1", "g.subscribe#2", "g.dispose#2", "p.dispose#1"])
    }
}

final class OperatorMaterializeTests: XCTestCase {
    private func describe(_ event: SignalEvent<Int, String>) -> String {
        switch event {
        case let .Next(value):
            return "Next(\(value))"
        case let .Error(error):
            return "Error(\(error))"
        case .Completion:
            return "Completion"
        }
    }

    private func recordEvents(_ signal: Signal<SignalEvent<Int, String>, NoError>, _ log: OperatorLog) -> Disposable {
        return signal.start(next: { event in
            log.add("next \(self.describe(event))")
        }, completed: {
            log.add("completed")
        })
    }

    func testDematerializeConvertsCompletionIntoEventThenCompletes() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = recordEvents(a.signal |> dematerialize, log)
        a.emit(1)
        a.emit(2)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next Next(1)", "next Next(2)", "next Completion", "completed", "a.dispose#1"])
    }

    func testDematerializeConvertsErrorIntoEventThenCompletes() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let _ = recordEvents(a.signal |> dematerialize, log)
        a.emit(1)
        a.fail("e")
        XCTAssertEqual(log.events, ["a.subscribe#1", "next Next(1)", "next Error(e)", "completed", "a.dispose#1"])
    }

    func testDematerializeDisposalAndSynchronousSource() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = recordEvents(a.signal |> dematerialize, log)
        disposable.dispose()
        let _ = recordEvents(Signal<Int, String>.single(3) |> dematerialize, log)
        let _ = recordEvents(Signal<Int, String>.fail("x") |> dematerialize, log)
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.dispose#1", "next Next(3)", "next Completion", "completed", "next Error(x)", "completed"])
    }

    func testMaterializeConvertsEventsBackIntoSignalTermination() {
        let log = OperatorLog()
        let a = OperatorSource<SignalEvent<Int, String>, NoError>("a", log)
        let disposable = operatorRecord(a.signal |> materialize, log)
        a.emit(.Next(1))
        a.emit(.Next(2))
        a.emit(.Error("e"))
        a.emit(.Next(3))
        disposable.dispose()
        let b = OperatorSource<SignalEvent<Int, String>, NoError>("b", log)
        operatorRecord(b.signal |> materialize, log)
        b.emit(.Next(4))
        b.emit(.Completion)
        let c = OperatorSource<SignalEvent<Int, String>, NoError>("c", log)
        operatorRecord(c.signal |> materialize, log)
        c.emit(.Next(5))
        c.complete()
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "next 1", "next 2", "error e", "a.dispose#1",
            "b.subscribe#1", "next 4", "completed", "b.dispose#1",
            "c.subscribe#1", "next 5", "completed", "c.dispose#1"
        ])
    }

    func testMaterializeDematerializeRoundTrip() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2], terminal: OperatorTerminal<String>.fail("boom"))
        operatorRecord(s.signal |> dematerialize |> materialize, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "next 2", "error boom", "s.dispose#1"])
    }
}

final class OperatorFeedbackLoopTests: XCTestCase {
    func testLoopsWithInitialStateUntilOnceReturnsNilWithoutEmittingValues() {
        let log = OperatorLog()
        let sources = [OperatorSource<Int, String>("l1", log), OperatorSource<Int, String>("l2", log)]
        let calls = OperatorCounter()
        let reduceCalls = OperatorCounter()
        let signal: Signal<Int, String> = feedbackLoop(once: { (state: SignalFeedbackLoopState<Int>) -> Signal<Int, String>? in
            let call = calls.increment()
            switch state {
            case .initial:
                log.add("once \(call) initial")
            case let .loop(value):
                log.add("once \(call) loop \(value)")
            }
            if call <= sources.count {
                return sources[call - 1].signal
            }
            return nil
        }, reduce: { lhs, rhs in
            reduceCalls.increment()
            return lhs + rhs
        })
        let disposable = operatorRecord(signal, log)
        sources[0].emit(1)
        sources[0].emit(2)
        sources[0].complete()
        sources[1].emit(3)
        sources[1].complete()
        disposable.dispose()
        XCTAssertEqual(reduceCalls.value, 0)
        XCTAssertEqual(log.events, [
            "once 1 initial", "l1.subscribe#1",
            "once 2 initial", "l2.subscribe#1", "l1.dispose#1",
            "once 3 initial", "completed", "l2.dispose#1"
        ])
    }

    func testOnceReturningNilImmediatelyCompletes() {
        let log = OperatorLog()
        let signal: Signal<String, String> = feedbackLoop(once: { (_: SignalFeedbackLoopState<Int>) -> Signal<Int, String>? in
            log.add("once")
            return nil
        }, reduce: { $0 + $1 })
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["once", "completed"])
    }

    func testErrorPropagatesAndStopsLooping() {
        let log = OperatorLog()
        let source = OperatorSource<Int, String>("l", log)
        let calls = OperatorCounter()
        let signal: Signal<Int, String> = feedbackLoop(once: { (_: SignalFeedbackLoopState<Int>) -> Signal<Int, String>? in
            calls.increment()
            return source.signal
        }, reduce: { $0 + $1 })
        operatorRecord(signal, log)
        source.emit(1)
        source.fail("e")
        XCTAssertEqual(log.events, ["l.subscribe#1", "error e", "l.dispose#1"])
        XCTAssertEqual(calls.value, 1)
    }

    func testDisposalDisposesCurrentIterationAndStopsLooping() {
        let log = OperatorLog()
        let source = OperatorSource<Int, String>("l", log)
        let calls = OperatorCounter()
        let signal: Signal<Int, String> = feedbackLoop(once: { (_: SignalFeedbackLoopState<Int>) -> Signal<Int, String>? in
            calls.increment()
            return source.signal
        }, reduce: { $0 + $1 })
        let disposable = operatorRecord(signal, log)
        disposable.dispose()
        source.complete()
        XCTAssertEqual(log.events, ["l.subscribe#1", "l.dispose#1"])
        XCTAssertEqual(calls.value, 1)
    }

    func testSynchronouslyCompletingIterations() {
        let log = OperatorLog()
        let calls = OperatorCounter()
        let signal: Signal<Int, String> = feedbackLoop(once: { (_: SignalFeedbackLoopState<Int>) -> Signal<Int, String>? in
            let call = calls.increment()
            log.add("once \(call)")
            if call <= 3 {
                return .single(call)
            }
            return nil
        }, reduce: { $0 + $1 })
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["once 1", "once 2", "once 3", "once 4", "completed"])
    }
}
