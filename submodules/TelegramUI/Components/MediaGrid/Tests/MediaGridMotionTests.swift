import XCTest
@testable import MediaGrid

final class MediaGridMotionTests: XCTestCase {
    private var time: CFTimeInterval = 100.0

    private func makeView(count: Int = 100_000) -> (MediaGridView, TestDataSource) {
        let dataSource = TestDataSource(count: count)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.motionClock = { [unowned self] in
            return self.time
        }
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        return (view, dataSource)
    }

    private func viewportIndices(_ view: MediaGridView) -> Range<Int> {
        guard let layout = view.currentLayout else {
            return 0 ..< 0
        }
        return layout.indexRange(intersecting: CGRect(x: 0.0, y: view.contentOffset, width: view.bounds.width, height: view.bounds.height))
    }

    private func scroll(_ view: MediaGridView, to offset: CGFloat, after interval: CFTimeInterval = 0.0625) {
        self.time += interval
        view.setContentOffset(offset)
    }

    private func startFastScrub(_ view: MediaGridView) {
        self.scroll(view, to: 10_000.0)
        self.scroll(view, to: 14_000.0)
    }

    func testFastScrubBindsFastQuality() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 10_000.0)
        XCTAssertFalse(view.isMovingFast)
        let before = dataSource.requests.count
        self.scroll(view, to: 14_000.0)
        XCTAssertTrue(view.isMovingFast)
        let added = dataSource.requests[before...]
        XCTAssertFalse(added.isEmpty)
        XCTAssertTrue(added.allSatisfy { $0.quality == .fast })
    }

    func testSlowScrollKeepsFullQuality() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 1000.0)
        let before = dataSource.requests.count
        for step in 1 ... 120 {
            self.scroll(view, to: 1000.0 + CGFloat(step) * 20.0)
        }
        XCTAssertFalse(view.isMovingFast)
        let added = dataSource.requests[before...]
        XCTAssertFalse(added.isEmpty)
        XCTAssertTrue(added.allSatisfy { $0.quality == .full })
    }

    func testOffsetUpdatesWithinOneFrameDoNotMeasureSpeed() {
        let (view, _) = self.makeView()
        self.scroll(view, to: 1000.0)
        self.scroll(view, to: 1001.0, after: 0.001)
        self.scroll(view, to: 9000.0, after: 0.001)
        XCTAssertFalse(view.isMovingFast)
    }

    func testFrameJumpOverAScreenBindsFast() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 1000.0)
        let before = dataSource.requests.count
        self.scroll(view, to: 1000.0 + view.bounds.height * 1.5, after: 1.0 / 60.0)
        XCTAssertTrue(view.isMovingFast)
        let added = dataSource.requests[before...]
        XCTAssertFalse(added.isEmpty)
        XCTAssertTrue(added.allSatisfy { $0.quality == .fast })
    }

    func testScrollBindsInsideOneDataSourceBatch() {
        let (view, dataSource) = self.makeView()
        let before = dataSource.requests.count
        let batchedBefore = dataSource.batchedRequests
        self.scroll(view, to: 5000.0)
        XCTAssertGreaterThan(dataSource.requests.count, before)
        XCTAssertEqual(dataSource.batchedRequests - batchedBefore, dataSource.requests.count - before)
        let upgradeBefore = dataSource.requests.count
        let upgradeBatchedBefore = dataSource.batchedRequests
        self.startFastScrub(view)
        self.time += 1.0
        view._testSettleMotion()
        XCTAssertGreaterThan(dataSource.requests.count, upgradeBefore)
        XCTAssertEqual(dataSource.batchedRequests - upgradeBatchedBefore, dataSource.requests.count - upgradeBefore)
    }

    func testFrameStepUnderAScreenWaitsForSample() {
        let (view, _) = self.makeView()
        self.scroll(view, to: 1000.0)
        self.scroll(view, to: 1000.0 + view.bounds.height * 0.9, after: 1.0 / 60.0)
        XCTAssertFalse(view.isMovingFast)
    }

    func testSettleUpgradesFastCellsKeepingTheirImage() {
        let (view, dataSource) = self.makeView()
        dataSource.deliveriesByQuality[.fast] = [(TestDataSource.sampleImage, true)]
        self.startFastScrub(view)
        XCTAssertTrue(view.isMovingFast)
        let visible = view.activeLayoutLayer.visibleCells
        XCTAssertFalse(visible.isEmpty)
        for cell in visible.values {
            XCTAssertNotNil(cell.contents)
            XCTAssertFalse(cell.hasFinalImage)
        }
        dataSource.holdsDeliveries = true
        dataSource.deliveriesByQuality[.full] = [(nil, true), (TestDataSource.sampleImage, false)]
        let before = dataSource.requests.count

        self.time += MediaGridView.motionSettleDelay / 2.0
        view._testSettleMotion()
        XCTAssertTrue(view.isMovingFast)
        XCTAssertEqual(dataSource.requests.count, before)

        self.time += MediaGridView.motionSettleDelay
        view._testSettleMotion()
        XCTAssertFalse(view.isMovingFast)
        let upgrades = dataSource.requests[before...]
        XCTAssertEqual(Set(upgrades.map { $0.index }), Set(visible.keys))
        XCTAssertTrue(upgrades.allSatisfy { $0.quality == .full })
        for cell in visible.values {
            XCTAssertNotNil(cell.contents)
        }
        dataSource.flushHeldDeliveries()
        for cell in visible.values {
            XCTAssertNotNil(cell.contents)
            XCTAssertTrue(cell.hasFinalImage)
        }
    }

    func testSettleRequestsViewportUpgradesLast() {
        let (view, dataSource) = self.makeView()
        dataSource.deliveriesByQuality[.fast] = [(TestDataSource.sampleImage, true)]
        self.startFastScrub(view)
        let before = dataSource.requests.count
        self.time += MediaGridView.motionSettleDelay * 2.0
        view._testSettleMotion()
        let upgrades = Array(dataSource.requests[before...])
        let viewport = self.viewportIndices(view)
        XCTAssertGreaterThan(upgrades.count, viewport.count)
        let tail = upgrades.suffix(viewport.count).map { $0.index }
        XCTAssertEqual(Set(tail), Set(viewport))
    }

    func testSettleDoesNotRerequestFinalImages() {
        let (view, dataSource) = self.makeView()
        dataSource.deliveriesByQuality[.fast] = [(TestDataSource.sampleImage, false)]
        self.startFastScrub(view)
        let before = dataSource.requests.count
        self.time += MediaGridView.motionSettleDelay * 2.0
        view._testSettleMotion()
        XCTAssertFalse(view.isMovingFast)
        XCTAssertEqual(dataSource.requests.count, before)
    }

    func testSettleUpgradesPendingFastRequests() {
        let (view, dataSource) = self.makeView()
        dataSource.holdsDeliveries = true
        self.startFastScrub(view)
        let visible = view.activeLayoutLayer.visibleCells
        let cancels = dataSource.cancelCount
        let before = dataSource.requests.count
        self.time += MediaGridView.motionSettleDelay * 2.0
        view._testSettleMotion()
        XCTAssertEqual(dataSource.requests.count - before, visible.count)
        XCTAssertEqual(dataSource.cancelCount - cancels, visible.count)
        dataSource.flushHeldDeliveries()
        for cell in visible.values {
            XCTAssertTrue(cell.hasFinalImage)
        }
    }

    func testFastScrubDoesNotRebindKeptCells() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 10_000.0)
        let kept = view.activeLayoutLayer.visibleCells
        let cancels = dataSource.cancelCount
        let before = dataSource.requests.count
        self.scroll(view, to: 10_000.0 + view.bounds.height * 0.5)
        XCTAssertTrue(view.isMovingFast)
        let after = view.activeLayoutLayer.visibleCells
        let stayed = Set(kept.keys).intersection(after.keys)
        XCTAssertFalse(stayed.isEmpty)
        for index in stayed {
            XCTAssertTrue(kept[index] === after[index])
        }
        let requested = Set(dataSource.requests[before...].map { $0.index })
        XCTAssertTrue(requested.isDisjoint(with: stayed))
        XCTAssertEqual(dataSource.cancelCount - cancels, Set(kept.keys).subtracting(after.keys).count)
    }

    func testJumpRequestsViewportLast() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 10_000.0)
        let before = dataSource.requests.count
        self.scroll(view, to: 60_000.0)
        let added = Array(dataSource.requests[before...])
        let viewport = self.viewportIndices(view)
        XCTAssertGreaterThan(added.count, viewport.count)
        XCTAssertEqual(Set(added.suffix(viewport.count).map { $0.index }), Set(viewport))
        XCTAssertEqual(added.last?.index, viewport.lowerBound)
    }

    func testPrefetchFollowsMotionQuality() {
        let (view, dataSource) = self.makeView()
        XCTAssertEqual(dataSource.cachingQualities.last, .full)
        self.startFastScrub(view)
        XCTAssertEqual(dataSource.cachingQualities.last, .fast)
        let viewport = self.viewportIndices(view)
        XCTAssertTrue(Set(viewport).isSubset(of: dataSource.cachedIndices))
        self.time += MediaGridView.motionSettleDelay * 2.0
        view._testSettleMotion()
        XCTAssertEqual(dataSource.cachingQualities.last, .full)
        XCTAssertTrue(Set(viewport).isSubset(of: dataSource.cachedIndices))
    }

    func testSlowSampleAfterDelayEndsFastMotion() {
        let (view, _) = self.makeView()
        self.startFastScrub(view)
        XCTAssertTrue(view.isMovingFast)
        self.scroll(view, to: 14_010.0)
        XCTAssertTrue(view.isMovingFast)
        self.scroll(view, to: 14_020.0, after: MediaGridView.motionSettleDelay)
        XCTAssertFalse(view.isMovingFast)
    }

    func testZoomTransitionBindsFullQualityWhileFast() {
        let (view, dataSource) = self.makeView()
        self.startFastScrub(view)
        XCTAssertTrue(view.isMovingFast)
        let before = dataSource.requests.count
        view.setLevel(.five, animated: true)
        XCTAssertNotNil(view.transition)
        let added = dataSource.requests[before...]
        XCTAssertFalse(added.isEmpty)
        XCTAssertTrue(added.allSatisfy { $0.quality == .full })
        view._testFinishAnimations()
    }

    func testZoomStartDoesNotUpgradeOutgoingFastCells() {
        let (view, dataSource) = self.makeView()
        dataSource.deliveriesByQuality[.fast] = [(TestDataSource.sampleImage, true)]
        self.startFastScrub(view)
        XCTAssertTrue(view.isMovingFast)
        let outgoing = Set(self.viewportIndices(view))
        let before = dataSource.requests.count
        view.setLevel(.five, animated: true)
        guard let transition = view.transition else {
            XCTFail("no transition")
            return
        }
        XCTAssertFalse(view.isMovingFast)
        let added = dataSource.requests[before...]
        XCTAssertEqual(added.count, transition.incoming.visibleCells.count)
        XCTAssertFalse(outgoing.isEmpty)
        view._testFinishAnimations()
    }

    func testCancelledZoomUpgradesFastCells() {
        let (view, dataSource) = self.makeView()
        dataSource.deliveriesByQuality[.fast] = [(TestDataSource.sampleImage, true)]
        self.startFastScrub(view)
        let viewport = Set(self.viewportIndices(view))
        let centre = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: centre)
        view._testPinch(.changed, center: centre, scale: 0.95)
        XCTAssertNotNil(view.transition)
        let before = dataSource.requests.count
        view._testPinch(.ended, center: centre, scale: 1.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .three)
        let upgraded = Set(dataSource.requests[before...].filter { $0.quality == .full }.map { $0.index })
        XCTAssertTrue(viewport.isSubset(of: upgraded))
    }

    func testNearestFirstOrdersByDistanceFromCentre() {
        XCTAssertEqual(MediaGridView.nearestFirst([1, 2, 3, 8, 9, 10], centre: 5), [3, 8, 2, 9, 1, 10])
        XCTAssertEqual(MediaGridView.nearestFirst([10, 11, 12], centre: 0), [10, 11, 12])
        XCTAssertEqual(MediaGridView.nearestFirst([1, 2, 3], centre: 50), [3, 2, 1])
        XCTAssertEqual(MediaGridView.nearestFirst([], centre: 3), [])
    }

    func testPrefetchStartsNearestTheViewportCentre() {
        let (view, dataSource) = self.makeView()
        self.scroll(view, to: 20_000.0)
        guard let layout = view.currentLayout else {
            XCTFail("no layout")
            return
        }
        XCTAssertFalse(dataSource.startedCachingOrder.isEmpty)
        let centre = layout.indexRange(intersecting: CGRect(x: 0.0, y: view.contentOffset + view.bounds.height * 0.5, width: view.bounds.width, height: 1.0)).lowerBound
        let distances = dataSource.startedCachingOrder.last!.map { abs($0 - centre) }
        XCTAssertEqual(distances, distances.sorted())
    }

    func testUpgradeRequestsFullBeforeCancellingFast() {
        let (view, dataSource) = self.makeView()
        dataSource.holdsDeliveries = true
        self.startFastScrub(view)
        let visible = view.activeLayoutLayer.visibleCells
        let before = dataSource.events.count
        self.time += MediaGridView.motionSettleDelay * 2.0
        view._testSettleMotion()
        let events = Array(dataSource.events[before...])
        XCTAssertEqual(events.count, 2 * visible.count)
        for pair in stride(from: 0, to: events.count, by: 2) {
            let request = events[pair]
            let cancel = events[pair + 1]
            XCTAssertTrue(request.hasPrefix("request "))
            XCTAssertEqual(cancel, request.replacingOccurrences(of: "request ", with: "cancel "))
        }
    }

    func testLateFastDeliveryAfterUpgradeIsDropped() {
        let (view, dataSource) = self.makeView()
        var images: [String: UIImage] = [:]
        dataSource.imageForIndex = { index, quality in
            let key = "\(index)-\(quality)"
            if let image = images[key] {
                return image
            }
            let image = TestDataSource.distinctImage(index + (quality == .fast ? 128 : 0))
            images[key] = image
            return image
        }
        dataSource.holdsDeliveries = true
        dataSource.deliversAfterCancel = true
        self.startFastScrub(view)
        let visible = view.activeLayoutLayer.visibleCells
        self.time += MediaGridView.motionSettleDelay * 2.0
        view._testSettleMotion()
        dataSource.flushHeldDeliveries(where: { _, quality in quality == .full })
        dataSource.flushHeldDeliveries()
        for (index, cell) in visible {
            XCTAssertTrue(cell.hasFinalImage)
            XCTAssertTrue((cell.contents as! CGImage) === images["\(index)-full"]?.cgImage, "index \(index) shows a late fast image")
        }
    }

    func testLateDeliveryAfterReuseIsDropped() {
        let (view, dataSource) = self.makeView()
        var images: [Int: UIImage] = [:]
        dataSource.imageForIndex = { index, _ in
            if let image = images[index] {
                return image
            }
            let image = TestDataSource.distinctImage(index)
            images[index] = image
            return image
        }
        dataSource.holdsDeliveries = true
        dataSource.deliversAfterCancel = true
        self.scroll(view, to: 10_000.0)
        let old = Set(view.activeLayoutLayer.visibleCells.keys)
        self.scroll(view, to: 10_000.0, after: 1.0)
        self.scroll(view, to: 40_000.0, after: 1.0)
        let current = view.activeLayoutLayer.visibleCells
        XCTAssertTrue(old.isDisjoint(with: current.keys))
        dataSource.flushHeldDeliveries(where: { index, _ in current[index] != nil })
        dataSource.flushHeldDeliveries()
        for (index, cell) in current {
            XCTAssertEqual(cell.index, index)
            XCTAssertTrue((cell.contents as! CGImage) === images[index]?.cgImage, "index \(index) shows a stale image")
        }
    }
}
