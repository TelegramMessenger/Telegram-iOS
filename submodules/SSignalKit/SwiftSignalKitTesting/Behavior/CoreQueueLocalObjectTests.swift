import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class CoreQueueLocalObjectTests: XCTestCase {
    private final class Box {
        var value: Int
        let onDeinit: (() -> Void)?

        init(_ value: Int, onDeinit: (() -> Void)? = nil) {
            self.value = value
            self.onDeinit = onDeinit
        }

        deinit {
            self.onDeinit?()
        }
    }

    func testGenerateRunsOnQueueAndWithRunsOnQueue() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.with")
        let generatedOnQueue = CoreFlag()
        let object = QueueLocalObject<Box>(queue: queue, generate: {
            generatedOnQueue.set(queue.isCurrent())
            return Box(5)
        })
        XCTAssertTrue(object.queue === queue)
        let done = self.expectation(description: "with")
        var observed: Int?
        var withOnQueue: Bool?
        object.with { box in
            withOnQueue = queue.isCurrent()
            observed = box.value
            done.fulfill()
        }
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(generatedOnQueue.value, true)
        XCTAssertEqual(withOnQueue, true)
        XCTAssertEqual(observed, 5)
    }

    func testSyncWithReturnsResultAndSeesMutations() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.syncWith")
        let object = QueueLocalObject<Box>(queue: queue, generate: {
            return Box(1)
        })
        object.with { box in
            box.value += 10
        }
        let result = object.syncWith { box -> String in
            return "\(box.value) \(queue.isCurrent())"
        }
        XCTAssertEqual(result, "11 true")
    }

    func testUnsafeGetOnQueueReturnsValue() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.unsafeGet")
        let object = QueueLocalObject<Box>(queue: queue, generate: {
            return Box(9)
        })
        var value: Int?
        queue.sync {
            value = object.unsafeGet()?.value
        }
        XCTAssertEqual(value, 9)
    }

    func testCreatedOnItsQueueGeneratesInlineAndWithRunsInline() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.inline")
        let log = CoreEventLog()
        var object: QueueLocalObject<Box>?
        queue.sync {
            object = QueueLocalObject<Box>(queue: queue, generate: {
                log.append("generate")
                return Box(2)
            })
            log.append("after init")
            object?.with { box in
                log.append("with \(box.value)")
            }
            log.append("after with")
        }
        XCTAssertEqual(log.events, ["generate", "after init", "with 2", "after with"])
        XCTAssertNotNil(object)
    }

    func testCreatedOffQueueGeneratesAsynchronously() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.async")
        let log = CoreEventLog()
        let gate = DispatchSemaphore(value: 0)
        queue.justDispatch {
            _ = gate.wait(timeout: .now() + 5.0)
        }
        let object = QueueLocalObject<Box>(queue: queue, generate: {
            log.append("generate")
            return Box(3)
        })
        log.append("after init")
        gate.signal()
        XCTAssertEqual(object.syncWith { $0.value }, 3)
        XCTAssertEqual(log.events, ["after init", "generate"])
    }

    func testValueReleasedOnItsQueueAfterObjectDies() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.release")
        let released = self.expectation(description: "released")
        let releasedOnQueue = CoreFlag()
        do {
            let object = QueueLocalObject<Box>(queue: queue, generate: {
                return Box(1, onDeinit: {
                    releasedOnQueue.set(queue.isCurrent())
                    released.fulfill()
                })
            })
            XCTAssertEqual(object.syncWith { $0.value }, 1)
        }
        self.wait(for: [released], timeout: 5.0)
        XCTAssertEqual(releasedOnQueue.value, true)
    }

    func testValueStaysAliveWhileObjectAlive() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.alive")
        let log = CoreEventLog()
        let object = QueueLocalObject<Box>(queue: queue, generate: {
            return Box(1, onDeinit: {
                log.append("released")
            })
        })
        XCTAssertEqual(object.syncWith { $0.value }, 1)
        queue.sync {
        }
        XCTAssertEqual(log.events, [])
        withExtendedLifetime(object) {}
    }

    func testSignalWithRunsOnQueueWithValue() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.signalWith")
        let object = QueueLocalObject<Box>(queue: queue, generate: {
            return Box(3)
        })
        let log = CoreEventLog()
        let done = self.expectation(description: "completed")
        let signal: Signal<Int, NoError> = object.signalWith { box, subscriber in
            log.append("generator onQueue=\(queue.isCurrent())")
            subscriber.putNext(box.value)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let handle = signal.start(next: { value in
            log.append("next \(value)")
        }, completed: {
            log.append("completed")
            done.fulfill()
        })
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(log.events, ["generator onQueue=true", "next 3", "completed"])
        handle.dispose()
    }

    func testSignalWithStartedOnQueueRunsSynchronously() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.signalWithInline")
        let object = QueueLocalObject<Box>(queue: queue, generate: {
            return Box(4)
        })
        let log = CoreEventLog()
        let signal: Signal<Int, NoError> = object.signalWith { box, subscriber in
            subscriber.putNext(box.value)
            return EmptyDisposable
        }
        queue.sync {
            let handle = signal.start(next: { value in
                log.append("next \(value)")
            })
            log.append("after start")
            handle.dispose()
        }
        XCTAssertEqual(log.events, ["next 4", "after start"])
    }

    func testSignalWithAfterObjectDiedEmitsNothing() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.signalWithDead")
        let log = CoreEventLog()
        var signal: Signal<Int, NoError>?
        do {
            let object = QueueLocalObject<Box>(queue: queue, generate: {
                return Box(5)
            })
            signal = object.signalWith { box, subscriber in
                log.append("generator")
                subscriber.putNext(box.value)
                return EmptyDisposable
            }
            XCTAssertEqual(object.syncWith { $0.value }, 5)
        }
        let handle = signal?.start(next: { value in
            log.append("next \(value)")
        }, completed: {
            log.append("completed")
        })
        queue.sync {
        }
        XCTAssertEqual(log.events, [])
        handle?.dispose()
    }

    func testSignalWithDisposedBeforeQueueRunsSkipsGenerator() {
        let queue = Queue(name: "CoreQueueLocalObjectTests.signalWithCancel")
        let object = QueueLocalObject<Box>(queue: queue, generate: {
            return Box(6)
        })
        _ = object.syncWith { $0.value }
        let log = CoreEventLog()
        let gate = DispatchSemaphore(value: 0)
        queue.justDispatch {
            _ = gate.wait(timeout: .now() + 5.0)
        }
        let handle = object.signalWith { (box: Box, subscriber: Subscriber<Int, NoError>) -> Disposable in
            log.append("generator")
            subscriber.putNext(box.value)
            return EmptyDisposable
        }.start(next: { value in
            log.append("next \(value)")
        })
        handle.dispose()
        gate.signal()
        queue.sync {
        }
        XCTAssertEqual(log.events, [])
    }
}
