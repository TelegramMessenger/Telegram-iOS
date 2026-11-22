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
        view._testAllowsWindowlessScrollAnimation = true
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
        XCTAssertFalse(view.isCameraVisible)
        view.setLevel(.three, animated: false)
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

    private func flingUp(_ view: MediaGridView, from start: CGFloat = 0.0, steps: Int = 5, endingHold: Bool = false) {
        view.engine.decelerationMode = .stepped
        view.engine.applyPanUpdate(state: .began, translation: .zero, velocity: .zero, forced: false, isIndirect: false)
        for step in 1 ... steps {
            view.engine.applyPanUpdate(state: .changed, translation: CGPoint(x: 0.0, y: -24.0 * CGFloat(step)), velocity: CGPoint(x: 0.0, y: -3000.0), forced: false, isIndirect: false)
        }
        if endingHold {
            view.endDragHold()
        }
        view.engine.applyPanUpdate(state: .ended, translation: CGPoint(x: 0.0, y: -24.0 * CGFloat(steps)), velocity: CGPoint(x: 0.0, y: -3000.0), forced: false, isIndirect: false)
    }

    func testHeldDragStaysAtTheTopAndDoesNotFling() {
        let (view, _) = self.makeView(count: 10_000)
        view.holdsDragAtTop = true
        self.flingUp(view)
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
        XCTAssertFalse(view.engine.isDecelerating)
        XCTAssertFalse(view.holdsDragAtTop)
    }

    func testHoldEndedBeforeReleaseStillDoesNotFling() {
        let (view, _) = self.makeView(count: 10_000)
        view.holdsDragAtTop = true
        self.flingUp(view, endingHold: true)
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
        XCTAssertFalse(view.engine.isDecelerating)
    }

    func testReleasingTheHoldMidDragContinuesFromTheTop() {
        let (view, _) = self.makeView(count: 10_000)
        view.engine.decelerationMode = .stepped
        view.holdsDragAtTop = true
        view.engine.applyPanUpdate(state: .began, translation: .zero, velocity: .zero, forced: false, isIndirect: false)
        view.engine.applyPanUpdate(state: .changed, translation: CGPoint(x: 0.0, y: -60.0), velocity: .zero, forced: false, isIndirect: false)
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
        view.holdsDragAtTop = false
        view.engine.applyPanUpdate(state: .changed, translation: CGPoint(x: 0.0, y: -100.0), velocity: .zero, forced: false, isIndirect: false)
        XCTAssertEqual(view.contentOffset, 40.0, accuracy: 1.0)
        view.engine.applyPanUpdate(state: .changed, translation: CGPoint(x: 0.0, y: -80.0), velocity: .zero, forced: false, isIndirect: false)
        XCTAssertEqual(view.contentOffset, 20.0, accuracy: 1.0)
        view.engine.applyPanUpdate(state: .ended, translation: CGPoint(x: 0.0, y: -80.0), velocity: .zero, forced: false, isIndirect: false)
    }

    func testUnheldDragFlings() {
        let (view, _) = self.makeView(count: 10_000)
        self.flingUp(view)
        XCTAssertTrue(view.engine.isDecelerating)
    }

    func testHoldingMidScrollReturnsToTheTop() {
        let (view, _) = self.makeView(count: 10_000)
        view.setContentOffset(300.0)
        view.holdsDragAtTop = true
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
        view.holdsDragAtTop = false
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

    func testReloadImagesRerequestsVisibleCellsWithoutEndingAZoom() {
        let (view, dataSource) = self.makeView(count: 1000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let replacement = UIGraphicsImageRenderer(size: CGSize(width: 4.0, height: 4.0), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 4.0, height: 4.0))
        }
        let offset = view.contentOffset
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        XCTAssertTrue(view.isZooming)
        dataSource.imageForIndex = { _ in replacement }
        let before = dataSource.requests.filter { $0.index == 4 }.count
        view.reloadImages(at: IndexSet([4]))
        XCTAssertTrue(view.isZooming)
        XCTAssertGreaterThan(dataSource.requests.filter { $0.index == 4 }.count, before)
        var cell: MediaGridCellLayer?
        view.forEachVisibleCell { index, visible in
            if index == 4 {
                cell = visible
            }
        }
        XCTAssertTrue(cell?.displayedImage === replacement)
        view._testPinch(.ended, center: center)
        view._testFinishAnimations()
        XCTAssertEqual(view.contentOffset, offset, accuracy: 1e-6)
    }

    func testForEachCellIncludesTheIncomingZoomLayer() {
        let (view, _) = self.makeView(count: 1000)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        var visible = 0
        view.forEachVisibleCell { _, _ in
            visible += 1
        }
        var all = 0
        view.forEachCell { _, _ in
            all += 1
        }
        XCTAssertEqual(all, visible)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 0.8)
        XCTAssertTrue(view.isZooming)
        var active = 0
        view.forEachVisibleCell { _, _ in
            active += 1
        }
        var during = 0
        view.forEachCell { _, _ in
            during += 1
        }
        XCTAssertGreaterThan(during, active)
        view._testPinch(.ended, center: center, scale: 0.8)
        view._testFinishAnimations()
    }

    func testGridGesturesIgnoreTouchesInTheHeaderAndCamera() {
        let (view, _) = self.makeView(count: 1000)
        let header = UIView()
        let button = UIView()
        header.addSubview(button)
        view.headerView = header
        view.headerHeight = 44.0
        let camera = UIView()
        let cameraChild = UIView()
        camera.addSubview(cameraChild)
        view.cameraView = camera
        view.layoutIfNeeded()
        XCTAssertFalse(view.gridGesturesReceiveTouch(in: button))
        XCTAssertFalse(view.gridGesturesReceiveTouch(in: header))
        XCTAssertFalse(view.gridGesturesReceiveTouch(in: cameraChild))
        XCTAssertTrue(view.gridGesturesReceiveTouch(in: view))
        XCTAssertTrue(view.gridGesturesReceiveTouch(in: view.engine.contentHost))
        XCTAssertTrue(view.gridGesturesReceiveTouch(in: nil))
    }
    func testAccessoryTakesTheFirstSlotWithoutACamera() {
        let (view, _) = self.makeView(count: 1000)
        let accessory = UIView()
        view.accessoryView = accessory
        view.layoutIfNeeded()
        guard let first = view.contentFrameForItem(at: 0), let second = view.contentFrameForItem(at: 1) else {
            XCTFail("no frame")
            return
        }
        XCTAssertFalse(accessory.isHidden)
        XCTAssertEqual(accessory.frame.minX, 0.0, accuracy: 1e-6)
        XCTAssertEqual(accessory.frame.minY, first.minY, accuracy: 1e-6)
        XCTAssertEqual(accessory.frame.size.width, first.width, accuracy: 0.5)
        XCTAssertEqual(accessory.frame.size.height, first.height, accuracy: 1e-6)
        XCTAssertGreaterThan(first.minX, accessory.frame.maxX)
        XCTAssertGreaterThan(second.minX, first.maxX)
    }

    func testAccessorySitsRightOfTheCamera() {
        let (view, _) = self.makeView(count: 1000)
        let camera = UIView()
        let accessory = UIView()
        view.cameraView = camera
        view.accessoryView = accessory
        view.layoutIfNeeded()
        guard let first = view.contentFrameForItem(at: 0), let second = view.contentFrameForItem(at: 1) else {
            XCTFail("no frame")
            return
        }
        XCTAssertEqual(camera.frame.minX, 0.0, accuracy: 1e-6)
        XCTAssertGreaterThan(accessory.frame.minX, camera.frame.maxX)
        XCTAssertEqual(accessory.frame.minY, camera.frame.minY, accuracy: 1e-6)
        XCTAssertEqual(accessory.frame.height, first.height, accuracy: 1e-6)
        XCTAssertGreaterThan(first.minX, accessory.frame.maxX)
        XCTAssertEqual(first.minY, accessory.frame.minY, accuracy: 1e-6)
        XCTAssertGreaterThan(second.minY, first.maxY)
        XCTAssertGreaterThan(second.minX, camera.frame.maxX)
        XCTAssertLessThan(second.minX, accessory.frame.maxX)
    }

    func testAccessoryFollowsItsLevels() {
        let (view, _) = self.makeView(count: 1000)
        let accessory = UIView()
        view.accessoryView = accessory
        view.layoutIfNeeded()
        view.setLevel(.five, animated: false)
        XCTAssertFalse(accessory.isHidden)
        XCTAssertGreaterThan(view.contentFrameForItem(at: 0)?.minX ?? 0.0, accessory.frame.maxX)
        view.setLevel(.one, animated: false)
        XCTAssertTrue(accessory.isHidden)
        view.setLevel(.three, animated: false)
        XCTAssertFalse(accessory.isHidden)
        view.accessoryView = nil
        view.layoutIfNeeded()
        XCTAssertNil(accessory.superview)
        XCTAssertEqual(view.contentFrameForItem(at: 0)?.minX ?? -1.0, 0.0, accuracy: 1e-6)
    }

    func testCameraLevelsCanIncludeLevelFive() {
        let (view, _) = self.makeView(count: 1000)
        let camera = UIView()
        view.cameraView = camera
        view.layoutIfNeeded()
        view.setLevel(.five, animated: false)
        view.setContentOffset(0.0)
        XCTAssertFalse(view.isCameraVisible)
        view.cameraLevels = [.three, .five]
        view.layoutIfNeeded()
        XCTAssertTrue(view.isCameraVisible)
        guard let first = view.contentFrameForItem(at: 0) else {
            XCTFail("no frame")
            return
        }
        XCTAssertEqual(camera.frame.width, first.width, accuracy: 0.5)
        XCTAssertEqual(camera.frame.height, first.height * 2.0 + 1.0, accuracy: 0.5)
        XCTAssertGreaterThan(first.minX, camera.frame.maxX)
    }

    func testSelectionPanCanBeDisabled() {
        let (view, _) = self.makeView(count: 1000)
        XCTAssertTrue(view.selectionGesture.isEnabled)
        view.isSelectionPanEnabled = false
        XCTAssertFalse(view.selectionGesture.isEnabled)
        view.isSelectionPanEnabled = true
        XCTAssertTrue(view.selectionGesture.isEnabled)
    }

    func testDisabledZoomKeepsTheLevelAndTheTap() {
        let (view, _) = self.makeView(count: 1000)
        view.isZoomEnabled = false
        var tapped: Int?
        view.onTapItemAt = { index, _ in
            tapped = index
        }
        XCTAssertFalse(view.canZoomIn)
        XCTAssertFalse(view.canZoomOut)
        guard let frame = view.frameForItem(at: 2) else {
            XCTFail("no frame")
            return
        }
        view._testTap(at: CGPoint(x: frame.midX, y: frame.midY))
        XCTAssertEqual(tapped, 2)
        XCTAssertEqual(view.level, .three)
    }

    func testTallCellsFollowTheCellAspect() {
        let (view, _) = self.makeView(count: 1000)
        view.cellAspect = 1.227
        view.layoutIfNeeded()
        guard let frame = view.contentFrameForItem(at: 0) else {
            XCTFail("no frame")
            return
        }
        XCTAssertEqual(frame.height, floor(frame.width * 1.227 * 3.0) / 3.0, accuracy: 0.34)
    }

    func testGridGesturesIgnoreTouchesInTheAccessory() {
        let (view, _) = self.makeView(count: 1000)
        let accessory = UIView()
        let child = UIView()
        accessory.addSubview(child)
        view.accessoryView = accessory
        view.layoutIfNeeded()
        XCTAssertFalse(view.gridGesturesReceiveTouch(in: child))
        XCTAssertFalse(view.gridGesturesReceiveTouch(in: accessory))
        XCTAssertTrue(view.gridGesturesReceiveTouch(in: view))
    }
}
