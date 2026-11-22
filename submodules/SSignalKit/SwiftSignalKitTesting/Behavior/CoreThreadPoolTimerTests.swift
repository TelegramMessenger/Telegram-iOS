import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
fileprivate typealias CoreSignalKitTimer = SwiftSignalKitLegacy.Timer
#else
@testable import SwiftSignalKit2
fileprivate typealias CoreSignalKitTimer = SwiftSignalKit2.Timer
#endif

final class CoreThreadPoolTests: XCTestCase {
    private static let pool = ThreadPool(threadCount: 4, threadPriority: 0.5)

    func testTasksOnOneThreadPoolQueueExecuteSeriallyInOrder() {
        let queue = CoreThreadPoolTests.pool.nextQueue()
        let log = CoreEventLog()
        let inFlight = CoreCounter()
        let overlaps = CoreCounter()
        let done = self.expectation(description: "all tasks")
        let count = 60
        for i in 0 ..< count {
            queue.addTask(ThreadPoolTask { _ in
                if inFlight.increment() > 1 {
                    overlaps.increment()
                }
                if i % 10 == 0 {
                    usleep(1000)
                }
                log.append("\(i)")
                inFlight.decrement()
                if i == count - 1 {
                    done.fulfill()
                }
            })
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, (0 ..< count).map { "\($0)" })
        XCTAssertEqual(overlaps.value, 0)
    }

    func testTasksOnDifferentQueuesCanRunConcurrently() {
        let first = CoreThreadPoolTests.pool.nextQueue()
        let second = CoreThreadPoolTests.pool.nextQueue()
        let firstStarted = DispatchSemaphore(value: 0)
        let secondStarted = DispatchSemaphore(value: 0)
        let done = self.expectation(description: "both")
        done.expectedFulfillmentCount = 2
        let observed = CoreEventLog()
        first.addTask(ThreadPoolTask { _ in
            firstStarted.signal()
            let result = secondStarted.wait(timeout: .now() + 3.0)
            observed.append("first saw second: \(result == .success)")
            done.fulfill()
        })
        second.addTask(ThreadPoolTask { _ in
            secondStarted.signal()
            let result = firstStarted.wait(timeout: .now() + 3.0)
            observed.append("second saw first: \(result == .success)")
            done.fulfill()
        })
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(Set(observed.events), Set(["first saw second: true", "second saw first: true"]))
    }

    func testCancelledTaskIsSkippedWhenCancelledBeforeExecution() {
        let queue = CoreThreadPoolTests.pool.nextQueue()
        let log = CoreEventLog()
        let gate = DispatchSemaphore(value: 0)
        let done = self.expectation(description: "third")
        queue.addTask(ThreadPoolTask { _ in
            _ = gate.wait(timeout: .now() + 5.0)
            log.append("first")
        })
        let cancelled = ThreadPoolTask { _ in
            log.append("cancelled")
        }
        queue.addTask(cancelled)
        cancelled.cancel()
        queue.addTask(ThreadPoolTask { _ in
            log.append("third")
            done.fulfill()
        })
        gate.signal()
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, ["first", "third"])
    }

    func testCancelDuringExecutionIsVisibleThroughState() {
        let started = DispatchSemaphore(value: 0)
        let cancelledSignal = DispatchSemaphore(value: 0)
        let done = self.expectation(description: "task")
        let observed = CoreEventLog()
        let task = ThreadPoolTask { state in
            observed.append("before \(state.cancelled.with { $0 })")
            started.signal()
            _ = cancelledSignal.wait(timeout: .now() + 5.0)
            observed.append("after \(state.cancelled.with { $0 })")
            done.fulfill()
        }
        CoreThreadPoolTests.pool.addTask(task)
        XCTAssertEqual(started.wait(timeout: .now() + 5.0), .success)
        task.cancel()
        cancelledSignal.signal()
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(observed.events, ["before false", "after true"])
    }

    func testIsCurrentThreadInPool() {
        let pool = CoreThreadPoolTests.pool
        XCTAssertFalse(pool.isCurrentThreadInPool())
        let done = self.expectation(description: "task")
        var inside: Bool?
        pool.addTask(ThreadPoolTask { _ in
            inside = pool.isCurrentThreadInPool()
            done.fulfill()
        })
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(inside, true)
        let otherDone = self.expectation(description: "dispatch")
        var onDispatch: Bool?
        DispatchQueue.global().async {
            onDispatch = pool.isCurrentThreadInPool()
            otherDone.fulfill()
        }
        self.wait(for: [otherDone], timeout: 5.0)
        XCTAssertEqual(onDispatch, false)
    }

    func testThreadPoolTaskExecuteRunsSynchronouslyUnlessCancelled() {
        let log = CoreEventLog()
        let task = ThreadPoolTask { state in
            log.append("run cancelled=\(state.cancelled.with { $0 })")
        }
        task.execute()
        task.execute()
        task.cancel()
        task.execute()
        XCTAssertEqual(log.events, ["run cancelled=false", "run cancelled=false"])
    }

    func testThreadPoolTaskCancelFromInsideActionIsObserved() {
        let log = CoreEventLog()
        var taskRef: ThreadPoolTask?
        taskRef = ThreadPoolTask { state in
            log.append("before \(state.cancelled.with { $0 })")
            taskRef?.cancel()
            log.append("after \(state.cancelled.with { $0 })")
        }
        taskRef?.execute()
        taskRef?.execute()
        XCTAssertEqual(log.events, ["before false", "after true"])
        taskRef = nil
    }

    func testThreadPoolQueueEqualityIsIdentity() {
        let a = CoreThreadPoolTests.pool.nextQueue()
        let b = CoreThreadPoolTests.pool.nextQueue()
        XCTAssertTrue(a == a)
        XCTAssertFalse(a == b)
        XCTAssertTrue(ThreadPoolQueue(threadPool: CoreThreadPoolTests.pool) != a)
    }

    func testThreadPoolAddTaskRunsOnPoolThread() {
        let done = self.expectation(description: "task")
        done.expectedFulfillmentCount = 10
        let inPool = CoreCounter()
        for _ in 0 ..< 10 {
            CoreThreadPoolTests.pool.addTask(ThreadPoolTask { _ in
                if CoreThreadPoolTests.pool.isCurrentThreadInPool() {
                    inPool.increment()
                }
                done.fulfill()
            })
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(inPool.value, 10)
    }

    func testTaskAddedFromInsideRunningTaskOnSameQueueRunsAfterIt() {
        let queue = CoreThreadPoolTests.pool.nextQueue()
        let log = CoreEventLog()
        let done = self.expectation(description: "nested")
        queue.addTask(ThreadPoolTask { _ in
            queue.addTask(ThreadPoolTask { _ in
                log.append("nested")
                done.fulfill()
            })
            usleep(2000)
            log.append("outer end")
        })
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, ["outer end", "nested"])
    }
}

