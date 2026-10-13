import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class OperatorConcurrencyTests: XCTestCase {
    func testTakeUnderConcurrentEmissionPassesExactlyCountValuesAndCompletesOnce() {
        for _ in 0 ..< 20 {
            let log = OperatorLog()
            let a = OperatorSource<Int, String>("a", log)
            let values = OperatorBox<Int>()
            let completions = OperatorCounter()
            let disposable = (a.signal |> take(10)).start(next: { value in
                values.append(value)
            }, completed: {
                completions.increment()
            })
            DispatchQueue.concurrentPerform(iterations: 8) { thread in
                for index in 0 ..< 20 {
                    a.emit(thread * 100 + index)
                }
            }
            disposable.dispose()
            XCTAssertLessThanOrEqual(values.values.count, 10)
            XCTAssertGreaterThanOrEqual(values.values.count, 1)
            XCTAssertEqual(Set(values.values).count, values.values.count)
            XCTAssertEqual(completions.value, 1)
            XCTAssertEqual(log.count(of: "a.dispose#1"), 1)
        }
    }

    func testCombineLatestUnderConcurrentEmissionEmitsOncePerValueAfterPriming() {
        for _ in 0 ..< 10 {
            let log = OperatorLog()
            let sources = (0 ..< 4).map { OperatorSource<Int, String>("s\($0)", log) }
            let emissions = OperatorCounter()
            let completions = OperatorCounter()
            let disposable = combineLatest(sources.map { $0.signal }).start(next: { values in
                XCTAssertEqual(values.count, 4)
                emissions.increment()
            }, completed: {
                completions.increment()
            })
            for source in sources {
                source.emit(-1)
            }
            XCTAssertEqual(emissions.value, 1)
            DispatchQueue.concurrentPerform(iterations: 4) { index in
                for value in 0 ..< 50 {
                    sources[index].emit(value)
                }
                sources[index].complete()
            }
            disposable.dispose()
            XCTAssertEqual(emissions.value, 1 + 4 * 50)
            XCTAssertEqual(completions.value, 1)
        }
    }

    func testCombineLatestTwoArityUnderConcurrentEmission() {
        let a = OperatorSource<Int, String>("a", OperatorLog())
        let b = OperatorSource<Int, String>("b", OperatorLog())
        let emissions = OperatorCounter()
        let lastSeen = OperatorBox<(Int, Int)>()
        let disposable = combineLatest(a.signal, b.signal).start(next: { value in
            lastSeen.append(value)
            emissions.increment()
        })
        a.emit(0)
        b.emit(0)
        DispatchQueue.concurrentPerform(iterations: 2) { index in
            for value in 1 ... 200 {
                if index == 0 {
                    a.emit(value)
                } else {
                    b.emit(value)
                }
            }
        }
        disposable.dispose()
        XCTAssertEqual(emissions.value, 401)
        XCTAssertTrue(lastSeen.values.contains(where: { $0.0 == 200 || $0.1 == 200 }))
    }

    func testQueueUnderConcurrentOuterEmissionRunsEveryInnerExactlyOnce() {
        for _ in 0 ..< 10 {
            let o = OperatorSource<Signal<Int, String>, String>("o", OperatorLog())
            let values = OperatorBox<Int>()
            let completions = OperatorCounter()
            let disposable = (o.signal |> queue).start(next: { value in
                values.append(value)
            }, completed: {
                completions.increment()
            })
            DispatchQueue.concurrentPerform(iterations: 4) { thread in
                for index in 0 ..< 50 {
                    o.emit(.single(thread * 1000 + index))
                }
            }
            o.complete()
            disposable.dispose()
            let expected = (0 ..< 4).flatMap { thread in (0 ..< 50).map { thread * 1000 + $0 } }
            XCTAssertEqual(values.values.sorted(), expected.sorted())
            XCTAssertEqual(completions.value, 1)
        }
    }

    func testQueueWithAsynchronousInnersRunsThemSequentiallyAcrossThreads() {
        let o = OperatorSource<Signal<Int, String>, String>("o", OperatorLog())
        let workQueue = Queue(name: "operator.concurrency.inner")
        let running = OperatorCounter()
        let overlaps = OperatorCounter()
        let values = OperatorBox<Int>()
        let done = expectation(description: "completed")
        let disposable = (o.signal |> queue).start(next: { value in
            values.append(value)
        }, completed: {
            done.fulfill()
        })
        let makeInner: (Int) -> Signal<Int, String> = { value in
            return Signal { subscriber in
                if running.increment() > 1 {
                    overlaps.increment()
                }
                workQueue.after(0.001) {
                    subscriber.putNext(value)
                    running.decrement()
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        }
        DispatchQueue.concurrentPerform(iterations: 4) { thread in
            for index in 0 ..< 10 {
                o.emit(makeInner(thread * 100 + index))
            }
        }
        o.complete()
        wait(for: [done], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(values.values.count, 40)
        XCTAssertEqual(overlaps.value, 0)
    }

    func testSwitchToLatestUnderConcurrentOuterEmissionDeliversOnlyFromActiveInnerAndCompletesOnce() {
        for _ in 0 ..< 10 {
            let o = OperatorSource<Signal<Int, String>, String>("o", OperatorLog())
            let completions = OperatorCounter()
            let values = OperatorCounter()
            let disposable = (o.signal |> switchToLatest).start(next: { _ in
                values.increment()
            }, completed: {
                completions.increment()
            })
            DispatchQueue.concurrentPerform(iterations: 4) { thread in
                for index in 0 ..< 50 {
                    o.emit(.single(thread * 1000 + index))
                }
            }
            o.complete()
            disposable.dispose()
            XCTAssertEqual(values.value, 200)
            XCTAssertEqual(completions.value, 1)
        }
    }

    func testDistinctUntilChangedSerialEmissionFromBackgroundQueue() {
        let a = OperatorSource<Int, String>("a", OperatorLog())
        let values = OperatorBox<Int>()
        let disposable = (a.signal |> distinctUntilChanged).start(next: { value in
            values.append(value)
        })
        let emitQueue = Queue(name: "operator.concurrency.distinct")
        emitQueue.sync {
            for value in [1, 1, 2, 2, 3, 3, 3, 1] {
                a.emit(value)
            }
        }
        disposable.dispose()
        XCTAssertEqual(values.values, [1, 2, 3, 1])
    }
}
