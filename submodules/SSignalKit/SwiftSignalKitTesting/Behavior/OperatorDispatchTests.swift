import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

private let operatorConcurrentPool = ThreadPool(threadCount: 2, threadPriority: 0.5)
private let operatorSerialPool = ThreadPool(threadCount: 1, threadPriority: 0.5)

private func operatorBlockPool(_ pool: ThreadPool) -> DispatchSemaphore {
    let gate = DispatchSemaphore(value: 0)
    let entered = DispatchSemaphore(value: 0)
    pool.addTask(ThreadPoolTask { _ in
        entered.signal()
        gate.wait()
    })
    precondition(entered.wait(timeout: .now() + 10.0) == .success, "thread pool did not start the blocking task")
    return gate
}

final class OperatorDeliverOnQueueTests: XCTestCase {
    func testPreservesOrderAndDeliversOnQueue() {
        let deliveryQueue = Queue(name: "operator.deliver.order")
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let values = OperatorBox<Int>()
        let onQueue = OperatorBox<Bool>()
        let done = expectation(description: "completed")
        let disposable = (a.signal |> deliverOn(deliveryQueue)).start(next: { value in
            onQueue.append(deliveryQueue.isCurrent())
            values.append(value)
        }, completed: {
            onQueue.append(deliveryQueue.isCurrent())
            done.fulfill()
        })
        for value in 0 ..< 200 {
            a.emit(value)
        }
        a.complete()
        wait(for: [done], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(values.values, Array(0 ..< 200))
        XCTAssertEqual(onQueue.values, Array(repeating: true, count: 201))
    }

    func testDeliversInlineWhenAlreadyOnQueue() {
        let deliveryQueue = Queue(name: "operator.deliver.inline")
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> deliverOn(deliveryQueue), log)
        deliveryQueue.sync {
            a.emit(1)
            log.add("emitted")
            a.complete()
            log.add("completed upstream")
        }
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "emitted", "completed", "a.dispose#1", "completed upstream"])
    }

    func testDefersDeliveryWhenNotOnQueueAndDisposesUpstreamImmediatelyOnCompletion() {
        let deliveryQueue = Queue(name: "operator.deliver.defer")
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let gate = operatorBlock(deliveryQueue)
        let disposable = operatorRecord(a.signal |> deliverOn(deliveryQueue), log)
        a.emit(1)
        log.add("emitted")
        a.complete()
        XCTAssertEqual(log.events, ["a.subscribe#1", "emitted", "a.dispose#1"])
        gate.signal()
        operatorFlush(deliveryQueue)
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "emitted", "a.dispose#1", "next 1", "completed"])
    }

    func testDeliversErrorOnQueue() {
        let deliveryQueue = Queue(name: "operator.deliver.error")
        let log = OperatorLog()
        let onQueue = OperatorBox<Bool>()
        let done = expectation(description: "error")
        let s = operatorSyncSource("s", log, values: [1], terminal: OperatorTerminal<String>.fail("e"))
        let gate = operatorBlock(deliveryQueue)
        let disposable = (s.signal |> deliverOn(deliveryQueue)).start(next: { value in
            onQueue.append(deliveryQueue.isCurrent())
            log.add("next \(value)")
        }, error: { error in
            onQueue.append(deliveryQueue.isCurrent())
            log.add("error \(error)")
            done.fulfill()
        })
        gate.signal()
        wait(for: [done], timeout: 5.0)
        operatorFlush(deliveryQueue)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "s.dispose#1", "next 1", "error e"])
        XCTAssertEqual(onQueue.values, [true, true])
    }

    func testDisposalBeforeDeliveryDropsQueuedEvents() {
        let deliveryQueue = Queue(name: "operator.deliver.dispose")
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let gate = operatorBlock(deliveryQueue)
        let disposable = operatorRecord(a.signal |> deliverOn(deliveryQueue), log)
        a.emit(1)
        a.emit(2)
        disposable.dispose()
        gate.signal()
        operatorFlush(deliveryQueue)
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.dispose#1"])
    }

    func testQueueWrappingExistingDispatchQueueIsNeverTreatedAsCurrent() {
        let dispatchQueue = DispatchQueue(label: "operator.deliver.wrapped")
        let wrapped = Queue(queue: dispatchQueue)
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> deliverOn(wrapped), log)
        dispatchQueue.sync {
            a.emit(1)
            log.add("emitted")
        }
        dispatchQueue.sync {
        }
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "emitted", "next 1", "a.dispose#1"])
    }

    func testRunOnQueueWrappingExistingDispatchQueueAlwaysDispatches() {
        let dispatchQueue = DispatchQueue(label: "operator.runon.wrapped")
        let wrapped = Queue(queue: dispatchQueue)
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        var disposable: Disposable?
        dispatchQueue.sync {
            disposable = operatorRecord(a.signal |> runOn(wrapped), log)
            log.add("returned")
        }
        dispatchQueue.sync {
        }
        disposable?.dispose()
        XCTAssertEqual(log.events, ["returned", "a.subscribe#1", "a.dispose#1"])
    }

    func testRunOnMainQueueFromBackgroundSubscribesOnMainThread() {
        let log = OperatorLog()
        let onMain = OperatorBox<Bool>()
        let subscribed = expectation(description: "subscribed")
        let a = OperatorSource<Int, String>("a", log, onSubscribe: { _, _ in
            onMain.append(Thread.isMainThread)
            subscribed.fulfill()
        })
        let holder = OperatorBox<Disposable>()
        let background = Queue(name: "operator.runon.main")
        let finished = DispatchSemaphore(value: 0)
        background.async {
            holder.append(operatorRecord(a.signal |> runOn(Queue.mainQueue()), log))
            log.add("returned")
            finished.signal()
        }
        XCTAssertEqual(finished.wait(timeout: .now() + 10.0), .success)
        XCTAssertEqual(log.events, ["returned"])
        wait(for: [subscribed], timeout: 5.0)
        a.emit(1)
        holder.values[0].dispose()
        XCTAssertEqual(log.events, ["returned", "a.subscribe#1", "next 1", "a.dispose#1"])
        XCTAssertEqual(onMain.values, [true])
    }

    func testSynchronousSourceIsDeliveredLater() {
        let deliveryQueue = Queue(name: "operator.deliver.sync")
        let log = OperatorLog()
        let gate = operatorBlock(deliveryQueue)
        let disposable = operatorRecord(Signal<Int, String>.single(1) |> deliverOn(deliveryQueue), log)
        XCTAssertEqual(log.events, [])
        gate.signal()
        operatorFlush(deliveryQueue)
        disposable.dispose()
        XCTAssertEqual(log.events, ["next 1", "completed"])
    }
}

