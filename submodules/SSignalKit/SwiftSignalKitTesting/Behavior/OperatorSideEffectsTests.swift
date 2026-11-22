import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

private final class OperatorStateObject {
    let id: Int

    init(id: Int) {
        self.id = id
    }
}

final class OperatorSideEffectsTests: XCTestCase {
    func testBeforeNextRunsBeforeDownstreamNext() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal = a.signal |> beforeNext { (value: Int) -> Int in
            log.add("before \(value)")
            return value * 100
        }
        let disposable = operatorRecord(signal, log)
        a.emit(1)
        a.emit(2)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "before 1", "next 1", "before 2", "next 2", "completed", "a.dispose#1"])
    }

    func testBeforeNextNotCalledForTerminationAndDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> beforeNext { log.add("before \($0)") }, log)
        a.fail("e")
        let disposable = operatorRecord(b.signal |> beforeNext { log.add("before \($0)") }, log)
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "error e", "a.dispose#1", "b.subscribe#1", "b.dispose#1"])
    }

    func testAfterNextRunsAfterDownstreamNext() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal = a.signal |> afterNext { (value: Int) -> Void in
            log.add("after \(value)")
        }
        operatorRecord(signal, log)
        a.emit(1)
        a.emit(2)
        a.fail("e")
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "after 1", "next 2", "after 2", "error e", "a.dispose#1"])
    }

    func testAfterNextRunsEvenWhenDownstreamTerminatedByThatValue() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal = a.signal |> afterNext { (value: Int) -> Void in
            log.add("after \(value)")
        } |> take(1)
        operatorRecord(signal, log)
        a.emit(1)
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "completed", "a.dispose#1", "after 1"])
    }

    func testAfterNextOnSynchronousSource() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1, 2], terminal: OperatorTerminal<String>.complete)
        operatorRecord(s.signal |> afterNext { log.add("after \($0)") }, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "after 1", "next 2", "after 2", "completed", "s.dispose#1"])
    }

    func testBeforeStartedRunsBeforeUpstreamSubscriptionPerSubscriber() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal = a.signal |> beforeStarted {
            log.add("started")
        }
        XCTAssertEqual(log.events, [])
        let first = operatorRecord(signal, log)
        let second = operatorRecord(signal, log)
        a.emit(1)
        first.dispose()
        second.dispose()
        XCTAssertEqual(log.events, ["started", "a.subscribe#1", "started", "a.subscribe#2", "next 1", "next 1", "a.dispose#1", "a.dispose#2"])
    }

    func testBeforeStartedWithSynchronousSource() {
        let log = OperatorLog()
        operatorRecord(Signal<Int, String>.single(1) |> beforeStarted { log.add("started") }, log)
        operatorRecord(Signal<Int, String>.fail("e") |> beforeStarted { log.add("started") }, log)
        XCTAssertEqual(log.events, ["started", "next 1", "completed", "started", "error e"])
    }

    func testBeforeCompletedRunsBeforeDownstreamCompletion() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        operatorRecord(a.signal |> beforeCompleted { log.add("beforeCompleted") }, log)
        a.emit(1)
        a.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "beforeCompleted", "completed", "a.dispose#1"])
    }

    func testBeforeCompletedNotCalledOnErrorOrDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> beforeCompleted { log.add("beforeCompleted") }, log)
        a.fail("e")
        let disposable = operatorRecord(b.signal |> beforeCompleted { log.add("beforeCompleted") }, log)
        disposable.dispose()
        b.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "error e", "a.dispose#1", "b.subscribe#1", "b.dispose#1"])
    }

    func testAfterCompletedRunsAfterDownstreamCompletionAndUpstreamDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        operatorRecord(a.signal |> afterCompleted { log.add("afterCompleted") }, log)
        a.emit(1)
        a.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "completed", "a.dispose#1", "afterCompleted"])
    }

    func testAfterCompletedWithSynchronousSourceRunsBeforeSourceDisposal() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1], terminal: OperatorTerminal<String>.complete)
        operatorRecord(s.signal |> afterCompleted { log.add("afterCompleted") }, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "completed", "afterCompleted", "s.dispose#1"])
    }

    func testAfterCompletedNotCalledOnErrorOrDisposal() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(a.signal |> afterCompleted { log.add("afterCompleted") }, log)
        a.fail("e")
        let disposable = operatorRecord(b.signal |> afterCompleted { log.add("afterCompleted") }, log)
        disposable.dispose()
        b.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "error e", "a.dispose#1", "b.subscribe#1", "b.dispose#1"])
    }

    func testAfterDisposedRunsOnDisposalAfterUpstreamDisposalExactlyOnce() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> afterDisposed { log.add("afterDisposed") }, log)
        a.emit(1)
        disposable.dispose()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "a.dispose#1", "afterDisposed"])
    }

    func testAfterDisposedRunsOnCompletionAndOnError() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let first = operatorRecord(a.signal |> afterDisposed { log.add("afterDisposed a") }, log)
        a.complete()
        first.dispose()
        let second = operatorRecord(b.signal |> afterDisposed { log.add("afterDisposed b") }, log)
        b.fail("e")
        second.dispose()
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "completed", "a.dispose#1", "afterDisposed a",
            "b.subscribe#1", "error e", "b.dispose#1", "afterDisposed b"
        ])
    }

    func testAfterDisposedWithSynchronousSource() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1], terminal: OperatorTerminal<String>.complete)
        let disposable = operatorRecord(s.signal |> afterDisposed { log.add("afterDisposed") }, log)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "completed", "s.dispose#1", "afterDisposed"])
    }

    func testWithStateCallbacksOrderOnCompletion() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let created = OperatorCounter()
        let signal = withState(a.signal, { () -> OperatorStateObject in
            let state = OperatorStateObject(id: created.increment())
            log.add("initialState \(state.id)")
            return state
        }, next: { value, state in
            log.add("stateNext \(value) \(state.id)")
        }, error: { error, state in
            log.add("stateError \(error) \(state.id)")
        }, completed: { state in
            log.add("stateCompleted \(state.id)")
        }, disposed: { state in
            log.add("stateDisposed \(state.id)")
        })
        XCTAssertEqual(created.value, 0)
        let disposable = operatorRecord(signal, log)
        a.emit(5)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "initialState 1", "a.subscribe#1", "stateNext 5 1", "next 5",
            "stateCompleted 1", "completed", "a.dispose#1", "stateDisposed 1"
        ])
    }

    func testWithStateCallbacksOrderOnErrorAndPerSubscriptionState() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let created = OperatorCounter()
        let signal = withState(a.signal, { OperatorStateObject(id: created.increment()) }, next: { value, state in
            log.add("stateNext \(value) \(state.id)")
        }, error: { error, state in
            log.add("stateError \(error) \(state.id)")
        }, completed: { state in
            log.add("stateCompleted \(state.id)")
        }, disposed: { state in
            log.add("stateDisposed \(state.id)")
        })
        let first = operatorRecord(signal, log)
        let second = operatorRecord(signal, log)
        a.fail("e")
        first.dispose()
        second.dispose()
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "a.subscribe#2",
            "stateError e 1", "error e", "a.dispose#1", "stateDisposed 1",
            "stateError e 2", "error e", "a.dispose#2", "stateDisposed 2"
        ])
    }

    func testWithStateDisposedCalledAfterUpstreamDisposalOnExplicitDisposeOnce() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let signal = withState(a.signal, { OperatorStateObject(id: 7) }, disposed: { state in
            log.add("stateDisposed \(state.id)")
        })
        let disposable = operatorRecord(signal, log)
        a.emit(1)
        disposable.dispose()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "a.dispose#1", "stateDisposed 7"])
    }

    func testWithStateOnSynchronousSource() {
        let log = OperatorLog()
        let s = operatorSyncSource("s", log, values: [1], terminal: OperatorTerminal<String>.complete)
        let signal = withState(s.signal, { OperatorStateObject(id: 3) }, next: { value, state in
            log.add("stateNext \(value) \(state.id)")
        }, completed: { state in
            log.add("stateCompleted \(state.id)")
        }, disposed: { state in
            log.add("stateDisposed \(state.id)")
        })
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["s.subscribe#1", "stateNext 1 3", "next 1", "stateCompleted 3", "completed", "s.dispose#1", "stateDisposed 3"])
    }
}
