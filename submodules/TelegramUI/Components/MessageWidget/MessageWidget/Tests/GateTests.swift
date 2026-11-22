import XCTest
@testable import MessageWidget

/// Planning ruling 6: the gate holds the next task of an instance on its pool thread until released — spec D9's stuck
/// widget, for the tests of Tasks 6–8.
class GateTests: MessageWidgetTestCase {
    func testAGatedTaskHoldsTheWidgetsQueueUntilReleased() {
        let instance = self.make("<!doctype html><p>x</p>", policy: MessageWidgetWaitPolicy(cap: 0.05))
        let gate = instance.gateNextTaskForTesting()
        _ = instance.layout(width: 300.0)
        XCTAssertEqual(gate.started.wait(timeout: .now() + 5.0), .success)
        XCTAssertFalse(instance.isIdleForTesting)
        XCTAssertNil(instance.appliedForTesting[.boot])
        gate.release.signal()
        XCTAssertTrue(self.pump(until: { instance.appliedForTesting[.boot] == 1 }))
        // The snapshot can reach main a moment before the thread marks the task done.
        XCTAssertTrue(self.pump(until: { instance.isIdleForTesting }))
        instance.destroy()
    }
}
