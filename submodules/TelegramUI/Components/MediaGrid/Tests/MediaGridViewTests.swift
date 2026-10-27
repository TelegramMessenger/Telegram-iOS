import XCTest
@testable import MediaGrid

final class MediaGridViewTests: XCTestCase {
    private var createdCells: [ObjectIdentifier: MediaGridCellLayer] = [:]

    private func makeView(count: Int) -> (MediaGridView, TestDataSource) {
        let dataSource = TestDataSource(count: count)
        let view = MediaGridView(dataSource: dataSource, cellFactory: { [unowned self] in
            let cell = MediaGridCellLayer()
            self.createdCells[ObjectIdentifier(cell)] = cell
            return cell
        })
        view.motionClock = { 0.0 }
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        return (view, dataSource)
    }

    private func visibleCells(_ view: MediaGridView) -> [Int: MediaGridCellLayer] {
        var result: [Int: MediaGridCellLayer] = [:]
        view.forEachVisibleCell { index, cell in
            result[index] = cell
        }
        return result
    }

    private func viewport(_ view: MediaGridView) -> CGRect {
        return CGRect(x: 0.0, y: view.contentOffset, width: view.bounds.width, height: view.bounds.height)
    }

    override func tearDown() {
        self.createdCells = [:]
        super.tearDown()
    }

    func testVisibleCellsMatchLayout() {
        let (view, _) = self.makeView(count: 100_000)
        XCTAssertEqual(view.level, .three)
        let height = view.contentHeight
        for offset in [0.0, 5000.0, height / 2.0, height - view.bounds.height] {
            view.setContentOffset(offset)
            XCTAssertEqual(view.contentOffset, offset, accuracy: 0.001)
            guard let layout = view.currentLayout else {
                XCTFail("no layout")
                return
            }
            let viewport = self.viewport(view)
            let window = layout.indexRange(intersecting: viewport.insetBy(dx: 0.0, dy: -view.bounds.height))
            let cells = self.visibleCells(view)
            XCTAssertFalse(cells.isEmpty)
            for (index, cell) in cells {
                XCTAssertTrue(window.contains(index), "index \(index) outside window \(window) at offset \(offset)")
                XCTAssertEqual(cell.index, index)
                let expected = layout.frame(at: index)
                XCTAssertEqual(cell.frame.minX, expected.minX, accuracy: 1e-6)
                XCTAssertEqual(cell.frame.minY, expected.minY, accuracy: 1e-6)
                XCTAssertEqual(cell.frame.width, expected.width, accuracy: 1e-6)
                XCTAssertEqual(cell.frame.height, expected.height, accuracy: 1e-6)
                XCTAssertFalse(cell.isHidden)
            }
            for index in layout.indexRange(intersecting: viewport) {
                XCTAssertNotNil(cells[index], "viewport index \(index) not visible at offset \(offset)")
            }
        }
    }

    func testFarJumpReusesCells() {
        let (view, _) = self.makeView(count: 100_000)
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        let pitch = layout.itemSize.height + 1.0
        let target = view.contentHeight / 2.0
        view.setContentOffset(target - 100.0 * pitch)
        let before = self.visibleCells(view)
        let identitiesBefore = Set(before.values.map(ObjectIdentifier.init))
        let sublayersBefore = view.activeLayoutLayer.sublayers?.count ?? 0

        view.setContentOffset(target)
        let after = self.visibleCells(view)
        XCTAssertTrue(Set(before.keys).isDisjoint(with: Set(after.keys)))
        XCTAssertEqual(Set(after.values.map(ObjectIdentifier.init)), identitiesBefore)
        XCTAssertLessThanOrEqual(self.createdCells.count, 2 * after.count)
        XCTAssertLessThanOrEqual(view.activeLayoutLayer.sublayers?.count ?? 0, sublayersBefore)
    }

    func testCancelsOffscreenRequests() {
        let (view, dataSource) = self.makeView(count: 100_000)
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        let pitch = layout.itemSize.height + 1.0
        let target = view.contentHeight / 2.0
        view.setContentOffset(target - 100.0 * pitch)
        let before = self.visibleCells(view)
        let cancelsBefore = dataSource.cancelCount

        view.setContentOffset(target)
        let after = self.visibleCells(view)
        let left = Set(before.keys).subtracting(after.keys).count
        XCTAssertGreaterThan(left, 0)
        XCTAssertGreaterThanOrEqual(dataSource.cancelCount - cancelsBefore, left)
    }

    func testEmptyAndTiny() {
        for count in [0, 1] {
            let (view, _) = self.makeView(count: count)
            XCTAssertGreaterThanOrEqual(view.contentHeight, 0.0)
            view.setContentOffset(100.0)
            view.layoutIfNeeded()
            XCTAssertEqual(self.visibleCells(view).count, count)
            if count == 1 {
                XCTAssertNotNil(view.frameForItem(at: 0))
            }
            XCTAssertNil(view.frameForItem(at: count))
        }
    }

    func testFlightStartsCachingAtLanding() {
        let (view, dataSource) = self.makeView(count: 100_000)
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        XCTAssertFalse(dataSource.cachedIndices.isEmpty)
        let landing = view.contentHeight / 2.0
        XCTAssertFalse(dataSource.cachedIndices.contains(layout.indexRange(intersecting: CGRect(x: 0.0, y: landing, width: 393.0, height: 1.0)).lowerBound))
        view._testFlight(settledOffset: landing)
        let expected = layout.indexRange(intersecting: CGRect(x: 0.0, y: landing - view.bounds.height, width: 393.0, height: view.bounds.height * 3.0))
        XCTAssertFalse(expected.isEmpty)
        XCTAssertTrue(Set(expected).isSubset(of: dataSource.cachedIndices))
        let viewport = layout.indexRange(intersecting: CGRect(x: 0.0, y: 0.0, width: 393.0, height: view.bounds.height))
        XCTAssertTrue(Set(viewport).isSubset(of: dataSource.cachedIndices))
        view._testFlight(settledOffset: nil)
        XCTAssertTrue(Set(expected).isDisjoint(with: dataSource.cachedIndices))
        XCTAssertTrue(Set(viewport).isSubset(of: dataSource.cachedIndices))
    }

    func testFinalNilKeepsDegradedImage() {
        let dataSource = TestDataSource(count: 10)
        dataSource.deliveries = [(TestDataSource.sampleImage, true), (nil, false)]
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        var count = 0
        view.forEachVisibleCell { _, cell in
            count += 1
            XCTAssertNotNil(cell.contents)
        }
        XCTAssertEqual(count, 10)
    }

