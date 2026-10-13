import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class CoreQueueTests: XCTestCase {
    private func onBackgroundThread<R>(_ f: @escaping () -> R) -> R? {
        let done = self.expectation(description: "background")
        var result: R?
        DispatchQueue.global().async {
            result = f()
            done.fulfill()
        }
        self.wait(for: [done], timeout: 5.0)
        return result
    }

    func testMainQueueIsSingletonWrappingDispatchMain() {
        XCTAssertTrue(Queue.mainQueue() === Queue.mainQueue())
        XCTAssertTrue(Queue.mainQueue().queue === DispatchQueue.main)
    }

    func testConcurrentQueuesWrapGlobalQueues() {
        XCTAssertTrue(Queue.concurrentDefaultQueue() === Queue.concurrentDefaultQueue())
        XCTAssertTrue(Queue.concurrentBackgroundQueue() === Queue.concurrentBackgroundQueue())
        XCTAssertTrue(Queue.concurrentDefaultQueue().queue === DispatchQueue.global(qos: .default))
        XCTAssertTrue(Queue.concurrentBackgroundQueue().queue === DispatchQueue.global(qos: .background))
    }

    func testWrapperExposesWrappedDispatchQueue() {
        let dispatchQueue = DispatchQueue(label: "CoreQueueTests.wrapped")
        XCTAssertTrue(Queue(queue: dispatchQueue).queue === dispatchQueue)
    }

    func testMainQueueIsCurrentOnMainThreadOnly() {
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertTrue(Queue.mainQueue().isCurrent())
        XCTAssertEqual(self.onBackgroundThread { Queue.mainQueue().isCurrent() }, false)
    }

    func testMainQueueIsCurrentInsideDispatchMainAsync() {
        let done = self.expectation(description: "main")
        var result: Bool?
        DispatchQueue.main.async {
            result = Queue.mainQueue().isCurrent()
            done.fulfill()
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(result, true)
    }

    func testMainQueueIsCurrentIsThreadBasedInsideCustomQueueSyncFromMainThread() {
        let queue = Queue(name: "CoreQueueTests.syncFromMain")
        var mainIsCurrent: Bool?
        var customIsCurrent: Bool?
        var onMainThread: Bool?
        queue.sync {
            onMainThread = Thread.isMainThread
            mainIsCurrent = Queue.mainQueue().isCurrent()
            customIsCurrent = queue.isCurrent()
        }
        XCTAssertEqual(customIsCurrent, true)
        XCTAssertEqual(mainIsCurrent, onMainThread)
    }

    func testCustomQueueIsCurrentOnlyInsideItsOwnBlocks() {
        let queue = Queue(name: "CoreQueueTests.a")
        let other = Queue(name: "CoreQueueTests.b")
        XCTAssertFalse(queue.isCurrent())
        var inside: Bool?
        var otherInside: Bool?
        queue.sync {
            inside = queue.isCurrent()
            otherInside = other.isCurrent()
        }
        XCTAssertEqual(inside, true)
        XCTAssertEqual(otherInside, false)
        XCTAssertEqual(self.onBackgroundThread { queue.isCurrent() }, false)
    }

    func testOuterQueueIsNotCurrentInsideNestedSyncOntoAnotherQueue() {
        let outer = Queue(name: "CoreQueueTests.outer")
        let inner = Queue(name: "CoreQueueTests.inner")
        var outerInsideInner: Bool?
        var innerInsideInner: Bool?
        var outerAfterInner: Bool?
        outer.sync {
            inner.sync {
                outerInsideInner = outer.isCurrent()
                innerInsideInner = inner.isCurrent()
            }
            outerAfterInner = outer.isCurrent()
        }
        XCTAssertEqual(outerInsideInner, false)
        XCTAssertEqual(innerInsideInner, true)
        XCTAssertEqual(outerAfterInner, true)
    }

    func testCustomQueueIsCurrentInsideDispatchQueueTargetingIt() {
        let queue = Queue(name: "CoreQueueTests.target")
        let targeting = DispatchQueue(label: "CoreQueueTests.targeting", target: queue.queue)
        let done = self.expectation(description: "targeting")
        var result: Bool?
        targeting.async {
            result = queue.isCurrent()
            done.fulfill()
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(result, true)
    }

    func testWrapperQueueIsNeverCurrent() {
        let dispatchQueue = DispatchQueue(label: "CoreQueueTests.plain")
        let wrapper = Queue(queue: dispatchQueue)
        XCTAssertFalse(wrapper.isCurrent())
        var inside: Bool?
        dispatchQueue.sync {
            inside = wrapper.isCurrent()
        }
        XCTAssertEqual(inside, false)
    }

    func testWrapperAroundNamedQueueIsNotCurrentButNamedQueueIs() {
        let named = Queue(name: "CoreQueueTests.named")
        let wrapper = Queue(queue: named.queue)
        var wrapperInside: Bool?
        var namedInside: Bool?
        wrapper.sync {
            wrapperInside = wrapper.isCurrent()
            namedInside = named.isCurrent()
        }
        XCTAssertEqual(wrapperInside, false)
        XCTAssertEqual(namedInside, true)
    }

    func testWrapperAroundDispatchMainIsNotCurrentOnMainThread() {
        let wrapper = Queue(queue: DispatchQueue.main)
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertFalse(wrapper.isCurrent())
    }

    func testWrapperAsyncFromItsOwnQueueIsNotInline() {
        let named = Queue(name: "CoreQueueTests.wrapperAsync")
        let wrapper = Queue(queue: named.queue)
        let log = CoreEventLog()
        let done = self.expectation(description: "dispatched")
        named.async {
            wrapper.async {
                log.append("wrapper block")
                done.fulfill()
            }
            log.append("after call")
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, ["after call", "wrapper block"])
    }

    func testConcurrentGlobalQueuesAreNeverCurrent() {
        XCTAssertFalse(Queue.concurrentDefaultQueue().isCurrent())
        XCTAssertFalse(Queue.concurrentBackgroundQueue().isCurrent())
        let done = self.expectation(description: "global")
        var defaultInside: Bool?
        var backgroundInside: Bool?
        Queue.concurrentDefaultQueue().async {
            defaultInside = Queue.concurrentDefaultQueue().isCurrent()
            done.fulfill()
        }
        let doneBackground = self.expectation(description: "background")
        Queue.concurrentBackgroundQueue().async {
            backgroundInside = Queue.concurrentBackgroundQueue().isCurrent()
            doneBackground.fulfill()
        }
        self.wait(for: [done, doneBackground], timeout: 5.0)
        XCTAssertEqual(defaultInside, false)
        XCTAssertEqual(backgroundInside, false)
    }

    func testAsyncRunsInlineWhenCurrent() {
        let queue = Queue(name: "CoreQueueTests.inline")
        let log = CoreEventLog()
        queue.sync {
            queue.async {
                log.append("inner")
            }
            log.append("after")
        }
        XCTAssertEqual(log.events, ["inner", "after"])
    }

    func testAsyncDispatchesWhenNotCurrent() {
        let queue = Queue(name: "CoreQueueTests.dispatch")
        let log = CoreEventLog()
        let gate = DispatchSemaphore(value: 0)
        let done = self.expectation(description: "block")
        queue.justDispatch {
            _ = gate.wait(timeout: .now() + 5.0)
        }
        queue.async {
            log.append("block current=\(queue.isCurrent())")
            done.fulfill()
        }
        log.append("returned")
        gate.signal()
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, ["returned", "block current=true"])
    }

    func testMainQueueAsyncRunsInlineOnMainThread() {
        let log = CoreEventLog()
        Queue.mainQueue().async {
            log.append("inner")
        }
        log.append("after")
        XCTAssertEqual(log.events, ["inner", "after"])
    }

    func testMainQueueAsyncFromBackgroundDispatchesToMainThread() {
        let done = self.expectation(description: "main")
        var onMain: Bool?
        DispatchQueue.global().async {
            Queue.mainQueue().async {
                onMain = Thread.isMainThread
                done.fulfill()
            }
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(onMain, true)
    }

    func testSyncRunsInlineWhenCurrent() {
        let queue = Queue(name: "CoreQueueTests.syncInline")
        let log = CoreEventLog()
        queue.sync {
            queue.sync {
                log.append("nested")
            }
            log.append("after nested")
        }
        log.append("after outer")
        XCTAssertEqual(log.events, ["nested", "after nested", "after outer"])
    }

    func testSyncWaitsForBlockOnQueue() {
        let queue = Queue(name: "CoreQueueTests.sync")
        let log = CoreEventLog()
        queue.justDispatch {
            usleep(20000)
            log.append("earlier block")
        }
        queue.sync {
            log.append("sync current=\(queue.isCurrent())")
        }
        log.append("after")
        XCTAssertEqual(log.events, ["earlier block", "sync current=true", "after"])
    }

    func testMainQueueSyncOnMainThreadRunsInline() {
        let log = CoreEventLog()
        Queue.mainQueue().sync {
            log.append("inline")
        }
        log.append("after")
        XCTAssertEqual(log.events, ["inline", "after"])
    }

    func testJustDispatchIsNeverInline() {
        let queue = Queue(name: "CoreQueueTests.justDispatch")
        let log = CoreEventLog()
        let done = self.expectation(description: "dispatched")
        queue.sync {
            queue.justDispatch {
                log.append("dispatched current=\(queue.isCurrent())")
                done.fulfill()
            }
            log.append("after")
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, ["after", "dispatched current=true"])
    }

    func testMainQueueJustDispatchIsNeverInline() {
        let log = CoreEventLog()
        let done = self.expectation(description: "dispatched")
        Queue.mainQueue().justDispatch {
            log.append("dispatched")
            done.fulfill()
        }
        log.append("after")
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, ["after", "dispatched"])
    }

    func testJustDispatchWithQoSRunsOnQueue() {
        let queue = Queue(name: "CoreQueueTests.qos")
        let done = self.expectation(description: "dispatched")
        var current: Bool?
        queue.justDispatchWithQoS(qos: .userInitiated) {
            current = queue.isCurrent()
            done.fulfill()
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(current, true)
    }

    func testJustDispatchPreservesFifoOrder() {
        let queue = Queue(name: "CoreQueueTests.fifo")
        let log = CoreEventLog()
        let done = self.expectation(description: "done")
        for i in 0 ..< 20 {
            queue.justDispatch {
                log.append("\(i)")
            }
        }
        queue.async {
            done.fulfill()
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, (0 ..< 20).map { "\($0)" })
    }

    func testAfterRunsOnQueueAfterDelay() {
        let queue = Queue(name: "CoreQueueTests.after")
        let done = self.expectation(description: "after")
        let start = DispatchTime.now()
        var elapsed: Double = 0.0
        var current: Bool?
        queue.after(0.05) {
            elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0
            current = queue.isCurrent()
            done.fulfill()
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertGreaterThanOrEqual(elapsed, 0.049)
        XCTAssertEqual(current, true)
    }

    func testAfterIsNotInlineEvenForZeroDelayWhenCurrent() {
        let queue = Queue(name: "CoreQueueTests.afterZero")
        let log = CoreEventLog()
        let done = self.expectation(description: "after")
        queue.sync {
            queue.after(0.0) {
                log.append("after block")
                done.fulfill()
            }
            log.append("caller")
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, ["caller", "after block"])
    }

    func testAfterOrdersByDeadline() {
        let queue = Queue(name: "CoreQueueTests.afterOrder")
        let log = CoreEventLog()
        let done = self.expectation(description: "both")
        done.expectedFulfillmentCount = 2
        queue.after(0.08) {
            log.append("late")
            done.fulfill()
        }
        queue.after(0.01) {
            log.append("early")
            done.fulfill()
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, ["early", "late"])
    }
}