final class CoreTimerTests: XCTestCase {
    func testOneShotTimerFiresOnceOnItsQueue() {
        let queue = Queue(name: "CoreTimerTests.oneShot")
        let fired = CoreCounter()
        let onQueue = CoreFlag()
        let firstFire = self.expectation(description: "fired")
        let timer = CoreSignalKitTimer(timeout: 0.02, repeat: false, completion: {
            onQueue.set(queue.isCurrent())
            if fired.increment() == 1 {
                firstFire.fulfill()
            }
        }, queue: queue)
        timer.start()
        self.wait(for: [firstFire], timeout: 5.0)
        let settle = self.expectation(description: "settle")
        queue.after(0.1) {
            settle.fulfill()
        }
        self.wait(for: [settle], timeout: 5.0)
        XCTAssertEqual(fired.value, 1)
        XCTAssertEqual(onQueue.value, true)
        withExtendedLifetime(timer) {}
    }

    func testOneShotTimerDoesNotFireBeforeTimeout() {
        let queue = Queue(name: "CoreTimerTests.delay")
        let start = DispatchTime.now()
        var elapsed: Double = 0.0
        let fired = self.expectation(description: "fired")
        let timer = CoreSignalKitTimer(timeout: 0.05, repeat: false, completion: {
            elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0
            fired.fulfill()
        }, queue: queue)
        timer.start()
        self.wait(for: [fired], timeout: 5.0)
        XCTAssertGreaterThanOrEqual(elapsed, 0.049)
        withExtendedLifetime(timer) {}
    }

    func testRepeatingTimerFiresUntilInvalidated() {
        let queue = Queue(name: "CoreTimerTests.repeat")
        let fired = CoreCounter()
        let threeFires = self.expectation(description: "three fires")
        threeFires.expectedFulfillmentCount = 3
        let timer = CoreSignalKitTimer(timeout: 0.01, repeat: true, completion: { timer in
            let count = fired.increment()
            if count <= 3 {
                threeFires.fulfill()
            }
            if count == 3 {
                timer.invalidate()
            }
        }, queue: queue)
        timer.start()
        self.wait(for: [threeFires], timeout: 5.0)
        let settle = self.expectation(description: "settle")
        queue.after(0.08) {
            settle.fulfill()
        }
        self.wait(for: [settle], timeout: 5.0)
        XCTAssertEqual(fired.value, 3)
        withExtendedLifetime(timer) {}
    }

    func testInvalidateBeforeFirePreventsFiring() {
        let queue = Queue(name: "CoreTimerTests.invalidate")
        let fired = CoreCounter()
        let timer = CoreSignalKitTimer(timeout: 0.03, repeat: false, completion: {
            fired.increment()
        }, queue: queue)
        timer.start()
        timer.invalidate()
        timer.invalidate()
        let settle = self.expectation(description: "settle")
        queue.after(0.12) {
            settle.fulfill()
        }
        self.wait(for: [settle], timeout: 5.0)
        XCTAssertEqual(fired.value, 0)
        withExtendedLifetime(timer) {}
    }

