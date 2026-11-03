import XCTest
import UIKit
@testable import CoreListDemo

/// Two full-replace carousels in a row: A -> B, then B -> C, each destination sharing no identity
/// with the window it leaves. The strips A and B are both departed content by the second pass, and
/// neither may be drawn over the live strip C while it travels in.
final class CarouselChainOverlapTests: XCTestCase {
    private final class Item: CoreListItem {
        let id: Int

        var identity: AnyHashable { id }

        init(id: Int) { self.id = id }

        func view() -> UIView & CoreListItemView { FixedHeightItemView(height: 50) }

        func isEqual(to other: CoreListItem) -> Bool { (other as? Item)?.id == id }
    }

    private func makeFixture() -> VirtualListFixture {
        VirtualListFixture(viewport: CGSize(width: 390, height: 300),
                           items: (0..<200).map { Item(id: $0) },
                           preloadMargin: 100)
    }

    private func jump(_ fixture: VirtualListFixture,
                      ids: Range<Int>,
                      to index: Int = 100,
                      direction: CoreListScrollTarget.Direction,
                      duration: TimeInterval) {
        fixture.listView.applyChanges(
            items: ids.map { Item(id: $0) },
            scrollTo: .init(index: index, direction: direction, resolve: { _, _ in 0 }),
            transition: .easeInOut(duration: duration)
        )
    }

    /// Total height, within the viewport, where a departed row is drawn on top of a live row.
    private func visibleStaleOverlap(_ fixture: VirtualListFixture) -> CGFloat {
        let height = fixture.listView.logicalSize.height
        func clipped(_ lower: CGFloat, _ upper: CGFloat) -> ClosedRange<CGFloat>? {
            let low = max(0, lower), high = min(height, upper)
            return low < high ? low...high : nil
        }
        let ghosts = fixture.ghostMemberViews.compactMap { view -> ClosedRange<CGFloat>? in
            guard let y = fixture.driver.exitScreenY(view: view) else { return nil }
            return clipped(y, y + view.bounds.height)
        }
        let lives = fixture.activeWindow.items.compactMap { item -> ClosedRange<CGFloat>? in
            guard let frame = fixture.screenFrame(forIndex: item.index) else { return nil }
            return clipped(frame.minY, frame.maxY)
        }
        var total: CGFloat = 0
        for ghost in ghosts {
            for live in lives {
                total += max(0, min(ghost.upperBound, live.upperBound)
                    - max(ghost.lowerBound, live.lowerBound))
            }
        }
        return total
    }

    /// Height of the viewport drawn by neither a departed nor a live row.
    private func uncoveredHeight(_ fixture: VirtualListFixture) -> CGFloat {
        let height = fixture.listView.logicalSize.height
        var intervals: [(CGFloat, CGFloat)] = []
        for view in fixture.ghostMemberViews {
            guard let y = fixture.driver.exitScreenY(view: view) else { continue }
            intervals.append((y, y + view.bounds.height))
        }
        for item in fixture.activeWindow.items {
            guard let frame = fixture.screenFrame(forIndex: item.index) else { continue }
            intervals.append((frame.minY, frame.maxY))
        }
        var covered: CGFloat = 0
        var reach: CGFloat = 0
        for (lower, upper) in intervals.sorted(by: { $0.0 < $1.0 }) {
            let low = max(reach, max(0, lower)), high = min(height, upper)
            if high > low { covered += high - low }
            reach = max(reach, high)
        }
        return height - covered
    }

