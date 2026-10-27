import XCTest
@testable import MediaGrid

private final class TrackingCellLayer: MediaGridCellLayer {
    var onEmptied: ((Int) -> Void)?
    var onReuse: (() -> Void)?
    private var hasShownImage = false
    var photoState: Int?
    var checksPhotoState = false

    override func bind(index: Int, detail: MediaGridCellDetail) {
        if self.checksPhotoState, let state = self.photoState, state != index {
            XCTFail("per-photo state of index \(state) carried over to \(index)")
        }
        super.bind(index: index, detail: detail)
        self.photoState = index
    }

    override var contents: Any? {
        didSet {
            if self.contents != nil {
                self.hasShownImage = true
            } else if self.hasShownImage {
                self.onEmptied?(self.index)
            }
        }
    }

    override func prepareForReuse() {
        self.onReuse?()
        self.hasShownImage = false
        self.photoState = nil
        super.prepareForReuse()
    }
}

final class MediaGridThumbnailBindingTests: XCTestCase {
    private var time: CFTimeInterval = 100.0
    private var emptied: [Int] = []
    private var reuses = 0

    private func makeView(count: Int = 100_000, thumbnails: Bool = true) -> (MediaGridView, TestDataSource) {
        let dataSource = TestDataSource(count: count)
        dataSource.providesThumbnails = thumbnails
        let view = MediaGridView(dataSource: dataSource, cellFactory: { [weak self] in
            let cell = TrackingCellLayer()
            cell.onEmptied = { index in
                self?.emptied.append(index)
            }
            cell.onReuse = {
                self?.reuses += 1
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
        self.reuses = 0
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

    private func covers(_ indices: IndexSet, _ range: Range<Int>) -> Bool {
        return range.allSatisfy { indices.contains($0) }
    }

    private func assertDisjoint(_ ranges: [Range<Int>], file: StaticString = #filePath, line: UInt = #line) {
        var seen = IndexSet()
        for range in ranges {
            XCTAssertFalse(range.isEmpty, file: file, line: line)
            XCTAssertFalse(seen.intersects(integersIn: range), "\(range) overlaps an earlier range in \(ranges)", file: file, line: line)
            seen.insert(integersIn: range)
        }
    }

    func testScrubPreparesTwoStepsAheadForACoalescedStep() {
        let (view, dataSource) = self.makeView()
        view.setLevel(.fifteen, animated: false)
        self.scroll(view, to: 10_000.0)
        dataSource.resetPreparedRanges()
        self.scroll(view, to: 14_000.0)
        XCTAssertTrue(view.isMovingFast)
        let oneStep = self.viewportRange(view, offset: 18_000.0)
        let twoSteps = self.viewportRange(view, offset: 22_000.0)
        XCTAssertTrue(self.covers(dataSource.preparedIndices, oneStep), "one step \(oneStep) not in \(dataSource.preparedRanges)")
        XCTAssertTrue(self.covers(dataSource.preparedIndices, twoSteps), "two steps \(twoSteps) not in \(dataSource.preparedRanges)")
        let ranges = dataSource.preparedRanges
        XCTAssertEqual(ranges.first, self.viewportRange(view))
        let firstTwoStep = ranges.firstIndex(where: { $0.overlaps(twoSteps) }) ?? Int.max
        let firstWindow = ranges.firstIndex(where: { !$0.overlaps(oneStep) && !$0.overlaps(twoSteps) && $0 != self.viewportRange(view) }) ?? Int.max
        XCTAssertLessThan(firstTwoStep, firstWindow, "\(ranges)")
    }

    func testPrepareCalledForScrubTargetAndIncomingLevel() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 10_000.0)
        XCTAssertEqual(dataSource.preparedRanges.first, self.viewportRange(view))
        dataSource.resetPreparedRanges()
        self.scroll(view, to: 14_000.0)
        XCTAssertTrue(view.isMovingFast)
        let ahead = self.viewportRange(view, offset: 18_000.0)
        XCTAssertTrue(self.covers(dataSource.preparedIndices, ahead), "scrub target \(ahead) not in \(dataSource.preparedRanges)")
        XCTAssertEqual(dataSource.preparedRanges.first, self.viewportRange(view))
        self.settle(view)

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
        XCTAssertTrue(self.covers(dataSource.preparedIndices, expected), "incoming \(expected) not in \(dataSource.preparedRanges)")
        XCTAssertNil(view.transition)
        view._testPinch(.ended, center: center)

        dataSource.resetPreparedRanges()
        view.setLevel(.five, animated: true)
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        let target = transition.targetLayout.indexRange(intersecting: CGRect(x: 0.0, y: transition.targetOffset, width: view.bounds.width, height: view.bounds.height))
        XCTAssertTrue(self.covers(dataSource.preparedIndices, target), "target \(target) not in \(dataSource.preparedRanges)")
        view._testFinishAnimations()
    }

    func testPrepareIsOneDisjointPriorityList() {
        let (view, dataSource) = self.makeView()
        dataSource.resetPreparedRanges()
        self.scroll(view, to: 20_000.0)
        XCTAssertEqual(dataSource.prepareCalls.count, 1)
        let ranges = dataSource.preparedRanges
        self.assertDisjoint(ranges)
        let viewport = self.viewportRange(view)
        XCTAssertEqual(ranges.first, viewport)
        let height = view.bounds.height
        let around = view.gridLayout!.indexRange(intersecting: CGRect(x: 0.0, y: view.contentOffset - height, width: view.bounds.width, height: height * 3.0))
        XCTAssertTrue(self.covers(dataSource.preparedIndices, around))
        let calls = dataSource.prepareCalls.count
        view.setNeedsLayout()
        view.layoutIfNeeded()
        view.thumbnailsDidChange(indices: nil)
        XCTAssertEqual(dataSource.prepareCalls.count, calls)
    }

    func testNeighbourLevelsPreparedAboveWindowAtRest() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 20_000.0, after: 1.0)
        guard let geometry = view.gridLayout?.geometry else {
            XCTFail("no layout")
            return
        }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let anchor = view.index(at: center)!
        let relative = MediaGridZoomMath.relativePosition(of: center, in: view.frameForItem(at: anchor)!)
        let five = MediaGridUniformLayout(geometry: geometry, columns: 5, cellAspect: 1.0, reservedSlots: [], count: 100_000)
        let offset = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: anchor, pointInView: center), in: five, viewportHeight: view.bounds.height, relativePosition: relative)
        let expected = five.indexRange(intersecting: CGRect(x: 0.0, y: offset, width: view.bounds.width, height: view.bounds.height))
        let ranges = dataSource.preparedRanges
        var covered = IndexSet()
        var neighbourDone: Int?
        for (position, range) in ranges.enumerated() {
            covered.insert(integersIn: range)
            if neighbourDone == nil && self.covers(covered, expected) {
                neighbourDone = position
            }
        }
        guard let neighbourDone else {
            XCTFail("neighbour viewport \(expected) not prepared in \(ranges)")
            return
        }
        let height = view.bounds.height
        var window = IndexSet(integersIn: view.gridLayout!.indexRange(intersecting: CGRect(x: 0.0, y: view.contentOffset - height, width: view.bounds.width, height: height * 3.0)))
        window.subtract(covered.intersection(IndexSet(ranges.prefix(neighbourDone + 1).flatMap { Array($0) })))
        XCTAssertFalse(window.isEmpty)
        for index in window {
            let position = ranges.firstIndex(where: { $0.contains(index) })
            XCTAssertNotNil(position)
            XCTAssertGreaterThan(position ?? -1, neighbourDone)
        }
    }

    func testFastCompactScrubDropsPrefetchWindowAndMargin() {
        let (view, dataSource) = self.makeView()
        view.setLevel(.thirtyOne, animated: false)
        self.scroll(view, to: 5_000.0)
        self.scroll(view, to: 5_600.0)
        XCTAssertTrue(view.isMovingFast)
        let viewport = self.viewportRange(view)
        XCTAssertEqual(view.activeLayoutLayer.visibleRange, viewport)
        let ahead = self.viewportRange(view, offset: 6_200.0)
        var expected = IndexSet(integersIn: viewport)
        expected.insert(integersIn: ahead)
        expected.insert(integersIn: self.viewportRange(view, offset: 6_800.0))
        XCTAssertEqual(dataSource.preparedIndices, expected)
        XCTAssertEqual(dataSource.preparedRanges.first, viewport)
    }

    private func pages(_ range: Range<Int>) -> Set<Int> {
        guard !range.isEmpty else {
            return []
        }
        return Set(range.lowerBound / TestDataSource.thumbnailPageCapacity ... (range.upperBound - 1) / TestDataSource.thumbnailPageCapacity)
    }

    func testNeighbourPagesDecodedBeforePinch() {
        let (view, dataSource) = self.makeView()
        dataSource.deliveries = []
        dataSource.decodesThumbnailPages = true
        view.setLevel(.fifteen, animated: false)
        self.scroll(view, to: 20_000.0, after: 1.0)
        self.scroll(view, to: 20_000.0, after: 1.0)
        for _ in 0 ..< 4 {
            let changed = dataSource.finishThumbnailDecodes()
            view.thumbnailsDidChange(indices: changed)
        }
        guard let layout = view.gridLayout else {
            XCTFail("no layout")
            return
        }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let height = view.bounds.height
        let around = layout.indexRange(intersecting: CGRect(x: 0.0, y: view.contentOffset - height, width: view.bounds.width, height: height * 3.0))
        for (scale, target) in [(CGFloat(0.52), MediaGridLevel.thirtyOne), (1.03, .five)] {
            dataSource.holdsDeliveries = true
            view._testPinch(.began, center: center)
            view._testPinch(.changed, center: center, scale: scale)
            guard let transition = view.transition else {
                XCTFail("no transition at \(scale)")
                return
            }
            XCTAssertEqual(transition.targetLevel, target)
            let rect = transition.incomingRect(at: transition.progress)
            if target == .thirtyOne {
                let reached = transition.targetLayout.indexRange(intersecting: rect)
                XCTAssertFalse(self.pages(reached).isSubset(of: self.pages(around)), "incoming \(reached) needs no page beyond level 15's ranges \(around)")
            }
            let incoming = transition.incoming.visibleCells.filter { $0.value.frame.intersects(rect) }
            XCTAssertFalse(incoming.isEmpty)
            let empty = incoming.filter { $0.value.contents == nil }.map { $0.key }.sorted()
            XCTAssertEqual(empty, [], "scale \(scale): empty incoming \(empty.prefix(8)) of \(incoming.count)")
            view._testPinch(.changed, center: center, scale: 1.0)
            view._testPinch(.ended, center: center, scale: 1.0)
            view._testFinishAnimations()
            XCTAssertEqual(view.level, .fifteen)
        }
    }

    func testKeptOversizedImageRerequestsOrFallsBack() {
        for (source, target, side) in [(MediaGridLevel.one, MediaGridLevel.three, CGFloat(1300.0)), (.three, .fifteen, 400.0)] {
            let (view, dataSource) = self.makeView()
            view.setLevel(source, animated: false)
            var images: [Int: UIImage] = [:]
            dataSource.imageForIndex = { index in
                if let image = images[index] {
                    return image
                }
                let image = TestDataSource.distinctImage(index, side: side)
                images[index] = image
                return image
            }
            view.setContentOffset(view.contentHeight * 0.2)
            let before = view.activeLayoutLayer.visibleCells
            XCTAssertTrue(before.values.allSatisfy { !$0.isShowingThumbnail })
            dataSource.holdsDeliveries = true
            let requests = dataSource.requests.count
            view.setLevel(target, animated: false)
            guard let layout = view.gridLayout else {
                XCTFail("no layout")
                return
            }
            let targetSize = layout.pixelSize(at: 0)
            let requested = Set(dataSource.requests[requests...].filter { $0.pixelSize == targetSize }.map { $0.index })
            var kept = 0
            for (index, cell) in view.activeLayoutLayer.visibleCells where before[index] === cell {
                kept += 1
                if target.isInteractive {
                    XCTAssertTrue((cell.contents as AnyObject?) === images[index]?.cgImage, "\(target.columns): index \(index) dropped its kept image")
                    XCTAssertTrue(requested.contains(index), "\(target.columns): index \(index) did not ask for a right-sized image")
                } else {
                    XCTAssertTrue(cell.isShowingThumbnail, "\(target.columns): index \(index) kept an oversized image")
                    XCTAssertFalse(requested.contains(index))
                }
            }
            XCTAssertGreaterThan(kept, 0, "\(source.columns) -> \(target.columns)")
        }
    }

    func testStaleSharpCellTakesArrivingThumbnail() {
        let (view, dataSource) = self.makeView()
        var available = false
        dataSource.thumbnailAvailable = { _ in available }
        dataSource.imageForIndex = { index in
            return TestDataSource.distinctImage(index, side: 400.0)
        }
        view.setContentOffset(20_000.0)
        let range = view.activeLayoutLayer.visibleRange
        let changed = IndexSet(integersIn: range.lowerBound + 3 ..< range.lowerBound + 6)
        dataSource.holdsDeliveries = true
        view.apply(MediaGridChanges(removed: IndexSet(), inserted: IndexSet(), changed: changed))
        for index in changed {
            let cell = view.activeLayoutLayer.visibleCells[index]!
            XCTAssertFalse(cell.isShowingThumbnail)
            XCTAssertNotNil(cell.imageRequest)
        }
        available = true
        view.thumbnailsDidChange(indices: changed)
        for index in changed {
            XCTAssertTrue(view.activeLayoutLayer.visibleCells[index]!.isShowingThumbnail, "index \(index) kept its stale image")
        }
    }

    func testDegradedDoesNotReplaceDonatedSharpImage() {
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
        dataSource.imageForIndex = nil
        let small = TestDataSource.distinctImage(1, side: 120.0)
        let big = TestDataSource.distinctImage(2, side: 1300.0)
        dataSource.deliveries = [(small, true), (big, false)]
        dataSource.holdsDeliveries = true
        view.setLevel(.one, animated: true)
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        let donated = transition.incoming.visibleCells.filter { images[$0.key] != nil && ($0.value.contents as AnyObject?) === images[$0.key]?.cgImage }
        XCTAssertFalse(donated.isEmpty)
        dataSource.flushNextHeldDelivery()
        for (index, cell) in donated {
            XCTAssertTrue((cell.contents as AnyObject?) === images[index]?.cgImage, "index \(index) lost its donated image to a smaller degraded one")
        }
        dataSource.flushHeldDeliveries()
        for (index, cell) in donated {
            XCTAssertTrue((cell.contents as AnyObject?) === big.cgImage, "index \(index)")
            XCTAssertTrue(cell.hasFinalImage)
        }
        view._testFinishAnimations()
    }

    func testZoomOutDoesNotAdoptOversizedDonor() {
        for (source, target, side) in [(MediaGridLevel.one, MediaGridLevel.three, CGFloat(1300.0)), (.three, .fifteen, 400.0)] {
            let (view, dataSource) = self.makeView()
            view.setLevel(source, animated: false)
            var images: [Int: UIImage] = [:]
            dataSource.imageForIndex = { index in
                if let image = images[index] {
                    return image
                }
                let image = TestDataSource.distinctImage(index, side: side)
                images[index] = image
                return image
            }
            view.setContentOffset(view.contentHeight * 0.2)
            let outgoing = view.activeLayoutLayer.visibleCells
            XCTAssertTrue(outgoing.values.allSatisfy { !$0.isShowingThumbnail })
            dataSource.holdsDeliveries = true
            let before = dataSource.requests.count
            view.setLevel(target, animated: true)
            guard let transition = view.transition else {
                XCTFail("no transition")
                return
            }
            let shared = Set(transition.incoming.visibleCells.keys).intersection(outgoing.keys)
            XCTAssertFalse(shared.isEmpty)
            for index in shared {
                let cell = transition.incoming.visibleCells[index]!
                XCTAssertTrue(cell.isShowingThumbnail, "\(source.columns) -> \(target.columns) index \(index) adopted an oversized donor")
            }
            let incomingSize = transition.targetLayout.pixelSize(at: 0)
            let requested = Set(dataSource.requests[before...].filter { $0.pixelSize == incomingSize }.map { $0.index })
            if target.isInteractive {
                XCTAssertTrue(shared.isSubset(of: requested))
            } else {
                XCTAssertTrue(requested.isEmpty)
            }
            view._testFinishAnimations()
        }
    }

    func testKeptFinalImageStaysFinal() {
        let (view, dataSource) = self.makeView(thumbnails: false)
        view.setContentOffset(5_000.0)
        let before = view.activeLayoutLayer.visibleCells
        XCTAssertTrue(before.values.allSatisfy { $0.hasFinalImage })
        dataSource.holdsDeliveries = true
        let requests = dataSource.requests.count
        view.setLevel(.five, animated: false)
        var kept = 0
        for (index, cell) in view.activeLayoutLayer.visibleCells where before[index] === cell {
            kept += 1
            XCTAssertTrue(cell.hasFinalImage, "index \(index)")
            XCTAssertNotNil(cell.contents)
        }
        XCTAssertGreaterThan(kept, 0)
        XCTAssertGreaterThan(dataSource.requests.count, requests)
    }

    func testJumpReassignsCellsInPlace() {
        let (view, dataSource) = self.makeView()
        dataSource.holdsDeliveries = true
        view.setContentOffset(10_000.0)
        let before = Set(view.activeLayoutLayer.visibleCells.values.map { ObjectIdentifier($0) })
        let pooled = view.pool.count
        let reuses = self.reuses
        for cell in view.activeLayoutLayer.visibleCells.values {
            (cell as? TrackingCellLayer)?.checksPhotoState = true
        }
        let cancels = dataSource.cancelCount
        view.setContentOffset(60_000.0)
        let after = view.activeLayoutLayer.visibleCells
        let afterIdentities = Set(after.values.map { ObjectIdentifier($0) })
        let excess = max(0, before.count - after.count)
        XCTAssertEqual(afterIdentities.intersection(before).count, min(before.count, after.count))
        XCTAssertEqual(self.reuses - reuses, before.count)
        XCTAssertEqual(view.pool.count - pooled, excess)
        XCTAssertEqual(dataSource.cancelCount - cancels, before.count)
        for (index, cell) in after {
            XCTAssertFalse(cell.isHidden)
            XCTAssertEqual(cell.index, index)
            XCTAssertTrue(cell.isShowingThumbnail)
        }
        self.assertNoEmptyCells(view, "after jump")
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
