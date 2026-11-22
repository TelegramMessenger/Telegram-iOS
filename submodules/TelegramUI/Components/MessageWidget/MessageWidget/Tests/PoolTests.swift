import XCTest
@testable import MessageWidget

/// Spec 2026-10-15 D2: a pool of threads, a serial queue per widget, no pinning.
final class PoolTests: XCTestCase {
    private var pool: MessageWidgetPool!

    override func setUp() {
        super.setUp()
        self.pool = MessageWidgetPool(threadCount: 2)
    }

    override func tearDown() {
        self.pool.stop()
        self.pool = nil
        super.tearDown()
    }

    /// Runs `body` on `queue` after what is queued there, and waits for it.
    private func run(_ queue: WidgetTaskQueue, _ body: @escaping () -> Void = {}) {
        let done = DispatchSemaphore(value: 0)
        queue.enqueue {
            body()
            done.signal()
        }
        XCTAssertEqual(done.wait(timeout: .now() + 10.0), .success)
    }

    func testTasksOfOneQueueRunInOrderOneAtATime() {
        let queue = self.pool.makeQueue()
        let lock = NSLock()
        var order: [Int] = []
        var inside = 0
        var overlapped = false
        for i in 0 ..< 200 {
            queue.enqueue {
                lock.lock()
                inside += 1
                overlapped = overlapped || inside > 1
                order.append(i)
                lock.unlock()
                usleep(50)
                lock.lock()
                inside -= 1
                lock.unlock()
            }
        }
        self.run(queue)
        XCTAssertEqual(order, Array(0 ..< 200))
        XCTAssertFalse(overlapped)
    }

    func testTwoQueuesRunAtTheSameTime() {
        let a = self.pool.makeQueue()
        let b = self.pool.makeQueue()
        let aStarted = DispatchSemaphore(value: 0)
        let bStarted = DispatchSemaphore(value: 0)
        var aSawB = false
        var bSawA = false
        let done = DispatchGroup()
        done.enter()
        a.enqueue {
            aStarted.signal()
            aSawB = bStarted.wait(timeout: .now() + 5.0) == .success
            done.leave()
        }
        done.enter()
        b.enqueue {
            bStarted.signal()
            bSawA = aStarted.wait(timeout: .now() + 5.0) == .success
            done.leave()
        }
        XCTAssertEqual(done.wait(timeout: .now() + 10.0), .success)
        XCTAssertTrue(aSawB)
        XCTAssertTrue(bSawA)
    }

    /// Spec D7: a task stuck in an uncharged native path keeps its thread; the other serves every other widget.
    func testABlockedQueueLeavesTheOtherThreadServing() {
        let stuck = self.pool.makeQueue()
        let other = self.pool.makeQueue()
        let release = DispatchSemaphore(value: 0)
        stuck.enqueue {
            release.wait()
        }
        var count = 0
        for _ in 0 ..< 20 {
            other.enqueue {
                count += 1
            }
        }
        self.run(other)
        XCTAssertEqual(count, 20)
        release.signal()
        self.run(stuck)
    }

    func testAKeyedTaskReplacesTheOneStillWaitingInItsPlace() {
        let queue = self.pool.makeQueue()
        let gate = DispatchSemaphore(value: 0)
        var seen: [String] = []
        queue.enqueue {
            gate.wait()
        }
        queue.enqueue(key: "v") {
            seen.append("v1")
        }
        queue.enqueue {
            seen.append("plain")
        }
        queue.enqueue(key: "v") {
            seen.append("v2")
        }
        gate.signal()
        self.run(queue)
        XCTAssertEqual(seen, ["v2", "plain"])
    }

    /// Spec D5: a destroyed widget's waiting tasks are dropped, and its teardown runs after the task it is in.
    func testCloseDropsWaitingTasksAndTearsDownAfterTheRunningOne() {
        let queue = self.pool.makeQueue()
        let gate = DispatchSemaphore(value: 0)
        let started = DispatchSemaphore(value: 0)
        let tornDown = DispatchSemaphore(value: 0)
        var seen: [String] = []
        queue.enqueue {
            started.signal()
            gate.wait()
            seen.append("running")
        }
        queue.enqueue {
            seen.append("waiting")
        }
        XCTAssertEqual(started.wait(timeout: .now() + 5.0), .success)
        queue.close {
            seen.append("teardown")
            tornDown.signal()
        }
        XCTAssertFalse(queue.enqueue {
            seen.append("late")
        })
        gate.signal()
        XCTAssertEqual(tornDown.wait(timeout: .now() + 5.0), .success)
        XCTAssertEqual(seen, ["running", "teardown"])
        // The thread marks the task done just after its body returns.
        for _ in 0 ..< 1000 where !queue.isIdle {
            usleep(1_000)
        }
        XCTAssertTrue(queue.isIdle)
    }

    func testPoolThreadsHaveEightMegabyteStacks() {
        let queue = self.pool.makeQueue()
        var stack = 0
        self.run(queue) {
            stack = Int(pthread_get_stacksize_np(pthread_self()))
        }
        XCTAssertGreaterThanOrEqual(stack, MessageWidgetPool.threadStackSize)
    }
}
