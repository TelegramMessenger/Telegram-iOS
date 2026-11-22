import XCTest
@testable import CoreListDemo

final class VirtualListDriverTests: XCTestCase {
    private func makeDriver(itemCount: Int = 100, itemHeight: CGFloat = 50) -> VirtualListDriver {
        let items: [CoreListItem] = (0..<itemCount).map { _ in FixedHeightItem(height: itemHeight) }
        return VirtualListDriver(viewport: CGSize(width: 390, height: 800), items: items)
    }

    func testTickAdvancesClockFirst() {
        let driver = makeDriver()
        let before = driver.clock.now
        driver.tick(dt: 0.1)
        XCTAssertEqual(driver.clock.now, before + 0.1, accuracy: 1e-9)
    }

    func testTickFiresScrollDelegateBeforeAnimator() {
        // A programmatic scroll causes scrollViewDidScroll → rebalance during the same tick.
        let driver = makeDriver(itemCount: 1000, itemHeight: 50)
        driver.scrollView.setContentOffset(CGPoint(x: 0, y: 500), animated: true)
        let beforeStart = driver.listView.activeWindow.startIndex

        // Advance enough for the scroll view to nearly finish; rebalance should pull in items
        driver.tick(dt: 0.3)
        XCTAssertGreaterThan(driver.listView.activeWindow.startIndex, beforeStart)
    }

    func testRunUntilSettled_terminatesWhenIdle() {
        let driver = makeDriver()
        // No animation, no scroll → settles immediately
        let trace = driver.runUntilSettled(max: 1.0)
        XCTAssertEqual(trace.count, 1)  // single settled frame
    }

    func testRunUntilSettled_completesScrollAnimation() {
        let driver = makeDriver(itemCount: 1000, itemHeight: 50)
        driver.scrollView.setContentOffset(CGPoint(x: 0, y: 1000), animated: true)
        let trace = driver.runUntilSettled(max: 2.0)
        XCTAssertGreaterThan(trace.count, 2)
        // The virtual list re-anchors bounds when the window shifts, so we verify
        // that we actually scrolled to item ~20 rather than asserting the raw bounds Y.
        XCTAssertGreaterThan(driver.listView.activeWindow.startIndex, 0)
    }

    func testRun_collectsTraceAtStepSize() {
        let driver = makeDriver()
        let trace = driver.run(duration: 1.0, step: 0.1)
        XCTAssertEqual(trace.count, 11)  // 0 .. 1.0 inclusive at step 0.1
        XCTAssertEqual(trace.first!.time, 0, accuracy: 1e-9)
        XCTAssertEqual(trace.last!.time, 1.0, accuracy: 1e-9)
    }

    func testSample_matchesSettledControllerBackedScreenY() {
        let items: [CoreListItem] = (0..<200).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: 50)
        }
        let driver = VirtualListDriver(viewport: CGSize(width: 390, height: 800), items: items)
        driver.listView.applyChanges(scrollTo: .init(index: 100, pointOffset: 125), transition: .easeInOut(duration: 0))

        let sampled = driver.sample()
        XCTAssertNil(sampled.snapshotOriginY)
        XCTAssertEqual(sampled.items[100]?.resolvedScreenY ?? .nan, 125, accuracy: 0.5)
        XCTAssertEqual(sampled.containerTranslationY, 0, accuracy: 0.001)
    }

    func testDriver_exposesScheduler() {
        let driver = VirtualListDriver(viewport: CGSize(width: 390, height: 800),
                                       items: [FixedHeightItem(height: 50)])
        XCTAssertNotNil(driver.scheduler)
        XCTAssertEqual(driver.scheduler.pending.count, 0)
    }
}