final class OperatorDeliverOnMainQueueTests: XCTestCase {
    func testDeliversOnMainThreadInOrderFromBackground() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let values = OperatorBox<Int>()
        let onMain = OperatorBox<Bool>()
        let done = expectation(description: "completed")
        let disposable = (a.signal |> deliverOnMainQueue).start(next: { value in
            onMain.append(Thread.isMainThread)
            values.append(value)
        }, completed: {
            onMain.append(Thread.isMainThread)
            done.fulfill()
        })
        let emitQueue = Queue(name: "operator.main.emitter")
        emitQueue.async {
            for value in 0 ..< 50 {
                a.emit(value)
            }
            a.complete()
        }
        wait(for: [done], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(values.values, Array(0 ..< 50))
        XCTAssertEqual(onMain.values, Array(repeating: true, count: 51))
    }

    func testDeliversInlineWhenAlreadyOnMainThread() {
        XCTAssertTrue(Thread.isMainThread)
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> deliverOnMainQueue, log)
        a.emit(1)
        log.add("emitted")
        a.fail("e")
        disposable.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "emitted", "error e", "a.dispose#1"])
        XCTAssertTrue(Queue.mainQueue().isCurrent())
    }

    func testSynchronousSourceFromBackgroundIsDeliveredOnMain() {
        let log = OperatorLog()
        let onMain = OperatorBox<Bool>()
        let done = expectation(description: "completed")
        let emitQueue = Queue(name: "operator.main.sync")
        emitQueue.async {
            let _ = (Signal<Int, String>.single(3) |> deliverOnMainQueue).start(next: { value in
                onMain.append(Thread.isMainThread)
                log.add("next \(value)")
            }, completed: {
                onMain.append(Thread.isMainThread)
                log.add("completed")
                done.fulfill()
            })
        }
        wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, ["next 3", "completed"])
        XCTAssertEqual(onMain.values, [true, true])
    }
}

