import XCTest
@testable import CoreList
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

    func testDateCacheStaysBounded() {
        let (view, dataSource) = self.makeView(count: 100_000)
        view.setLevel(.thirtyOne, animated: false)
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        for row in 0 ..< 2000 {
            view.setContentOffset(layout.frame(at: row * layout.columns).minY)
            XCTAssertEqual(view.topVisibleDate, dataSource.date(at: row * layout.columns))
        }
        XCTAssertLessThanOrEqual(view.dateCache.count, MediaGridView.dateCacheLimit)
        let index = view.topVisibleIndex!
        let calls = dataSource.dateCalls[index] ?? 0
        _ = view.topVisibleDate
        XCTAssertEqual(dataSource.dateCalls[index], calls)
    }

    func testTopInsetChangeDuringFlingKeepsFlying() {
        let (view, window) = self.makeWindowedView(count: 10_000)
        view.geometryInsets = UIEdgeInsets(top: 44.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        view.setContentOffset(5000.0)
        self.fling(view, velocity: 3000.0)
        XCTAssertTrue(view.engine.isDecelerating)
        let before = view.contentOffset
        view.geometryInsets = UIEdgeInsets(top: 100.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        XCTAssertTrue(view.engine.isDecelerating)
        XCTAssertEqual(view.contentOffset, before + 56.0, accuracy: 1e-6)
        self.spinUntilSettled(view)
        XCTAssertGreaterThan(view.contentOffset, before + 56.0)
        self.assertCellsMatchLayout(view, "after fling settles")
        window.isHidden = true
    }

    func testLayoutPassKeepsRubberBandedDrag() {
        let (view, _) = self.makeView(count: 1000)
        let maxOffset = view.contentHeight - view.bounds.height
        view.setContentOffset(maxOffset)
        view.engine.applyPanUpdate(state: .began, translation: .zero, velocity: .zero, forced: false, isIndirect: false)
        view.engine.applyPanUpdate(state: .changed, translation: CGPoint(x: 0.0, y: -200.0), velocity: .zero, forced: false, isIndirect: false)
        let stretched = view.contentOffset
        XCTAssertGreaterThan(stretched, maxOffset)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertEqual(view.contentOffset, stretched, accuracy: 1e-6)
        view.engine.applyPanUpdate(state: .ended, translation: CGPoint(x: 0.0, y: -200.0), velocity: .zero, forced: false, isIndirect: false)
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
        let cameraCenter = CGPoint(x: camera.frame.midX, y: camera.frame.midY)
        XCTAssertNil(view.index(at: cameraCenter))
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

    func testZoomCrossfadeKeepsDenseLevelUnderSparseAndShowsNoBackground() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        for zoomsOut in [true, false] {
            if zoomsOut {
                view.zoomOut()
            } else {
                view.zoomIn()
            }
            guard let transition = view.transition, let sublayers = transition.incoming.superlayer?.sublayers, let incomingIndex = sublayers.firstIndex(where: { $0 === transition.incoming }), let outgoingIndex = sublayers.firstIndex(where: { $0 === transition.outgoing }) else {
                XCTFail("no transition")
                return
            }
            let dense = zoomsOut ? transition.incoming : transition.outgoing
            let sparse = zoomsOut ? transition.outgoing : transition.incoming
            XCTAssertEqual(zoomsOut, incomingIndex < outgoingIndex)
            for step in 0 ... 40 {
                let progress = CGFloat(step) / 40.0
                transition.apply(progress: progress)
                let background = (1.0 - CGFloat(sparse.opacity)) * (1.0 - CGFloat(dense.opacity))
                XCTAssertLessThanOrEqual(background, 0.04, "zoomsOut \(zoomsOut) progress \(progress)")
            }
            transition.apply(progress: 0.0)
            XCTAssertEqual(transition.outgoing.opacity, 1.0)
            XCTAssertEqual(transition.incoming.opacity, 0.0)
            transition.apply(progress: 1.0)
            XCTAssertEqual(transition.outgoing.opacity, 0.0)
            XCTAssertEqual(transition.incoming.opacity, 1.0)
            view._testFinishAnimations()
        }
        XCTAssertEqual(view.level, .three)
    }

    func testAnimatedZoomOpacityKeyframesShowNoBackground() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        for zoomsOut in [true, false] {
            if zoomsOut {
                view.zoomOut()
            } else {
                view.zoomIn()
            }
            guard let transition = view.transition, let outgoing = transition.outgoing.animation(forKey: "mediaGridZoom.opacity") as? CAKeyframeAnimation, let incoming = transition.incoming.animation(forKey: "mediaGridZoom.opacity") as? CAKeyframeAnimation, let outgoingValues = outgoing.values as? [NSNumber], let incomingValues = incoming.values as? [NSNumber] else {
                XCTFail("no opacity keyframes")
                return
            }
            XCTAssertEqual(outgoingValues.count, incomingValues.count)
            XCTAssertEqual(outgoing.keyTimes, incoming.keyTimes)
            XCTAssertEqual(outgoingValues.first?.floatValue, 1.0)
            XCTAssertEqual(incomingValues.first?.floatValue, 0.0)
            XCTAssertEqual(outgoingValues.last?.floatValue, 0.0)
            XCTAssertEqual(incomingValues.last?.floatValue, 1.0)
            for (outgoingValue, incomingValue) in zip(outgoingValues, incomingValues) {
                let background = (1.0 - CGFloat(outgoingValue.floatValue)) * (1.0 - CGFloat(incomingValue.floatValue))
                XCTAssertLessThanOrEqual(background, 0.04, "zoomsOut \(zoomsOut)")
            }
            view._testFinishAnimations()
        }
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

    func testCameraFadesBetweenThreeAndFive() {
        let (view, _) = self.makeView(count: 1000)
        let camera = UIView()
        view.cameraView = camera
        view.layoutIfNeeded()
        XCTAssertEqual(view.level, .three)
        let slots: Set<MediaGridSlot> = [MediaGridSlot(row: 0, column: 0), MediaGridSlot(row: 1, column: 0)]
        guard let sourceFrame = view.currentLayout?.reservedFrame(slots) else {
            XCTFail("no camera frame")
            return
        }
        view.zoomOut()
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        XCTAssertEqual(transition.targetLayout.frame(at: 0), (transition.targetLayout as? MediaGridUniformLayout)?.reservedFrame([MediaGridSlot(row: 0, column: 0)]))
        transition.apply(progress: 0.0)
        XCTAssertEqual(camera.frame, sourceFrame)
        XCTAssertEqual(camera.alpha, 1.0)
        transition.apply(progress: 0.5)
        XCTAssertEqual(camera.alpha, 0.5, accuracy: 1e-6)
        transition.apply(progress: 1.0)
        XCTAssertEqual(camera.alpha, 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
        XCTAssertTrue(camera.isHidden)
        XCTAssertFalse(view.isCameraVisible)
        view.zoomIn()
        XCTAssertFalse(camera.isHidden)
        guard let back = view.transition else {
            XCTFail("no transition back")
            return
        }
        back.apply(progress: 0.0)
        XCTAssertEqual(camera.alpha, 0.0)
        back.apply(progress: 1.0)
        XCTAssertEqual(camera.alpha, 1.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(camera.frame, sourceFrame)
        XCTAssertFalse(camera.isHidden)
        XCTAssertEqual(camera.alpha, 1.0)
    }

    func testCameraTakesNoPartBetweenFiveAndFifteen() {
        let (view, _) = self.makeView(count: 1000)
        let camera = UIView()
        view.cameraView = camera
        view.layoutIfNeeded()
        view.setLevel(.five, animated: false)
        XCTAssertTrue(camera.isHidden)
        view.zoomOut()
        XCTAssertNil(view.transition?.camera)
        XCTAssertTrue(camera.isHidden)
        view._testFinishAnimations()
        view.zoomIn()
        XCTAssertNil(view.transition?.camera)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
        XCTAssertTrue(camera.isHidden)
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
        view.setLevel(.three, animated: false)
        XCTAssertEqual(camera.alpha, 1.0)
        XCTAssertFalse(camera.isHidden)
        view.setLevel(.fifteen, animated: true)
        XCTAssertEqual(camera.alpha, 0.0)
        XCTAssertNotNil(camera.layer.animation(forKey: "mediaGridZoom.opacity"))
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .fifteen)
        XCTAssertEqual(camera.alpha, 0.0)
        XCTAssertTrue(CATransform3DIsIdentity(camera.layer.transform))
        view.setLevel(.three, animated: true)
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
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let expected = layout.index(at: CGPoint(x: center.x, y: center.y + presentedOffset))
        XCTAssertNotNil(expected)
        XCTAssertNotEqual(expected, layout.index(at: CGPoint(x: center.x, y: center.y + 20_000.0)))
        view._testPinch(.began, center: center)
        XCTAssertFalse(view.isUserScrolling)
        XCTAssertFalse(view.engine.isScrollEnabled)
        XCTAssertEqual(view.pinchAnchor?.index, expected)
        XCTAssertEqual(view.contentOffset, presentedOffset, accuracy: 0.5)
        host.layer.removeAnimation(forKey: "testFlight")
        view._testPinch(.ended, center: center)
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
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: pow(3.0 / 5.0, 0.3))
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        XCTAssertEqual(transition.sourceLevel, .three)
        XCTAssertEqual(transition.targetLevel, .five)
        XCTAssertEqual(transition.progress, 0.3, accuracy: 1e-6)
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(self.layoutLayerCount(view), 2)
        view._testPinch(.ended, center: center, scale: pow(3.0 / 5.0, 0.3), velocity: 0.0)
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
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let anchorIndex = view.index(at: center) else {
            XCTFail("no anchor")
            return
        }
        var levels: [MediaGridLevel] = []
        view.onLevelChanged = { levels.append($0) }
        var scrolls = 0
        view.onScroll = { _ in scrolls += 1 }
        let cachedBefore = dataSource.cachedIndices
        view._testPinch(.began, center: center)
        var scale: CGFloat = 1.0
        while scale > 3.0 / 15.0 * pow(15.0 / 31.0, 0.2) {
            scale *= 0.97
            view._testPinch(.changed, center: center, scale: scale)
            XCTAssertLessThanOrEqual(self.layoutLayerCount(view), 2)
            XCTAssertEqual(view.level, .three)
        }
        XCTAssertEqual(view.transition?.sourceLevel, .fifteen)
        XCTAssertEqual(view.transition?.targetLevel, .thirtyOne)
        XCTAssertEqual(levels, [])
        XCTAssertEqual(scrolls, 0)
        XCTAssertEqual(dataSource.cachedIndices, cachedBefore)
        view._testPinch(.ended, center: center, scale: scale, velocity: 0.0)
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
        XCTAssertTrue(frame.minY <= center.y && center.y <= frame.maxY, "\(frame) \(center)")
    }

    func testPinchRoundTripThroughClampedLevelsRestoresOffset() {
        let (view, _) = self.makeView(count: 100_000)
        for start in [0.0, 20_000.0] as [CGFloat] {
            view.setContentOffset(start)
            let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            view._testPinch(.began, center: center)
            var scale: CGFloat = 1.0
            while scale > 3.0 / 15.0 * 0.9 {
                scale *= 0.95
                view._testPinch(.changed, center: center, scale: scale)
            }
            while scale < 1.0 {
                scale = min(1.0, scale / 0.95)
                view._testPinch(.changed, center: center, scale: scale)
            }
            XCTAssertEqual(view.level, .three)
            view._testPinch(.ended, center: center, scale: 1.0, velocity: 0.0)
            view._testFinishAnimations()
            XCTAssertNil(view.transition)
            XCTAssertEqual(view.level, .three)
            XCTAssertEqual(view.contentOffset, start, accuracy: 0.5)
        }
    }

    func testPinchBackAcrossLevelReusesShownLayer() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 3.0 / 5.0 * pow(5.0 / 15.0, 0.6))
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(view.transition?.sourceLevel, .five)
        guard let fiveLayer = view.transition?.outgoing else {
            XCTFail("no transition")
            return
        }
        let shownCells = fiveLayer.visibleCells
        view._testPinch(.changed, center: center, scale: pow(3.0 / 5.0, 0.9))
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
        view._testPinch(.ended, center: center, scale: pow(3.0 / 5.0, 0.9), velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
        XCTAssertEqual(levels, [.five])
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: pow(5.0 / 3.0, 0.3))
        view._testPinch(.ended, center: center, scale: pow(5.0 / 3.0, 0.3), velocity: 2.0)
        guard let spring = view.transition?.incoming.animation(forKey: "mediaGridZoom.transform") as? CASpringAnimation else {
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
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 0.8)
        XCTAssertEqual(view.transition?.targetLevel, .five)
        view._testPinch(.changed, center: center, scale: 1.0)
        XCTAssertEqual(view.transition?.targetLevel, .five)
        XCTAssertEqual(view.transition?.progress ?? -1.0, 0.0, accuracy: 1e-9)
        view._testPinch(.changed, center: center, scale: 1.3)
        XCTAssertEqual(view.transition?.sourceLevel, .three)
        XCTAssertEqual(view.transition?.targetLevel, .one)
        XCTAssertEqual(self.layoutLayerCount(view), 2)
        view._testPinch(.ended, center: center, scale: 1.3, velocity: 2.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .one)
    }

    func testPinchReleaseCarriesVelocity() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: pow(3.0 / 5.0, 0.4))
        view._testPinch(.ended, center: center, scale: pow(3.0 / 5.0, 0.4), velocity: -2.0)
        guard let transition = view.transition, let spring = transition.incoming.animation(forKey: "mediaGridZoom.transform") as? CASpringAnimation else {
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
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        XCTAssertTrue(view.transition === transition)
        XCTAssertGreaterThan(transition.progress, 0.02)
        XCTAssertLessThan(transition.progress, 0.98)
        XCTAssertNil(transition.incoming.animation(forKey: "mediaGridZoom.opacity"))
        self.spin(0.1)
        XCTAssertTrue(view.transition === transition)
        XCTAssertEqual(levels, [])
        let presented = transition.progress
        view._testPinch(.changed, center: center, scale: 1.0)
        XCTAssertEqual(transition.progress, presented, accuracy: 1e-6)
        view._testPinch(.ended, center: center, scale: 1.0, velocity: -3.0)
        view._testPinch(.began, center: center)
        XCTAssertTrue(view.transition === transition)
        self.spin(0.1)
        XCTAssertTrue(view.transition === transition)
        view._testPinch(.ended, center: center, scale: 1.0, velocity: -3.0)
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
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 0.3)
        XCTAssertNil(view.transition)
        let hostLayer = view.engine.contentHost.layer
        XCTAssertTrue(CATransform3DIsIdentity(view.layer.sublayerTransform))
        let squeezed = hostLayer.sublayerTransform.m11
        XCTAssertLessThan(squeezed, 1.0)
        XCTAssertGreaterThan(squeezed, 0.85)
        let content = view.activeLayoutLayer
        let pivot = content.convert(CGPoint(x: center.x, y: center.y + view.contentOffset), to: view.layer)
        XCTAssertEqual(pivot.x, center.x, accuracy: 0.5)
        XCTAssertEqual(pivot.y, center.y, accuracy: 0.5)
        let corner = content.convert(CGPoint(x: 0.0, y: view.contentOffset), to: view.layer)
        XCTAssertEqual(corner.x, center.x * (1.0 - squeezed), accuracy: 0.5)
        view._testPinch(.changed, center: center, scale: 0.01)
        XCTAssertLessThan(hostLayer.sublayerTransform.m11, squeezed)
        XCTAssertGreaterThan(hostLayer.sublayerTransform.m11, 0.85)
        view._testPinch(.ended, center: center, scale: 0.01, velocity: 0.0)
        XCTAssertTrue(CATransform3DIsIdentity(hostLayer.sublayerTransform))
        XCTAssertEqual(view.level, .thirtyOne)
        XCTAssertTrue(view.engine.isScrollEnabled)
    }

    private func beginIdlePinch(_ view: MediaGridView) -> CGPoint {
        view.setContentOffset(20_000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 1.0)
        XCTAssertNotNil(view.pinchAnchor)
        XCTAssertNil(view.transition)
        return center
    }

    func testSetContentOffsetEndsIdlePinch() {
        let (view, _) = self.makeView(count: 100_000)
        let center = self.beginIdlePinch(view)
        view.setContentOffset(40_000.0)
        XCTAssertNil(view.pinchAnchor)
        XCTAssertTrue(view.engine.isScrollEnabled)
        view._testPinch(.changed, center: center, scale: 0.7)
        XCTAssertNil(view.transition)
        XCTAssertEqual(view.contentOffset, 40_000.0, accuracy: 1e-6)
    }

    func testReloadDataEndsIdlePinch() {
        let (view, dataSource) = self.makeView(count: 100_000)
        let center = self.beginIdlePinch(view)
        dataSource.count = 50
        view.reloadData()
        XCTAssertNil(view.pinchAnchor)
        XCTAssertTrue(view.engine.isScrollEnabled)
        view._testPinch(.changed, center: center, scale: 0.7)
        XCTAssertNil(view.transition)
        XCTAssertEqual(view.currentLayout?.count, 50)
    }

    func testSetLevelEndsIdlePinch() {
        let (view, _) = self.makeView(count: 100_000)
        let center = self.beginIdlePinch(view)
        view.setLevel(.five, animated: false)
        XCTAssertNil(view.pinchAnchor)
        XCTAssertEqual(view.level, .five)
        view._testPinch(.changed, center: center, scale: 0.5)
        XCTAssertNil(view.transition)
        XCTAssertEqual(self.layoutLayerCount(view), 1)
    }

    func testAnimatedSetLevelEndsIdlePinch() {
        let (view, _) = self.makeView(count: 100_000)
        let center = self.beginIdlePinch(view)
        view.setLevel(.five, animated: true)
        XCTAssertNil(view.pinchAnchor)
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        view._testPinch(.changed, center: center, scale: 1.3)
        XCTAssertTrue(view.transition === transition)
        XCTAssertEqual(transition.destination, 1.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
    }

    func testPinchJitterAtBoundaryKeepsPair() {
        let (view, dataSource) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: pow(3.0 / 5.0, 0.95))
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        view._testPinch(.changed, center: center, scale: 3.0 / 5.0)
        let requests = dataSource.requestCount
        for scale in [3.0 / 5.0 * 0.98, 3.0 / 5.0 * 1.01, 3.0 / 5.0 * 1.005, 3.0 / 5.0 * 0.985] as [CGFloat] {
            view._testPinch(.changed, center: center, scale: scale)
            XCTAssertTrue(view.transition === transition)
        }
        XCTAssertEqual(dataSource.requestCount, requests)
        XCTAssertGreaterThan(transition.progress, 1.0)
        XCTAssertEqual(transition.incoming.opacity, 1.0)
        view._testPinch(.changed, center: center, scale: 3.0 / 5.0 * 0.8)
        XCTAssertEqual(view.transition?.sourceLevel, .five)
        XCTAssertEqual(view.transition?.targetLevel, .fifteen)
    }

    func testPinchBindsGrowingWindowWithoutMargin() {
        let (view, _) = self.makeView(count: 100_000)
        view.setLevel(.fifteen, animated: false)
        view.setContentOffset(5_000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: pow(15.0 / 31.0, 0.02))
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        let early = transition.incoming.visibleCells.count
        let fullRect = transition.incomingRect(at: 0.0).union(transition.incomingRect(at: 1.0))
        let full = transition.targetLayout.indexRange(intersecting: fullRect).count
        let taskEightWindow = transition.targetLayout.indexRange(intersecting: fullRect.insetBy(dx: 0.0, dy: -view.bounds.height * 0.25)).count
        XCTAssertLessThan(early, taskEightWindow / 2)
        view._testPinch(.changed, center: center, scale: pow(15.0 / 31.0, 0.98))
        XCTAssertTrue(view.transition === transition)
        XCTAssertGreaterThanOrEqual(transition.incoming.visibleCells.count, full)
        let margin = view.bounds.height * 0.25
        let withMargin = transition.targetLayout.indexRange(intersecting: fullRect.insetBy(dx: 0.0, dy: -margin)).count
        XCTAssertLessThan(transition.incoming.visibleCells.count, withMargin)
    }

    func testFastPinchAcrossLevelsBindsOnlyFinalPair() {
        let (view, dataSource) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: pow(3.0 / 5.0, 0.5))
        XCTAssertNotNil(view.transition)
        let requests = dataSource.requestCount
        view._testPinch(.changed, center: center, scale: 3.0 / 15.0 * pow(15.0 / 31.0, 0.5))
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

    private func pinchGradually(_ view: MediaGridView, center: CGPoint, to scale: CGFloat) {
        var current: CGFloat = 1.0
        let step: CGFloat = scale < 1.0 ? 0.97 : 1.0 / 0.97
        while (scale < 1.0 && current * step > scale) || (scale > 1.0 && current * step < scale) {
            current *= step
            view._testPinch(.changed, center: center, scale: current)
        }
        view._testPinch(.changed, center: center, scale: scale)
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
                let center = CGPoint(x: view.bounds.midX, y: view.bounds.height * fraction)
                view._testPinch(.began, center: center)
                var scale: CGFloat = 1.0
                for target in path {
                    let step: CGFloat = target < scale ? 0.97 : 1.0 / 0.97
                    while (target < scale && scale * step > target) || (target > scale && scale * step < target) {
                        scale *= step
                        view._testPinch(.changed, center: center, scale: scale)
                    }
                    scale = target
                    view._testPinch(.changed, center: center, scale: scale)
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
            let center = CGPoint(x: view.bounds.midX, y: view.bounds.height * fraction)
            view._testPinch(.began, center: center)
            view._testPinch(.changed, center: center, scale: pow(3.0 / 5.0, 0.6))
            view._testPinch(.changed, center: center, scale: 3.0 / 5.0 * pow(5.0 / 15.0, 0.045))
            XCTAssertGreaterThan(view.transition?.progress ?? 0.0, 1.0)
            self.assertVisibleCellsBound(view, "f=\(fraction)")
        }
    }

    func testReleaseInBandFollowsFling() {
        let (view, _) = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        var levels: [MediaGridLevel] = []
        view.onLevelChanged = { levels.append($0) }
        view._testPinch(.began, center: center)
        let band = 3.0 / 5.0 * pow(5.0 / 15.0, 0.03)
        self.pinchGradually(view, center: center, to: band)
        XCTAssertEqual(view.transition?.targetLevel, .five)
        XCTAssertGreaterThan(view.transition?.progress ?? 0.0, 1.0)
        view._testPinch(.ended, center: center, scale: band, velocity: -2.0)
        XCTAssertEqual(view.transition?.sourceLevel, .five)
        XCTAssertEqual(view.transition?.targetLevel, .fifteen)
        XCTAssertEqual(view.transition?.destination, 1.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .fifteen)
        XCTAssertEqual(levels, [.fifteen])

        view.setLevel(.three, animated: false)
        levels = []
        view._testPinch(.began, center: center)
        self.pinchGradually(view, center: center, to: 3.0 / 5.0 * pow(5.0 / 15.0, 0.3))
        let back = pow(3.0 / 5.0, 0.97)
        view._testPinch(.changed, center: center, scale: back)
        XCTAssertEqual(view.transition?.sourceLevel, .five)
        XCTAssertEqual(view.transition?.targetLevel, .fifteen)
        XCTAssertLessThan(view.transition?.progress ?? 1.0, 0.0)
        view._testPinch(.ended, center: center, scale: back, velocity: 2.0)
        XCTAssertEqual(view.transition?.targetLevel, .three)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(levels, [])

        view._testPinch(.began, center: center)
        self.pinchGradually(view, center: center, to: band)
        view._testPinch(.ended, center: center, scale: band, velocity: 0.0)
        XCTAssertEqual(view.transition?.targetLevel, .five)
        XCTAssertEqual(view.transition?.destination, 1.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
    }

    func testBandReleaseInterruptKeepsGeometry() {
        let (view, window) = self.makeWindowedView(count: 100_000)
        view.setContentOffset(20_000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        let band = 3.0 / 5.0 * pow(5.0 / 15.0, 0.04)
        self.pinchGradually(view, center: center, to: band)
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        let extrapolated = transition.progress
        XCTAssertGreaterThan(extrapolated, 1.0)
        view._testPinch(.ended, center: center, scale: band, velocity: 0.0)
        XCTAssertEqual(transition.destination, 1.0)
        let keyframes = transition.incoming.animation(forKey: "mediaGridZoom.opacity") as? CAKeyframeAnimation
        XCTAssertLessThanOrEqual((keyframes?.values as? [NSNumber])?.map(\.floatValue).max() ?? 2.0, 1.0)
        CATransaction.flush()
        self.spin(0.01)
        view._testPinch(.began, center: center)
        XCTAssertTrue(view.transition === transition)
        XCTAssertEqual(transition.progress, extrapolated, accuracy: 0.02)
        view._testPinch(.changed, center: center, scale: 1.0)
        XCTAssertTrue(view.transition === transition)
        XCTAssertEqual(transition.progress, extrapolated, accuracy: 0.02)
        view._testPinch(.ended, center: center, scale: 1.0, velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
        window.isHidden = true
    }

    func testPinchIgnoredWhenZoomDisabled() {
        let (view, _) = self.makeView(count: 100_000)
        view.isZoomEnabled = false
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 0.5)
        XCTAssertNil(view.transition)
        XCTAssertNil(view.pinchAnchor)
        XCTAssertTrue(view.engine.isScrollEnabled)
        view._testPinch(.ended, center: center, scale: 0.5, velocity: -3.0)
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
        view.aspectLoader = { count, _, completion in
            harness.loadCounts.append(count)
            harness.pendingAspects = completion
            return {
                harness.cancelCount += 1
            }
        }
        view.aspectChangeApplier = { aspects, changes, reader, completion in
            harness.pendingAspectChanges = (aspects, changes, reader, completion)
            return {
                harness.changeCancelCount += 1
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
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        for _ in 0 ..< 3 {
            view._testPinch(.began, center: center)
            for scale in stride(from: 1.0, through: 0.3, by: -0.05) as StrideThrough<CGFloat> {
                view._testPinch(.changed, center: center, scale: scale)
            }
            for scale in stride(from: 0.3, through: 1.0, by: 0.05) as StrideThrough<CGFloat> {
                view._testPinch(.changed, center: center, scale: scale)
            }
            view._testPinch(.ended, center: center, scale: 1.0)
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
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let index = view.index(at: center) else {
            XCTFail("no index")
            return
        }
        XCTAssertNotEqual(MediaGridViewTests.testAspects(count: 1000)[index], 1.0)
        view.setLevel(.one, animated: true, anchor: MediaGridZoomAnchor(index: index, pointInView: center))
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
            XCTAssertTrue(outgoing.minY <= center.y && center.y <= outgoing.maxY, "progress \(progress)")
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
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let index = view.index(at: center) else {
            XCTFail("no index")
            return
        }
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 2.0)
        XCTAssertEqual(view.transition?.targetLevel, .one)
        view._testPinch(.changed, center: center, scale: 3.5)
        view._testPinch(.ended, center: center, scale: 3.5)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .one)
        XCTAssertTrue(view.gridLayout is MediaGridAspectLayout)
        guard let frame = view.frameForItem(at: index) else {
            XCTFail("no frame")
            return
        }
        XCTAssertTrue(view.bounds.intersects(frame))
    }

    private func assertCellsMatchLayout(_ view: MediaGridView, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let layout = view.gridLayout else {
            XCTFail("no layout \(message)", file: file, line: line)
            return
        }
        let cells = self.visibleCells(view)
        for (index, cell) in cells {
            XCTAssertLessThan(index, layout.count, message, file: file, line: line)
            XCTAssertEqual(cell.index, index, message, file: file, line: line)
            self.assertFrame(cell.frame, layout.frame(at: index), file: file, line: line)
        }
        for index in layout.indexRange(intersecting: self.viewport(view)) {
            XCTAssertNotNil(cells[index], "\(message): viewport index \(index) has no cell", file: file, line: line)
        }
        XCTAssertEqual(self.layoutLayerCount(view), 1, message, file: file, line: line)
    }

    private func assertContiguousRows(_ layout: MediaGridLayout, file: StaticString = #filePath, line: UInt = #line) {
        for index in 0 ..< layout.count - 1 {
            XCTAssertEqual(layout.frame(at: index + 1).minY, layout.frame(at: index).maxY + 1.0, accuracy: 1e-6, "row \(index)", file: file, line: line)
        }
    }

    func testInsertAboveKeepsTopItem() {
        let (view, dataSource) = self.makeView(count: 10_000)
        view.setLevel(.five, animated: false)
        guard let layout = view.gridLayout else {
            XCTFail("no layout")
            return
        }
        view.setContentOffset(layout.frame(at: 500).minY + 7.0)
        XCTAssertEqual(view.topVisibleIndex, 500)
        guard let before = view.frameForItem(at: 500) else {
            XCTFail("no frame")
            return
        }
        let requests = dataSource.requestCount
        dataSource.count += 10
        view.apply(MediaGridChanges(removed: [], inserted: IndexSet(0 ..< 10), changed: []))
        XCTAssertEqual(view.topVisibleIndex, 510)
        XCTAssertEqual(view.frameForItem(at: 510)?.minY ?? -1.0, before.minY, accuracy: 1e-6)
        XCTAssertEqual(view.gridLayout?.count, 10_010)
        XCTAssertEqual(dataSource.requestCount, requests)
        self.assertCellsMatchLayout(view, "after insert")
    }

    func testRemoveAnchorKeepsNearest() {
        let (view, dataSource) = self.makeView(count: 10_000)
        view.setLevel(.five, animated: false)
        guard let layout = view.gridLayout else {
            XCTFail("no layout")
            return
        }
        view.setContentOffset(layout.frame(at: 500).minY + 7.0)
        guard let before = view.frameForItem(at: 500) else {
            XCTFail("no frame")
            return
        }
        dataSource.count -= 5
        view.apply(MediaGridChanges(removed: IndexSet(498 ..< 503), inserted: [], changed: []))
        XCTAssertEqual(view.frameForItem(at: 498)?.minY ?? -1.0, before.minY, accuracy: 1e-6)
        self.assertCellsMatchLayout(view, "after tie removal")

        guard let anchor = view.topVisibleIndex, let top = view.frameForItem(at: anchor) else {
            XCTFail("no top")
            return
        }
        XCTAssertEqual(anchor, 495)
        dataSource.count -= 4
        view.apply(MediaGridChanges(removed: IndexSet(496 ..< 500), inserted: [], changed: []))
        XCTAssertEqual(view.frameForItem(at: 495)?.minY ?? -1.0, top.minY, accuracy: 1e-6)
        XCTAssertEqual(view.topVisibleIndex, 495)
        self.assertCellsMatchLayout(view, "after second removal")

        let tail = MediaGridChanges(removed: IndexSet(495 ..< 9_991), inserted: [], changed: [])
        XCTAssertEqual(tail.nearestSurvivor(toOld: 495, oldCount: 9_991), 494)
        dataSource.count = 495
        view.apply(tail)
        XCTAssertEqual(view.contentOffset, view.contentHeight - view.bounds.height, accuracy: 1e-6)
        XCTAssertTrue(view.bounds.intersects(view.frameForItem(at: 494) ?? .null))
        self.assertCellsMatchLayout(view, "after removal through the end")

        dataSource.count = 0
        view.apply(MediaGridChanges(removed: IndexSet(0 ..< 495), inserted: [], changed: []))
        XCTAssertEqual(view.contentOffset, 0.0)
        XCTAssertTrue(self.visibleCells(view).isEmpty)
    }

    func testChangedRebindsOnlyVisible() {
        let (view, dataSource) = self.makeView(count: 10_000)
        view.setContentOffset(20_000.0)
        let visible = self.visibleCells(view).keys.sorted()
        XCTAssertGreaterThan(visible.count, 10)
        let requests = dataSource.requests.count
        let changed: IndexSet = [visible[2], visible[7], 5, visible.last! + 3000]
        view.apply(MediaGridChanges(removed: [], inserted: [], changed: changed))
        let rebound = dataSource.requests[requests...].map { $0.index }
        XCTAssertEqual(rebound.sorted(), [visible[2], visible[7]])
        self.assertCellsMatchLayout(view, "after change")
    }

    func testAspectIndexAppliesChanges() {
        let index = MediaGridAspectIndex(aspects: [1.0, 0.5, 2.0, 1.5, 0.75])
        var reads: [Int] = []
        let changes = MediaGridChanges(removed: [1, 3], inserted: [0, 4], changed: [2])
        let result = index.apply(changes, aspectRatio: { i in
            reads.append(i)
            return [3.0, 9.0, 1.25, 9.0, 0.2][i]
        })
        XCTAssertEqual(result, [2.0, 1.0, 1.25, 0.75, 0.5])
        XCTAssertEqual(reads.sorted(), [0, 2, 4])

        var chainReads: [Int] = []
        let chained = index.apply([changes, MediaGridChanges(removed: [0], inserted: [2], changed: [])], aspectRatio: { i in
            chainReads.append(i)
            return [1.0, 1.25, 0.6, 0.75, 0.5][i]
        })
        XCTAssertEqual(chained, [1.0, 1.25, 0.6, 0.75, 0.5])
        XCTAssertEqual(chainReads.sorted(), [1, 2, 4])

        let counted = MediaGridAspectIndex(count: 3, aspectRatio: { [0.5, 1.0, 2.0][$0] })
        XCTAssertEqual(counted.apply(MediaGridChanges(removed: [1], inserted: [], changed: []), aspectRatio: { _ in 9.0 }), [0.5, 2.0])
    }

    func testChangesMapIndices() {
        let changes = MediaGridChanges(removed: [2, 3, 7], inserted: [0, 5], changed: [])
        let mapped = (0 ..< 10).map { changes.newIndex(forOld: $0) }
        XCTAssertEqual(mapped, [1, 2, nil, nil, 3, 4, 6, nil, 7, 8])
        XCTAssertTrue(changes.isValid(oldCount: 10, newCount: 9))
        XCTAssertFalse(changes.isValid(oldCount: 10, newCount: 10))
        XCTAssertFalse(MediaGridChanges(removed: [10], inserted: [], changed: []).isValid(oldCount: 10, newCount: 9))
        XCTAssertFalse(MediaGridChanges(removed: [], inserted: [], changed: [10]).isValid(oldCount: 10, newCount: 10))
    }

    func testMovedIndexShowsRightImage() {
        let (view, dataSource) = self.makeView(count: 1000)
        let bank = ImageBank()
        bank.identifiers = Array(0 ..< 1000)
        dataSource.imageForIndex = { index in
            return bank.image(for: bank.identifiers[index])
        }
        view.reloadData()
        view.setContentOffset(3000.0)
        let check: (String) -> Void = { message in
            let cells = self.visibleCells(view)
            XCTAssertFalse(cells.isEmpty)
            for (index, cell) in cells {
                XCTAssertTrue((cell.contents as AnyObject?) === bank.image(for: bank.identifiers[index]).cgImage, "\(message): index \(index)")
            }
        }
        check("before")
        let visible = self.visibleCells(view).keys.sorted()
        let middle = visible[visible.count / 2]
        bank.identifiers.insert(contentsOf: [5000, 5001], at: middle)
        bank.identifiers.remove(at: visible[1])
        dataSource.count += 1
        view.apply(MediaGridChanges(removed: [visible[1]], inserted: [middle - 1, middle], changed: []))
        check("after insert")

        dataSource.holdsDeliveries = true
        view.reloadData()
        bank.identifiers.insert(contentsOf: [6000, 6001, 6002], at: middle + 4)
        bank.identifiers.remove(at: middle)
        dataSource.count += 2
        view.apply(MediaGridChanges(removed: [middle], inserted: IndexSet(middle + 3 ..< middle + 6), changed: []))
        dataSource.flushHeldDeliveries()
        check("after held deliveries")
    }

    func testSelectionFollowsChange() {
        let selected = Box()
        let dataSource = TestDataSource(count: 100)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return SelectableTestCell()
        })
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.isItemSelected = { selected.values.contains($0) }
        view.layoutIfNeeded()
        selected.values = [4, 9]
        view.updateSelectionForVisibleItems()
        let changes = MediaGridChanges(removed: [0], inserted: [6, 7], changed: [])
        selected.values = Set(selected.values.compactMap { changes.newIndex(forOld: $0) })
        dataSource.count += 1
        view.apply(changes)
        var result: [Int: Bool] = [:]
        view.forEachVisibleCell { index, cell in
            result[index] = (cell as? SelectableTestCell)?.selected
        }
        XCTAssertEqual(selected.values, [3, 10])
        XCTAssertEqual(result[3], true)
        XCTAssertEqual(result[10], true)
        XCTAssertEqual(result[4], false)
        XCTAssertEqual(result[9], false)
    }

    func testChangeDuringAnimatedZoomFinishesIt() {
        let (view, dataSource) = self.makeView(count: 10_000)
        view.setContentOffset(5000.0)
        view.setLevel(.five, animated: true)
        XCTAssertNotNil(view.transition)
        dataSource.count += 3
        view.apply(MediaGridChanges(removed: [], inserted: IndexSet(0 ..< 3), changed: []))
        XCTAssertNil(view.transition)
        XCTAssertEqual(view.level, .five)
        XCTAssertEqual(view.gridLayout?.count, 10_003)
        XCTAssertTrue(view.engine.isScrollEnabled)
        self.assertCellsMatchLayout(view, "after change mid-zoom")
    }

    func testChangeDuringPinchEndsIt() {
        let (view, dataSource) = self.makeView(count: 10_000)
        view.setContentOffset(5000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 0.8)
        XCTAssertNotNil(view.transition)
        dataSource.count -= 3
        view.apply(MediaGridChanges(removed: IndexSet(0 ..< 3), inserted: [], changed: []))
        XCTAssertNil(view.transition)
        XCTAssertNil(view.pinchAnchor)
        XCTAssertTrue(view.engine.isScrollEnabled)
        view._testPinch(.changed, center: center, scale: 0.6)
        XCTAssertNil(view.transition)
        view._testPinch(.ended, center: center, scale: 0.6)
        XCTAssertEqual(view.gridLayout?.count, 9_997)
        self.assertCellsMatchLayout(view, "after change mid-pinch")
    }

    func testChangeDuringDragShiftsWithoutClamping() {
        let (view, dataSource) = self.makeView(count: 10_000)
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        let bottom = view.contentHeight - view.bounds.height
        view.setContentOffset(bottom)
        view.engine.applyPanUpdate(state: .began, translation: .zero, velocity: .zero, forced: false, isIndirect: false)
        XCTAssertTrue(view.isUserScrolling)
        guard let top = view.topVisibleIndex else {
            XCTFail("no top")
            return
        }
        dataSource.count = top + 3
        view.apply(MediaGridChanges(removed: IndexSet(top + 3 ..< 10_000), inserted: [], changed: []))
        let newMax = view.contentHeight - view.bounds.height
        XCTAssertLessThan(newMax, bottom - 2.0 * layout.itemSize.height)
        XCTAssertEqual(view.contentOffset, bottom, accuracy: 1e-6)
        XCTAssertTrue(view.isUserScrolling)
        dataSource.count += 30
        view.apply(MediaGridChanges(removed: [], inserted: IndexSet(0 ..< 30), changed: []))
        XCTAssertEqual(view.contentOffset, bottom + 10.0 * (layout.itemSize.height + 1.0), accuracy: 1e-6)
        view.engine.applyPanUpdate(state: .changed, translation: CGPoint(x: 0.0, y: 5.0), velocity: .zero, forced: false, isIndirect: false)
        XCTAssertLessThan(abs(view.contentOffset - (bottom + 10.0 * (layout.itemSize.height + 1.0))), 6.0)
        view.engine.applyPanUpdate(state: .ended, translation: CGPoint(x: 0.0, y: 5.0), velocity: .zero, forced: false, isIndirect: false)

        let (rest, restSource) = self.makeView(count: 10_000)
        rest.setContentOffset(bottom)
        restSource.count = top + 3
        rest.apply(MediaGridChanges(removed: IndexSet(top + 3 ..< 10_000), inserted: [], changed: []))
        XCTAssertEqual(rest.contentOffset, rest.contentHeight - rest.bounds.height, accuracy: 1e-6)
        self.assertCellsMatchLayout(rest, "after clamped removal")
    }

    private func fling(_ view: MediaGridView, velocity: CGFloat) {
        view.engine.decelerationMode = .stepped
        view.engine.applyPanUpdate(state: .began, translation: .zero, velocity: .zero, forced: false, isIndirect: false)
        for step in 1 ... 5 {
            view.engine.applyPanUpdate(state: .changed, translation: CGPoint(x: 0.0, y: -velocity * 0.008 * CGFloat(step)), velocity: CGPoint(x: 0.0, y: -velocity), forced: false, isIndirect: false)
        }
        view.engine.applyPanUpdate(state: .ended, translation: CGPoint(x: 0.0, y: -velocity * 0.04), velocity: CGPoint(x: 0.0, y: -velocity), forced: false, isIndirect: false)
    }

    private func spinUntilSettled(_ view: MediaGridView, timeout: TimeInterval = 10.0) {
        let deadline = Date().addingTimeInterval(timeout)
        while view.engine.isDecelerating && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func makeWindowedSourceView(count: Int) -> (MediaGridView, TestDataSource, UIWindow) {
        let (view, dataSource) = self.makeView(count: count)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: view.frame)
        window.frame = view.frame
        window.windowLevel = .alert
        window.isHidden = false
        window.addSubview(view)
        view.layoutIfNeeded()
        return (view, dataSource, window)
    }

    func testChangeDuringFlingInsertAboveShiftsByDelta() {
        let (view, dataSource, window) = self.makeWindowedSourceView(count: 10_000)
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        view.setContentOffset(5000.0)
        self.fling(view, velocity: 3000.0)
        XCTAssertTrue(view.engine.isDecelerating)
        let before = view.contentOffset
        dataSource.count += 30
        view.apply(MediaGridChanges(removed: [], inserted: IndexSet(0 ..< 30), changed: []))
        XCTAssertEqual(view.contentOffset, before + 10.0 * (layout.itemSize.height + 1.0), accuracy: 1e-6)
        XCTAssertTrue(view.engine.isDecelerating)
        self.spinUntilSettled(view)
        XCTAssertFalse(view.engine.isDecelerating)
        XCTAssertGreaterThan(view.contentOffset, before + 10.0 * (layout.itemSize.height + 1.0))
        self.assertCellsMatchLayout(view, "after fling settles")
        window.isHidden = true
    }

    func testChangeDuringFlingShrinkingBelowOffsetSpringsToNewEnd() {
        let (view, dataSource, window) = self.makeWindowedSourceView(count: 10_000)
        view.setContentOffset(view.contentHeight - view.bounds.height - 3000.0)
        self.fling(view, velocity: 2000.0)
        XCTAssertTrue(view.engine.isDecelerating)
        let before = view.contentOffset
        guard let top = view.topVisibleIndex else {
            XCTFail("no top")
            return
        }
        dataSource.count = top + 3
        view.apply(MediaGridChanges(removed: IndexSet(top + 3 ..< 10_000), inserted: [], changed: []))
        let newMax = view.contentHeight - view.bounds.height
        XCTAssertLessThan(newMax, before)
        XCTAssertEqual(view.contentOffset, before, accuracy: 1e-6)
        XCTAssertTrue(view.engine.isDecelerating)
        self.spinUntilSettled(view)
        XCTAssertFalse(view.engine.isDecelerating)
        XCTAssertEqual(view.contentOffset, newMax, accuracy: 0.5)
        self.assertCellsMatchLayout(view, "after spring back")
        window.isHidden = true
    }

    func testLevelOneChangeUsesPatchedRowsUntilRebuilt() {
        let (view, dataSource, harness) = self.makeLevelOneView(count: 1000)
        let aspects = MediaGridViewTests.testAspects(count: 1000)
        harness.pendingAspects?(aspects)
        XCTAssertTrue(self.isExact(view))
        guard let old = view.gridLayout else {
            XCTFail("no layout")
            return
        }
        view.setContentOffset(old.frame(at: 300).minY + 10.0)
        XCTAssertEqual(view.topVisibleIndex, 300)
        guard let before = view.frameForItem(at: 300) else {
            XCTFail("no frame")
            return
        }
        harness.buildsTablesImmediately = false
        let builds = harness.tableBuilds
        dataSource.count = 1001
        dataSource.aspectRatios = [0.5, 2.0, 1.0] + aspects.enumerated().filter { $0.offset != 10 && $0.offset != 11 }.map { CGFloat($0.element) }
        view.apply(MediaGridChanges(removed: [10, 11], inserted: [0, 1, 2], changed: []))
        XCTAssertNotNil(harness.pendingAspectChanges)
        guard let patched = view.gridLayout as? MediaGridAspectLayout else {
            XCTFail("no aspect layout")
            return
        }
        XCTAssertFalse(patched.isExact)
        XCTAssertEqual(patched.count, 1001)
        XCTAssertEqual(view.topVisibleIndex, 301)
        XCTAssertEqual(view.frameForItem(at: 301)?.minY ?? -1.0, before.minY, accuracy: 1e-6)
        for index in 0 ..< 3 {
            XCTAssertEqual(patched.frame(at: index).height, floor(393.0 / 0.75 * 3.0) / 3.0, accuracy: 1e-9)
        }
        for oldIndex in 0 ..< 1000 where oldIndex != 10 && oldIndex != 11 {
            let newIndex = oldIndex < 10 ? oldIndex + 3 : oldIndex + 1
            XCTAssertEqual(patched.frame(at: newIndex).height, old.frame(at: oldIndex).height, accuracy: 1e-9, "old \(oldIndex)")
        }
        self.assertContiguousRows(patched)
        self.assertCellsMatchLayout(view, "patched")

        harness.completeAspectChanges()
        XCTAssertEqual(harness.tableBuilds, builds + 1)
        XCTAssertFalse(self.isExact(view))
        harness.pendingTables.popLast()?()
        XCTAssertTrue(self.isExact(view))
        XCTAssertEqual(view.topVisibleIndex, 301)
        XCTAssertEqual(view.frameForItem(at: 301)?.minY ?? -1.0, before.minY, accuracy: 0.5)
        XCTAssertEqual(view.gridLayout?.frame(at: 1).height ?? 0.0, floor(393.0 / 2.0 * 3.0) / 3.0, accuracy: 1e-9)
        self.assertContiguousRows(view.gridLayout!)
        self.assertCellsMatchLayout(view, "exact")
    }

    func testSecondChangeRestartsAspectRebuild() {
        let (view, dataSource, harness) = self.makeLevelOneView(count: 1000)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        view.setContentOffset(view.gridLayout!.frame(at: 200).minY)
        dataSource.count = 1002
        view.apply(MediaGridChanges(removed: [], inserted: [0, 1], changed: []))
        XCTAssertEqual(harness.pendingAspectChanges?.changes.count, 1)
        dataSource.count = 1001
        view.apply(MediaGridChanges(removed: [5], inserted: [], changed: [0]))
        XCTAssertEqual(harness.changeCancelCount, 1)
        XCTAssertEqual(harness.pendingAspectChanges?.changes.count, 2)
        XCTAssertEqual(harness.pendingAspectChanges?.aspects.count, 1000)
        XCTAssertEqual(view.gridLayout?.count, 1001)
        XCTAssertEqual(view.topVisibleIndex, 201)
        self.assertContiguousRows(view.gridLayout!)
        harness.completeAspectChanges()
        XCTAssertTrue(self.isExact(view))
        XCTAssertEqual(view.gridLayout?.count, 1001)
        XCTAssertEqual(view.topVisibleIndex, 201)
        self.assertCellsMatchLayout(view, "exact after two changes")
    }

    func testChangeDuringAspectLoadRestartsLoad() {
        let (view, dataSource, harness) = self.makeLevelOneView(count: 1000)
        let stale = harness.pendingAspects
        dataSource.count = 1005
        view.apply(MediaGridChanges(removed: [], inserted: IndexSet(0 ..< 5), changed: []))
        XCTAssertEqual(harness.cancelCount, 1)
        XCTAssertEqual(harness.loadCounts, [1000, 1005])
        stale?(MediaGridViewTests.testAspects(count: 1000))
        XCTAssertFalse(self.isExact(view))
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1005))
        XCTAssertTrue(self.isExact(view))
        XCTAssertEqual(view.gridLayout?.count, 1005)
    }

    func testChangeDropsStaleTableBuild() {
        let (view, dataSource, harness) = self.makeLevelOneView(count: 1000)
        harness.buildsTablesImmediately = false
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        XCTAssertEqual(harness.pendingTables.count, 1)
        dataSource.count = 999
        view.apply(MediaGridChanges(removed: [3], inserted: [], changed: []))
        harness.pendingTables.popLast()?()
        XCTAssertFalse(self.isExact(view))
        XCTAssertEqual(view.gridLayout?.count, 999)
        harness.completeAspectChanges()
        XCTAssertEqual(harness.pendingTables.count, 1)
        harness.pendingTables.popLast()?()
        XCTAssertTrue(self.isExact(view))
        XCTAssertEqual(view.gridLayout?.count, 999)
        self.assertContiguousRows(view.gridLayout!)
    }

    func testInvalidChangesReload() {
        let (view, dataSource) = self.makeView(count: 1000)
        view.setContentOffset(3000.0)
        dataSource.count = 500
        view.apply(MediaGridChanges(removed: [1], inserted: [], changed: []))
        XCTAssertEqual(view.gridLayout?.count, 500)
        self.assertCellsMatchLayout(view, "after invalid change")
    }

    private static let portrait = CGSize(width: 393.0, height: 852.0)
    private static let landscape = CGSize(width: 852.0, height: 393.0)

    private func rotate(_ view: MediaGridView, toLandscape: Bool, safeInsets: UIEdgeInsets = .zero, duration: TimeInterval = 0.0) {
        let size = toLandscape ? MediaGridViewTests.landscape : MediaGridViewTests.portrait
        view.frame = CGRect(origin: .zero, size: size)
        view.updateLayout(size: size, safeInsets: safeInsets, isLandscape: toLandscape, transition: duration)
    }

    private func assertInFirstRow(_ view: MediaGridView, _ index: Int, fraction: CGFloat = 0.0, file: StaticString = #filePath, line: UInt = #line) {
        guard let frame = view.frameForItem(at: index) else {
            XCTFail("no frame for \(index)", file: file, line: line)
            return
        }
        XCTAssertEqual(-frame.minY / frame.height, fraction, accuracy: 1.0 / frame.height, "index \(index) frame \(frame)", file: file, line: line)
        if let top = view.topVisibleIndex, let topFrame = view.frameForItem(at: top) {
            XCTAssertEqual(topFrame.minY, frame.minY, accuracy: 1e-6, file: file, line: line)
        } else {
            XCTFail("no top", file: file, line: line)
        }
    }

    func testRotateThreeToFiveKeepsTop() {
        let (view, _) = self.makeView(count: 10_000)
        var levels: [MediaGridLevel] = []
        view.onLevelChanged = { levels.append($0) }
        self.rotate(view, toLandscape: false)
        XCTAssertEqual(view.level, .three)
        XCTAssertTrue(levels.isEmpty)
        let row = view.currentLayout!.frame(at: 900)
        view.setContentOffset(row.minY + row.height * 0.4)
        XCTAssertEqual(view.topVisibleIndex, 900)
        self.rotate(view, toLandscape: true)
        XCTAssertEqual(view.level, .five)
        XCTAssertEqual(view.currentLayout?.columns, 5)
        XCTAssertEqual(view.currentLayout?.geometry.width, 852.0)
        XCTAssertEqual(levels, [.five])
        self.assertInFirstRow(view, 900, fraction: 0.4)
        self.assertCellsMatchLayout(view, "after rotation to landscape")
        self.rotate(view, toLandscape: false)
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(levels, [.five, .three])
        self.assertInFirstRow(view, 900, fraction: 0.4)
        self.assertCellsMatchLayout(view, "after rotation back")
    }

    func testRotateThirtyOneStays() {
        let (view, _) = self.makeView(count: 100_000)
        self.rotate(view, toLandscape: false)
        view.setLevel(.thirtyOne, animated: false)
        let layout = view.currentLayout!
        view.setContentOffset(layout.frame(at: 31 * 400).minY)
        XCTAssertEqual(view.topVisibleIndex, 31 * 400)
        self.rotate(view, toLandscape: true)
        XCTAssertEqual(view.level, .thirtyOne)
        XCTAssertEqual(view.currentLayout?.columns, 31)
        self.assertInFirstRow(view, 31 * 400)
        self.assertCellsMatchLayout(view, "31 in landscape")
        self.rotate(view, toLandscape: false)
        XCTAssertEqual(view.level, .fifteen)
        self.assertInFirstRow(view, 31 * 400)
        self.assertCellsMatchLayout(view, "15 in portrait")
    }

    func testLandscapeOneToPortraitOne() {
        let harness = LevelOneHarness()
        let (view, _, _) = self.makeLevelOneView(count: 1000, harness: harness)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        self.rotate(view, toLandscape: true)
        XCTAssertEqual(view.level, .one)
        XCTAssertTrue(self.isExact(view))
        let row = view.gridLayout!.frame(at: 300)
        view.setContentOffset(row.minY + row.height * 0.25)
        XCTAssertEqual(view.topVisibleIndex, 300)
        harness.buildsTablesImmediately = false
        let builds = harness.tableBuilds
        self.rotate(view, toLandscape: false)
        XCTAssertEqual(view.level, .one)
        XCTAssertEqual(view.gridLayout?.geometry.width, 393.0)
        XCTAssertEqual(harness.tableBuilds, builds)
        XCTAssertTrue(self.isExact(view))
        self.assertInFirstRow(view, 300, fraction: 0.25)
        self.assertCellsMatchLayout(view, "level 1 in portrait")
    }

    func testRotationOntoLevelOneUsesScaledTableUntilRebuilt() {
        let harness = LevelOneHarness()
        let (view, _, _) = self.makeLevelOneView(count: 1000, harness: harness)
        harness.pendingAspects?(MediaGridViewTests.testAspects(count: 1000))
        self.rotate(view, toLandscape: false)
        view.setLevel(.three, animated: false)
        self.rotate(view, toLandscape: true, safeInsets: UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0))
        XCTAssertEqual(view.level, .five)
        view.setLevel(.three, animated: false)
        let row = view.currentLayout!.frame(at: 300)
        view.setContentOffset(row.minY + row.height * 0.5)
        XCTAssertEqual(view.topVisibleIndex, 300)
        harness.buildsTablesImmediately = false
        let builds = harness.tableBuilds
        self.rotate(view, toLandscape: false, safeInsets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 34.0, right: 10.0))
        XCTAssertEqual(view.level, .one)
        XCTAssertEqual(harness.tableBuilds, builds + 1)
        XCTAssertFalse(self.isExact(view))
        XCTAssertEqual(view.gridLayout?.frame(at: 0).width ?? 0.0, 373.0, accuracy: 1e-9)
        self.assertInFirstRow(view, 300, fraction: 0.5)
        self.assertCellsMatchLayout(view, "scaled level 1")
        harness.pendingTables.removeFirst()()
        XCTAssertTrue(self.isExact(view))
        XCTAssertEqual(view.topVisibleIndex, 300)
        self.assertInFirstRow(view, 300, fraction: 0.5)
        self.assertCellsMatchLayout(view, "exact level 1")
    }

    func testSideInsetsRespected() {
        let (view, _) = self.makeView(count: 1000)
        self.rotate(view, toLandscape: false)
        let insets = UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0)
        self.rotate(view, toLandscape: true, safeInsets: insets)
        XCTAssertEqual(view.frameForItem(at: 0)?.minX ?? -1.0, 59.0, accuracy: 1e-6)
        XCTAssertEqual(view.frameForItem(at: 4)?.maxX ?? -1.0, 852.0 - 59.0, accuracy: 1e-6)
        let layout = view.currentLayout!
        XCTAssertEqual(layout.contentHeight, layout.frame(at: 999).maxY + 21.0, accuracy: 1e-6)
        self.rotate(view, toLandscape: false, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 0.0))
        XCTAssertEqual(view.frameForItem(at: 0)?.minX ?? -1.0, 0.0, accuracy: 1e-6)
    }

    func testTopInsetIsKeptAcrossRotation() {
        let (view, _) = self.makeView(count: 1000)
        view.geometryInsets = UIEdgeInsets(top: 50.0, left: 0.0, bottom: 0.0, right: 0.0)
        self.rotate(view, toLandscape: false)
        self.rotate(view, toLandscape: true, safeInsets: UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0))
        XCTAssertEqual(view.geometryInsets.top, 50.0)
        XCTAssertEqual(view.frameForItem(at: 0)?.minY ?? -1.0, 50.0, accuracy: 1e-6)
    }

    func testRepeatedUpdateIsNoOp() {
        let (view, dataSource) = self.makeView(count: 1000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(2000.0)
        let requests = dataSource.requests.count
        self.rotate(view, toLandscape: false)
        XCTAssertEqual(view.contentOffset, 2000.0)
        XCTAssertEqual(dataSource.requests.count, requests)
    }

    func testRotationDuringZoomFinishesItFirst() {
        let (view, _) = self.makeView(count: 10_000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(view.currentLayout!.frame(at: 900).minY)
        view.setLevel(.five, animated: true)
        XCTAssertNotNil(view.transition)
        self.rotate(view, toLandscape: true)
        XCTAssertNil(view.transition)
        XCTAssertEqual(view.level, .fifteen)
        XCTAssertEqual(self.layoutLayerCount(view), 1)
        self.assertCellsMatchLayout(view, "after rotation mid-zoom")
    }

    func testRotationDuringPinchEndsIt() {
        let (view, _) = self.makeView(count: 10_000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(20_000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 0.8)
        XCTAssertNotNil(view.transition)
        self.rotate(view, toLandscape: true)
        XCTAssertNil(view.transition)
        XCTAssertNil(view.pinchAnchor)
        XCTAssertTrue(view.engine.isScrollEnabled)
        self.assertCellsMatchLayout(view, "after rotation mid-pinch")
    }

    func testRotationDuringFlingStopsAndKeepsTop() {
        let (view, _, window) = self.makeWindowedSourceView(count: 10_000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(5000.0)
        self.fling(view, velocity: 3000.0)
        XCTAssertTrue(view.engine.isDecelerating)
        self.spin(0.05)
        guard let top = view.topVisibleIndex, let before = view.frameForItem(at: top) else {
            XCTFail("no top")
            return
        }
        window.frame = CGRect(origin: .zero, size: MediaGridViewTests.landscape)
        self.rotate(view, toLandscape: true)
        XCTAssertFalse(view.engine.isDecelerating)
        XCTAssertFalse(view.isUserScrolling)
        self.assertInFirstRow(view, top, fraction: -before.minY / before.height)
        let offset = view.contentOffset
        self.spin(0.1)
        XCTAssertEqual(view.contentOffset, offset)
        self.assertCellsMatchLayout(view, "after rotation mid-fling")
        window.isHidden = true
    }

    func testRotationDuringDragKeepsTop() {
        let (view, _) = self.makeView(count: 10_000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(view.currentLayout!.frame(at: 900).minY)
        view.engine.applyPanUpdate(state: .began, translation: .zero, velocity: .zero, forced: false, isIndirect: false)
        self.rotate(view, toLandscape: true)
        self.assertInFirstRow(view, 900)
        let offset = view.contentOffset
        view.engine.applyPanUpdate(state: .changed, translation: CGPoint(x: 0.0, y: -10.0), velocity: .zero, forced: false, isIndirect: false)
        XCTAssertEqual(view.contentOffset, offset + 10.0, accuracy: 1.0)
        view.engine.applyPanUpdate(state: .ended, translation: CGPoint(x: 0.0, y: -10.0), velocity: CGPoint(x: 0.0, y: -3000.0), forced: false, isIndirect: false)
        XCTAssertFalse(view.engine.isDecelerating)
    }

    func testRotationRoundTripsKeepTopIndex() {
        let (view, _) = self.makeView(count: 10_000)
        self.rotate(view, toLandscape: false)
        let row = view.currentLayout!.frame(at: 903)
        view.setContentOffset(row.minY + row.height * 0.3)
        XCTAssertEqual(view.topVisibleIndex, 903)
        self.rotate(view, toLandscape: true)
        let landscapeTop = view.topVisibleIndex
        XCTAssertEqual(landscapeTop, 900)
        self.assertInFirstRow(view, 903, fraction: 0.3)
        self.rotate(view, toLandscape: false)
        XCTAssertEqual(view.topVisibleIndex, 903)
        self.assertInFirstRow(view, 903, fraction: 0.3)
        self.rotate(view, toLandscape: true)
        XCTAssertEqual(view.topVisibleIndex, landscapeTop)
        self.assertInFirstRow(view, 903, fraction: 0.3)
        self.rotate(view, toLandscape: false)
        XCTAssertEqual(view.topVisibleIndex, 903)
        view.setContentOffset(view.contentOffset + 2000.0)
        guard let scrolledTop = view.topVisibleIndex, let scrolledFrame = view.frameForItem(at: scrolledTop) else {
            XCTFail("no top")
            return
        }
        self.rotate(view, toLandscape: true)
        self.assertInFirstRow(view, scrolledTop, fraction: -scrolledFrame.minY / scrolledFrame.height)
        self.rotate(view, toLandscape: false)
        XCTAssertEqual(view.topVisibleIndex, scrolledTop)
    }

    func testRotationAnchorClearedByZoomAndChanges() {
        let (view, dataSource) = self.makeView(count: 10_000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(view.currentLayout!.frame(at: 903).minY)
        self.rotate(view, toLandscape: true)
        dataSource.count += 5
        view.apply(MediaGridChanges(removed: [], inserted: IndexSet(0 ..< 5), changed: []))
        guard let top = view.topVisibleIndex else {
            XCTFail("no top")
            return
        }
        XCTAssertEqual(top, 905)
        self.rotate(view, toLandscape: false)
        XCTAssertEqual(view.topVisibleIndex, 903)
        self.assertInFirstRow(view, top)
    }

    func testRotationDuringDragReleasesWithoutFlight() {
        let (view, _, window) = self.makeWindowedSourceView(count: 10_000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(5000.0)
        var flights = 0
        let forward = view.engine.onFlightChanged
        view.engine.onFlightChanged = { flight in
            if flight != nil {
                flights += 1
            }
            forward?(flight)
        }
        view.engine.applyPanUpdate(state: .began, translation: .zero, velocity: .zero, forced: false, isIndirect: false)
        for step in 1 ... 5 {
            view.engine.applyPanUpdate(state: .changed, translation: CGPoint(x: 0.0, y: -24.0 * CGFloat(step)), velocity: CGPoint(x: 0.0, y: -3000.0), forced: false, isIndirect: false)
        }
        window.frame = CGRect(origin: .zero, size: MediaGridViewTests.landscape)
        self.rotate(view, toLandscape: true)
        let offset = view.contentOffset
        view.engine.applyPanUpdate(state: .cancelled, translation: CGPoint(x: 0.0, y: -120.0), velocity: CGPoint(x: 0.0, y: -3000.0), forced: false, isIndirect: false)
        XCTAssertEqual(flights, 0)
        XCTAssertFalse(view.engine.isDecelerating)
        XCTAssertEqual(view.contentOffset, offset, accuracy: 1e-6)
        view.engine.applyPanUpdate(state: .began, translation: .zero, velocity: .zero, forced: false, isIndirect: false)
        for step in 1 ... 5 {
            view.engine.applyPanUpdate(state: .changed, translation: CGPoint(x: 0.0, y: -24.0 * CGFloat(step)), velocity: CGPoint(x: 0.0, y: -3000.0), forced: false, isIndirect: false)
        }
        view.engine.applyPanUpdate(state: .ended, translation: CGPoint(x: 0.0, y: -120.0), velocity: CGPoint(x: 0.0, y: -3000.0), forced: false, isIndirect: false)
        XCTAssertEqual(flights, 1)
        view.engine.haltMotionInPlace()
        window.isHidden = true
    }

    func testRotationBeforeFrameChangeRebuildsAtNewLevel() {
        let (view, dataSource) = self.makeView(count: 10_000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(view.currentLayout!.frame(at: 903).minY)
        view.updateLayout(size: MediaGridViewTests.landscape, safeInsets: .zero, isLandscape: true, transition: 0.0)
        XCTAssertEqual(view.level, .five)
        XCTAssertEqual(view.currentLayout?.columns, 5)
        XCTAssertEqual(view.currentLayout?.geometry.width, 393.0)
        self.assertCellsMatchLayout(view, "rebuilt before the frame change")
        self.assertInFirstRow(view, 903)
        dataSource.count += 30
        view.apply(MediaGridChanges(removed: [], inserted: IndexSet(0 ..< 30), changed: []))
        XCTAssertEqual(view.currentLayout?.columns, 5)
        self.assertCellsMatchLayout(view, "change before the frame change")
        view.frame = CGRect(origin: .zero, size: MediaGridViewTests.landscape)
        view.layoutIfNeeded()
        XCTAssertEqual(view.currentLayout?.geometry.width, 852.0)
        XCTAssertEqual(view.currentLayout?.columns, 5)
        self.assertInFirstRow(view, 933)
        self.assertCellsMatchLayout(view, "after the frame change")
    }

    func testBottomInsetChangeKeepsFling() {
        let (view, _, window) = self.makeWindowedSourceView(count: 10_000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(5000.0)
        self.fling(view, velocity: 3000.0)
        XCTAssertTrue(view.engine.isDecelerating)
        view.updateLayout(size: MediaGridViewTests.portrait, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 50.0, right: 0.0), isLandscape: false, transition: 0.3)
        XCTAssertTrue(view.engine.isDecelerating)
        view.layoutIfNeeded()
        XCTAssertTrue(view.engine.isDecelerating)
        XCTAssertEqual(view.currentLayout?.geometry.bottomInset, 50.0)
        XCTAssertNil(view.layer.animation(forKey: kCATransition))
        self.spinUntilSettled(view)
        self.assertCellsMatchLayout(view, "after fling")
        window.isHidden = true
    }

    func testAnimatedRotationDefersBindingOneTurn() {
        let (view, dataSource, window) = self.makeWindowedSourceView(count: 10_000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(view.currentLayout!.frame(at: 900).minY)
        let requests = dataSource.requests.count
        window.frame = CGRect(origin: .zero, size: MediaGridViewTests.landscape)
        self.rotate(view, toLandscape: true, duration: 0.3)
        XCTAssertEqual(view.currentLayout?.columns, 5)
        XCTAssertEqual(dataSource.requests.count, requests)
        XCTAssertNotNil(view.layer.animation(forKey: kCATransition))
        self.assertInFirstRow(view, 900)
        self.spin(0.05)
        XCTAssertGreaterThan(dataSource.requests.count, requests)
        self.assertCellsMatchLayout(view, "after the deferred binding")
        window.isHidden = true
    }

    func testAnimatedRotationDefersBindingThroughOwnLayoutPass() {
        let (view, dataSource, window) = self.makeWindowedSourceView(count: 10_000)
        self.rotate(view, toLandscape: false)
        view.setContentOffset(view.currentLayout!.frame(at: 900).minY)
        let requests = dataSource.requests.count
        let caching = dataSource.startedCachingOrder.count
        window.frame = CGRect(origin: .zero, size: MediaGridViewTests.landscape)
        self.rotate(view, toLandscape: true, duration: 0.3)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertEqual(view.currentLayout?.columns, 5)
        XCTAssertEqual(dataSource.requests.count, requests)
        XCTAssertEqual(dataSource.startedCachingOrder.count, caching)
        self.assertInFirstRow(view, 900)
        var requestsInNextDispatch: Int?
        DispatchQueue.main.async {
            requestsInNextDispatch = dataSource.requests.count
        }
        self.spin(0.05)
        XCTAssertEqual(requestsInNextDispatch, requests)
        XCTAssertGreaterThan(dataSource.requests.count, requests)
        self.assertCellsMatchLayout(view, "after the deferred binding")
        window.isHidden = true
    }

    func testCameraFollowsRotatedLevel() {
        let (view, _) = self.makeView(count: 1000)
        let camera = UIView()
        view.cameraView = camera
        view.layoutIfNeeded()
        self.rotate(view, toLandscape: false)
        XCTAssertFalse(camera.isHidden)
        let portraitFrame = camera.frame
        self.rotate(view, toLandscape: true)
        XCTAssertEqual(view.level, .five)
        XCTAssertTrue(camera.isHidden)
        view.setLevel(.three, animated: false)
        XCTAssertFalse(camera.isHidden)
        let frame = view.currentLayout!.reservedFrame([MediaGridSlot(row: 0, column: 0), MediaGridSlot(row: 1, column: 0)])!
        XCTAssertEqual(camera.frame, frame)
        XCTAssertNotEqual(camera.frame, portraitFrame)
        view.setLevel(.fifteen, animated: false)
        self.rotate(view, toLandscape: false)
        XCTAssertEqual(view.level, .five)
        XCTAssertTrue(camera.isHidden)
        self.rotate(view, toLandscape: true)
        XCTAssertEqual(view.level, .fifteen)
        XCTAssertTrue(camera.isHidden)
    }
}

private final class ImageBank {
    var identifiers: [Int] = []
    private var images: [Int: UIImage] = [:]

    func image(for identifier: Int) -> UIImage {
        if let image = self.images[identifier] {
            return image
        }
        let image = TestDataSource.distinctImage(identifier)
        self.images[identifier] = image
        return image
    }
}

private final class LevelOneHarness {
    var pendingAspects: (([Float]) -> Void)?
    var loadCounts: [Int] = []
    var cancelCount = 0
    var pendingAspectChanges: (aspects: [Float], changes: [MediaGridChanges], reader: MediaGridAspectRatioReader, completion: ([Float]) -> Void)?
    var changeCancelCount = 0

    func completeAspectChanges() {
        guard let pending = self.pendingAspectChanges else {
            return
        }
        self.pendingAspectChanges = nil
        pending.completion(MediaGridAspectIndex(aspects: pending.aspects).apply(pending.changes, aspectRatio: pending.reader))
    }
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
