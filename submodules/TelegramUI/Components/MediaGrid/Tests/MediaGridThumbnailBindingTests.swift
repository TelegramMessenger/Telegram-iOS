import XCTest
@testable import MediaGrid

private final class TrackingCellLayer: MediaGridCellLayer {
    var onEmptied: ((Int) -> Void)?
    private var hasShownImage = false
    private var isReusing = false

    override var contents: Any? {
        didSet {
            if self.contents != nil {
                self.hasShownImage = true
            } else if self.hasShownImage && !self.isReusing {
                self.onEmptied?(self.index)
            }
        }
    }

    override func prepareForReuse() {
        self.isReusing = true
        super.prepareForReuse()
        self.isReusing = false
        self.hasShownImage = false
    }
}

final class MediaGridThumbnailBindingTests: XCTestCase {
    private var time: CFTimeInterval = 100.0
    private var emptied: [Int] = []

    private func makeView(count: Int = 100_000, thumbnails: Bool = true) -> (MediaGridView, TestDataSource) {
        let dataSource = TestDataSource(count: count)
        dataSource.providesThumbnails = thumbnails
        let view = MediaGridView(dataSource: dataSource, cellFactory: { [weak self] in
            let cell = TrackingCellLayer()
            cell.onEmptied = { index in
                self?.emptied.append(index)
            }
            return cell
        })
        view.motionClock = { [unowned self] in
            return self.time
        }
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        return (view, dataSource)
    }

    override func tearDown() {
        self.emptied = []
        super.tearDown()
    }

    private func scroll(_ view: MediaGridView, to offset: CGFloat, after interval: CFTimeInterval = 0.0625) {
        self.time += interval
        view.setContentOffset(offset)
    }

    private func settle(_ view: MediaGridView) {
        self.time += MediaGridView.motionSettleDelay * 2.0
        view._testSettleMotion()
    }

    private func viewportRange(_ view: MediaGridView, offset: CGFloat? = nil) -> Range<Int> {
        guard let layout = view.gridLayout else {
            return 0 ..< 0
        }
        return layout.indexRange(intersecting: CGRect(x: 0.0, y: offset ?? view.contentOffset, width: view.bounds.width, height: view.bounds.height))
    }

    private func allBoundCells(_ view: MediaGridView) -> [(Int, MediaGridCellLayer)] {
        var result = view.activeLayoutLayer.visibleCells.map { ($0.key, $0.value) }
        if let transition = view.transition, transition.incoming !== view.activeLayoutLayer {
            result.append(contentsOf: transition.incoming.visibleCells.map { ($0.key, $0.value) })
        }
        return result
    }

    private func assertNoEmptyCells(_ view: MediaGridView, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let cells = self.allBoundCells(view)
        XCTAssertFalse(cells.isEmpty, message, file: file, line: line)
        let empty = cells.filter { $0.1.contents == nil }.map { $0.0 }.sorted()
        XCTAssertEqual(empty, [], "\(message): empty cells \(empty.prefix(8))", file: file, line: line)
        XCTAssertEqual(self.emptied, [], "\(message): cells returned to empty \(self.emptied.prefix(8))", file: file, line: line)
    }

    func testBindShowsThumbnailSynchronously() {
        let (view, dataSource) = self.makeView()
        dataSource.holdsDeliveries = true
        view.setContentOffset(20_000.0)
        let cells = view.activeLayoutLayer.visibleCells
        XCTAssertFalse(cells.isEmpty)
        for (index, cell) in cells {
            XCTAssertTrue(cell.contents.map { ($0 as AnyObject) === TestDataSource.thumbnailPage } ?? false, "index \(index)")
            XCTAssertTrue(cell.isShowingThumbnail)
            XCTAssertEqual(cell.contentsRect, dataSource.thumbnail(at: index)!.contentsRect(fillingAspect: cell.frame.width / cell.frame.height))
        }
    }