final class OperatorDeliverOnThreadPoolTests: XCTestCase {
    func testPreservesOrderAndDeliversOnPoolThread() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let values = OperatorBox<Int>()
        let inPool = OperatorBox<Bool>()
        let done = expectation(description: "completed")
        let disposable = (a.signal |> deliverOn(operatorConcurrentPool)).start(next: { value in
            inPool.append(operatorConcurrentPool.isCurrentThreadInPool())
            values.append(value)
        }, completed: {
            inPool.append(operatorConcurrentPool.isCurrentThreadInPool())
            done.fulfill()
        })
        for value in 0 ..< 200 {
            a.emit(value)
        }
        a.complete()
        wait(for: [done], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(values.values, Array(0 ..< 200))
        XCTAssertEqual(inPool.values, Array(repeating: true, count: 201))
        XCTAssertFalse(operatorConcurrentPool.isCurrentThreadInPool())
    }

    func testDeliversErrorOnPoolThread() {
        let log = OperatorLog()
        let done = expectation(description: "error")
        let inPool = OperatorBox<Bool>()
        let disposable = (Signal<Int, String>.fail("e") |> deliverOn(operatorConcurrentPool)).start(error: { error in
            inPool.append(operatorConcurrentPool.isCurrentThreadInPool())
            log.add("error \(error)")
            done.fulfill()
        })
        wait(for: [done], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(log.events, ["error e"])
        XCTAssertEqual(inPool.values, [true])
    }

    func testDisposalBeforeExecutionDropsQueuedEvent() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let gate = operatorBlockPool(operatorSerialPool)
        let disposable = operatorRecord(a.signal |> deliverOn(operatorSerialPool), log)
        a.emit(1)
        disposable.dispose()
        let drained = expectation(description: "drained")
        operatorSerialPool.addTask(ThreadPoolTask { _ in
            drained.fulfill()
        })
        gate.signal()
        wait(for: [drained], timeout: 5.0)
        XCTAssertEqual(log.events, ["a.subscribe#1", "a.dispose#1"])
    }
}

final class OperatorRunOnQueueTests: XCTestCase {
    func testSubscribesInlineWhenAlreadyOnQueue() {
        let runQueue = Queue(name: "operator.runon.inline")
        let log = OperatorLog()
        let onQueue = OperatorBox<Bool>()
        let a = OperatorSource<Int, String>("a", log, onSubscribe: { _, _ in
            onQueue.append(runQueue.isCurrent())
        })
        var disposable: Disposable?
        runQueue.sync {
            disposable = operatorRecord(a.signal |> runOn(runQueue), log)
            log.add("returned")
        }
        a.emit(1)
        disposable?.dispose()
        XCTAssertEqual(log.events, ["a.subscribe#1", "returned", "next 1", "a.dispose#1"])
        XCTAssertEqual(onQueue.values, [true])
    }

    func testSubscribesAsynchronouslyOnQueueWhenNotCurrent() {
        let runQueue = Queue(name: "operator.runon.async")
        let log = OperatorLog()
        let onQueue = OperatorBox<Bool>()
        let a = OperatorSource<Int, String>("a", log, onSubscribe: { _, _ in
            onQueue.append(runQueue.isCurrent())
        })
        let gate = operatorBlock(runQueue)
        let disposable = operatorRecord(a.signal |> runOn(runQueue), log)
        log.add("returned")
        XCTAssertEqual(log.events, ["returned"])
        gate.signal()
        operatorFlush(runQueue)
        a.emit(1)
        a.complete()
        disposable.dispose()
        XCTAssertEqual(log.events, ["returned", "a.subscribe#1", "next 1", "completed", "a.dispose#1"])
        XCTAssertEqual(onQueue.values, [true])
    }

