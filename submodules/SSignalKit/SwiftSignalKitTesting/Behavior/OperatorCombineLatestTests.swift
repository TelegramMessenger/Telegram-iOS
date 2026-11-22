import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class OperatorCombineLatestTests: XCTestCase {
    func testTwoArityEmitsOnlyOnceEverySourceProducedAValue() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<String, String>("b", log)
        let disposable = operatorRecord(combineLatest(a.signal, b.signal), log)
        a.emit(1)
        a.emit(2)
        b.emit("x")
        a.emit(3)
        b.emit("y")
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "next (2, \"x\")", "next (3, \"x\")", "next (3, \"y\")", "a.dispose#1", "b.dispose#1"])
    }

    func testTwoArityCompletesOnlyWhenAllSourcesComplete() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let disposable = operatorRecord(combineLatest(a.signal, b.signal), log)
        a.emit(1)
        a.complete()
        b.emit(2)
        b.emit(3)
        b.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "a.dispose#1", "next (1, 2)", "next (1, 3)", "completed", "b.dispose#1"])
    }

    func testCompletionOfSourceWithoutValueStillWaitsForOthersToComplete() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        operatorRecord(combineLatest(a.signal, b.signal), log)
        a.complete()
        b.emit(1)
        b.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "a.dispose#1", "completed", "b.dispose#1"])
    }

    func testFirstErrorWinsAndDisposesAllSourcesInOrder() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let c = OperatorSource<Int, String>("c", log)
        operatorRecord(combineLatest(a.signal, b.signal, c.signal), log)
        a.emit(1)
        b.fail("b-error")
        c.fail("c-error")
        a.fail("a-error")
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "c.subscribe#1", "error b-error", "a.dispose#1", "b.dispose#1", "c.dispose#1"])
    }

    func testSynchronousFailuresStillSubscribeRemainingSourcesAndOnlyFirstErrorIsDelivered() {
        let log = OperatorLog()
        let s1 = operatorSyncSource("s1", log, values: [Int](), terminal: OperatorTerminal<String>.fail("first"))
        let s2 = operatorSyncSource("s2", log, values: [2], terminal: OperatorTerminal<String>.fail("second"))
        operatorRecord(combineLatest(s1.signal, s2.signal), log)
        XCTAssertEqual(log.events, ["s1.subscribe#1", "error first", "s1.dispose#1", "s2.subscribe#1", "s2.dispose#1"])
    }

    func testSynchronousSources() {
        let log = OperatorLog()
        let s1 = operatorSyncSource("s1", log, values: [1, 2], terminal: OperatorTerminal<String>.complete)
        let s2 = operatorSyncSource("s2", log, values: [10, 20], terminal: OperatorTerminal<String>.complete)
        operatorRecord(combineLatest(s1.signal, s2.signal), log)
        XCTAssertEqual(log.events, ["s1.subscribe#1", "s1.dispose#1", "s2.subscribe#1", "next (2, 10)", "next (2, 20)", "completed", "s2.dispose#1"])
    }

    func testSingleSignals() {
        let log = OperatorLog()
        operatorRecord(combineLatest(Signal<Int, NoError>.single(1), Signal<String, NoError>.single("a")), log)
        operatorRecord(combineLatest(Signal<Int, NoError>.single(1), Signal<Int, NoError>.complete()), log)
        XCTAssertEqual(log.events, ["next (1, \"a\")", "completed", "completed"])
    }

    func testDisposalDisposesEverySourceExactlyOnce() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let disposable = operatorRecord(combineLatest(a.signal, b.signal), log)
        a.emit(1)
        b.emit(2)
        disposable.dispose()
        disposable.dispose()
        a.emit(3)
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "next (1, 2)", "a.dispose#1", "b.dispose#1"])
    }

    func testDisposalAfterOneSourceCompletedDisposesRemainingSource() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let disposable = operatorRecord(combineLatest(a.signal, b.signal), log)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "b.subscribe#1", "a.dispose#1", "b.dispose#1"])
    }

    func testTwoArityWithInitialValuesEmitsImmediatelyBeforeSubscribing() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<String, String>("b", log)
        let disposable = operatorRecord(combineLatest(a.signal, 0, b.signal, "z"), log)
        a.emit(1)
        b.emit("y")
        a.complete()
        b.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["next (0, \"z\")", "a.subscribe#1", "b.subscribe#1", "next (1, \"z\")", "next (1, \"y\")", "a.dispose#1", "completed", "b.dispose#1"])
    }

    func testInitialValuesWithSynchronousSourcesEmitInitialThenEachUpdate() {
        let log = OperatorLog()
        operatorRecord(combineLatest(Signal<Int, String>.single(5), 0, Signal<Int, String>.single(6), 1), log)
        operatorRecord(combineLatest(Signal<Int, String>.fail("e"), 0, Signal<Int, String>.single(6), 1), log)
        XCTAssertEqual(log.events, ["next (0, 1)", "next (5, 1)", "next (5, 6)", "completed", "next (0, 1)", "error e"])
    }

    func testThreeArity() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Bool, String>("b", log)
        let c = OperatorSource<String, String>("c", log)
        let disposable = operatorRecord(combineLatest(a.signal, b.signal, c.signal), log)
        a.emit(1)
        b.emit(true)
        c.emit("c")
        b.emit(false)
        a.complete()
        b.complete()
        c.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "a.subscribe#1", "b.subscribe#1", "c.subscribe#1",
            "next (1, true, \"c\")", "next (1, false, \"c\")",
            "a.dispose#1", "b.dispose#1", "completed", "c.dispose#1"
        ])
    }

    func testFourArityWithSynchronousValues() {
        let log = OperatorLog()
        let signal = combineLatest(Signal<Int, NoError>.single(1), Signal<Int, NoError>.single(2), Signal<Int, NoError>.single(3), Signal<Int, NoError>.single(4))
        operatorRecord(signal, log)
        XCTAssertEqual(log.events, ["next (1, 2, 3, 4)", "completed"])
    }

    func testTwentySixArityWaitsForAllSourcesAndCombinesInOrder() {
        let log = OperatorLog()
        let s = (0 ..< 26).map { OperatorSource<Int, String>("s\($0)", log) }
        let signal = combineLatest(
            s[0].signal, s[1].signal, s[2].signal, s[3].signal, s[4].signal, s[5].signal, s[6].signal,
            s[7].signal, s[8].signal, s[9].signal, s[10].signal, s[11].signal, s[12].signal, s[13].signal,
            s[14].signal, s[15].signal, s[16].signal, s[17].signal, s[18].signal, s[19].signal, s[20].signal,
            s[21].signal, s[22].signal, s[23].signal, s[24].signal, s[25].signal
        )
        let disposable = operatorRecord(signal, log)
        XCTAssertEqual(log.events, (0 ..< 26).map { "s\($0).subscribe#1" })
        log.clear()
        for index in (1 ..< 26).reversed() {
            s[index].emit(index * 100)
        }
        XCTAssertEqual(log.events, [])
        s[0].emit(0)
        s[25].emit(1)
        var firstParts: [String] = []
        var secondParts: [String] = []
        for index in 0 ..< 26 {
            firstParts.append(String(index * 100))
            secondParts.append(index == 25 ? "1" : String(index * 100))
        }
        let first: String = firstParts.joined(separator: ", ")
        let second: String = secondParts.joined(separator: ", ")
        XCTAssertEqual(log.events, ["next (\(first))", "next (\(second))"])
        log.clear()
        for index in 0 ..< 25 {
            s[index].complete()
        }
        XCTAssertFalse(log.events.contains("completed"))
        log.clear()
        s[25].complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["completed", "s25.dispose#1"])
    }

    func testTwentySixArityErrorDisposesAllSourcesInOrder() {
        let log = OperatorLog()
        let s = (0 ..< 26).map { OperatorSource<Int, String>("s\($0)", log) }
        let signal = combineLatest(
            s[0].signal, s[1].signal, s[2].signal, s[3].signal, s[4].signal, s[5].signal, s[6].signal,
            s[7].signal, s[8].signal, s[9].signal, s[10].signal, s[11].signal, s[12].signal, s[13].signal,
            s[14].signal, s[15].signal, s[16].signal, s[17].signal, s[18].signal, s[19].signal, s[20].signal,
            s[21].signal, s[22].signal, s[23].signal, s[24].signal, s[25].signal
        )
        let disposable = operatorRecord(signal, log)
        s[3].complete()
        log.clear()
        s[13].fail("e13")
        disposable.dispose()
        var expected: [String] = ["error e13"]
        for index in 0 ..< 26 where index != 3 {
            expected.append("s\(index).dispose#1")
        }
        XCTAssertEqual(log.events, expected)
    }

    func testTwentySixArityExplicitDisposalDisposesAllSourcesInOrder() {
        let log = OperatorLog()
        let s = (0 ..< 26).map { OperatorSource<Int, String>("s\($0)", log) }
        let signal = combineLatest(
            s[0].signal, s[1].signal, s[2].signal, s[3].signal, s[4].signal, s[5].signal, s[6].signal,
            s[7].signal, s[8].signal, s[9].signal, s[10].signal, s[11].signal, s[12].signal, s[13].signal,
            s[14].signal, s[15].signal, s[16].signal, s[17].signal, s[18].signal, s[19].signal, s[20].signal,
            s[21].signal, s[22].signal, s[23].signal, s[24].signal, s[25].signal
        )
        let disposable = operatorRecord(signal, log)
        log.clear()
        disposable.dispose()
        disposable.dispose()
        XCTAssertEqual(log.events, (0 ..< 26).map { "s\($0).dispose#1" })
    }

    func testTwentySixArityWithMixedTypesAndSynchronousSignals() {
        let log = OperatorLog()
        let i: (Int) -> Signal<Int, NoError> = { Signal<Int, NoError>.single($0) }
        let v1: Signal<Int, NoError> = .single(1)
        let v2: Signal<String, NoError> = .single("b")
        let v3: Signal<Bool, NoError> = .single(true)
        let v4 = i(4), v5 = i(5), v6 = i(6), v7 = i(7), v8 = i(8), v9 = i(9), v10 = i(10)
        let v11 = i(11), v12 = i(12), v13 = i(13), v14 = i(14), v15 = i(15), v16 = i(16), v17 = i(17)
        let v18 = i(18), v19 = i(19), v20 = i(20), v21 = i(21), v22 = i(22), v23 = i(23), v24 = i(24), v25 = i(25)
        let v26: Signal<Double, NoError> = .single(26.5)
        let signal = combineLatest(v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18, v19, v20, v21, v22, v23, v24, v25, v26)
        let values = OperatorBox<String>()
        let _ = signal.start(next: { value in
            values.append("\(value.0) \(value.1) \(value.2) \(value.12) \(value.24) \(value.25)")
        }, completed: {
            log.add("completed")
        })
        XCTAssertEqual(values.values, ["1 b true 13 25 26.5"])
        XCTAssertEqual(log.events, ["completed"])
    }

    func testArrayVersionEmptyArrayEmitsEmptyArrayAndCompletes() {
        let log = OperatorLog()
        operatorRecord(combineLatest([Signal<Int, String>]()), log)
        operatorRecord(combineLatest(queue: Queue(name: "operator.combine.empty"), [Signal<Int, String>]()), log)
        XCTAssertEqual(log.events, ["next []", "completed", "next []", "completed"])
    }

    func testArrayVersionCombinesInOrder() {
        let log = OperatorLog()
        let s = (0 ..< 3).map { OperatorSource<Int, String>("s\($0)", log) }
        let disposable = operatorRecord(combineLatest(s.map { $0.signal }), log)
        s[2].emit(2)
        s[0].emit(0)
        s[1].emit(1)
        s[0].emit(5)
        s[1].complete()
        s[0].fail("e")
        s[2].emit(9)
        disposable.dispose()
        XCTAssertEqual(log.events, [
            "s0.subscribe#1", "s1.subscribe#1", "s2.subscribe#1",
            "next [0, 1, 2]", "next [5, 1, 2]",
            "s1.dispose#1", "error e", "s0.dispose#1", "s2.dispose#1"
        ])
    }

    func testArrayVersionSingleSignalAndSynchronousSignals() {
        let log = OperatorLog()
        operatorRecord(combineLatest([Signal<Int, String>.single(1)]), log)
        operatorRecord(combineLatest([Signal<Int, String>.single(1), .single(2), .single(3)]), log)
        operatorRecord(combineLatest([Signal<Int, String>.single(1), .complete()]), log)
        XCTAssertEqual(log.events, ["next [1]", "completed", "next [1, 2, 3]", "completed", "completed"])
    }

    func testQueueParameterDeliversCombinedValuesOnQueue() {
        let log = OperatorLog()
        let deliveryQueue = Queue(name: "operator.combine.queue")
        let a = OperatorSource<Int, String>("a", log)
        let b = OperatorSource<Int, String>("b", log)
        let onQueue = OperatorBox<Bool>()
        let done = expectation(description: "completed")
        let disposable = combineLatest(queue: deliveryQueue, a.signal, b.signal).start(next: { value in
            onQueue.append(deliveryQueue.isCurrent())
            log.add("next \(value)")
        }, completed: {
            onQueue.append(deliveryQueue.isCurrent())
            log.add("completed")
            done.fulfill()
        })
        a.emit(1)
        b.emit(2)
        a.emit(3)
        a.complete()
        b.complete()
        wait(for: [done], timeout: 5.0)
        operatorFlush(deliveryQueue)
        disposable.dispose()
        XCTAssertEqual(log.events.filter { !$0.contains("subscribe") && !$0.contains("dispose") }, ["next (1, 2)", "next (3, 2)", "completed"])
        XCTAssertEqual(onQueue.values, [true, true, true])
    }

    func testQueueParameterDefersDeliveryUntilQueueRuns() {
        let log = OperatorLog()
        let deliveryQueue = Queue(name: "operator.combine.deferred")
        let gate = operatorBlock(deliveryQueue)
        let disposable = operatorRecord(combineLatest(queue: deliveryQueue, Signal<Int, String>.single(1), Signal<Int, String>.single(2)), log)
        XCTAssertEqual(log.events, [])
        gate.signal()
        operatorFlush(deliveryQueue)
        disposable.dispose()
        XCTAssertEqual(log.events, ["next (1, 2)", "completed"])
    }

    func testQueueParameterWithInitialValuesEmitsInitialSynchronously() {
        let log = OperatorLog()
        let deliveryQueue = Queue(name: "operator.combine.initial")
        let gate = operatorBlock(deliveryQueue)
        let disposable = operatorRecord(combineLatest(queue: deliveryQueue, Signal<Int, String>.single(1), 0, Signal<Int, String>.never(), 7), log)
        XCTAssertEqual(log.events, ["next (0, 7)"])
        gate.signal()
        operatorFlush(deliveryQueue)
        disposable.dispose()
        XCTAssertEqual(log.events, ["next (0, 7)", "next (1, 7)"])
    }

    func testArrayVersionQueueParameter() {
        let log = OperatorLog()
        let deliveryQueue = Queue(name: "operator.combine.array")
        let onQueue = OperatorBox<Bool>()
        let done = expectation(description: "completed")
        let signal = combineLatest(queue: deliveryQueue, [Signal<Int, String>.single(1), .single(2)])
        let disposable = signal.start(next: { value in
            onQueue.append(deliveryQueue.isCurrent())
            log.add("next \(value)")
        }, completed: {
            log.add("completed")
            done.fulfill()
        })
        wait(for: [done], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(log.events, ["next [1, 2]", "completed"])
        XCTAssertEqual(onQueue.values, [true])
    }
}
