import XCTest
@testable import MessageWidget

/// Spec 2026-10-15 D6: engine timers fire on main's run loop; each fire is handed back with its key, to be queued as a
/// task of the widget's.
final class TimersTests: XCTestCase {
    func testATimerFiresOnMainsRunLoopWithItsKey() {
        let timers = MessageWidgetTimers()
        var fired: [String] = []
        timers.fire = { key, body in
            XCTAssertTrue(Thread.isMainThread)
            fired.append(key)
            body()
        }
        var ran = false
        _ = timers.schedule(after: 0.02, key: "timer-7") {
            ran = true
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(fired, ["timer-7"])
        XCTAssertTrue(ran)
    }

    /// A timer cancelled from the core's thread (`clearTimeout`, a kill) neither fires nor keeps its block until its
    /// deadline.
    func testACancelledTimerNeitherFiresNorKeepsItsBlock() {
        final class Sentinel {}
        weak var weakSentinel: Sentinel?
        let timers = MessageWidgetTimers()
        var fired = 0
        timers.fire = { _, body in
            fired += 1
            body()
        }
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            let sentinel = Sentinel()
            weakSentinel = sentinel
            let handle = timers.schedule(after: 10.0, key: "timer-1") {
                _ = sentinel
            }
            handle.cancel()
            done.signal()
        }
        done.wait()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertNil(weakSentinel)
        XCTAssertEqual(fired, 0)
    }

    /// A timer cancelled after it fired on main but before its task ran does nothing in the task.
    func testATimerCancelledBetweenItsFireAndItsTaskRunsNothing() {
        let timers = MessageWidgetTimers()
        var queued: [() -> Void] = []
        timers.fire = { _, body in
            queued.append(body)
        }
        var ran = false
        let handle = timers.schedule(after: 0.0, key: "timer-2") {
            ran = true
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(queued.count, 1)
        handle.cancel()
        queued.forEach { $0() }
        XCTAssertFalse(ran)
    }
}
