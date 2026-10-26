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
}
