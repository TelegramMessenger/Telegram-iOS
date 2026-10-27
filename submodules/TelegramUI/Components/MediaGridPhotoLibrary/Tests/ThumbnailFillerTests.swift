import XCTest
import UIKit
import MediaGrid
@testable import MediaGridPhotoLibrary

private final class FakeThumbnailRequest: ThumbnailRequest {
    var isCancelled = false

    func cancel() {
        self.isCancelled = true
    }
}

private final class FakeThumbnailSource: ThumbnailImageSource {
    var requests: [(index: Int, id: String, network: Bool, request: FakeThumbnailRequest, completion: (ThumbnailImageResult) -> Void)] = []
    var log: [String] = []
    var networkLog: [String] = []

    func requestThumbnail(index: Int, id: String, network: Bool, completion: @escaping (ThumbnailImageResult) -> Void) -> ThumbnailRequest? {
        let request = FakeThumbnailRequest()
        self.requests.append((index, id, network, request, completion))
        if network {
            self.networkLog.append(id)
        } else {
            self.log.append(id)
        }
        return request
    }

    var localRequests: [String] {
        return self.requests.filter { !$0.network }.map(\.id)
    }

    var networkRequests: [String] {
        return self.requests.filter { $0.network }.map(\.id)
    }

    func completeFirst(_ result: ThumbnailImageResult) {
        let position = self.requests.firstIndex(where: { !$0.network })!
        let request = self.requests.remove(at: position)
        request.completion(result)
    }

    func complete(id: String, network: Bool = false, _ result: ThumbnailImageResult) {
        let position = self.requests.firstIndex(where: { $0.id == id && $0.network == network })!
        let request = self.requests.remove(at: position)
        request.completion(result)
    }

    func drainLocal(_ result: (String) -> ThumbnailImageResult) {
        while let position = self.requests.firstIndex(where: { !$0.network }) {
            let request = self.requests.remove(at: position)
            request.completion(result(request.id))
        }
    }
}

final class ThumbnailFillerTests: XCTestCase {
    private var now: CFTimeInterval = 1000.0
    private var scheduled: [TimeInterval] = []

