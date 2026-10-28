import XCTest
@testable import CoreList
@testable import MediaGrid

final class MediaGridVisibleRangeTests: XCTestCase {
    private var time: CFTimeInterval = 0.0

    private func makeView(count: Int = 1000) -> MediaGridView {
        let dataSource = TestDataSource(count: count)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.motionClock = { [unowned self] in
            return self.time
        }
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0)
        view.layoutIfNeeded()
        return view
    }

    func testVisibleRangeAfterLayout() {
        let view = self.makeView()
        guard let range = view.visibleIndexRange, let layout = view.gridLayout else {
            XCTFail("no range")
            return
        }
        XCTAssertEqual(range.lowerBound, 0)
        XCTAssertEqual(range, layout.indexRange(intersecting: CGRect(x: 0.0, y: view.contentOffset, width: 390.0, height: 844.0)))
        XCTAssertGreaterThan(range.count, 3)
    }

    func testVisibleRangeCallbackOnScroll() {
        let view = self.makeView()
        var reported: [Range<Int>] = []
        view.onVisibleRangeChanged = { reported.append($0) }
        view.setContentOffset(844.0)
        XCTAssertEqual(reported.count, 1)
        XCTAssertEqual(reported.last, view.visibleIndexRange)
        XCTAssertGreaterThan(reported.last?.lowerBound ?? 0, 0)
    }

    func testVisibleRangeCallbackNotRepeated() {
        let view = self.makeView()
        view.setContentOffset(844.0)
        var reported: [Range<Int>] = []
        view.onVisibleRangeChanged = { reported.append($0) }
        view.setContentOffset(845.0)
        view.setContentOffset(845.0)
        let rowHeight = view.contentFrameForItem(at: 0)?.height ?? 0.0
        XCTAssertGreaterThan(rowHeight, 1.0)
        XCTAssertTrue(reported.count <= 1)
        let before = reported.count
        view.setContentOffset(845.0)
        XCTAssertEqual(reported.count, before)
    }

    func testVisibleRangeCallbackOnZoomLanding() {
        let view = self.makeView()
        var reported: [Range<Int>] = []
        view.onVisibleRangeChanged = { reported.append($0) }
        view.setLevel(.five, animated: false)
        XCTAssertEqual(reported.last, view.visibleIndexRange)
        XCTAssertFalse(reported.isEmpty)
    }

    func testTransferVelocityStartsFling() {
        let view = self.makeView(count: 10_000)
        view._testAllowsWindowlessScrollAnimation = true
        let start = view.contentOffset
        view.transferVelocity(2.0)
        for _ in 0 ..< 10 {
            self.time += 1.0 / 60.0
            view._testStepTransferredVelocity()
        }
        XCTAssertGreaterThan(view.contentOffset, start + 10.0)
    }

    func testTransferVelocityIgnoresNonPositive() {
        let view = self.makeView(count: 10_000)
        view.setContentOffset(1000.0)
        view.transferVelocity(-2.0)
        self.time += 1.0 / 60.0
        view._testStepTransferredVelocity()
        XCTAssertEqual(view.contentOffset, 1000.0, accuracy: 1e-6)
    }

    func testScrollLockPinsToTopAndDisablesScrolling() {
        let view = self.makeView(count: 10_000)
        view.setContentOffset(2000.0)
        view.isScrollingLockedAtTop = true
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
        XCTAssertFalse(view.engine.isScrollEnabled)
        view.isScrollingLockedAtTop = false
        XCTAssertTrue(view.engine.isScrollEnabled)
    }

    func testScrollLockSurvivesAZoom() {
        let view = self.makeView(count: 10_000)
        view.isScrollingLockedAtTop = true
        view.setLevel(.five, animated: true)
        view._testFinishAnimations()
        XCTAssertFalse(view.engine.isScrollEnabled)
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
    }

    func testTransferVelocityWithoutAWindowDoesNotStayAnimating() {
        let view = self.makeView(count: 10_000)
        view.transferVelocity(2.0)
        XCTAssertFalse(view.isAnimatingScroll)
    }
}