    func testNoSharpRequestAtFifteenAndThirtyOne() {
        let (view, dataSource) = self.makeView()
        dataSource.holdsDeliveries = true
        for level in [MediaGridLevel.fifteen, .thirtyOne] {
            view.setLevel(level, animated: false)
            XCTAssertEqual(view.level, level)
            let before = dataSource.requests.count
            let caching = dataSource.startedCachingOrder.count
            for step in 1 ... 20 {
                self.scroll(view, to: 5_000.0 + CGFloat(step) * 30.0)
            }
            self.settle(view)
            view.setContentOffset(60_000.0)
            self.settle(view)
            XCTAssertEqual(dataSource.requests.count, before, "level \(level.columns)")
            XCTAssertEqual(dataSource.startedCachingOrder.count, caching, "level \(level.columns)")
            XCTAssertTrue(view.activeLayoutLayer.visibleCells.values.allSatisfy { $0.isShowingThumbnail })
        }
    }

    func testSharpRequestedAtCompactLevelWithoutThumbnail() {
        let (view, dataSource) = self.makeView(thumbnails: false)
        view.setLevel(.thirtyOne, animated: false)
        let before = dataSource.requests.count
        view.setContentOffset(30_000.0)
        XCTAssertGreaterThan(dataSource.requests.count, before)
    }