    func testDisposingBeforeQueueRunsPreventsSubscription() {
        let runQueue = Queue(name: "operator.runon.cancel")
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let gate = operatorBlock(runQueue)
        let disposable = operatorRecord(a.signal |> runOn(runQueue), log)
        disposable.dispose()
        gate.signal()
        operatorFlush(runQueue)
        XCTAssertEqual(log.events, [])
        XCTAssertEqual(a.subscriptionCount, 0)
    }

    func testDisposingAfterSubscriptionDisposesSource() {
        let runQueue = Queue(name: "operator.runon.live")
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let disposable = operatorRecord(a.signal |> runOn(runQueue), log)
        operatorFlush(runQueue)
        a.emit(1)
        disposable.dispose()
        a.emit(2)
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "a.dispose#1"])
    }

    func testSynchronousSourceEventsArriveOnQueue() {
        let runQueue = Queue(name: "operator.runon.sync")
        let log = OperatorLog()
        let onQueue = OperatorBox<Bool>()
        let done = expectation(description: "completed")
        let s = operatorSyncSource("s", log, values: [1, 2], terminal: OperatorTerminal<String>.complete)
        let disposable = (s.signal |> runOn(runQueue)).start(next: { value in
            onQueue.append(runQueue.isCurrent())
            log.add("next \(value)")
        }, completed: {
            onQueue.append(runQueue.isCurrent())
            log.add("completed")
            done.fulfill()
        })
        wait(for: [done], timeout: 5.0)
        operatorFlush(runQueue)
        disposable.dispose()
        XCTAssertEqual(log.events, ["s.subscribe#1", "next 1", "next 2", "completed", "s.dispose#1"])
        XCTAssertEqual(onQueue.values, [true, true, true])
    }
}

final class OperatorRunOnThreadPoolTests: XCTestCase {
    func testSubscribesOnPoolThread() {
        let log = OperatorLog()
        let inPool = OperatorBox<Bool>()
        let a = OperatorSource<Int, String>("a", log, onSubscribe: { _, _ in
            inPool.append(operatorSerialPool.isCurrentThreadInPool())
        })
        let gate = operatorBlockPool(operatorSerialPool)
        let disposable = operatorRecord(a.signal |> runOn(operatorSerialPool), log)
        XCTAssertEqual(log.events, [])
        let drained = expectation(description: "drained")
        operatorSerialPool.addTask(ThreadPoolTask { _ in
            drained.fulfill()
        })
        gate.signal()
        wait(for: [drained], timeout: 5.0)
        a.emit(1)
        disposable.dispose()
        a.emit(2)
        XCTAssertEqual(log.events, ["a.subscribe#1", "next 1", "a.dispose#1"])
        XCTAssertEqual(inPool.values, [true])
    }

    func testSynchronousSourceEventsArriveOnPoolThread() {
        let log = OperatorLog()
        let inPool = OperatorBox<Bool>()
        let done = expectation(description: "completed")
        let disposable = (Signal<Int, String>.single(4) |> runOn(operatorConcurrentPool)).start(next: { value in
            inPool.append(operatorConcurrentPool.isCurrentThreadInPool())
            log.add("next \(value)")
        }, completed: {
            inPool.append(operatorConcurrentPool.isCurrentThreadInPool())
            log.add("completed")
            done.fulfill()
        })
        wait(for: [done], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(log.events, ["next 4", "completed"])
        XCTAssertEqual(inPool.values, [true, true])
    }

    func testDisposingBeforeTaskExecutesPreventsSubscription() {
        let log = OperatorLog()
        let a = OperatorSource<Int, String>("a", log)
        let gate = operatorBlockPool(operatorSerialPool)
        let disposable = operatorRecord(a.signal |> runOn(operatorSerialPool), log)
        disposable.dispose()
        let drained = expectation(description: "drained")
        operatorSerialPool.addTask(ThreadPoolTask { _ in
            drained.fulfill()
        })
        gate.signal()
        wait(for: [drained], timeout: 5.0)
        XCTAssertEqual(log.events, [])
        XCTAssertEqual(a.subscriptionCount, 0)
    }
}
