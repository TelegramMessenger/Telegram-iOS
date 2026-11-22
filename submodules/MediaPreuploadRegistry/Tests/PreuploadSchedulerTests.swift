import XCTest
import SwiftSignalKit
import MediaPreuploadRegistry

final class PreuploadSchedulerTests: XCTestCase {
    func testManualSchedulerFiresOnlyAfterDeadline() {
        let scheduler = ManualPreuploadScheduler()
        var fired = false
        let _ = scheduler.after(1.0, { fired = true })

        scheduler.advance(by: 0.5)
        XCTAssertFalse(fired)

        scheduler.advance(by: 0.6)
        XCTAssertTrue(fired)
    }

    func testManualSchedulerDoesNotFireCancelledTimers() {
        let scheduler = ManualPreuploadScheduler()
        var fired = false
        let disposable = scheduler.after(1.0, { fired = true })
        disposable.dispose()

        scheduler.advance(by: 2.0)
        XCTAssertFalse(fired)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }

    func testStateIsTerminal() {
        XCTAssertFalse(PreuploadState<Int>.progress(0.5).isTerminal)
        XCTAssertTrue(PreuploadState<Int>.done(1).isTerminal)
        XCTAssertTrue(PreuploadState<Int>.failed.isTerminal)
    }
}