    func testScrubToEndAndBack() {
        let (view, _) = self.makeView(count: 100_000)
        view.geometryInsets = UIEdgeInsets(top: 100.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        view.setContentOffset(view.contentHeight - view.bounds.height)
        var cells = self.visibleCells(view)
        XCTAssertNotNil(cells[99_999])
        XCTAssertLessThanOrEqual(layout.frame(at: 99_999).maxY, view.contentOffset + view.bounds.height)
        for index in layout.indexRange(intersecting: self.viewport(view)) {
            XCTAssertNotNil(cells[index]?.contents, "index \(index) has no image at the end")
        }
        view.setContentOffset(0.0)
        cells = self.visibleCells(view)
        XCTAssertNotNil(cells[0])
        XCTAssertEqual(layout.frame(at: 0).minY, 100.0, accuracy: 1e-6)
        for index in layout.indexRange(intersecting: self.viewport(view)) {
            XCTAssertNotNil(cells[index]?.contents, "index \(index) has no image at the start")
        }
    }

    func testTopVisibleIndexAndDate() {
        let (view, dataSource) = self.makeView(count: 100_000)
        view.geometryInsets = UIEdgeInsets(top: 100.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        XCTAssertEqual(view.topVisibleIndex, 0)
        XCTAssertEqual(view.topVisibleDate, dataSource.date(at: 0))
        let calls = dataSource.dateCalls[0] ?? 0
        _ = view.topVisibleDate
        _ = view.topVisibleDate
        XCTAssertEqual(dataSource.dateCalls[0], calls)
        let target = 10 * layout.columns
        view.setContentOffset(layout.frame(at: target).minY - 100.0)
        XCTAssertEqual(view.topVisibleIndex, target)
        XCTAssertEqual(view.topVisibleDate, dataSource.date(at: target))
        let targetCalls = dataSource.dateCalls[target] ?? 0
        _ = view.topVisibleDate
        XCTAssertEqual(dataSource.dateCalls[target], targetCalls)
        view.reloadData()
        _ = view.topVisibleDate
        XCTAssertEqual(dataSource.dateCalls[target], targetCalls + 1)
    }

    func testTopVisibleIndexInBottomOverscroll() {
        let (view, _) = self.makeView(count: 1000)
        view.setContentOffset(view.contentHeight - view.bounds.height)
        let expected = view.topVisibleIndex
        XCTAssertNotNil(expected)
        view._testSetRawOffset(view.contentHeight + 300.0)
        XCTAssertNotNil(view.topVisibleIndex)
        XCTAssertNotNil(view.topVisibleDate)
    }

    func testListenerSeesFinalOffsetOfNestedWrite() {
        let (view, _) = self.makeView(count: 100_000)
        var received: [CGFloat] = []
        view.onScroll = { [unowned view] offset in
            received.append(offset)
            if offset == 500.0 {
                view.setContentOffset(1234.0)
            }
        }
        view.setContentOffset(500.0)
        XCTAssertEqual(received.last ?? -1.0, view.contentOffset, accuracy: 0.001)
        XCTAssertEqual(view.contentOffset, 1234.0, accuracy: 0.001)
    }

    func testTopVisibleIndexEmpty() {
        let (view, _) = self.makeView(count: 0)
        XCTAssertNil(view.topVisibleIndex)
        XCTAssertNil(view.topVisibleDate)
    }

    func testSetContentOffsetFromOnScrollDoesNotRecurse() {
        let (view, _) = self.makeView(count: 100_000)
        var calls = 0
        view.onScroll = { [unowned view] _ in
            calls += 1
            XCTAssertLessThan(calls, 5)
            view.setContentOffset(1234.0)
        }
        view.setContentOffset(500.0)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(view.contentOffset, 1234.0, accuracy: 0.001)
    }

    func testOffsetBeforeFirstLayoutIsKeptAndClamped() {
        let dataSource = TestDataSource(count: 100_000)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.scaleOverride = 3.0
        view.setContentOffset(777.0)
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        XCTAssertEqual(view.contentOffset, 777.0, accuracy: 0.001)

        let other = MediaGridView(dataSource: TestDataSource(count: 10), cellFactory: {
            return MediaGridCellLayer()
        })
        other.scaleOverride = 3.0
        other.setContentOffset(1.0e9)
        other.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        other.layoutIfNeeded()
        XCTAssertEqual(other.contentOffset, max(0.0, other.contentHeight - 852.0), accuracy: 0.001)
    }

    func testIsUserScrollingFalseAtRest() {
        let (view, _) = self.makeView(count: 1000)
        XCTAssertFalse(view.isUserScrolling)
        view.setContentOffset(300.0)
        XCTAssertFalse(view.isUserScrolling)
    }

    func testTapAtInteractiveLevelReportsIndex() {
        let (view, _) = self.makeView(count: 1000)
        guard let frame = view.frameForItem(at: 7) else {
            XCTFail("no frame")
            return
        }
        var tapped: [Int] = []
        view.onTapItem = { tapped.append($0) }
        view._testTap(at: CGPoint(x: frame.midX, y: frame.midY))
        XCTAssertEqual(tapped, [7])
        view.setContentOffset(2000.0)
        guard let moved = view.frameForItem(at: 400) else {
            XCTFail("no frame")
            return
        }
        view._testTap(at: CGPoint(x: moved.midX, y: moved.midY))
        XCTAssertEqual(tapped, [7, 400])
        XCTAssertEqual(view.index(at: CGPoint(x: moved.midX, y: moved.midY)), 400)
    }

    func testTapRefreshesSelection() {
        let selected = Box()
        let dataSource = TestDataSource(count: 100)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return SelectableTestCell()
        })
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.isItemSelected = { selected.values.contains($0) }
        view.onTapItem = { selected.values.insert($0) }
        view.layoutIfNeeded()
        guard let frame = view.frameForItem(at: 3) else {
            XCTFail("no frame")
            return
        }
        view._testTap(at: CGPoint(x: frame.midX, y: frame.midY))
        var result: [Int: Bool] = [:]
        view.forEachVisibleCell { index, cell in
            result[index] = (cell as? SelectableTestCell)?.selected
        }
        XCTAssertEqual(result[3], true)
        XCTAssertEqual(result[2], false)
    }

    func testCameraTakesTwoSlots() {
        let (view, _) = self.makeView(count: 100)
        let camera = UIView()
        view.cameraView = camera
        view.layoutIfNeeded()
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        let expected = layout.reservedFrame([MediaGridSlot(row: 0, column: 0), MediaGridSlot(row: 1, column: 0)])
        XCTAssertEqual(camera.frame, expected)
        XCTAssertEqual(camera.frame.height, 2.0 * layout.itemSize.height + 1.0, accuracy: 1e-6)
        XCTAssertEqual(layout.frame(at: 0).minX, layout.itemSize.width + 1.0, accuracy: 1e-6)
        XCTAssertEqual(layout.frame(at: 0).minY, 0.0, accuracy: 1e-6)
        XCTAssertEqual(layout.frame(at: 2).minX, layout.itemSize.width + 1.0, accuracy: 1e-6)
        XCTAssertEqual(layout.frame(at: 2).minY, layout.itemSize.height + 1.0, accuracy: 1e-6)
        XCTAssertEqual(layout.frame(at: 4).minY, 2.0 * (layout.itemSize.height + 1.0), accuracy: 1e-6)
        XCTAssertEqual(layout.frame(at: 4).minX, 0.0, accuracy: 1e-6)
        XCTAssertTrue(camera.superview === view.subviews.first)
        XCTAssertNil(view.index(at: CGPoint(x: camera.frame.midX, y: camera.frame.midY)))
    }

    func testNoCameraSlotsAtFifteen() {
        let (view, _) = self.makeView(count: 100)
        let camera = UIView()
        view.cameraView = camera
        view.layoutIfNeeded()
        let cameraCentre = CGPoint(x: camera.frame.midX, y: camera.frame.midY)
        XCTAssertNil(view.index(at: cameraCentre))
        view.setLevel(.fifteen, animated: false)
        XCTAssertEqual(view.level, .fifteen)
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        XCTAssertEqual(layout.columns, 15)
        XCTAssertEqual(layout.frame(at: 0).minX, 0.0, accuracy: 1e-6)
        XCTAssertEqual(layout.frame(at: 0).minY, 0.0, accuracy: 1e-6)
        XCTAssertEqual(layout.frame(at: 15).minY, layout.itemSize.height + 1.0, accuracy: 1e-6)
        XCTAssertNotNil(view.index(at: CGPoint(x: 5.0, y: 5.0)))
        XCTAssertEqual(camera.alpha, 0.0)
    }