    private let image: CGImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 96.0, height: 72.0), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 96.0, height: 72.0))
        }.cgImage!
    }()

    private func catalog(_ count: Int, version: String = "1") -> ThumbnailCatalog {
        return ThumbnailCatalog.build(count: count, entry: { ("p\($0)", version) })
    }

    private func makeFiller(store: MediaGridThumbnailStore = MediaGridThumbnailStore(directory: nil), registry: ThumbnailRetryRegistry = ThumbnailRetryRegistry(url: nil)) -> (ThumbnailFiller, FakeThumbnailSource) {
        let source = FakeThumbnailSource()
        let filler = ThumbnailFiller(store: store, source: source, registry: registry, clock: { [unowned self] in self.now }, schedule: { [unowned self] delay, _ in self.scheduled.append(delay) })
        return (filler, source)
    }

    private func makeFiller(count: Int, store: MediaGridThumbnailStore = MediaGridThumbnailStore(directory: nil), ranges: [Range<Int>] = []) -> (ThumbnailFiller, FakeThumbnailSource, MediaGridThumbnailStore) {
        let (filler, source) = self.makeFiller(store: store)
        filler.setPriority(ranges: ranges)
        filler.install(filler.makePlan(for: self.catalog(count)))
        return (filler, source, store)
    }

    private func waitForPublish(_ store: MediaGridThumbnailStore, ids: Set<String>) {
        let expectation = self.expectation(description: "published")
        var pending = ids
        store.onThumbnailsChanged = { changed in
            pending.subtract(changed)
            if pending.isEmpty {
                store.onThumbnailsChanged = nil
                expectation.fulfill()
            }
        }
        self.wait(for: [expectation], timeout: 5.0)
    }

    func testFillsMissingInPriorityOrder() {
        let (filler, source, _) = self.makeFiller(count: 100, ranges: [40 ..< 44, 80 ..< 82])
        XCTAssertEqual(filler.missingCount, 84)
        let expected = [40, 41, 42, 43, 80, 81, 44, 39, 45, 38, 46, 37, 47, 36, 48, 35].map { "p\($0)" }
        XCTAssertEqual(source.log, expected)
        source.completeFirst(.image(self.image))
        XCTAssertEqual(source.log.last, "p49")
        XCTAssertEqual(filler.inFlightCount, 16)
    }

    func testRestOfLibraryFollowsInGridOrderAfterOutward() {
        let (filler, source, _) = self.makeFiller(count: 2000, ranges: [1000 ..< 1001])
        while source.log.count < 1027 {
            source.completeFirst(.image(self.image))
        }
        XCTAssertEqual(source.log[0], "p1000")
        XCTAssertEqual(source.log[1], "p999")
        XCTAssertEqual(source.log[2], "p1001")
        XCTAssertEqual(source.log[1023], "p488")
        XCTAssertEqual(source.log[1024], "p1512")
        XCTAssertEqual(source.log[1025], "p0")
        XCTAssertEqual(source.log[1026], "p1")
        XCTAssertFalse(filler.isComplete)
    }

    func testNewCenterDoesNotRescanFilledIndices() {
        let (filler, source) = self.makeFiller()
        let count = 100_000
        let plan = ThumbnailFillPlan.make(catalog: self.catalog(count), isFilled: { id, _ in Int(id.dropFirst())! < 90_000 }, retryFailures: { _, _ in nil }, storedIds: [])
        filler.isMovingFast = true
        filler.install(plan)
        XCTAssertEqual(source.localRequests.count, ThumbnailFiller.fastLimit)
        let before = filler.probeCount
        for step in 0 ..< 50 {
            let center = step * 997
            filler.setPriority(ranges: [center ..< center + 2000, center + 4000 ..< center + 6000])
            source.completeFirst(.image(self.image))
        }
        XCTAssertEqual(source.localRequests.count, ThumbnailFiller.fastLimit)
        XCTAssertEqual(source.log.count, ThumbnailFiller.fastLimit + 50)
        XCTAssertLessThan(filler.probeCount - before, 2000)
    }

    func testCompletesWhenEverythingIsFilled() {
        let (filler, source, store) = self.makeFiller(count: 20)
        source.drainLocal { _ in .image(self.image) }
        XCTAssertTrue(filler.isComplete)
        XCTAssertEqual(filler.filledCount, 20)
        XCTAssertEqual(filler.missingCount, 0)
        XCTAssertEqual(store.version(for: "p7"), "1")
        XCTAssertEqual(source.log.count, 20)
    }

    func testSkipsUpToDateVersion() {
        let store = MediaGridThumbnailStore(directory: nil)
        store.write(self.image, id: "p1", version: "1")
        store.write(self.image, id: "p2", version: "0")
        let (filler, source, _) = self.makeFiller(count: 4, store: store)
        XCTAssertEqual(source.log, ["p0", "p2", "p3"])
        XCTAssertEqual(filler.filledCount, 1)
    }

    func testChangedVersionRefills() {
        let (filler, source, store) = self.makeFiller(count: 3)
        source.drainLocal { _ in .image(self.image) }
        XCTAssertEqual(store.version(for: "p1"), "1")
        let changes = MediaGridChanges(removed: [], inserted: [], changed: [1])
        let catalog = filler.catalog.applying(changes, newCount: 3, entry: { _ in ("p1", "2") })
        filler.install(filler.makePlan(for: catalog), urgent: ["p1"])
        XCTAssertEqual(source.localRequests, ["p1"])
        XCTAssertFalse(filler.isComplete)
        source.completeFirst(.image(self.image))
        XCTAssertEqual(store.version(for: "p1"), "2")
        XCTAssertTrue(filler.isComplete)
    }

    func testRemovedFreesSlot() {
        let (filler, source, store) = self.makeFiller(count: 3)
        source.drainLocal { _ in .image(self.image) }
        self.waitForPublish(store, ids: ["p0", "p1", "p2"])
        let removedRect = store.thumbnail(for: "p1")!.contentsRect
        let changes = MediaGridChanges(removed: [1], inserted: [0], changed: [])
        let catalog = filler.catalog.applying(changes, newCount: 3, entry: { _ in ("n", "1") })
        filler.install(filler.makePlan(for: catalog), removed: ["p1"], urgent: ["n"])
        XCTAssertNil(store.version(for: "p1"))
        XCTAssertEqual(source.localRequests, ["n"])
        source.completeFirst(.image(self.image))
        self.waitForPublish(store, ids: ["n"])
        XCTAssertNil(store.thumbnail(for: "p1"))
        XCTAssertEqual(store.thumbnail(for: "n")!.contentsRect, removedRect)
    }

    func testOrphanedStoreIdsAreRemovedOnInstall() {
        let store = MediaGridThumbnailStore(directory: nil)
        store.write(self.image, id: "gone", version: "1")
        store.write(self.image, id: "p1", version: "1")
        let registry = ThumbnailRetryRegistry(url: nil)
        _ = registry.recordFailure(id: "gone2", version: "1")
        let (filler, _) = self.makeFiller(store: store, registry: registry)
        let plan = filler.makePlan(for: self.catalog(3))
        XCTAssertEqual(Set(plan.orphans), ["gone"])
        XCTAssertEqual(plan.retryOrphans, ["gone2"])
        filler.install(plan)
        XCTAssertNil(store.version(for: "gone"))
        XCTAssertEqual(store.version(for: "p1"), "1")
        XCTAssertNil(registry.failures(id: "gone2", version: "1"))
        XCTAssertEqual(Set(store.storedIds()), ["p1"])
    }

    func testLateCompletionForRemovedIdIsNotWritten() {
        let (filler, source, store) = self.makeFiller(count: 2)
        let changes = MediaGridChanges(removed: [0], inserted: [], changed: [])
        let catalog = filler.catalog.applying(changes, newCount: 1, entry: { _ in ("x", "1") })
        filler.install(filler.makePlan(for: catalog), removed: ["p0"])
        source.complete(id: "p0", .image(self.image))
        XCTAssertNil(store.version(for: "p0"))
    }

    func testUnavailableRetriesWithBackoffAndFillsOnceLocal() {
        let (filler, source, store) = self.makeFiller(count: 3)
        source.complete(id: "p1", .unavailable)
        source.drainLocal { _ in .image(self.image) }
        XCTAssertEqual(filler.unavailableCount, 1)
        XCTAssertTrue(filler.isComplete)
        XCTAssertEqual(filler.registry.failures(id: "p1", version: "1"), 1)

        self.now += 29.0
        filler.processRetries()
        XCTAssertTrue(source.localRequests.isEmpty)
        self.now += 1.0
        filler.processRetries()
        XCTAssertEqual(source.localRequests, ["p1"])
        source.complete(id: "p1", .unavailable)
        XCTAssertEqual(filler.registry.failures(id: "p1", version: "1"), 2)

        self.now += 60.0
        filler.processRetries()
        XCTAssertTrue(source.localRequests.isEmpty)
        self.now += 60.0
        filler.processRetries()
        XCTAssertEqual(source.localRequests, ["p1"])
        source.complete(id: "p1", .image(self.image))
        XCTAssertEqual(store.version(for: "p1"), "1")
        XCTAssertEqual(filler.unavailableCount, 0)
        XCTAssertEqual(filler.filledCount, 3)
        XCTAssertNil(filler.registry.failures(id: "p1", version: "1"))
    }

    func testRetriesStopAfterTenMinuteStepUntilNextLaunch() {
        let registry = ThumbnailRetryRegistry(url: nil)
        let (filler, source) = self.makeFiller(registry: registry)
        filler.install(filler.makePlan(for: self.catalog(1)))
        for delay in [0.0, 30.0, 120.0, 600.0] {
            self.now += delay
            filler.processRetries()
            XCTAssertEqual(source.localRequests, ["p0"], "after \(delay)")
            source.complete(id: "p0", .unavailable)
        }
        XCTAssertEqual(registry.failures(id: "p0", version: "1"), 4)
        self.now += 3600.0
        filler.processRetries()
        XCTAssertTrue(source.localRequests.isEmpty)

        let (relaunched, relaunchedSource) = self.makeFiller(registry: registry)
        relaunched.install(relaunched.makePlan(for: self.catalog(1)))
        XCTAssertTrue(relaunchedSource.localRequests.isEmpty)
        XCTAssertEqual(relaunched.unavailableCount, 1)
        self.now += ThumbnailFiller.launchRetryDelay
        relaunched.processRetries()
        XCTAssertEqual(relaunchedSource.localRequests, ["p0"])
        relaunchedSource.complete(id: "p0", .unavailable)
        self.now += 3600.0
        relaunched.processRetries()
        XCTAssertTrue(relaunchedSource.localRequests.isEmpty)
    }

    func testRetryForOtherVersionStartsOver() {
        let registry = ThumbnailRetryRegistry(url: nil)
        _ = registry.recordFailure(id: "p0", version: "0")
        _ = registry.recordFailure(id: "p0", version: "0")
        XCTAssertNil(registry.failures(id: "p0", version: "1"))
        XCTAssertEqual(registry.recordFailure(id: "p0", version: "1"), 1)
    }

    func testSharpDeliveryHarvestsAndClearsRetry() {
        let (filler, source, store) = self.makeFiller(count: 2)
        source.complete(id: "p1", .unavailable)
        XCTAssertEqual(filler.harvestVersion(for: "p1"), "1")
        XCTAssertNil(filler.harvestVersion(for: "unknown"))
        filler.harvest(id: "p1", version: "1", image: self.image)
        XCTAssertEqual(store.version(for: "p1"), "1")
        XCTAssertNil(filler.registry.failures(id: "p1", version: "1"))
        XCTAssertEqual(filler.unavailableCount, 0)
        XCTAssertNil(filler.harvestVersion(for: "p1"))
        self.now += 30.0
        filler.processRetries()
        XCTAssertFalse(source.localRequests.contains("p1"))
        source.complete(id: "p0", .image(self.image))
        XCTAssertTrue(filler.isComplete)
        XCTAssertEqual(filler.filledCount, 2)
    }

    func testHarvestWritesNewVersionOverOldStoreEntry() {
        let (filler, source, store) = self.makeFiller(count: 1)
        source.complete(id: "p0", .image(self.image))
        XCTAssertNil(filler.harvestVersion(for: "p0"))
        let catalog = ThumbnailCatalog(ids: ["p0"], versions: ["2"])
        filler.install(filler.makePlan(for: catalog))
        XCTAssertEqual(filler.harvestVersion(for: "p0"), "2")
        filler.harvest(id: "p0", version: "2", image: self.image)
        XCTAssertEqual(store.version(for: "p0"), "2")
    }

    func testHarvestDropsStaleVersion() {
        let (filler, source, store) = self.makeFiller(count: 1)
        source.complete(id: "p0", .unavailable)
        let captured = filler.harvestVersion(for: "p0")
        XCTAssertEqual(captured, "1")
        filler.install(filler.makePlan(for: ThumbnailCatalog(ids: ["p0"], versions: ["2"])))
        filler.harvest(id: "p0", version: captured!, image: self.image)
        XCTAssertNil(store.version(for: "p0"))
    }

    func testLocalMissAfterHarvestCountsAsFilled() {
        let (filler, source, store) = self.makeFiller(count: 1)
        filler.harvest(id: "p0", version: "1", image: self.image)
        XCTAssertEqual(store.version(for: "p0"), "1")
        source.complete(id: "p0", .unavailable)
        XCTAssertEqual(filler.filledCount, 1)
        XCTAssertEqual(filler.unavailableCount, 0)
        XCTAssertNil(filler.registry.failures(id: "p0", version: "1"))
        XCTAssertTrue(filler.isComplete)
    }

    func testRefusedWriteIsNotMarkedFilled() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = MediaGridThumbnailStore(directory: directory)
        let (filler, source) = self.makeFiller(store: store)
        filler.install(ThumbnailFillPlan.make(catalog: self.catalog(1), isFilled: { _, _ in false }, retryFailures: { _, _ in nil }, storedIds: []))
        source.complete(id: "p0", .image(self.image))
        XCTAssertNil(store.version(for: "p0"))
        XCTAssertEqual(filler.filledCount, 0)
        XCTAssertTrue(source.localRequests.isEmpty)
        try? FileManager.default.removeItem(at: directory)
    }

    func testInstallKeepsDueRetryMissing() {
        let (filler, source) = self.makeFiller()
        filler.isPaused = true
        filler.install(filler.makePlan(for: self.catalog(2)))
        filler.isPaused = false
        source.complete(id: "p1", .unavailable)
        source.complete(id: "p0", .image(self.image))
        self.now += 30.0
        filler.isPaused = true
        filler.processRetries()
        filler.install(filler.makePlan(for: filler.catalog))
        XCTAssertEqual(filler.missingCount, 1)
        filler.isPaused = false
        XCTAssertEqual(source.localRequests, ["p1"])
        filler.install(filler.makePlan(for: filler.catalog))
        source.complete(id: "p1", .unavailable)
        XCTAssertEqual(filler.registry.failures(id: "p1", version: "1"), 2)
    }

    func testRetryNowReleasesUnavailableIds() {
        let (filler, source, _) = self.makeFiller(count: 3)
        source.complete(id: "p1", .unavailable)
        source.drainLocal { _ in .image(self.image) }
        XCTAssertTrue(source.localRequests.isEmpty)
        filler.retryNow(ids: ["p1", "p2", "unknown"])
        XCTAssertEqual(source.localRequests, ["p1"])
    }

    func testLaunchRetriesReleaseInBatchesNearTheViewport() {
        let registry = ThumbnailRetryRegistry(url: nil)
        for index in 0 ..< 1000 {
            for _ in 0 ..< 4 {
                _ = registry.recordFailure(id: "p\(index)", version: "1")
            }
        }
        let (filler, source) = self.makeFiller(registry: registry)
        filler.isPaused = true
        filler.setPriority(ranges: [500 ..< 502])
        filler.install(filler.makePlan(for: self.catalog(1000)))
        self.now += ThumbnailFiller.launchRetryDelay
        filler.isMovingFast = true
        filler.processRetries()
        XCTAssertEqual(filler.missingCount, 0)
        filler.isMovingFast = false
        filler.processRetries()
        XCTAssertEqual(filler.missingCount, ThumbnailFiller.launchRetryBatch)
        filler.isPaused = false
        XCTAssertEqual(source.localRequests.first, "p500")
        let released = Set(source.localRequests.map { Int($0.dropFirst())! })
        XCTAssertTrue(released.allSatisfy { abs($0 - 500) <= ThumbnailFiller.launchRetryBatch })
        self.now += ThumbnailFiller.launchRetryInterval
        filler.processRetries()
        XCTAssertEqual(filler.missingCount + filler.inFlightCount, 2 * ThumbnailFiller.launchRetryBatch - (source.log.count - source.localRequests.count))
    }

    func testNetworkLaneRunsOnlyWhenIdleAndViewportFirst() {
        let (filler, source) = self.makeFiller()
        var gate = false
        filler.networkGate = { gate }
        filler.setPriority(ranges: [10 ..< 12])
        filler.install(filler.makePlan(for: self.catalog(20)))
        source.drainLocal { id in ["p2", "p11", "p15", "p19"].contains(id) ? .unavailable : .image(self.image) }
        XCTAssertTrue(source.networkRequests.isEmpty)
        gate = true
        filler.isMovingFast = true
        filler.networkConditionsChanged()
        XCTAssertTrue(source.networkRequests.isEmpty)
        filler.isMovingFast = false
        XCTAssertEqual(source.networkRequests, ["p11", "p15"])
        XCTAssertEqual(filler.networkInFlightCount, ThumbnailFiller.networkLimit)
        source.complete(id: "p11", network: true, .image(self.image))
        XCTAssertEqual(source.networkRequests, ["p15", "p19"])
        let running = source.requests.filter { $0.network }.map(\.request)
        filler.isPaused = true
        XCTAssertTrue(running.allSatisfy { $0.isCancelled })
        XCTAssertEqual(filler.networkInFlightCount, 0)
        source.requests.removeAll()
        filler.isPaused = false
        XCTAssertEqual(source.networkRequests, ["p15", "p19"])
        source.requests.removeAll()
        let movingRunning = filler.networkInFlightCount
        XCTAssertEqual(movingRunning, 2)
        filler.isMovingFast = true
        XCTAssertEqual(filler.networkInFlightCount, 0)
        filler.isMovingFast = false
        XCTAssertEqual(source.networkRequests, ["p15", "p19"])
        XCTAssertEqual(filler.store.version(for: "p11"), "1")
        XCTAssertNil(filler.registry.failures(id: "p11", version: "1"))
    }

    func testNetworkLaneYieldsToSharpNetworkWork() {
        let (filler, source) = self.makeFiller()
        var gate = true
        filler.networkGate = { gate }
        filler.install(filler.makePlan(for: self.catalog(4)))
        source.drainLocal { _ in .unavailable }
        XCTAssertEqual(source.networkRequests.count, 2)
        let running = source.requests.filter { $0.network }.map(\.request)
        gate = false
        filler.networkConditionsChanged()
        XCTAssertTrue(running.allSatisfy { $0.isCancelled })
        XCTAssertEqual(filler.networkInFlightCount, 0)
        for request in source.requests where request.network {
            request.completion(.cancelled)
        }
        source.requests.removeAll()
        XCTAssertEqual(filler.registry.failures(id: "p0", version: "1"), 1)
        gate = true
        filler.networkConditionsChanged()
        XCTAssertEqual(source.networkRequests.count, 2)
    }

    func testNetworkFailureBacksOff() {
        let (filler, source) = self.makeFiller()
        filler.networkGate = { true }
        filler.install(filler.makePlan(for: self.catalog(1)))
        var expectedFailures = 0
        for delay in [0.0, 30.0, 120.0, 600.0] {
            if delay > 0.0 {
                self.now += delay - 1.0
                filler.processRetries()
                XCTAssertTrue(source.requests.isEmpty, "early before \(delay)")
                self.now += 1.0
                filler.processRetries()
            }
            XCTAssertEqual(source.localRequests, ["p0"], "local after \(delay)")
            source.complete(id: "p0", .unavailable)
            expectedFailures += 1
            XCTAssertEqual(source.networkRequests, ["p0"], "network after \(delay)")
            source.complete(id: "p0", network: true, .unavailable)
            XCTAssertEqual(filler.registry.failures(id: "p0", version: "1"), expectedFailures)
            XCTAssertTrue(source.requests.isEmpty)
        }
        self.now += 3600.0
        filler.processRetries()
        XCTAssertTrue(source.requests.isEmpty)
    }

    func testLostIdsAreRefilled() {
        let (filler, source, store) = self.makeFiller(count: 2)
        source.drainLocal { _ in .image(self.image) }
        XCTAssertTrue(filler.isComplete)
        store.remove(ids: ["p0"])
        filler.storeChanged(ids: ["p0", "p1"])
        XCTAssertEqual(source.localRequests, ["p0"])
        XCTAssertFalse(filler.isComplete)
    }

    func testThrottlesWhileMovingFast() {
        let (filler, source) = self.makeFiller()
        filler.isMovingFast = true
        filler.install(filler.makePlan(for: self.catalog(100)))
        XCTAssertEqual(source.requests.count, 4)
        source.completeFirst(.image(self.image))
        XCTAssertEqual(source.requests.count, 4)
        filler.isMovingFast = false
        XCTAssertEqual(source.requests.count, 16)
        filler.isMovingFast = true
        source.completeFirst(.image(self.image))
        XCTAssertEqual(source.requests.count, 15)
        XCTAssertEqual(filler.inFlightCount, 15)
    }

    func testPausedWhileStoreIsNotWritable() {
        let (filler, source) = self.makeFiller()
        filler.isPaused = true
        filler.install(filler.makePlan(for: self.catalog(10)))
        XCTAssertTrue(source.requests.isEmpty)
        filler.isPaused = false
        XCTAssertEqual(source.requests.count, 10)
    }

    func testIdToIndexMapFollowsChanges() {
        let initial = self.catalog(6)
        XCTAssertEqual(initial.indexById["p4"], 4)
        let changes = MediaGridChanges(removed: [1, 4], inserted: [0, 3], changed: [2])
        XCTAssertTrue(changes.isValid(oldCount: 6, newCount: 6))
        var read: [Int] = []
        let updated = initial.applying(changes, newCount: 6, entry: { index in
            read.append(index)
            return ("n\(index)", "2")
        })
        XCTAssertEqual(updated.ids, ["n0", "p0", "n2", "n3", "p3", "p5"])
        XCTAssertEqual(updated.versions, ["2", "1", "2", "2", "1", "1"])
        XCTAssertEqual(read, [0, 2, 3])
        XCTAssertEqual(updated.indexById["p5"], 5)
        XCTAssertEqual(updated.indexById["p3"], 4)
        XCTAssertNil(updated.indexById["p1"])
        XCTAssertNil(updated.indexById["p4"])
        XCTAssertEqual(updated.id(at: 1), "p0")
        XCTAssertNil(updated.id(at: 6))
    }

    func testFastFormatFailureRetriesHighQualityOnceWithoutNetwork() {
        let policy = ThumbnailFormatPolicy()
        var attempts: [ThumbnailFormatPolicy.Attempt] = []
        var result: ThumbnailImageResult?
        policy.run(attempt: { attempt, completion in
            attempts.append(attempt)
            if attempt == .fastFormat {
                completion(nil, true)
            } else {
                completion(self.image, false)
            }
        }, completion: { result = $0 })
        XCTAssertEqual(attempts, [.fastFormat, .highQuality])
        guard case .image = result else {
            return XCTFail("expected an image")
        }
        XCTAssertEqual(policy.fastFormatFailures, 1)

        attempts = []
        policy.run(attempt: { attempt, completion in
            attempts.append(attempt)
            completion(nil, attempt == .highQuality)
        }, completion: { result = $0 })
        XCTAssertEqual(attempts, [.fastFormat, .highQuality])
        guard case .unavailable = result else {
            return XCTFail("expected unavailable")
        }
    }

    func testFastFormatSwitchesOffAfterRepeatedFailures() {
        let policy = ThumbnailFormatPolicy()
        for _ in 0 ..< ThumbnailFormatPolicy.fallbackLimit {
            policy.run(attempt: { attempt, completion in
                completion(attempt == .fastFormat ? nil : self.image, attempt == .fastFormat)
            }, completion: { _ in })
        }
        var attempts: [ThumbnailFormatPolicy.Attempt] = []
        policy.run(attempt: { attempt, completion in
            attempts.append(attempt)
            completion(self.image, false)
        }, completion: { _ in })
        XCTAssertEqual(attempts, [.highQuality])
    }

    func testLaunchSnapshotServesIdsAndDiffs() {
        let snapshot = ThumbnailLaunchSnapshot(count: 10, segments: [ThumbnailLaunchSnapshot.Segment(start: 0, ids: ["a", "b", "c"]), ThumbnailLaunchSnapshot.Segment(start: 6, ids: ["g", "h"])])
        let decoded = ThumbnailLaunchSnapshot.decode(snapshot.encode())
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded?.id(at: 1), "b")
        XCTAssertEqual(decoded?.id(at: 7), "h")
        XCTAssertNil(decoded?.id(at: 4))
        XCTAssertNil(decoded?.id(at: 8))
        XCTAssertEqual(snapshot.indices, IndexSet([0, 1, 2, 6, 7]))
        let catalog = ThumbnailCatalog(ids: ["a", "x", "c", "d", "e", "f", "g", "y", "i", "j"], versions: Array(repeating: "1", count: 10))
        let made = ThumbnailLaunchSnapshot.make(catalog: catalog, head: 2, ranges: [5 ..< 7, 20 ..< 30])
        XCTAssertEqual(made.count, 10)
        XCTAssertEqual(made.segments, [ThumbnailLaunchSnapshot.Segment(start: 0, ids: ["a", "x"]), ThumbnailLaunchSnapshot.Segment(start: 5, ids: ["f", "g"])])
        XCTAssertNil(ThumbnailLaunchSnapshot.decode(Data([1, 2, 3])))
    }
}
