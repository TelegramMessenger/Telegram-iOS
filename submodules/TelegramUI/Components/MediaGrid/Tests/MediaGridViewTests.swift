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
        XCTAssertEqual(view.level, .fifteen)
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
        XCTAssertEqual(view.level, .five)
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
