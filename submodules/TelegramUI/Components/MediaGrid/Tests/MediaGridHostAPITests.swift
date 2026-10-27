import XCTest
@testable import CoreList
@testable import MediaGrid

final class MediaGridHostAPITests: XCTestCase {
    private func makeView(count: Int, layout: Bool = true) -> (MediaGridView, TestDataSource) {
        let dataSource = TestDataSource(count: count)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.motionClock = { 0.0 }
        view.scaleOverride = 3.0
        view.requiresWindowForScrollAnimation = false
        if layout {
            view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
            view.layoutIfNeeded()
        }
        return (view, dataSource)
    }

    func testHeaderRegionSitsAboveTheFirstRowAndScrollsWithContent() {
        let (view, _) = self.makeView(count: 1000)
        let heightWithoutHeader = view.contentHeight
        let header = UIView()
        view.geometryInsets = UIEdgeInsets(top: 100.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.headerView = header
        view.headerHeight = 44.0
        view.layoutIfNeeded()

        XCTAssertEqual(header.frame, CGRect(x: 0.0, y: 100.0, width: 393.0, height: 44.0))
        XCTAssertEqual(view.contentFrameForItem(at: 0)?.minY ?? -1.0, 144.0, accuracy: 1e-6)
        XCTAssertEqual(view.contentHeight, heightWithoutHeader + 144.0, accuracy: 1e-6)
        XCTAssertEqual(view.frameForItem(at: 0)?.minY ?? -1.0, 144.0, accuracy: 1e-6)

        view.setContentOffset(30.0)
        XCTAssertEqual(header.frame.minY, 100.0, accuracy: 1e-6)
        XCTAssertEqual(header.convert(header.bounds, to: view).minY, 70.0, accuracy: 1e-6)
        XCTAssertEqual(view.frameForItem(at: 0)?.minY ?? -1.0, 114.0, accuracy: 1e-6)

        view.headerHeight = 0.0
        view.layoutIfNeeded()
        XCTAssertEqual(view.contentFrameForItem(at: 0)?.minY ?? -1.0, 100.0, accuracy: 1e-6)
        XCTAssertEqual(header.frame.height, 0.0, accuracy: 1e-6)

        view.headerView = nil
        XCTAssertNil(header.superview)
    }

    func testAnimatedScrollToTopReachesTheTopThroughIntermediateOffsets() {
        let (view, _) = self.makeView(count: 10_000)
        var now: CFTimeInterval = 10.0
        view.motionClock = { now }
        view.setContentOffset(600.0)
        view.scrollToTop(animated: true)
        XCTAssertTrue(view.isAnimatingScroll)
        XCTAssertEqual(view.contentOffset, 600.0, accuracy: 1e-6)

        now += MediaGridView.scrollToTopDuration * 0.5
        view._testStepScrollAnimation()
        XCTAssertGreaterThan(view.contentOffset, 0.0)
        XCTAssertLessThan(view.contentOffset, 600.0)

        now += MediaGridView.scrollToTopDuration
        view._testStepScrollAnimation()
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
        XCTAssertFalse(view.isAnimatingScroll)
    }

    func testAnimatedScrollToTopFromFarAwayJumpsCloseFirst() {
        let (view, _) = self.makeView(count: 100_000)
        var now: CFTimeInterval = 10.0
        view.motionClock = { now }
        view.setContentOffset(view.contentHeight / 2.0)
        view.scrollToTop(animated: true)
        XCTAssertLessThanOrEqual(view.contentOffset, MediaGridView.scrollToTopMaxDistance * view.bounds.height + 1e-6)
        now += MediaGridView.scrollToTopDuration * 2.0
        view._testStepScrollAnimation()
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
    }

    func testUnanimatedScrollToTopAndDragCancelsAnimation() {
        let (view, _) = self.makeView(count: 10_000)
        var now: CFTimeInterval = 10.0
        view.motionClock = { now }
        view.setContentOffset(500.0)
        view.scrollToTop(animated: false)
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)

        view.setContentOffset(500.0)
        view.scrollToTop(animated: true)
        var began = 0
        view.onWillBeginDragging = {
            began += 1
        }
        view.engine.onWillBeginDragging?()
        XCTAssertEqual(began, 1)
        XCTAssertFalse(view.isAnimatingScroll)
        now += MediaGridView.scrollToTopDuration * 2.0
        view._testStepScrollAnimation()
        XCTAssertEqual(view.contentOffset, 500.0, accuracy: 1e-6)
    }

    func testScrollToEndBeforeTheFirstLayoutLandsAtTheEnd() {
        let (view, _) = self.makeView(count: 1000, layout: false)
        view.scrollToEnd()
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        XCTAssertGreaterThan(view.contentOffset, 0.0)
        XCTAssertEqual(view.contentOffset, view.contentHeight - view.bounds.height, accuracy: 1e-6)
    }

    func testScrollToEndAfterLayout() {
        let (view, _) = self.makeView(count: 1000)
        view.scrollToEnd()
        XCTAssertEqual(view.contentOffset, view.contentHeight - view.bounds.height, accuracy: 1e-6)
    }

