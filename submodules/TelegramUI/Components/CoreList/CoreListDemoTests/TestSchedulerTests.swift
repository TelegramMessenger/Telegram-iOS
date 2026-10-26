import XCTest
@testable import CoreListDemo

final class TestSchedulerTests: XCTestCase {
    func testTestScheduler_schedule_doesNotFireImmediately() {
        let scheduler = TestScheduler()
        var fired = false
        scheduler.schedule { fired = true }
        XCTAssertFalse(fired)
    }

    func testTestScheduler_flush_firesAllPending() {
        let scheduler = TestScheduler()
        var count = 0
        scheduler.schedule { count += 1 }
        scheduler.schedule { count += 1 }
        scheduler.flush()
        XCTAssertEqual(count, 2)
    }

    func testTestScheduler_flushTwice_doesNotRefire() {
        let scheduler = TestScheduler()
        var count = 0
        scheduler.schedule { count += 1 }
        scheduler.flush()
        scheduler.flush()
        XCTAssertEqual(count, 1)
    }

    func testTestScheduler_workScheduledDuringFlush_isPending() {
        let scheduler = TestScheduler()
        var phase = 0
        scheduler.schedule {
            phase = 1
            scheduler.schedule { phase = 2 }
        }
        scheduler.flush()
        XCTAssertEqual(phase, 1)
        scheduler.flush()
        XCTAssertEqual(phase, 2)
    }
}