    func testInvalidateRepeatingTimerFromOutsideStopsIt() {
        let queue = Queue(name: "CoreTimerTests.invalidateRepeat")
        let fired = CoreCounter()
        let firstFire = self.expectation(description: "first")
        let timer = CoreSignalKitTimer(timeout: 0.01, repeat: true, completion: {
            if fired.increment() == 1 {
                firstFire.fulfill()
            }
        }, queue: queue)
        timer.start()
        self.wait(for: [firstFire], timeout: 5.0)
        queue.sync {
            timer.invalidate()
        }
        let countAtInvalidate = fired.value
        let settle = self.expectation(description: "settle")
        queue.after(0.08) {
            settle.fulfill()
        }
        self.wait(for: [settle], timeout: 5.0)
        XCTAssertEqual(fired.value, countAtInvalidate)
        withExtendedLifetime(timer) {}
    }

    func testInvalidateWithoutStartIsNoop() {
        let timer = CoreSignalKitTimer(timeout: 0.01, repeat: false, completion: {
        }, queue: Queue.mainQueue())
        timer.invalidate()
    }

    func testDeinitInvalidatesTimer() {
        let queue = Queue(name: "CoreTimerTests.deinit")
        let fired = CoreCounter()
        weak var weakTimer: CoreSignalKitTimer?
        do {
            let timer = CoreSignalKitTimer(timeout: 0.03, repeat: true, completion: {
                fired.increment()
            }, queue: queue)
            weakTimer = timer
            timer.start()
        }
        XCTAssertNil(weakTimer)
        let settle = self.expectation(description: "settle")
        queue.after(0.12) {
            settle.fulfill()
        }
        self.wait(for: [settle], timeout: 5.0)
        XCTAssertEqual(fired.value, 0)
    }

    func testRunningTimerDoesNotRetainItself() {
        let queue = Queue(name: "CoreTimerTests.retain")
        weak var weakTimer: CoreSignalKitTimer?
        var timer: CoreSignalKitTimer? = CoreSignalKitTimer(timeout: 10.0, repeat: false, completion: {
        }, queue: queue)
        weakTimer = timer
        timer?.start()
        XCTAssertNotNil(weakTimer)
        timer = nil
        XCTAssertNil(weakTimer)
    }

    func testCompletionReceivesTheTimer() {
        let queue = Queue(name: "CoreTimerTests.argument")
        let fired = self.expectation(description: "fired")
        var received: CoreSignalKitTimer?
        let timer = CoreSignalKitTimer(timeout: 0.01, repeat: false, completion: { timer in
            received = timer
            fired.fulfill()
        }, queue: queue)
        timer.start()
        self.wait(for: [fired], timeout: 5.0)
        XCTAssertTrue(received === timer)
        received = nil
    }

    func testTimerOnMainQueueFiresOnMainThread() {
        let fired = self.expectation(description: "fired")
        var onMain: Bool?
        let timer = CoreSignalKitTimer(timeout: 0.01, repeat: false, completion: {
            onMain = Thread.isMainThread
            fired.fulfill()
        }, queue: Queue.mainQueue())
        timer.start()
        self.wait(for: [fired], timeout: 5.0)
        XCTAssertEqual(onMain, true)
        withExtendedLifetime(timer) {}
    }

    func testTimerCanBeRestartedAfterFiring() {
        let queue = Queue(name: "CoreTimerTests.restart")
        let fired = CoreCounter()
        let first = self.expectation(description: "first")
        let second = self.expectation(description: "second")
        let timer = CoreSignalKitTimer(timeout: 0.01, repeat: false, completion: {
            let count = fired.increment()
            if count == 1 {
                first.fulfill()
            } else if count == 2 {
                second.fulfill()
            }
        }, queue: queue)
        timer.start()
        self.wait(for: [first], timeout: 5.0)
        queue.sync {
        }
        timer.start()
        self.wait(for: [second], timeout: 5.0)
        XCTAssertEqual(fired.value, 2)
        withExtendedLifetime(timer) {}
    }

    func testTimerCanBeRestartedAfterInvalidate() {
        let queue = Queue(name: "CoreTimerTests.restartInvalidated")
        let fired = CoreCounter()
        let firedOnce = self.expectation(description: "fired")
        let timer = CoreSignalKitTimer(timeout: 0.02, repeat: false, completion: {
            if fired.increment() == 1 {
                firedOnce.fulfill()
            }
        }, queue: queue)
        timer.start()
        timer.invalidate()
        timer.start()
        self.wait(for: [firedOnce], timeout: 5.0)
        let settle = self.expectation(description: "settle")
        queue.after(0.08) {
            settle.fulfill()
        }
        self.wait(for: [settle], timeout: 5.0)
        XCTAssertEqual(fired.value, 1)
        withExtendedLifetime(timer) {}
    }
}