    func testCameraVisibilityFollowsTheViewportAndLevel() {
        let (view, _) = self.makeView(count: 1000)
        let camera = UIView()
        view.cameraView = camera
        view.layoutIfNeeded()
        XCTAssertTrue(view.isCameraVisible)
        view.setContentOffset(2000.0)
        XCTAssertFalse(view.isCameraVisible)
        view.setContentOffset(0.0)
        view.setLevel(.fifteen, animated: false)
        XCTAssertFalse(view.isCameraVisible)
        view.setLevel(.five, animated: false)
        view.setContentOffset(0.0)
        XCTAssertTrue(view.isCameraVisible)
    }

    func testDisabledBounceClampsOverscrollAtTheTop() {
        let (view, _) = self.makeView(count: 1000)
        view._testSetRawOffset(-40.0)
        XCTAssertEqual(view.contentOffset, -40.0, accuracy: 1e-6)
        view.bounces = false
        view._testSetRawOffset(-40.0)
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
        view._testSetRawOffset(30.0)
        XCTAssertEqual(view.contentOffset, 30.0, accuracy: 1e-6)
    }

    func testSelectionPanBeganIsReported() {
        let (view, _) = self.makeView(count: 1000)
        var began = 0
        view.onSelectionPanBegan = {
            began += 1
        }
        view.selectionGesture.updateIsScrollEnabled(false)
        XCTAssertEqual(began, 1)
        view.selectionGesture.updateIsScrollEnabled(true)
        XCTAssertEqual(began, 1)
    }

    func testTapReportsTheLocation() {
        let (view, _) = self.makeView(count: 1000)
        var tapped: (Int, CGPoint)?
        view.onTapItemAt = { index, point in
            tapped = (index, point)
        }
        guard let frame = view.frameForItem(at: 4) else {
            XCTFail("no frame")
            return
        }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        view._testTap(at: point)
        XCTAssertEqual(tapped?.0, 4)
        XCTAssertEqual(tapped?.1, point)
    }

    func testOverlayViewIsAboveTheCellsInContentCoordinates() {
        let (view, _) = self.makeView(count: 1000)
        let overlay = view.overlayView
        XCTAssertFalse(overlay.isUserInteractionEnabled)
        view.setContentOffset(300.0)
        let child = UIView(frame: view.contentFrameForItem(at: 30) ?? .zero)
        overlay.addSubview(child)
        let frame = child.convert(child.bounds, to: view)
        XCTAssertEqual(frame.minY, (view.frameForItem(at: 30)?.minY ?? 0.0), accuracy: 1e-6)
        XCTAssertFalse(view.isZooming)
    }

    func testDisplayedImageIsTheSharpImageOnly() {
        let (view, dataSource) = self.makeView(count: 100)
        var cell: MediaGridCellLayer?
        view.forEachVisibleCell { index, visible in
            if index == 0 {
                cell = visible
            }
        }
        XCTAssertNotNil(cell?.displayedImage)
        dataSource.providesThumbnails = true
        let thumbnailCell = MediaGridCellLayer()
        if let thumbnail = dataSource.thumbnail(at: 3) {
            thumbnailCell.setThumbnail(thumbnail, cellAspect: 1.0)
        }
        XCTAssertTrue(thumbnailCell.isShowingThumbnail)
        XCTAssertNil(thumbnailCell.displayedImage)
    }

    private func drag(_ view: MediaGridView, _ state: UIGestureRecognizer.State, _ translation: CGFloat) {
        view.engine.applyPanUpdate(state: state, translation: CGPoint(x: 0.0, y: translation), velocity: .zero, forced: false, isIndirect: false)
    }

    func testSettingTheOffsetMidDragContinuesTheDragFromThere() {
        let (view, _) = self.makeView(count: 10_000)
        view.setContentOffset(500.0)
        self.drag(view, .began, 0.0)
        self.drag(view, .changed, -100.0)
        XCTAssertEqual(view.contentOffset, 600.0, accuracy: 1.0)
        view.setContentOffset(0.0)
        self.drag(view, .changed, -110.0)
        XCTAssertEqual(view.contentOffset, 10.0, accuracy: 1.0)
        view.reanchorDrag()
        self.drag(view, .changed, -130.0)
        XCTAssertEqual(view.contentOffset, 30.0, accuracy: 1.0)
        self.drag(view, .ended, -130.0)
    }

    func testDisabledBounceHoldsADragAtTheTop() {
        let (view, _) = self.makeView(count: 10_000)
        view.bounces = false
        self.drag(view, .began, 0.0)
        self.drag(view, .changed, 80.0)
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
        self.drag(view, .changed, 120.0)
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
        self.drag(view, .changed, 80.0)
        XCTAssertEqual(view.contentOffset, 40.0, accuracy: 1.0)
        self.drag(view, .ended, 0.0)
    }

    func testZoomingChangesAreReported() {
        let (view, _) = self.makeView(count: 1000)
        var events: [Bool] = []
        view.onZoomingChanged = { isZooming in
            events.append(isZooming)
        }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        XCTAssertEqual(events, [true])
        view._testPinch(.changed, center: center, scale: 0.7)
        view._testPinch(.ended, center: center, scale: 0.7)
        view._testFinishAnimations()
        XCTAssertEqual(events, [true, false])
        XCTAssertFalse(view.isZooming)

        view.zoomOut()
        XCTAssertEqual(events, [true, false, true])
        view._testFinishAnimations()
        XCTAssertEqual(events, [true, false, true, false])
    }
}