    func testFastMotionBindsThumbnailsOnly() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 10_000.0)
        let before = dataSource.requests.count
        self.scroll(view, to: 14_000.0)
        XCTAssertTrue(view.isMovingFast)
        self.scroll(view, to: 18_000.0)
        XCTAssertEqual(dataSource.requests.count, before)
        let cells = view.activeLayoutLayer.visibleCells
        XCTAssertFalse(cells.isEmpty)
        for cell in cells.values {
            XCTAssertTrue(cell.isShowingThumbnail)
            XCTAssertTrue(cell.isAwaitingSharpImage)
        }
    }

    func testSettleUpgradesToSharp() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 10_000.0)
        self.scroll(view, to: 14_000.0)
        XCTAssertTrue(view.isMovingFast)
        let sharp = TestDataSource.distinctImage(9, side: 600.0)
        dataSource.deliveries = [(sharp, false)]
        let cells = view.activeLayoutLayer.visibleCells
        let before = dataSource.requests.count
        self.settle(view)
        XCTAssertFalse(view.isMovingFast)
        XCTAssertEqual(Set(dataSource.requests[before...].map { $0.index }), Set(cells.keys))
        for cell in cells.values {
            XCTAssertTrue(cell.hasFinalImage)
            XCTAssertFalse(cell.isShowingThumbnail)
            XCTAssertTrue((cell.contents as AnyObject?) === sharp.cgImage)
            XCTAssertEqual(cell.contentsRect, CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))
        }
    }

    func testSmallerImageDoesNotReplaceThumbnail() {
        let (view, dataSource) = self.makeView()
        dataSource.deliveries = [(TestDataSource.distinctImage(3, side: 40.0), true), (TestDataSource.distinctImage(4, side: 40.0), false)]
        view.setContentOffset(5_000.0)
        let cells = view.activeLayoutLayer.visibleCells
        XCTAssertFalse(cells.isEmpty)
        for cell in cells.values {
            XCTAssertTrue((cell.contents as AnyObject?) === TestDataSource.thumbnailPage)
            XCTAssertTrue(cell.isShowingThumbnail)
            XCTAssertTrue(cell.hasFinalImage)
        }
        let degraded = TestDataSource.distinctImage(5, side: 200.0)
        dataSource.deliveries = [(degraded, true)]
        view.setContentOffset(40_000.0)
        for cell in view.activeLayoutLayer.visibleCells.values {
            XCTAssertTrue((cell.contents as AnyObject?) === degraded.cgImage)
            XCTAssertFalse(cell.hasFinalImage)
        }
    }

    func testZoomIncomingHasThumbnailsOnFirstFrame() {
        let (view, dataSource) = self.makeView()
        view.setContentOffset(20_000.0)
        dataSource.holdsDeliveries = true
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 0.97)
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        let incomingRect = transition.incomingRect(at: transition.progress)
        let incoming = transition.incoming.visibleCells.filter { $0.value.frame.intersects(incomingRect) }
        XCTAssertFalse(incoming.isEmpty)
        for (index, cell) in incoming {
            XCTAssertNotNil(cell.contents, "index \(index)")
        }
        view._testPinch(.ended, center: center, scale: 0.97)
        view._testFinishAnimations()

        view.setLevel(.five, animated: true)
        guard let animated = view.transition else {
            XCTFail("no animated transition")
            return
        }
        XCTAssertFalse(animated.incoming.visibleCells.isEmpty)
        for (index, cell) in animated.incoming.visibleCells {
            XCTAssertNotNil(cell.contents, "index \(index)")
        }
        view._testFinishAnimations()
    }

    func testZoomInReusesOutgoingSharpImage() {
        let (view, dataSource) = self.makeView()
        var images: [Int: UIImage] = [:]
        dataSource.imageForIndex = { index in
            if let image = images[index] {
                return image
            }
            let image = TestDataSource.distinctImage(index, side: 400.0)
            images[index] = image
            return image
        }
        view.setContentOffset(20_000.0)
        let outgoing = view.activeLayoutLayer.visibleCells
        XCTAssertTrue(outgoing.values.allSatisfy { !$0.isShowingThumbnail })
        dataSource.holdsDeliveries = true
        view.setLevel(.one, animated: true)
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        let shared = Set(transition.incoming.visibleCells.keys).intersection(outgoing.keys)
        XCTAssertFalse(shared.isEmpty)
        for index in shared {
            let cell = transition.incoming.visibleCells[index]!
            XCTAssertTrue((cell.contents as AnyObject?) === images[index]?.cgImage, "index \(index)")
            XCTAssertFalse(cell.isShowingThumbnail)
        }
        let requested = Set(dataSource.requests.suffix(transition.incoming.visibleCells.count).map { $0.index })
        XCTAssertTrue(shared.isSubset(of: requested))
        view._testFinishAnimations()
    }

    func testThumbnailsDidChangeFillsEmptyCellsOnly() {
        let (view, dataSource) = self.makeView()
        var available = Set<Int>()
        dataSource.thumbnailAvailable = { available.contains($0) }
        dataSource.holdsDeliveries = true
        let sharp = TestDataSource.distinctImage(1, side: 600.0)
        dataSource.deliveries = [(sharp, false)]
        view.setContentOffset(20_000.0)
        let cells = view.activeLayoutLayer.visibleCells
        XCTAssertTrue(cells.values.allSatisfy { $0.contents == nil })
        let sharpIndices = Set(cells.keys.filter { $0 % 2 == 0 })
        dataSource.flushHeldDeliveries(where: { sharpIndices.contains($0) })
        let range = view.activeLayoutLayer.visibleRange
        available = Set(range)
        let limited = IndexSet(integersIn: range.lowerBound ..< range.lowerBound + range.count / 2)
        view.thumbnailsDidChange(indices: limited)
        for (index, cell) in cells {
            if sharpIndices.contains(index) {
                XCTAssertTrue((cell.contents as AnyObject?) === sharp.cgImage, "index \(index)")
            } else if limited.contains(index) {
                XCTAssertTrue(cell.isShowingThumbnail, "index \(index)")
            } else {
                XCTAssertNil(cell.contents, "index \(index)")
            }
        }
        view.thumbnailsDidChange(indices: nil)
        for (index, cell) in cells {
            if sharpIndices.contains(index) {
                XCTAssertTrue((cell.contents as AnyObject?) === sharp.cgImage, "index \(index)")
            } else {
                XCTAssertTrue(cell.isShowingThumbnail, "index \(index)")
            }
        }
    }

    func testThumbnailArrivalCancelsCompactSharpRequest() {
        let (view, dataSource) = self.makeView()
        var available = false
        dataSource.thumbnailAvailable = { _ in available }
        dataSource.holdsDeliveries = true
        view.setLevel(.thirtyOne, animated: false)
        view.setContentOffset(30_000.0)
        let cells = view.activeLayoutLayer.visibleCells
        XCTAssertTrue(cells.values.allSatisfy { $0.imageRequest != nil })
        let cancels = dataSource.cancelCount
        available = true
        view.thumbnailsDidChange(indices: nil)
        XCTAssertEqual(dataSource.cancelCount - cancels, cells.count)
        XCTAssertTrue(cells.values.allSatisfy { $0.isShowingThumbnail && $0.imageRequest == nil })
    }

    func testPrepareCalledForScrubTargetAndIncomingLevel() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 10_000.0)
        XCTAssertEqual(dataSource.preparedRanges.last, self.viewportRange(view))
        dataSource.resetPreparedRanges()
        self.scroll(view, to: 14_000.0)
        XCTAssertTrue(view.isMovingFast)
        let ahead = self.viewportRange(view, offset: 18_000.0)
        XCTAssertTrue(dataSource.preparedRanges.contains(ahead), "scrub target \(ahead) not in \(dataSource.preparedRanges)")
        XCTAssertEqual(dataSource.preparedRanges.last, self.viewportRange(view))
        self.settle(view)

        dataSource.resetPreparedRanges()
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let anchor = view.index(at: center), let anchorFrame = view.frameForItem(at: anchor), let geometry = view.gridLayout?.geometry else {
            XCTFail("no anchor")
            return
        }
        let relative = MediaGridZoomMath.relativePosition(of: center, in: anchorFrame)
        view._testPinch(.began, center: center)
        let five = MediaGridUniformLayout(geometry: geometry, columns: 5, cellAspect: 1.0, reservedSlots: [], count: 100_000)
        let fiveOffset = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: anchor, pointInView: center), in: five, viewportHeight: view.bounds.height, relativePosition: relative)
        let expected = five.indexRange(intersecting: CGRect(x: 0.0, y: fiveOffset, width: view.bounds.width, height: view.bounds.height))
        XCTAssertTrue(dataSource.preparedRanges.contains(expected), "incoming \(expected) not in \(dataSource.preparedRanges)")
        XCTAssertNil(view.transition)
        view._testPinch(.ended, center: center)

        dataSource.resetPreparedRanges()
        view.setLevel(.five, animated: true)
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        let target = transition.targetLayout.indexRange(intersecting: CGRect(x: 0.0, y: transition.targetOffset, width: view.bounds.width, height: view.bounds.height))
        XCTAssertTrue(dataSource.preparedRanges.contains(where: { $0.lowerBound <= target.lowerBound && $0.upperBound >= target.upperBound }), "target \(target) not in \(dataSource.preparedRanges)")
        view._testFinishAnimations()
    }

    func testNeverReturnsToEmpty() {
        let (view, dataSource) = self.makeView()
        dataSource.deliveries = [(TestDataSource.distinctImage(2, side: 600.0), false)]
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: view.frame)
        window.frame = view.frame
        window.windowLevel = .alert
        window.isHidden = false
        window.addSubview(view)
        view.layoutIfNeeded()
        defer {
            window.isHidden = true
        }
        view.updateLayout(size: view.bounds.size, safeInsets: .zero, isLandscape: false, transition: 0.0)
        self.assertNoEmptyCells(view, "initial")

        for step in 1 ... 30 {
            self.scroll(view, to: CGFloat(step) * 1_500.0, after: 1.0 / 60.0)
            self.assertNoEmptyCells(view, "scrub step \(step)")
        }
        self.settle(view)
        self.assertNoEmptyCells(view, "settled")

        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        var scale: CGFloat = 1.0
        while scale > 0.12 {
            scale *= 0.93
            view._testPinch(.changed, center: center, scale: scale)
            self.assertNoEmptyCells(view, "pinch out \(scale)")
        }
        while scale < 2.5 {
            scale *= 1.07
            view._testPinch(.changed, center: center, scale: scale)
            self.assertNoEmptyCells(view, "pinch in \(scale)")
        }
        view._testPinch(.ended, center: center, scale: scale)
        self.assertNoEmptyCells(view, "pinch ended")
        view._testFinishAnimations()
        self.assertNoEmptyCells(view, "pinch finished")

        view.setLevel(.three, animated: true)
        self.assertNoEmptyCells(view, "menu zoom")
        view._testFinishAnimations()

        let landscape = CGSize(width: 852.0, height: 393.0)
        window.frame = CGRect(origin: .zero, size: landscape)
        view.frame = CGRect(origin: .zero, size: landscape)
        view.updateLayout(size: landscape, safeInsets: .zero, isLandscape: true, transition: 0.3)
        XCTAssertEqual(view.level, .five)
        self.assertNoEmptyCells(view, "rotation first commit")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        self.assertNoEmptyCells(view, "rotation deferred binding")

        dataSource.count += 10
        view.apply(MediaGridChanges(removed: IndexSet(), inserted: IndexSet(integersIn: 0 ..< 10), changed: IndexSet(view.activeLayoutLayer.visibleRange.prefix(5))))
        self.assertNoEmptyCells(view, "apply")
        view.setContentOffset(view.contentOffset + 200.0)
        self.assertNoEmptyCells(view, "after apply")
    }
}