    /// Runs A -> B, waits `gap`, runs B -> C, then samples the second travel frame by frame.
    private func peakOverlap(first: CoreListScrollTarget.Direction,
                             second: CoreListScrollTarget.Direction,
                             gap: TimeInterval) -> (peak: CGFloat, ghostFrames: Int) {
        let fixture = makeFixture()
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))
        jump(fixture, ids: 1000..<1200, direction: first, duration: 2)
        fixture.tick(dt: gap)
        jump(fixture, ids: 5000..<5200, direction: second, duration: 2)

        var peak: CGFloat = 0
        var ghostFrames = 0
        var elapsed: TimeInterval = 0
        while elapsed < 2.1 {
            if !fixture.ghostMemberViews.isEmpty { ghostFrames += 1 }
            peak = max(peak, visibleStaleOverlap(fixture))
            fixture.tick(dt: 1.0 / 60)
            elapsed += 1.0 / 60
        }
        return (peak, ghostFrames)
    }

    private func assertNoOverlap(first: CoreListScrollTarget.Direction,
                                 second: CoreListScrollTarget.Direction,
                                 gap: TimeInterval,
                                 file: StaticString = #filePath,
                                 line: UInt = #line) {
        let result = peakOverlap(first: first, second: second, gap: gap)
        XCTAssertGreaterThan(result.ghostFrames, 10,
                             "the second travel was never observed with ghosts on screen",
                             file: file, line: line)
        XCTAssertLessThanOrEqual(result.peak, 1e-6,
                                 "stale rows drawn over live rows (\(first) then \(second), gap \(gap))",
                                 file: file, line: line)
    }

    // Second jump while the first is still travelling.

    func testForwardThenForwardMidFlight() {
        assertNoOverlap(first: .forward, second: .forward, gap: 0.4)
    }

    func testForwardThenBackwardMidFlight() {
        assertNoOverlap(first: .forward, second: .backward, gap: 0.4)
    }

    func testBackwardThenForwardMidFlight() {
        assertNoOverlap(first: .backward, second: .forward, gap: 0.4)
    }

    func testBackwardThenBackwardMidFlight() {
        assertNoOverlap(first: .backward, second: .backward, gap: 0.4)
    }

    // Second jump after the first has settled.

    func testForwardThenBackwardSettled() {
        assertNoOverlap(first: .forward, second: .backward, gap: 2.5)
    }

    func testBackwardThenForwardSettled() {
        assertNoOverlap(first: .backward, second: .forward, gap: 2.5)
    }

    func testForwardThenForwardSettled() {
        assertNoOverlap(first: .forward, second: .forward, gap: 2.5)
    }

    /// Reversing just before the first travel ends. The first strip is off-screen at that moment,
    /// but the reversal carries it back across the viewport, so its own deadline — a tenth of a second
    /// away — would remove it mid-screen and leave an empty band travelling between the other two.
    /// It has to live as long as the track now carrying it.
    func testALateReversalLeavesNoEmptyBandBetweenTheStrips() {
        for (first, second) in [(CoreListScrollTarget.Direction.forward, CoreListScrollTarget.Direction.backward),
                                (.backward, .forward)] {
            let fixture = makeFixture()
            fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                          transition: .easeInOut(duration: 0))
            jump(fixture, ids: 1000..<1200, direction: first, duration: 2)
            fixture.tick(dt: 1.9)
            jump(fixture, ids: 5000..<5200, direction: second, duration: 2)

            var worst: CGFloat = 0
            var peakOverlap: CGFloat = 0
            var elapsed: TimeInterval = 0
            while elapsed < 2.1 {
                worst = max(worst, uncoveredHeight(fixture))
                peakOverlap = max(peakOverlap, visibleStaleOverlap(fixture))
                fixture.tick(dt: 1.0 / 60)
                elapsed += 1.0 / 60
            }
            XCTAssertLessThanOrEqual(worst, 1e-6, "empty band during \(first) then \(second)")
            XCTAssertLessThanOrEqual(peakOverlap, 1e-6, "overlap during \(first) then \(second)")
        }
    }

    /// The chat's own shape: jump into old history, then straight back to the newest messages. The
    /// history the second jump loads is the one the first left, so the incoming rows share their
    /// identities with the departed strip still parked in the viewport — a live row and its own
    /// departure coexisting — and the destination touches collection index 0.
    func testJumpingStraightBackToTheNewestMessagesMidFlight() {
        for gap in [0.1, 0.4, 1.0, 1.9] {
            let fixture = makeFixture()
            fixture.listView.applyChanges(scrollTo: .init(index: 0, pointOffset: 0),
                                          transition: .easeInOut(duration: 0))
            jump(fixture, ids: 1000..<1200, to: 100, direction: .forward, duration: 2)
            fixture.tick(dt: gap)
            jump(fixture, ids: 0..<200, to: 0, direction: .backward, duration: 2)

            var peakOverlap: CGFloat = 0
            var worstGap: CGFloat = 0
            var elapsed: TimeInterval = 0
            while elapsed < 2.1 {
                peakOverlap = max(peakOverlap, visibleStaleOverlap(fixture))
                worstGap = max(worstGap, uncoveredHeight(fixture))
                fixture.tick(dt: 1.0 / 60)
                elapsed += 1.0 / 60
            }
            XCTAssertLessThanOrEqual(peakOverlap, 1e-6, "stale over live, gap \(gap)")
            XCTAssertLessThanOrEqual(worstGap, 1e-6, "empty band, gap \(gap)")
            XCTAssertTrue(fixture.ghostMemberViews.isEmpty, "departed rows outlived the travel, gap \(gap)")
        }
    }

    /// An immediate jump ends every travel at once, so nothing an earlier carousel parked may outlive
    /// it: frozen in the viewport, it would sit over the destination until its old deadline.
    func testAnImmediateSecondJumpLeavesNoEarlierStripBehind() {
        let fixture = makeFixture()
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))
        jump(fixture, ids: 1000..<1200, direction: .forward, duration: 2)
        fixture.tick(dt: 0.4)
        XCTAssertFalse(fixture.ghostMemberViews.isEmpty)

        jump(fixture, ids: 5000..<5200, direction: .backward, duration: 0)

        XCTAssertTrue(fixture.ghostMemberViews.isEmpty,
                      "\(fixture.ghostMemberViews.count) departed rows outlived an immediate jump")
        XCTAssertEqual(visibleStaleOverlap(fixture), 0)
    }
}
