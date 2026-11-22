import XCTest
@testable import CoreListDemo

final class UserScrollTests: XCTestCase {

    func testDragPastTop_thenRelease_rubberBandsToZero() {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50)
        fixture.scrollView.simulateDrag(by: -100)
        XCTAssertLessThan(fixture.boundsOriginY, 0)

        fixture.scrollView.simulateRelease()
        let trace = fixture.runUntilSettled(max: 3.0)

        XCTAssertEqual(fixture.boundsOriginY, 0, accuracy: 1)
        trace.assertContiguousEveryFrame()
    }

    func testFlick_decelerationFiresRebalance() {
        let fixture = VirtualListFixture(itemCount: 1000, itemHeight: 50, preloadMargin: 100)
        let initialEnd = fixture.activeWindow.endIndex

        fixture.scrollView.simulateFlick(velocity: 1000)
        _ = fixture.runUntilSettled(max: 2.0)

        XCTAssertGreaterThan(fixture.activeWindow.endIndex, initialEnd)
        XCTAssertGreaterThan(fixture.boundsOriginY, 0)
    }

    func testFlick_noPerFrameJumps() {
        let fixture = VirtualListFixture(itemCount: 1000, itemHeight: 50, preloadMargin: 100)
        fixture.scrollView.simulateFlick(velocity: 1500)
        let trace = fixture.runUntilSettled(max: 2.0)

        // With a 1500 pt/s flick and 1/60 s step, max per-frame movement is ~25 pt.
        // Allow generous headroom for the first eased step.
        trace.assertNoVisibleJump(maxPerFrameDeltaY: 35)
        trace.assertContiguousEveryFrame()
    }

    func testProgrammaticAnimatedScroll_settlesAtTarget() {
        let fixture = VirtualListFixture(itemCount: 1000, itemHeight: 50)
        fixture.scrollView.setContentOffset(CGPoint(x: 0, y: 1000), animated: true)
        let trace = fixture.runUntilSettled(max: 1.0)

        // The scroll view's tick is now delta-based, so rebalance-induced bounds shifts
        // are preserved. The target index (item 20 at model y=1000) should end up at
        // screenY ≈ 0 after settling.
        XCTAssertEqual(fixture.screenY(forIndex: 20)!, 0, accuracy: 1)
        trace.assertContiguousEveryFrame()
    }

    func testHugeDelta_clampedInOneTick() {
        // CoreVirtualListView clamps any single-event delta to bounds.height.
        // Simulate this by writing a huge delta directly and verify the window stays valid.
        let fixture = VirtualListFixture(itemCount: 1000, itemHeight: 50)
        fixture.scrollView.bounds.origin.y += 5000
        fixture.fireScroll()

        XCTAssertFalse(fixture.activeWindow.isEmpty)
        let items = fixture.activeWindow.items
        for i in 0..<items.count - 1 {
            XCTAssertEqual(items[i].frame.maxY, items[i + 1].frame.minY, accuracy: 0.01)
        }
    }

    func testDragWithinBounds_writesScrollAndRebalances() {
        let fixture = VirtualListFixture(itemCount: 1000, itemHeight: 50, preloadMargin: 100)
        let initialEnd = fixture.activeWindow.endIndex

        fixture.scrollView.simulateDrag(by: 600)

        XCTAssertGreaterThan(fixture.activeWindow.endIndex, initialEnd)
    }
}