    func testCompactDetailAtFifteen() {
        let dataSource = TestDataSource(count: 100)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return DetailRecordingCell()
        })
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        var details: Set<String> = []
        view.forEachVisibleCell { _, cell in
            details.insert("\((cell as! DetailRecordingCell).detail!)")
        }
        XCTAssertEqual(details, ["full"])
        view.setLevel(.fifteen, animated: false)
        details = []
        view.forEachVisibleCell { _, cell in
            details.insert("\((cell as! DetailRecordingCell).detail!)")
        }
        XCTAssertEqual(details, ["compact"])
    }

    func testTopInsetShiftsContent() {
        let (view, _) = self.makeView(count: 1000)
        view.geometryInsets = UIEdgeInsets(top: 60.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        XCTAssertEqual(view.frameForItem(at: 0)?.minY ?? -1.0, 60.0, accuracy: 1e-6)
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
    }

    func testTopInsetDecreaseClampsAtTopAndNotifies() {
        let (view, _) = self.makeView(count: 1000)
        view.geometryInsets = UIEdgeInsets(top: 100.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        view.setContentOffset(20.0)
        var last: CGFloat?
        view.onScroll = { last = $0 }
        view.geometryInsets = UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        XCTAssertEqual(view.contentOffset, 0.0, accuracy: 1e-6)
        XCTAssertEqual(last ?? -1.0, 0.0, accuracy: 1e-6)
    }

    func testTopInsetChangeKeepsVisibleContentInPlace() {
        let (view, _) = self.makeView(count: 1000)
        view.geometryInsets = UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        view.setContentOffset(1000.0)
        let before = view.frameForItem(at: 30)?.minY ?? 0.0
        view.geometryInsets = UIEdgeInsets(top: 100.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        XCTAssertEqual(view.contentOffset, 1056.0, accuracy: 1e-6)
        XCTAssertEqual(view.frameForItem(at: 30)?.minY ?? -1.0, before, accuracy: 1e-6)
        view.geometryInsets = UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        XCTAssertEqual(view.contentOffset, 1000.0, accuracy: 1e-6)
        XCTAssertEqual(view.frameForItem(at: 30)?.minY ?? -1.0, before, accuracy: 1e-6)
    }

    func testZoomInFromThirtyOneByTap() {
        let (view, _) = self.makeView(count: 100_000)
        view.setLevel(.thirtyOne, animated: false)
        XCTAssertEqual(view.level, .thirtyOne)
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        view.setContentOffset(layout.frame(at: 4000).minY - 300.0)
        guard let frame = view.frameForItem(at: 4000) else {
            XCTFail("no frame")
            return
        }
        var levels: [MediaGridLevel] = []
        view.onLevelChanged = { levels.append($0) }
        var tapped: [Int] = []
        view.onTapItem = { tapped.append($0) }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        view._testTap(at: point)
        XCTAssertTrue(tapped.isEmpty)
        XCTAssertEqual(view.level, .thirtyOne)
        XCTAssertEqual(levels, [])
        XCTAssertFalse(view.engine.isScrollEnabled)
        view._testFinishAnimations()
        XCTAssertTrue(view.engine.isScrollEnabled)
        XCTAssertEqual(levels, [.fifteen])
        XCTAssertEqual(view.currentLayout?.columns, 15)
        guard let zoomed = view.frameForItem(at: 4000) else {
            XCTFail("no frame")
            return
        }
        XCTAssertTrue(zoomed.minY <= point.y && point.y < zoomed.maxY, "\(zoomed) \(point)")
        XCTAssertEqual(zoomed.midY, point.y, accuracy: 0.5)
        XCTAssertEqual(view.index(at: CGPoint(x: zoomed.midX, y: zoomed.midY)), 4000)
    }

    func testAnimatedZoomBuildsTwoLayersAndSettles() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let host = view.subviews[0].layer
        let layoutLayersBefore = host.sublayers?.filter { $0 is MediaGridLayoutLayer }.count
        XCTAssertEqual(layoutLayersBefore, 1)
        let outgoing = view.activeLayoutLayer
        view.zoomOut()
        XCTAssertEqual(view.level, .three)
        let during = host.sublayers?.compactMap { $0 as? MediaGridLayoutLayer } ?? []
        XCTAssertEqual(during.count, 2)
        guard let incoming = during.first(where: { $0 !== outgoing }) else {
            XCTFail("no incoming layer")
            return
        }
        XCTAssertNotNil(outgoing.animation(forKey: "mediaGridZoom.transform"))
        XCTAssertNotNil(incoming.animation(forKey: "mediaGridZoom.opacity"))
        XCTAssertEqual(outgoing.opacity, 0.0)
        XCTAssertEqual(incoming.opacity, 1.0)
        XCTAssertTrue(CATransform3DIsIdentity(incoming.transform))
        XCTAssertFalse(incoming.visibleCells.isEmpty)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
        let after = host.sublayers?.compactMap { $0 as? MediaGridLayoutLayer } ?? []
        XCTAssertEqual(after.count, 1)
        XCTAssertTrue(after.first === incoming)
        XCTAssertTrue(view.activeLayoutLayer === incoming)
        XCTAssertTrue(outgoing.visibleCells.isEmpty)
        XCTAssertTrue(CATransform3DIsIdentity(incoming.transform))
        XCTAssertEqual(incoming.opacity, 1.0)
        XCTAssertEqual(incoming.frame.minY, 0.0)
        XCTAssertNil(incoming.animation(forKey: "mediaGridZoom.transform"))
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        XCTAssertEqual(layout.columns, 5)
        let window = layout.indexRange(intersecting: self.viewport(view).insetBy(dx: 0.0, dy: -view.bounds.height))
        XCTAssertEqual(Set(self.visibleCells(view).keys), Set(window))
        view.zoomIn()
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .three)
        XCTAssertTrue(view.activeLayoutLayer === outgoing)
    }

    func testCameraMovesBetweenSlotsAtThreeToFive() {
        let (view, _) = self.makeView(count: 1000)
        let camera = UIView()
        view.cameraView = camera
        view.layoutIfNeeded()
        let slots: Set<MediaGridSlot> = [MediaGridSlot(row: 0, column: 0), MediaGridSlot(row: 1, column: 0)]
        guard let sourceFrame = view.currentLayout?.reservedFrame(slots) else {
            XCTFail("no camera frame")
            return
        }
        view.zoomOut()
        guard let transition = view.transition, let targetFrame = (transition.targetLayout as? MediaGridUniformLayout)?.reservedFrame(slots) else {
            XCTFail("no transition")
            return
        }
        let shift = view.contentOffset - transition.targetOffset
        transition.apply(progress: 0.0)
        XCTAssertEqual(camera.frame.minX, sourceFrame.minX, accuracy: 1e-6)
        XCTAssertEqual(camera.frame.minY, sourceFrame.minY, accuracy: 1e-6)
        XCTAssertEqual(camera.frame.width, sourceFrame.width, accuracy: 1e-6)
        XCTAssertEqual(camera.frame.height, sourceFrame.height, accuracy: 1e-6)
        XCTAssertEqual(camera.alpha, 1.0)
        transition.apply(progress: 1.0)
        XCTAssertEqual(camera.frame.minX, targetFrame.minX, accuracy: 1e-6)
        XCTAssertEqual(camera.frame.minY, targetFrame.minY + shift, accuracy: 1e-6)
        XCTAssertEqual(camera.frame.width, targetFrame.width, accuracy: 1e-6)
        XCTAssertEqual(camera.frame.height, targetFrame.height, accuracy: 1e-6)
        XCTAssertEqual(camera.alpha, 1.0)
        view._testFinishAnimations()
        XCTAssertEqual(camera.frame, targetFrame)
    }

    func testAnchorMapsToItselfAtDeepOffset() {
        let (view, _) = self.makeView(count: 100_000)
        for (from, to) in [(MediaGridLevel.three, MediaGridLevel.five), (.five, .three)] {
            view.setLevel(from, animated: false)
            guard let source = view.currentLayout else {
                XCTFail("no layout")
                return
            }
            view.setContentOffset(source.frame(at: 90_000).minY - 300.0)
            let point = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            guard let index = view.index(at: point) else {
                XCTFail("no anchor")
                return
            }
            let hostAnchor = CGPoint(x: point.x, y: point.y + view.contentOffset)
            let sourceFrame = source.frame(at: index)
            let relative = MediaGridZoomMath.relativePosition(of: hostAnchor, in: sourceFrame)
            view.setLevel(to, animated: true, anchor: MediaGridZoomAnchor(index: index, pointInView: point))
            guard let transition = view.transition else {
                XCTFail("no transition")
                return
            }
            let host = view.subviews[0].layer
            let shift = view.contentOffset - transition.targetOffset
            let targetFrame = transition.targetLayout.frame(at: index)
            let incomingLocal = CGPoint(x: targetFrame.minX + relative.x * targetFrame.width, y: targetFrame.minY + relative.y * targetFrame.height)
            XCTAssertEqual(incomingLocal.y + shift, hostAnchor.y, accuracy: 0.5)
            for progress in [0.0, 0.37, 1.0] as [CGFloat] {
                transition.apply(progress: progress)
                XCTAssertTrue(CATransform3DIsAffine(transition.outgoing.transform))
                XCTAssertEqual(transition.outgoing.transform.m41, 0.0)
                XCTAssertEqual(transition.outgoing.transform.m42, 0.0)
                XCTAssertEqual(transition.incoming.transform.m42, 0.0)
                let outgoing = transition.outgoing.convert(hostAnchor, to: host)
                XCTAssertEqual(outgoing.x, hostAnchor.x, accuracy: 0.5, "\(from)->\(to) p=\(progress)")
                XCTAssertEqual(outgoing.y, hostAnchor.y, accuracy: 0.5, "\(from)->\(to) p=\(progress)")
                let incoming = transition.incoming.convert(CGPoint(x: hostAnchor.x, y: incomingLocal.y), to: host)
                XCTAssertEqual(incoming.x, hostAnchor.x, accuracy: 0.5, "\(from)->\(to) p=\(progress)")
                XCTAssertEqual(incoming.y, hostAnchor.y, accuracy: 0.5, "\(from)->\(to) p=\(progress)")
                let sourceTop = transition.outgoing.convert(CGPoint(x: sourceFrame.minX, y: sourceFrame.minY), to: host)
                let scale = 1.0 + (transition.scale - 1.0) * progress
                XCTAssertEqual(sourceTop.y, hostAnchor.y + (sourceFrame.minY - hostAnchor.y) * scale, accuracy: 0.5)
            }
            view._testFinishAnimations()
            XCTAssertEqual(view.level, to)
            guard let settled = view.frameForItem(at: index) else {
                XCTFail("no frame")
                return
            }
            XCTAssertEqual(settled.minY + relative.y * settled.height, point.y, accuracy: 0.5)
        }
    }

    func testZoomButtonsDisabledAtEnds() {
        let (view, _) = self.makeView(count: 1000)
        XCTAssertTrue(view.canZoomIn)
        XCTAssertTrue(view.canZoomOut)
        view.setLevel(.one, animated: false)
        XCTAssertFalse(view.canZoomIn)
        XCTAssertTrue(view.canZoomOut)
        view.zoomIn()
        XCTAssertEqual(view.level, .one)
        view.setLevel(.thirtyOne, animated: false)
        XCTAssertTrue(view.canZoomIn)
        XCTAssertFalse(view.canZoomOut)
        view.zoomOut()
        XCTAssertEqual(view.level, .thirtyOne)
        view.isZoomEnabled = false
        XCTAssertFalse(view.canZoomIn)
        XCTAssertFalse(view.canZoomOut)
        view.zoomIn()
        XCTAssertEqual(view.level, .thirtyOne)
        guard let frame = view.frameForItem(at: 10) else {
            XCTFail("no frame")
            return
        }
        view._testTap(at: CGPoint(x: frame.midX, y: frame.midY))
        XCTAssertEqual(view.level, .thirtyOne)
    }

    func testCameraFadesAtFifteen() {
        let (view, _) = self.makeView(count: 1000)
        let camera = UIView()
        view.cameraView = camera
        view.layoutIfNeeded()
        view.setLevel(.five, animated: false)
        XCTAssertEqual(camera.alpha, 1.0)
        XCTAssertFalse(camera.isHidden)
        view.zoomOut()
        XCTAssertEqual(camera.alpha, 0.0)
        XCTAssertNotNil(camera.layer.animation(forKey: "mediaGridZoom.opacity"))
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .fifteen)
        XCTAssertEqual(camera.alpha, 0.0)
        XCTAssertTrue(CATransform3DIsIdentity(camera.layer.transform))
        view.zoomIn()
        XCTAssertFalse(camera.isHidden)
        XCTAssertEqual(camera.alpha, 1.0)
        view._testFinishAnimations()
        XCTAssertEqual(camera.alpha, 1.0)
        XCTAssertTrue(CATransform3DIsIdentity(camera.layer.transform))
        XCTAssertEqual(camera.frame, view.currentLayout?.reservedFrame([MediaGridSlot(row: 0, column: 0), MediaGridSlot(row: 1, column: 0)]))
    }

    func testNoMarkersAtCompact() {
        let dataSource = TestDataSource(count: 100_000)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MarkerTestCell()
        })
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        var markers = 0
        view.forEachVisibleCell { _, cell in
            markers += cell.sublayers?.count ?? 0
        }
        XCTAssertGreaterThan(markers, 0)
        view.zoomOut()
        view._testFinishAnimations()
        view.zoomOut()
        view._testFinishAnimations()
        view.zoomOut()
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .thirtyOne)
        var visible = 0
        view.forEachVisibleCell { index, cell in
            visible += 1
            XCTAssertEqual(cell.sublayers?.count ?? 0, 0, "index \(index) has a marker")
        }
        XCTAssertGreaterThan(visible, 0)
    }

    private func makeWindowedView(count: Int) -> (MediaGridView, UIWindow) {
        let (view, _) = self.makeView(count: count)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = view.frame
        window.windowLevel = .alert
        window.isHidden = false
        window.addSubview(view)
        view.layoutIfNeeded()
        CATransaction.flush()
        return (view, window)
    }

    private func spin(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func layoutLayerCount(_ view: MediaGridView) -> Int {
        return view.engine.contentHost.layer.sublayers?.filter { $0 is MediaGridLayoutLayer }.count ?? 0
    }

    func testPinchDuringFlightAnchorsPresentedItem() {
        let (view, window) = self.makeWindowedView(count: 100_000)
        view.setContentOffset(20_000.0)
        view._testFlight(settledOffset: 40_000.0)
        let host = view.engine.contentHost
        let presentedOffset: CGFloat = 20_520.0
        let animation = CABasicAnimation(keyPath: "bounds.origin.y")
        animation.fromValue = presentedOffset
        animation.toValue = presentedOffset
        animation.duration = 100.0
        host.layer.add(animation, forKey: "testFlight")
        CATransaction.flush()
        self.spin(0.05)
        XCTAssertEqual(host.layer.presentation()?.bounds.origin.y ?? -1.0, presentedOffset, accuracy: 0.5)
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let expected = layout.index(at: CGPoint(x: centre.x, y: centre.y + presentedOffset))
        XCTAssertNotNil(expected)
        XCTAssertNotEqual(expected, layout.index(at: CGPoint(x: centre.x, y: centre.y + 20_000.0)))
        view._testPinch(.began, center: centre)
        XCTAssertFalse(view.isUserScrolling)
        XCTAssertFalse(view.engine.isScrollEnabled)
        XCTAssertEqual(view.pinchAnchor?.index, expected)
        XCTAssertEqual(view.contentOffset, presentedOffset, accuracy: 0.5)
        host.layer.removeAnimation(forKey: "testFlight")
        view._testPinch(.ended, center: centre)
        XCTAssertTrue(view.engine.isScrollEnabled)
        XCTAssertNil(view.pinchAnchor)
        window.isHidden = true
    }

    func testPinchCancelReturnsToSource() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let source = view.activeLayoutLayer
        var levels: [MediaGridLevel] = []
        view.onLevelChanged = { levels.append($0) }
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: pow(3.0 / 5.0, 0.3))
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        XCTAssertEqual(transition.sourceLevel, .three)
        XCTAssertEqual(transition.targetLevel, .five)
        XCTAssertEqual(transition.progress, 0.3, accuracy: 1e-6)
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(self.layoutLayerCount(view), 2)
        view._testPinch(.ended, center: centre, scale: pow(3.0 / 5.0, 0.3), velocity: 0.0)
        XCTAssertFalse(view.engine.isScrollEnabled)
        XCTAssertEqual(view.level, .three)
        view._testFinishAnimations()
        XCTAssertNil(view.transition)
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(levels, [])
        XCTAssertEqual(view.currentLayout?.columns, 3)
        XCTAssertEqual(view.contentOffset, 20_000.0, accuracy: 1e-6)
        XCTAssertTrue(view.activeLayoutLayer === source)
        XCTAssertTrue(CATransform3DIsIdentity(source.transform))
        XCTAssertEqual(source.opacity, 1.0)
        XCTAssertEqual(source.frame.minY, 0.0)
        XCTAssertEqual(self.layoutLayerCount(view), 1)
        XCTAssertTrue(view.engine.isScrollEnabled)
        let window = view.currentLayout!.indexRange(intersecting: self.viewport(view).insetBy(dx: 0.0, dy: -view.bounds.height))
        XCTAssertEqual(Set(self.visibleCells(view).keys), Set(window))
    }

    func testPinchChainsThroughLevelsAndCommitsOnce() {
        let (view, dataSource) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let anchorIndex = view.index(at: centre) else {
            XCTFail("no anchor")
            return
        }
        var levels: [MediaGridLevel] = []
        view.onLevelChanged = { levels.append($0) }
        var scrolls = 0
        view.onScroll = { _ in scrolls += 1 }
        let cachedBefore = dataSource.cachedIndices
        view._testPinch(.began, center: centre)
        var scale: CGFloat = 1.0
        while scale > 3.0 / 15.0 * pow(15.0 / 31.0, 0.2) {
            scale *= 0.97
            view._testPinch(.changed, center: centre, scale: scale)
            XCTAssertLessThanOrEqual(self.layoutLayerCount(view), 2)
            XCTAssertEqual(view.level, .three)
        }
        XCTAssertEqual(view.transition?.sourceLevel, .fifteen)
        XCTAssertEqual(view.transition?.targetLevel, .thirtyOne)
        XCTAssertEqual(levels, [])
        XCTAssertEqual(scrolls, 0)
        XCTAssertEqual(dataSource.cachedIndices, cachedBefore)
        view._testPinch(.ended, center: centre, scale: scale, velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .fifteen)
        XCTAssertEqual(levels, [.fifteen])
        XCTAssertGreaterThan(scrolls, 0)
        XCTAssertNotEqual(dataSource.cachedIndices, cachedBefore)
        XCTAssertEqual(view.currentLayout?.columns, 15)
        XCTAssertEqual(self.layoutLayerCount(view), 1)
        guard let frame = view.frameForItem(at: anchorIndex) else {
            XCTFail("no frame")
            return
        }
        XCTAssertTrue(frame.minY <= centre.y && centre.y <= frame.maxY, "\(frame) \(centre)")
    }

    func testPinchRoundTripThroughClampedLevelsRestoresOffset() {
        let (view, _) = self.makeView(count: 100_000)
        for start in [0.0, 20_000.0] as [CGFloat] {
            view.setContentOffset(start)
            let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            view._testPinch(.began, center: centre)
            var scale: CGFloat = 1.0
            while scale > 3.0 / 15.0 * 0.9 {
                scale *= 0.95
                view._testPinch(.changed, center: centre, scale: scale)
            }
            while scale < 1.0 {
                scale = min(1.0, scale / 0.95)
                view._testPinch(.changed, center: centre, scale: scale)
            }
            XCTAssertEqual(view.level, .three)
            view._testPinch(.ended, center: centre, scale: 1.0, velocity: 0.0)
            view._testFinishAnimations()
            XCTAssertNil(view.transition)
            XCTAssertEqual(view.level, .three)
            XCTAssertEqual(view.contentOffset, start, accuracy: 0.5)
        }
    }

    func testPinchBackAcrossLevelReusesShownLayer() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: 3.0 / 5.0 * pow(5.0 / 15.0, 0.6))
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(view.transition?.sourceLevel, .five)
        guard let fiveLayer = view.transition?.outgoing else {
            XCTFail("no transition")
            return
        }
        let shownCells = fiveLayer.visibleCells
        view._testPinch(.changed, center: centre, scale: pow(3.0 / 5.0, 0.9))
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(transition.sourceLevel, .five)
        XCTAssertEqual(transition.targetLevel, .three)
        XCTAssertEqual(transition.progress, 0.1, accuracy: 1e-6)
        XCTAssertTrue(transition.outgoing === fiveLayer)
        for (index, cell) in shownCells where fiveLayer.visibleCells[index] != nil {
            XCTAssertTrue(fiveLayer.visibleCells[index] === cell)
        }
        var levels: [MediaGridLevel] = []
        view.onLevelChanged = { levels.append($0) }
        view._testPinch(.ended, center: centre, scale: pow(3.0 / 5.0, 0.9), velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
        XCTAssertEqual(levels, [.five])
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: pow(5.0 / 3.0, 0.3))
        view._testPinch(.ended, center: centre, scale: pow(5.0 / 3.0, 0.3), velocity: 2.0)
        guard let spring = view.transition?.incoming.animation(forKey: "mediaGridZoom.opacity") as? CASpringAnimation else {
            XCTFail("no settle animation")
            return
        }
        XCTAssertGreaterThan(spring.initialVelocity, 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .three)
    }

    func testPinchBackAcrossStartFlipsDirection() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: 0.8)
        XCTAssertEqual(view.transition?.targetLevel, .five)
        view._testPinch(.changed, center: centre, scale: 1.0)
        XCTAssertEqual(view.transition?.targetLevel, .five)
        XCTAssertEqual(view.transition?.progress ?? -1.0, 0.0, accuracy: 1e-9)
        view._testPinch(.changed, center: centre, scale: 1.3)
        XCTAssertEqual(view.transition?.sourceLevel, .three)
        XCTAssertEqual(view.transition?.targetLevel, .one)
        XCTAssertEqual(self.layoutLayerCount(view), 2)
        view._testPinch(.ended, center: centre, scale: 1.3, velocity: 2.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .one)
    }

    func testPinchReleaseCarriesVelocity() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: pow(3.0 / 5.0, 0.4))
        view._testPinch(.ended, center: centre, scale: pow(3.0 / 5.0, 0.4), velocity: -2.0)
        guard let transition = view.transition, let spring = transition.incoming.animation(forKey: "mediaGridZoom.opacity") as? CASpringAnimation else {
            XCTFail("no settle animation")
            return
        }
        XCTAssertEqual(transition.incoming.opacity, 1.0)
        XCTAssertGreaterThan(spring.initialVelocity, 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
    }

    func testPinchInterruptsSpringAtPresentedProgress() {
        let (view, window) = self.makeWindowedView(count: 100_000)
        view.setContentOffset(20_000.0)
        var levels: [MediaGridLevel] = []
        view.onLevelChanged = { levels.append($0) }
        view.zoomOut()
        XCTAssertEqual(view.level, .three)
        CATransaction.flush()
        self.spin(0.1)
        guard let transition = view.transition else {
            XCTFail("zoom finished before the interruption")
            return
        }
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        XCTAssertTrue(view.transition === transition)
        XCTAssertGreaterThan(transition.progress, 0.02)
        XCTAssertLessThan(transition.progress, 0.98)
        XCTAssertNil(transition.incoming.animation(forKey: "mediaGridZoom.opacity"))
        self.spin(0.1)
        XCTAssertTrue(view.transition === transition)
        XCTAssertEqual(levels, [])
        let presented = transition.progress
        view._testPinch(.changed, center: centre, scale: 1.0)
        XCTAssertEqual(transition.progress, presented, accuracy: 1e-6)
        view._testPinch(.ended, center: centre, scale: 1.0, velocity: -3.0)
        view._testPinch(.began, center: centre)
        XCTAssertTrue(view.transition === transition)
        self.spin(0.1)
        XCTAssertTrue(view.transition === transition)
        view._testPinch(.ended, center: centre, scale: 1.0, velocity: -3.0)
        let deadline = Date().addingTimeInterval(3.0)
        while view.transition != nil && Date() < deadline {
            self.spin(0.02)
        }
        XCTAssertNil(view.transition)
        XCTAssertEqual(view.level, .five)
        XCTAssertEqual(levels, [.five])
        XCTAssertTrue(view.engine.isScrollEnabled)
        window.isHidden = true
    }

    func testPinchOvershootRubberBandsAtEnd() {
        let (view, _) = self.makeView(count: 100_000)
        view.setLevel(.thirtyOne, animated: false)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: 0.3)
        XCTAssertNil(view.transition)
        let hostLayer = view.engine.contentHost.layer
        XCTAssertTrue(CATransform3DIsIdentity(view.layer.sublayerTransform))
        let squeezed = hostLayer.sublayerTransform.m11
        XCTAssertLessThan(squeezed, 1.0)
        XCTAssertGreaterThan(squeezed, 0.85)
        let content = view.activeLayoutLayer
        let pivot = content.convert(CGPoint(x: centre.x, y: centre.y + view.contentOffset), to: view.layer)
        XCTAssertEqual(pivot.x, centre.x, accuracy: 0.5)
        XCTAssertEqual(pivot.y, centre.y, accuracy: 0.5)
        let corner = content.convert(CGPoint(x: 0.0, y: view.contentOffset), to: view.layer)
        XCTAssertEqual(corner.x, centre.x * (1.0 - squeezed), accuracy: 0.5)
        view._testPinch(.changed, center: centre, scale: 0.01)
        XCTAssertLessThan(hostLayer.sublayerTransform.m11, squeezed)
        XCTAssertGreaterThan(hostLayer.sublayerTransform.m11, 0.85)
        view._testPinch(.ended, center: centre, scale: 0.01, velocity: 0.0)
        XCTAssertTrue(CATransform3DIsIdentity(hostLayer.sublayerTransform))
        XCTAssertEqual(view.level, .thirtyOne)
        XCTAssertTrue(view.engine.isScrollEnabled)
    }

    private func beginIdlePinch(_ view: MediaGridView) -> CGPoint {
        view.setContentOffset(20_000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: 1.0)
        XCTAssertNotNil(view.pinchAnchor)
        XCTAssertNil(view.transition)
        return centre
    }

    func testSetContentOffsetEndsIdlePinch() {
        let (view, _) = self.makeView(count: 100_000)
        let centre = self.beginIdlePinch(view)
        view.setContentOffset(40_000.0)
        XCTAssertNil(view.pinchAnchor)
        XCTAssertTrue(view.engine.isScrollEnabled)
        view._testPinch(.changed, center: centre, scale: 0.7)
        XCTAssertNil(view.transition)
        XCTAssertEqual(view.contentOffset, 40_000.0, accuracy: 1e-6)
    }

    func testReloadDataEndsIdlePinch() {
        let (view, dataSource) = self.makeView(count: 100_000)
        let centre = self.beginIdlePinch(view)
        dataSource.count = 50
        view.reloadData()
        XCTAssertNil(view.pinchAnchor)
        XCTAssertTrue(view.engine.isScrollEnabled)
        view._testPinch(.changed, center: centre, scale: 0.7)
        XCTAssertNil(view.transition)
        XCTAssertEqual(view.currentLayout?.count, 50)
    }

    func testSetLevelEndsIdlePinch() {
        let (view, _) = self.makeView(count: 100_000)
        let centre = self.beginIdlePinch(view)
        view.setLevel(.five, animated: false)
        XCTAssertNil(view.pinchAnchor)
        XCTAssertEqual(view.level, .five)
        view._testPinch(.changed, center: centre, scale: 0.5)
        XCTAssertNil(view.transition)
        XCTAssertEqual(self.layoutLayerCount(view), 1)
    }

    func testAnimatedSetLevelEndsIdlePinch() {
        let (view, _) = self.makeView(count: 100_000)
        let centre = self.beginIdlePinch(view)
        view.setLevel(.five, animated: true)
        XCTAssertNil(view.pinchAnchor)
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        view._testPinch(.changed, center: centre, scale: 1.3)
        XCTAssertTrue(view.transition === transition)
        XCTAssertEqual(transition.destination, 1.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
    }

    func testPinchJitterAtBoundaryKeepsPair() {
        let (view, dataSource) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: pow(3.0 / 5.0, 0.95))
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        view._testPinch(.changed, center: centre, scale: 3.0 / 5.0)
        let requests = dataSource.requestCount
        for scale in [3.0 / 5.0 * 0.98, 3.0 / 5.0 * 1.01, 3.0 / 5.0 * 1.005, 3.0 / 5.0 * 0.985] as [CGFloat] {
            view._testPinch(.changed, center: centre, scale: scale)
            XCTAssertTrue(view.transition === transition)
        }
        XCTAssertEqual(dataSource.requestCount, requests)
        XCTAssertGreaterThan(transition.progress, 1.0)
        XCTAssertEqual(transition.incoming.opacity, 1.0)
        view._testPinch(.changed, center: centre, scale: 3.0 / 5.0 * 0.8)
        XCTAssertEqual(view.transition?.sourceLevel, .five)
        XCTAssertEqual(view.transition?.targetLevel, .fifteen)
    }

    func testPinchBindsGrowingWindowWithoutMargin() {
        let (view, _) = self.makeView(count: 100_000)
        view.setLevel(.fifteen, animated: false)
        view.setContentOffset(5_000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: pow(15.0 / 31.0, 0.02))
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        let early = transition.incoming.visibleCells.count
        let fullRect = transition.incomingRect(at: 0.0).union(transition.incomingRect(at: 1.0))
        let full = transition.targetLayout.indexRange(intersecting: fullRect).count
        let taskEightWindow = transition.targetLayout.indexRange(intersecting: fullRect.insetBy(dx: 0.0, dy: -view.bounds.height * 0.25)).count
        XCTAssertLessThan(early, taskEightWindow / 2)
        view._testPinch(.changed, center: centre, scale: pow(15.0 / 31.0, 0.98))
        XCTAssertTrue(view.transition === transition)
        XCTAssertGreaterThanOrEqual(transition.incoming.visibleCells.count, full)
        let margin = view.bounds.height * 0.25
        let withMargin = transition.targetLayout.indexRange(intersecting: fullRect.insetBy(dx: 0.0, dy: -margin)).count
        XCTAssertLessThan(transition.incoming.visibleCells.count, withMargin)
    }

    func testFastPinchAcrossLevelsBindsOnlyFinalPair() {
        let (view, dataSource) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: pow(3.0 / 5.0, 0.5))
        XCTAssertNotNil(view.transition)
        let requests = dataSource.requestCount
        view._testPinch(.changed, center: centre, scale: 3.0 / 15.0 * pow(15.0 / 31.0, 0.5))
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        XCTAssertEqual(transition.sourceLevel, .fifteen)
        XCTAssertEqual(transition.targetLevel, .thirtyOne)
        XCTAssertEqual(self.layoutLayerCount(view), 2)
        XCTAssertEqual(view.level, .three)
        XCTAssertLessThanOrEqual(dataSource.requestCount - requests, transition.outgoing.visibleCells.count + transition.incoming.visibleCells.count)
    }

    private func assertVisibleCellsBound(_ view: MediaGridView, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let transition = view.transition else {
            XCTFail("no transition \(message)", file: file, line: line)
            return
        }
        let progress = transition.progress
        let layers: [(MediaGridLayoutLayer, MediaGridLayout, CGRect)] = [
            (transition.incoming, transition.targetLayout, transition.incomingRect(at: progress)),
            (transition.outgoing, transition.sourceLayout, transition.outgoingRect(at: progress))
        ]
        for (layer, layout, rect) in layers where layer.opacity > 0.0 {
            let needed = layout.indexRange(intersecting: rect)
            let bound = layer.visibleRange
            XCTAssertTrue(needed.isEmpty || (bound.lowerBound <= needed.lowerBound && bound.upperBound >= needed.upperBound), "\(message): needed \(needed) bound \(bound) progress \(progress)", file: file, line: line)
        }
    }

    private func pinchGradually(_ view: MediaGridView, centre: CGPoint, to scale: CGFloat) {
        var current: CGFloat = 1.0
        let step: CGFloat = scale < 1.0 ? 0.97 : 1.0 / 0.97
        while (scale < 1.0 && current * step > scale) || (scale > 1.0 && current * step < scale) {
            current *= step
            view._testPinch(.changed, center: centre, scale: current)
        }
        view._testPinch(.changed, center: centre, scale: scale)
    }

    func testBandBindsEveryVisibleCellAtEdgeAnchors() {
        let bands: [(String, [CGFloat])] = [
            ("L5", [3.0 / 5.0 * pow(5.0 / 15.0, 0.049)]),
            ("L15", [3.0 / 15.0 * pow(15.0 / 31.0, 0.049)]),
            ("L5 back", [3.0 / 5.0 * pow(5.0 / 15.0, 0.3), pow(3.0 / 5.0, 0.951)]),
            ("L15 back", [3.0 / 15.0 * pow(15.0 / 31.0, 0.3), 3.0 / 5.0 * pow(5.0 / 15.0, 0.951)])
        ]
        for (name, path) in bands {
            for fraction in [0.1, 0.5, 0.9] as [CGFloat] {
                let (view, _) = self.makeView(count: 100_000)
                view.setContentOffset(20_000.0)
                let centre = CGPoint(x: view.bounds.midX, y: view.bounds.height * fraction)
                view._testPinch(.began, center: centre)
                var scale: CGFloat = 1.0
                for target in path {
                    let step: CGFloat = target < scale ? 0.97 : 1.0 / 0.97
                    while (target < scale && scale * step > target) || (target > scale && scale * step < target) {
                        scale *= step
                        view._testPinch(.changed, center: centre, scale: scale)
                    }
                    scale = target
                    view._testPinch(.changed, center: centre, scale: scale)
                }
                guard let transition = view.transition else {
                    XCTFail("no transition \(name)")
                    continue
                }
                XCTAssertTrue(transition.progress > 1.0 || transition.progress < 0.0, "\(name) not in band: \(transition.progress)")
                self.assertVisibleCellsBound(view, "\(name) f=\(fraction)")
            }
        }
    }

    func testSingleFrameJumpIntoBandBindsVisibleCells() {
        for fraction in [0.1, 0.9] as [CGFloat] {
            let (view, _) = self.makeView(count: 100_000)
            view.setContentOffset(20_000.0)
            let centre = CGPoint(x: view.bounds.midX, y: view.bounds.height * fraction)
            view._testPinch(.began, center: centre)
            view._testPinch(.changed, center: centre, scale: pow(3.0 / 5.0, 0.6))
            view._testPinch(.changed, center: centre, scale: 3.0 / 5.0 * pow(5.0 / 15.0, 0.045))
            XCTAssertGreaterThan(view.transition?.progress ?? 0.0, 1.0)
            self.assertVisibleCellsBound(view, "f=\(fraction)")
        }
    }

    func testReleaseInBandFollowsFling() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        var levels: [MediaGridLevel] = []
        view.onLevelChanged = { levels.append($0) }
        view._testPinch(.began, center: centre)
        let band = 3.0 / 5.0 * pow(5.0 / 15.0, 0.03)
        self.pinchGradually(view, centre: centre, to: band)
        XCTAssertEqual(view.transition?.targetLevel, .five)
        XCTAssertGreaterThan(view.transition?.progress ?? 0.0, 1.0)
        view._testPinch(.ended, center: centre, scale: band, velocity: -2.0)
        XCTAssertEqual(view.transition?.sourceLevel, .five)
        XCTAssertEqual(view.transition?.targetLevel, .fifteen)
        XCTAssertEqual(view.transition?.destination, 1.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .fifteen)
        XCTAssertEqual(levels, [.fifteen])

        view.setLevel(.three, animated: false)
        levels = []
        view._testPinch(.began, center: centre)
        self.pinchGradually(view, centre: centre, to: 3.0 / 5.0 * pow(5.0 / 15.0, 0.3))
        let back = pow(3.0 / 5.0, 0.97)
        view._testPinch(.changed, center: centre, scale: back)
        XCTAssertEqual(view.transition?.sourceLevel, .five)
        XCTAssertEqual(view.transition?.targetLevel, .fifteen)
        XCTAssertLessThan(view.transition?.progress ?? 1.0, 0.0)
        view._testPinch(.ended, center: centre, scale: back, velocity: 2.0)
        XCTAssertEqual(view.transition?.targetLevel, .three)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(levels, [])

        view._testPinch(.began, center: centre)
        self.pinchGradually(view, centre: centre, to: band)
        view._testPinch(.ended, center: centre, scale: band, velocity: 0.0)
        XCTAssertEqual(view.transition?.targetLevel, .five)
        XCTAssertEqual(view.transition?.destination, 1.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
    }

    func testBandReleaseInterruptKeepsGeometry() {
        let (view, window) = self.makeWindowedView(count: 100_000)
        view.setContentOffset(20_000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        let band = 3.0 / 5.0 * pow(5.0 / 15.0, 0.04)
        self.pinchGradually(view, centre: centre, to: band)
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        let extrapolated = transition.progress
        XCTAssertGreaterThan(extrapolated, 1.0)
        view._testPinch(.ended, center: centre, scale: band, velocity: 0.0)
        XCTAssertEqual(transition.destination, 1.0)
        let spring = transition.incoming.animation(forKey: "mediaGridZoom.opacity") as? CASpringAnimation
        XCTAssertLessThanOrEqual((spring?.fromValue as? NSNumber)?.floatValue ?? 2.0, 1.0)
        CATransaction.flush()
        self.spin(0.01)
        view._testPinch(.began, center: centre)
        XCTAssertTrue(view.transition === transition)
        XCTAssertEqual(transition.progress, extrapolated, accuracy: 0.02)
        view._testPinch(.changed, center: centre, scale: 1.0)
        XCTAssertTrue(view.transition === transition)
        XCTAssertEqual(transition.progress, extrapolated, accuracy: 0.02)
        view._testPinch(.ended, center: centre, scale: 1.0, velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
        window.isHidden = true
    }

    func testPinchIgnoredWhenZoomDisabled() {
        let (view, _) = self.makeView(count: 100_000)
        view.isZoomEnabled = false
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: 0.5)
        XCTAssertNil(view.transition)
        XCTAssertNil(view.pinchAnchor)
        XCTAssertTrue(view.engine.isScrollEnabled)
        view._testPinch(.ended, center: centre, scale: 0.5, velocity: -3.0)
        XCTAssertEqual(view.level, .three)
    }

    func testWindowStaysExactAcrossSmallAndLargeScrolls() {
        let (view, _) = self.makeView(count: 100_000)
        for level in [MediaGridLevel.three, .thirtyOne] {
            view.setLevel(level, animated: false)
            let margin = level.isInteractive ? view.bounds.height : view.bounds.height * 0.25
            var offsets: [CGFloat] = []
            var y: CGFloat = 1000.0
            for _ in 0 ..< 40 {
                y += 7.0
                offsets.append(y)
            }
            for _ in 0 ..< 20 {
                y -= 13.0
                offsets.append(y)
            }
            offsets.append(contentsOf: [y + 600.0, y + 3000.0, view.contentHeight / 2.0, view.contentHeight / 2.0 - 900.0, 0.0, view.contentHeight])
            for offset in offsets {
                view.setContentOffset(offset)
                guard let layout = view.currentLayout else {
                    XCTFail("no layout")
                    return
                }
                let window = layout.indexRange(intersecting: self.viewport(view).insetBy(dx: 0.0, dy: -margin))
                let cells = self.visibleCells(view)
                XCTAssertEqual(Set(cells.keys), Set(window), "level \(level) offset \(offset)")
                let mismatched = cells.filter { index, cell in
                    let expected = layout.frame(at: index)
                    return cell.index != index || cell.isHidden || abs(cell.frame.minX - expected.minX) > 1e-6 || abs(cell.frame.minY - expected.minY) > 1e-6 || abs(cell.frame.width - expected.width) > 1e-6
                }
                XCTAssertTrue(mismatched.isEmpty, "level \(level) offset \(offset): \(mismatched.keys.sorted().prefix(5))")
            }
        }
    }

    func testPoolShrinksAfterCompactLevel() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(30_000.0)
        let interactiveVisible = self.visibleCells(view).count
        view.setLevel(.thirtyOne, animated: false)
        let compactVisible = self.visibleCells(view).count
        XCTAssertGreaterThan(compactVisible, interactiveVisible)
        view.setLevel(.three, animated: false)
        let visible = self.visibleCells(view).count
        XCTAssertLessThanOrEqual(view.pool.count, 2 * visible)
        let attached = view.activeLayoutLayer.sublayers?.count ?? 0
        XCTAssertLessThanOrEqual(attached, 3 * visible)
    }

    func testRebindAtNewPixelSizeKeepsContents() {
        let dataSource = TestDataSource(count: 100)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        let before = self.visibleCells(view)
        XCTAssertTrue(before.values.allSatisfy { $0.contents != nil })
        dataSource.deliveries = []
        let cancels = dataSource.cancelCount
        view.setLevel(.five, animated: false)
        var kept = 0
        view.forEachVisibleCell { index, cell in
            if before[index] === cell {
                kept += 1
                XCTAssertNotNil(cell.contents, "index \(index) lost its image")
            }
        }
        XCTAssertGreaterThan(kept, 0)
        XCTAssertGreaterThanOrEqual(dataSource.cancelCount - cancels, kept)
    }

    private func makeLevelOneView(count: Int, harness: LevelOneHarness = LevelOneHarness()) -> (MediaGridView, TestDataSource, LevelOneHarness) {
        let dataSource = TestDataSource(count: count)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.aspectLoader = { _, _, completion in
            harness.pendingAspects = completion
            return {
                harness.cancelCount += 1
            }
        }
        view.aspectTableBuilder = { key, aspects, completion in
            harness.tableBuilds += 1
            let build = {
                completion(MediaGridAspectTable(key: key, aspects: aspects))
            }
            if harness.buildsTablesImmediately {
                build()
            } else {
                harness.pendingTables.append(build)
            }
        }
        view.motionClock = { 0.0 }
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        view.setLevel(.one, animated: false)
        return (view, dataSource, harness)
    }

    private func assertFrame(_ frame: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(frame.minX, expected.minX, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(frame.minY, expected.minY, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(frame.width, expected.width, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(frame.height, expected.height, accuracy: 1e-6, file: file, line: line)
    }

    private static func testAspects(count: Int) -> [Float] {
        return (0 ..< count).map { index in [0.5, 2.0, 1.0, 1.5, 0.75][index % 5] }
    }

    private func isExact(_ view: MediaGridView) -> Bool {
        return (view.gridLayout as? MediaGridAspectLayout)?.isExact ?? false
    }

    func testLevelOneUsesEstimatesUntilAspectsArrive() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        XCTAssertEqual(view.level, .one)
        XCTAssertNotNil(harness.pendingAspects)
        guard let layout = view.gridLayout as? MediaGridAspectLayout else {
            XCTFail("no aspect layout")
            return
        }
        XCTAssertFalse(layout.isExact)
        XCTAssertEqual(layout.frame(at: 0).width, 393.0, accuracy: 1e-9)
        XCTAssertEqual(layout.frame(at: 0).height, floor(393.0 / 0.75 * 3.0) / 3.0, accuracy: 1e-9)
        for (index, cell) in self.visibleCells(view) {
            self.assertFrame(cell.frame, layout.frame(at: index))
            XCTAssertEqual(cell.contentsGravity, .resizeAspectFill)
        }
    }

    func testLevelOneRequestsRowPixelSize() {
        let (view, dataSource, harness) = self.makeLevelOneView(count: 1000)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        let requests = dataSource.pixelSizes
        view.setContentOffset(5000.0)
        guard let layout = view.gridLayout as? MediaGridAspectLayout else {
            XCTFail("no aspect layout")
            return
        }
        XCTAssertTrue(layout.isExact)
        let fresh = dataSource.pixelSizes.dropFirst(requests.count)
        XCTAssertFalse(fresh.isEmpty)
        for (index, size) in fresh {
            let frame = layout.frame(at: index)
            XCTAssertEqual(size, CGSize(width: (frame.width * 3.0).rounded(), height: (frame.height * 3.0).rounded()), "index \(index)")
        }
        let cachedSizes = Set(dataSource.cachingPixelSizes.map { "\($0.width)x\($0.height)" })
        XCTAssertGreaterThan(cachedSizes.count, 1)
    }

    func testExactHeightsKeepTopItem() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        guard let estimated = view.gridLayout else {
            XCTFail("no layout")
            return
        }
        view.setContentOffset(estimated.frame(at: 300).minY)
        XCTAssertEqual(view.topVisibleIndex, 300)
        guard let before = view.frameForItem(at: 300) else {
            XCTFail("no frame")
            return
        }
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        guard let exact = view.gridLayout as? MediaGridAspectLayout, exact.isExact, let after = view.frameForItem(at: 300) else {
            XCTFail("no exact layout")
            return
        }
        XCTAssertEqual(exact.frame(at: 1).height, floor(393.0 / 2.0 * 3.0) / 3.0, accuracy: 1e-9)
        XCTAssertLessThan(abs(after.minY - before.minY), 1.0)
        XCTAssertEqual(view.topVisibleIndex, 300)
        for (index, cell) in self.visibleCells(view) {
            self.assertFrame(cell.frame, exact.frame(at: index))
        }
        let viewport = self.viewport(view)
        for index in exact.indexRange(intersecting: viewport) {
            XCTAssertNotNil(self.visibleCells(view)[index])
        }
    }

    func testExactHeightsKeepFractionInsideTopRow() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        guard let estimated = view.gridLayout else {
            XCTFail("no layout")
            return
        }
        let row = estimated.frame(at: 301)
        view.setContentOffset(row.minY + row.height * 0.4)
        XCTAssertEqual(view.topVisibleIndex, 301)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        guard let exact = view.gridLayout as? MediaGridAspectLayout, exact.isExact else {
            XCTFail("no exact layout")
            return
        }
        let newRow = exact.frame(at: 301)
        XCTAssertNotEqual(newRow.height, row.height, accuracy: 1.0)
        XCTAssertEqual((view.contentOffset - newRow.minY) / newRow.height, 0.4, accuracy: 0.5 / newRow.height)
        XCTAssertEqual(view.topVisibleIndex, 301)
    }

    func testAspectsArrivingAtOtherLevelApplyOnEntry() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        view.setLevel(.three, animated: false)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        XCTAssertNotNil(view.currentLayout)
        view.setLevel(.one, animated: false)
        guard let layout = view.gridLayout as? MediaGridAspectLayout else {
            XCTFail("no aspect layout")
            return
        }
        XCTAssertTrue(layout.isExact)
        XCTAssertEqual(layout.frame(at: 0).height, 786.0, accuracy: 1e-9)
    }

    func testSwapWaitsForFlightToEnd() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        view.setContentOffset(20_000.0)
        view.engine.onWillBeginDragging?()
        view._testFlight(settledOffset: 30_000.0)
        view.engine.onDidEndDragging?()
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        XCTAssertFalse(self.isExact(view))
        guard let top = view.topVisibleIndex, let estimated = view.gridLayout else {
            XCTFail("no layout")
            return
        }
        let fraction = (view.contentOffset - estimated.frame(at: top).minY) / estimated.frame(at: top).height
        view.engine.onFlightChanged?(nil)
        XCTAssertTrue(self.isExact(view))
        XCTAssertEqual(view.topVisibleIndex, top)
        guard let exact = view.gridLayout else {
            XCTFail("no layout")
            return
        }
        XCTAssertEqual((view.contentOffset - exact.frame(at: top).minY) / exact.frame(at: top).height, fraction, accuracy: 0.01)
    }

    func testSwapWaitsForDragToEnd() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        view.engine.onWillBeginDragging?()
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        XCTAssertFalse(self.isExact(view))
        view.engine.onDidEndDragging?()
        XCTAssertTrue(self.isExact(view))
    }

    func testSwapWaitsForSelectionPan() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        view.selectionGesture.updateIsScrollEnabled(false)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        XCTAssertFalse(self.isExact(view))
        view.selectionGesture.updateIsScrollEnabled(true)
        XCTAssertTrue(self.isExact(view))
    }

    func testRowTableIsBuiltOnceAcrossCrossings() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        XCTAssertEqual(harness.tableBuilds, 1)
        view.setContentOffset(3000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        for _ in 0 ..< 3 {
            view._testPinch(.began, center: centre)
            for scale in stride(from: 1.0, through: 0.3, by: -0.05) as StrideThrough<CGFloat> {
                view._testPinch(.changed, center: centre, scale: scale)
            }
            for scale in stride(from: 0.3, through: 1.0, by: 0.05) as StrideThrough<CGFloat> {
                view._testPinch(.changed, center: centre, scale: scale)
            }
            view._testPinch(.ended, center: centre, scale: 1.0)
            view._testFinishAnimations()
            XCTAssertEqual(view.level, .one)
            XCTAssertTrue(self.isExact(view))
        }
        view.setLevel(.three, animated: true)
        XCTAssertTrue((view.transition?.sourceLayout as? MediaGridAspectLayout)?.isExact ?? false)
        view._testFinishAnimations()
        view.setLevel(.one, animated: true)
        XCTAssertTrue((view.transition?.targetLayout as? MediaGridAspectLayout)?.isExact ?? false)
        view._testFinishAnimations()
        XCTAssertEqual(harness.tableBuilds, 1)
    }

    func testWidthChangeUsesScaledRowsUntilRebuilt() {
        let harness = LevelOneHarness()
        let (view, _, _) = self.makeLevelOneView(count: 1000, harness: harness)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        harness.buildsTablesImmediately = false
        view.setContentOffset(view.gridLayout!.frame(at: 200).minY)
        view.geometryInsets = UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 10.0)
        view.layoutIfNeeded()
        XCTAssertEqual(harness.tableBuilds, 2)
        guard let scaled = view.gridLayout as? MediaGridAspectLayout else {
            XCTFail("no layout")
            return
        }
        XCTAssertFalse(scaled.isExact)
        XCTAssertEqual(scaled.frame(at: 1).width, 373.0, accuracy: 1e-9)
        for index in 0 ..< 999 {
            let frame = scaled.frame(at: index)
            let next = scaled.frame(at: index + 1)
            XCTAssertEqual(next.minY, frame.maxY + 1.0, accuracy: 1e-6)
            XCTAssertEqual(frame.height * 3.0, (frame.height * 3.0).rounded(), accuracy: 1e-6)
            let exactHeight = floor(373.0 / CGFloat([0.5, 2.0, 1.0, 1.5, 0.75][index % 5]) * 3.0) / 3.0
            XCTAssertEqual(frame.height, exactHeight, accuracy: 1.0)
        }
        let top = view.topVisibleIndex
        harness.pendingTables.removeFirst()()
        XCTAssertTrue(self.isExact(view))
        XCTAssertEqual(view.topVisibleIndex, top)
        XCTAssertEqual(view.gridLayout!.frame(at: 1).height, floor(373.0 / 2.0 * 3.0) / 3.0, accuracy: 1e-9)
    }

    func testExactSwapRebindsOnlyResizedCells() {
        let (view, dataSource, harness) = self.makeLevelOneView(count: 1000)
        view.setContentOffset(view.gridLayout!.frame(at: 100).minY)
        let visible = self.visibleCells(view).keys.sorted()
        XCTAssertGreaterThan(visible.count, 2)
        var aspects = [Float](repeating: 0.75, count: 1000)
        let changed = visible[1]
        aspects[changed] = 1.5
        let before = dataSource.requests.count
        harness.pendingAspects?(aspects)
        XCTAssertTrue(self.isExact(view))
        let rebound = dataSource.requests[before...].map { $0.index }
        XCTAssertTrue(rebound.contains(changed))
        XCTAssertFalse(rebound.contains(visible[0]))
        XCTAssertFalse(rebound.contains(visible[2]))
    }

    func testReloadCancelsAspectBuild() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        let stale = harness.pendingAspects
        view.reloadData()
        XCTAssertEqual(harness.cancelCount, 1)
        stale?(MediaGridViewTests.testAspects(count: 1000))
        XCTAssertFalse(self.isExact(view))
    }

    func testZoomOneToThreeAnchors() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        guard let layout = view.gridLayout else {
            XCTFail("no layout")
            return
        }
        view.setContentOffset(layout.frame(at: 300).minY - 100.0)
        guard let frame = view.frameForItem(at: 300) else {
            XCTFail("no frame")
            return
        }
        let point = CGPoint(x: frame.midX, y: min(frame.midY, view.bounds.height * 0.5))
        view.setLevel(.three, animated: true, anchor: MediaGridZoomAnchor(index: 300, pointInView: point))
        XCTAssertNotNil(view.transition)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .three)
        guard let after = view.frameForItem(at: 300) else {
            XCTFail("no frame")
            return
        }
        XCTAssertTrue(view.bounds.intersects(after))
        XCTAssertTrue(after.minY - 1.0 <= point.y && point.y <= after.maxY + 1.0, "\(after) vs \(point)")
        XCTAssertNotNil(self.visibleCells(view)[300])

        view.setLevel(.one, animated: true, anchor: MediaGridZoomAnchor(index: 300, pointInView: CGPoint(x: after.midX, y: after.midY)))
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .one)
        guard let back = view.frameForItem(at: 300) else {
            XCTFail("no frame")
            return
        }
        XCTAssertTrue(back.minY <= after.midY + 1.0 && after.midY <= back.maxY + 1.0)
    }

    func testAnchorCellMorphsBetweenOneAndThree() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        view.setLevel(.three, animated: false)
        view.setContentOffset(3000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let index = view.index(at: centre) else {
            XCTFail("no index")
            return
        }
        XCTAssertNotEqual(MediaGridViewTests.testAspects(count: 1000)[index], 1.0)
        view.setLevel(.one, animated: true, anchor: MediaGridZoomAnchor(index: index, pointInView: centre))
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        let host = view.layer
        let sourceFrame = transition.sourceLayout.frame(at: index)
        let targetFrame = transition.targetLayout.frame(at: index)
        XCTAssertGreaterThan(abs(targetFrame.height / sourceFrame.height - targetFrame.width / sourceFrame.width), 0.1)
        var heights: [CGFloat] = []
        for progress in [0.0, 0.25, 0.5, 0.75, 1.0] as [CGFloat] {
            transition.apply(progress: progress)
            let outgoing = transition.outgoing.convert(sourceFrame, to: host)
            let incoming = transition.incoming.convert(targetFrame, to: host)
            XCTAssertEqual(outgoing.minY, incoming.minY, accuracy: 0.5, "progress \(progress)")
            XCTAssertEqual(outgoing.height, incoming.height, accuracy: 0.5, "progress \(progress)")
            XCTAssertEqual(outgoing.width, incoming.width, accuracy: 0.5, "progress \(progress)")
            XCTAssertTrue(outgoing.minY <= centre.y && centre.y <= outgoing.maxY, "progress \(progress)")
            heights.append(incoming.height)
        }
        XCTAssertEqual(heights[0], sourceFrame.height, accuracy: 0.5)
        XCTAssertEqual(heights[4], targetFrame.height, accuracy: 0.5)
        let lastIncoming = transition.incoming.convert(targetFrame, to: host)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .one)
        guard let settled = view.frameForItem(at: index) else {
            XCTFail("no frame")
            return
        }
        XCTAssertEqual(settled.minY, lastIncoming.minY, accuracy: 0.5)
    }

    func testPinchThreeToOneSettlesAtOne() {
        let (view, _, harness) = self.makeLevelOneView(count: 1000)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        view.setLevel(.three, animated: false)
        view.setContentOffset(3000.0)
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let index = view.index(at: centre) else {
            XCTFail("no index")
            return
        }
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: 2.0)
        XCTAssertEqual(view.transition?.targetLevel, .one)
        view._testPinch(.changed, center: centre, scale: 3.5)
        view._testPinch(.ended, center: centre, scale: 3.5)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .one)
        XCTAssertTrue(view.gridLayout is MediaGridAspectLayout)
        guard let frame = view.frameForItem(at: index) else {
            XCTFail("no frame")
            return
        }
        XCTAssertTrue(view.bounds.intersects(frame))
    }
}

private final class LevelOneHarness {
    var pendingAspects: (([Float]) -> Void)?
    var cancelCount = 0
    var tableBuilds = 0
    var buildsTablesImmediately = true
    var pendingTables: [() -> Void] = []
}

private final class MarkerTestCell: MediaGridCellLayer {
    private var marker: CALayer?

    override func bind(index: Int, detail: MediaGridCellDetail) {
        super.bind(index: index, detail: detail)
        if detail == .full {
            if self.marker == nil {
                let marker = CALayer()
                self.addSublayer(marker)
                self.marker = marker
            }
        } else {
            self.marker?.removeFromSuperlayer()
            self.marker = nil
        }
    }
}

private final class Box {
    var values: Set<Int> = []
}

private final class SelectableTestCell: MediaGridCellLayer {
    var selected = false

    override func setSelected(_ selected: Bool) {
        self.selected = selected
    }
}

private final class DetailRecordingCell: MediaGridCellLayer {
    var detail: MediaGridCellDetail?

    override func bind(index: Int, detail: MediaGridCellDetail) {
        super.bind(index: index, detail: detail)
        self.detail = detail
    }
}
