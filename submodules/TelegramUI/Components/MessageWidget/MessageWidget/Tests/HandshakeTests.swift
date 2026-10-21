import QuartzCore
import XCTest
@testable import MessageWidget

/// Spec 2026-10-15 D3: main waits for a task until it finishes, spends its sync budget, or the cap passes; results reach
/// main in task order.
final class HandshakeTests: XCTestCase {
    private final class Applied {
        var values: [Int] = []
    }

    private var pool: MessageWidgetPool!
    private var turn: MessageWidgetTurn!

    override func setUp() {
        super.setUp()
        self.pool = MessageWidgetPool(threadCount: 2)
        self.turn = MessageWidgetTurn()
    }

    override func tearDown() {
        self.pool.stop()
        self.pool = nil
        self.turn = nil
        super.tearDown()
    }

    private func make(_ policy: MessageWidgetWaitPolicy) -> (WidgetHandshake<Int>, Applied) {
        let applied = Applied()
        let handshake = WidgetHandshake<Int>(queue: self.pool.makeQueue(), policy: policy, turn: self.turn)
        handshake.apply = { value in
            applied.values.append(value)
        }
        return (handshake, applied)
    }

    /// Runs main's run loop until `condition` holds, for at most `timeout` seconds.
    private func waitUntil(timeout: TimeInterval = 5.0, _ condition: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
        }
        XCTAssertTrue(condition())
    }

    func testAWaitEndsWhenTheTaskFinishes() {
        let (handshake, applied) = self.make(.standard)
        XCTAssertTrue(handshake.run(wait: true) { _ in 7 })
        XCTAssertEqual(applied.values, [7])
    }

    func testAWaitEndsWhenTheTaskSpendsItsSyncBudget() {
        let (handshake, applied) = self.make(MessageWidgetWaitPolicy(cap: 5.0, allowance: 1_000))
        let release = DispatchSemaphore(value: 0)
        let start = CACurrentMediaTime()
        XCTAssertFalse(handshake.run(wait: true) { meter in
            meter.add(1_000)
            release.wait()
            return 1
        })
        XCTAssertLessThan(CACurrentMediaTime() - start, 1.0, "the wait ended at the crossing, long before the 5 s cap")
        XCTAssertEqual(applied.values, [])
        release.signal()
        self.waitUntil { applied.values == [1] }
    }

    func testAWaitEndsAtTheCap() {
        let (handshake, applied) = self.make(MessageWidgetWaitPolicy(cap: 0.05, allowance: nil))
        let release = DispatchSemaphore(value: 0)
        let start = CACurrentMediaTime()
        XCTAssertFalse(handshake.run(wait: true) { _ in
            release.wait()
            return 2
        })
        let waited = CACurrentMediaTime() - start
        XCTAssertGreaterThanOrEqual(waited, 0.04)
        XCTAssertLessThan(waited, 1.0)
        release.signal()
        self.waitUntil { applied.values == [2] }
    }

    /// The race the ticket's lock exists for: a task finishing right at the cap is delivered exactly once — returned by
    /// the wait or applied from the mailbox, never both and never neither.
    func testATaskFinishingAtTheCapIsDeliveredExactlyOnce() {
        for i in 0 ..< 300 {
            self.turn.reset()
            let (handshake, applied) = self.make(MessageWidgetWaitPolicy(cap: 0.002, allowance: nil))
            let sync = handshake.run(wait: true) { _ in
                usleep(UInt32(1_000 + (i % 3) * 500))
                return i
            }
            self.waitUntil { applied.values.count == 1 }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            XCTAssertEqual(applied.values, [i], "run \(i), returned by the wait: \(sync)")
        }
    }

    func testTheAllowanceIsSharedWithinATurnAndResetAfterIt() {
        let policy = MessageWidgetWaitPolicy(cap: nil, allowance: 1_000)
        let (handshake, _) = self.make(policy)
        XCTAssertTrue(handshake.run(wait: true) { meter in
            meter.add(600)
            return 1
        })
        XCTAssertEqual(self.turn.remainingUnits(policy), 400)
        let release = DispatchSemaphore(value: 0)
        XCTAssertFalse(handshake.run(wait: true) { meter in
            meter.add(600)
            release.wait()
            return 2
        })
        XCTAssertEqual(self.turn.remainingUnits(policy), 0)
        let start = CACurrentMediaTime()
        XCTAssertFalse(handshake.run(wait: true) { _ in 3 })
        XCTAssertLessThan(CACurrentMediaTime() - start, 0.5, "no allowance left in this turn: no wait")
        release.signal()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(self.turn.remainingUnits(policy), 1_000, "the run loop waited: a new turn")
    }

    /// A result that arrived after its wait is applied before a newer one, though nothing has drained the mailbox yet.
    func testALateResultIsAppliedBeforeANewerOne() {
        let (handshake, applied) = self.make(MessageWidgetWaitPolicy(cap: 0.02, allowance: nil))
        let release = DispatchSemaphore(value: 0)
        XCTAssertFalse(handshake.run(wait: true) { _ in
            release.wait()
            return 1
        })
        self.turn.reset()
        release.signal()
        XCTAssertTrue(handshake.run(wait: true) { _ in 2 })
        XCTAssertEqual(applied.values, [1, 2])
    }

    /// Applying a result can queue another task (a snapshot asks for its tiles' draw). That run must not apply anything
    /// ahead of the results the mailbox still holds: neither a result that landed meanwhile nor its own, finished at once.
    func testATaskQueuedWhileApplyingKeepsTheResultsInOrder() {
        let queue = self.pool.makeQueue()
        let handshake = WidgetHandshake<Int>(queue: queue, policy: .standard, turn: self.turn)
        let applied = Applied()
        let waitForIdle = {
            while !queue.isIdle {
                usleep(1_000)
            }
        }
        handshake.apply = { value in
            applied.values.append(value)
            if value == 1 {
                handshake.run(wait: false) { _ in 3 }
                waitForIdle()
                handshake.run(wait: false) { _ in 4 }
            }
        }
        // Held, so both are abandoned and land in the mailbox together.
        let release = DispatchSemaphore(value: 0)
        XCTAssertFalse(handshake.run(wait: false) { _ in
            release.wait()
            return 1
        })
        XCTAssertFalse(handshake.run(wait: false) { _ in 2 })
        release.signal()
        waitForIdle()
        self.waitUntil { applied.values.count == 4 }
        XCTAssertEqual(applied.values, [1, 2, 3, 4])
        handshake.apply = nil
    }

    /// A waited result takes its place among the results in the order its task ran: the drain its run starts applies
    /// it before a task that drain queued (a draw asked for by an older result), not after.
    func testAWaitedResultIsAppliedBeforeATaskItsDrainQueued() {
        let queue = self.pool.makeQueue()
        let handshake = WidgetHandshake<Int>(queue: queue, policy: .standard, turn: self.turn)
        let applied = Applied()
        let waitForIdle = {
            while !queue.isIdle {
                usleep(1_000)
            }
        }
        handshake.apply = { value in
            applied.values.append(value)
            if value == 1 {
                handshake.run(wait: false) { _ in 3 }
                waitForIdle()
            }
        }
        let release = DispatchSemaphore(value: 0)
        XCTAssertFalse(handshake.run(wait: false) { _ in
            release.wait()
            return 1
        })
        release.signal()
        waitForIdle()
        XCTAssertTrue(handshake.run(wait: true, policy: .unbounded) { _ in 2 })
        self.waitUntil { applied.values.count == 3 }
        XCTAssertEqual(applied.values, [1, 2, 3])
        handshake.apply = nil
    }

    /// The test accessors wait for their task whatever the widget's policy (Task 4's `onCoreForTesting`).
    func testAPolicyGivenForOneCallOverridesTheHandshakes() {
        let (handshake, applied) = self.make(MessageWidgetWaitPolicy(cap: 0.0, allowance: 0))
        // Held, or a pool thread could finish it before main looks, and a finished task is reported done.
        let release = DispatchSemaphore(value: 0)
        XCTAssertFalse(handshake.run(wait: true) { _ in
            release.wait()
            return 1
        })
        release.signal()
        XCTAssertTrue(handshake.run(wait: true, policy: .unbounded) { _ in
            usleep(20_000)
            return 2
        })
        XCTAssertEqual(applied.values, [1, 2])
    }

    func testAMeterCountsEveryReportOfItsTask() {
        var crossed = 0
        let meter = WorkMeter(threshold: 1_000, crossed: { crossed += 1 })
        meter.add(700)
        XCTAssertFalse(meter.hasCrossed)
        meter.add(300)
        meter.add(5)
        XCTAssertEqual(meter.spent, 1_005)
        XCTAssertTrue(meter.hasCrossed)
        XCTAssertEqual(crossed, 1)
    }
}
