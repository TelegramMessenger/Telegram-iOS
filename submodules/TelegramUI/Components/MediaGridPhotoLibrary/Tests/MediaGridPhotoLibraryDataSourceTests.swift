import XCTest
import UIKit
import Photos
@testable import MediaGrid
@testable import MediaGridPhotoLibrary

final class MediaGridPhotoLibraryDataSourceTests: XCTestCase {
    private var directories: [URL] = []

    override func tearDown() {
        for directory in self.directories {
            try? FileManager.default.removeItem(at: directory)
        }
        self.directories = []
        super.tearDown()
    }

    private func makeDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MediaGridPhotoLibraryDataSourceTests-\(UUID().uuidString)", isDirectory: true)
        self.directories.append(url)
        return url
    }

    private func makeDataSource(_ fetchResult: PHFetchResult<PHAsset>, reversed: Bool = true, launch: MediaGridLaunchMatch? = nil) -> MediaGridPhotoLibraryDataSource {
        let store = MediaGridThumbnailStore(directory: nil)
        let filler = MediaGridPhotoLibraryFiller(store: store, retryRegistryURL: nil)
        return MediaGridPhotoLibraryDataSource(fetchResult: fetchResult, reversed: reversed, store: store, launch: launch, filler: filler)
    }

    func testFetchChangesReverseToNewestFirst() {
        let changes = MediaGridPhotoLibraryDataSource.gridChanges(removed: [0, 1], inserted: [8, 9], changed: [3], oldCount: 10, newCount: 10, reversed: true)
        XCTAssertEqual(changes.removed, [8, 9])
        XCTAssertEqual(changes.inserted, [0, 1])
        XCTAssertEqual(changes.changed, [6])
        XCTAssertTrue(changes.isValid(oldCount: 10, newCount: 10))
    }

    func testFetchChangesWithCountChange() {
        let changes = MediaGridPhotoLibraryDataSource.gridChanges(removed: [4], inserted: [9, 10, 11], changed: [], oldCount: 10, newCount: 12, reversed: true)
        XCTAssertEqual(changes.removed, [5])
        XCTAssertEqual(changes.inserted, [0, 1, 2])
        XCTAssertTrue(changes.isValid(oldCount: 10, newCount: 12))
    }

    func testUnreversedFetchChangesKeepFetchOrder() {
        let changes = MediaGridPhotoLibraryDataSource.gridChanges(removed: [4], inserted: [9, 10, 11], changed: [2], oldCount: 10, newCount: 12, reversed: false)
        XCTAssertEqual(changes.removed, [4])
        XCTAssertEqual(changes.inserted, [9, 10, 11])
        XCTAssertEqual(changes.changed, [2])
        XCTAssertTrue(changes.isValid(oldCount: 10, newCount: 12))
    }

    func testFetchIndexInBothOrders() {
        XCTAssertEqual((0 ..< 4).map { MediaGridPhotoLibraryDataSource.fetchIndex($0, count: 4, reversed: true) }, [3, 2, 1, 0])
        XCTAssertEqual((0 ..< 4).map { MediaGridPhotoLibraryDataSource.fetchIndex($0, count: 4, reversed: false) }, [0, 1, 2, 3])
    }

    func testDataSourceKeepsItsOrder() {
        let reversed = self.makeDataSource(PHFetchResult<PHAsset>(), reversed: true)
        let unreversed = self.makeDataSource(PHFetchResult<PHAsset>(), reversed: false)
        XCTAssertTrue(reversed.reversed)
        XCTAssertFalse(unreversed.reversed)
        XCTAssertEqual(unreversed.count, 0)
        XCTAssertNil(unreversed.asset(at: 0))
        XCTAssertNil(reversed.asset(at: -1))
    }

    func testDataSourceWithoutFillerServesStoreOnly() {
        let store = MediaGridThumbnailStore(directory: nil)
        let initial = PHFetchResult<PHAsset>()
        let dataSource = MediaGridPhotoLibraryDataSource(fetchResult: initial, reversed: false, store: store, launch: nil)
        var update = self.update(previous: initial, changes: MediaGridChanges(removed: [], inserted: [], changed: []), changed: ["a"])
        update.catalog = ThumbnailCatalog(ids: ["a"], versions: ["1"])
        update.plan = MediaGridPhotoLibraryFiller(store: store, retryRegistryURL: nil).filler.makePlan(for: update.catalog)
        dataSource.apply(update)
        XCTAssertNil(dataSource.filler)
        XCTAssertEqual(dataSource.planInstallCount, 0)
        XCTAssertEqual(dataSource.catalogCount, 1)
        dataSource.prepareThumbnails(ranges: [0 ..< 1])
        XCTAssertNil(dataSource.thumbnail(at: 0))
    }

    private func update(previous: PHFetchResult<PHAsset>, changes: MediaGridChanges?, invalidatesAll: Bool = false, changed: [String] = []) -> MediaGridPhotoLibraryDataSource.LibraryUpdate {
        return MediaGridPhotoLibraryDataSource.LibraryUpdate(previous: previous, fetchResult: PHFetchResult<PHAsset>(), changes: changes, invalidatesAll: invalidatesAll, changedIdentifiers: changed, removedIdentifiers: [])
    }

    func testChangesWithUnchangedVersionAreDropped() {
        let previous = ThumbnailCatalog(ids: ["a", "b", "c", "d"], versions: ["1", "1", "1", "1"])
        let changes = MediaGridChanges(removed: [3], inserted: [0], changed: [1, 3])
        let filtered = MediaGridPhotoLibraryDataSource.droppingUnversionedChanges(changes, changedIdentifiers: ["a", "c"], newVersions: ["a": "1", "c": "2"], previous: previous)
        XCTAssertEqual(filtered.changes.changed, [3])
        XCTAssertEqual(filtered.changes.removed, [3])
        XCTAssertEqual(filtered.changes.inserted, [0])
        XCTAssertEqual(filtered.changedIdentifiers, ["c"])
        let availability = MediaGridPhotoLibraryDataSource.droppingUnversionedChanges(MediaGridChanges(removed: [], inserted: [], changed: [2]), changedIdentifiers: ["c"], newVersions: ["c": "1"], previous: previous)
        XCTAssertTrue(availability.changes.isEmpty)
        XCTAssertTrue(availability.changedIdentifiers.isEmpty)
    }

    func testAvailabilityOnlyUpdateSwapsWithoutNotifying() {
        let initial = PHFetchResult<PHAsset>()
        let dataSource = self.makeDataSource(initial)
        var received: [MediaGridChanges?] = []
        dataSource.onChange = { received.append($0) }
        var update = self.update(previous: initial, changes: MediaGridChanges(removed: [], inserted: [], changed: []))
        update.isAvailabilityOnly = true
        dataSource.apply(update)
        XCTAssertTrue(received.isEmpty)
        dataSource.apply(self.update(previous: update.fetchResult, changes: MediaGridChanges(removed: [], inserted: [], changed: []), changed: ["a"]))
        XCTAssertEqual(received.count, 1)
        XCTAssertNotNil(received[0] ?? nil)
    }

    func testAvailabilityOnlyUpdateSkipsPlanInstall() {
        let initial = PHFetchResult<PHAsset>()
        let dataSource = self.makeDataSource(initial)
        var update = self.update(previous: initial, changes: MediaGridChanges(removed: [], inserted: [], changed: []))
        update.isAvailabilityOnly = true
        update.availabilityIdentifiers = ["a"]
        update.plan = dataSource.filler?.filler.makePlan(for: ThumbnailCatalog(ids: ["a"], versions: ["1"]))
        dataSource.apply(update)
        XCTAssertEqual(dataSource.planInstallCount, 0)
        XCTAssertEqual(dataSource.catalog.count, 0)
    }

    func testCatalogInstallPostsOnlyNewAndMismatchedSnapshotIndices() {
        let dataSource = self.makeDataSource(PHFetchResult<PHAsset>())
        var posted: [IndexSet] = []
        dataSource.onThumbnailsChanged = { posted.append($0) }
        dataSource.installLaunchSnapshot(ThumbnailLaunchSnapshot(count: 6, segments: [ThumbnailLaunchSnapshot.Segment(start: 0, ids: ["a", "b", "x"]), ThumbnailLaunchSnapshot.Segment(start: 5, ids: ["f"])]))
        XCTAssertEqual(posted, [IndexSet([0, 1, 2, 5])])
        XCTAssertEqual(dataSource.debugId(at: 5), "f")
        posted = []
        dataSource.installCatalog(ThumbnailCatalog(ids: ["a", "b", "c", "d"], versions: ["1", "1", "1", "1"]), generation: 0)
        XCTAssertEqual(posted, [IndexSet([2, 3])])
        XCTAssertEqual(dataSource.debugId(at: 5), "f")
        posted = []
        dataSource.installCatalog(ThumbnailCatalog(ids: ["a", "b", "c", "d", "e", "g"], versions: ["1", "1", "1", "1", "1", "1"]), generation: 1)
        XCTAssertEqual(posted, [IndexSet([4, 5])])
        XCTAssertEqual(dataSource.debugId(at: 5), "g")
    }

    func testConsecutiveUpdateAppliesIncrementally() {
        let initial = PHFetchResult<PHAsset>()
        let dataSource = self.makeDataSource(initial)
        var received: [MediaGridChanges?] = []
        dataSource.onChange = { received.append($0) }
        let first = self.update(previous: initial, changes: MediaGridChanges(removed: [], inserted: [], changed: []), changed: ["a"])
        dataSource.apply(first)
        XCTAssertEqual(received.count, 1)
        XCTAssertNotNil(received[0])
        XCTAssertEqual(dataSource.imageRevision(for: "a"), 1)
        XCTAssertEqual(dataSource.imageRevision(for: "b"), 0)
        dataSource.apply(self.update(previous: first.fetchResult, changes: nil, changed: ["b"]))
        XCTAssertEqual(received.count, 2)
        XCTAssertNil(received[1] ?? nil)
        XCTAssertEqual(dataSource.imageRevision(for: "a"), 1)
        XCTAssertEqual(dataSource.imageRevision(for: "b"), 1)
    }

    func testOutOfOrderUpdateReloadsAndInvalidates() {
        let initial = PHFetchResult<PHAsset>()
        let dataSource = self.makeDataSource(initial)
        var received: [MediaGridChanges?] = []
        dataSource.onChange = { received.append($0) }
        dataSource.apply(self.update(previous: PHFetchResult<PHAsset>(), changes: MediaGridChanges(removed: [], inserted: [], changed: [])))
        XCTAssertEqual(received.count, 1)
        XCTAssertNil(received[0] ?? nil)
        XCTAssertEqual(dataSource.imageRevision(for: "a"), 1)
        let full = self.makeDataSource(initial)
        full.apply(self.update(previous: initial, changes: nil, invalidatesAll: true))
        XCTAssertEqual(full.imageRevision(for: "a"), 1)
    }

    private func spin(timeout: TimeInterval = 5.0, until condition: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
        }
    }

    private func keys(_ ids: [String], version: String = "1") -> [MediaGridLaunchCache.Key] {
        return ids.map { MediaGridLaunchCache.Key(id: $0, version: version) }
    }

    private static func makeImage(width: Int, height: Int, color: UIColor) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func makeStoredCache(ids: [String], capacity: Int = 3) -> MediaGridLaunchCache {
        let directory = self.makeDirectory()
        if !ids.isEmpty {
            let writer = MediaGridLaunchCache(directory: directory, capacity: capacity, pixelSize: 64)
            var delivered: [String: MediaGridLaunchCache.Delivered] = [:]
            for id in ids {
                delivered[id] = MediaGridLaunchCache.Delivered(version: "1", image: MediaGridPhotoLibraryDataSourceTests.makeImage(width: 800, height: 600, color: .red))
            }
            let done = self.expectation(description: "update")
            writer.update(head: self.keys(ids), delivered: delivered, completion: { _ in
                done.fulfill()
            })
            self.wait(for: [done], timeout: 5.0)
        }
        return MediaGridLaunchCache(directory: directory, capacity: capacity, pixelSize: 64)
    }

    private func makeLibraryDataSource(cache: MediaGridLaunchCache, head: [MediaGridLaunchCache.Key], gate: DispatchSemaphore?) -> MediaGridPhotoLibraryDataSource {
        let match = MediaGridLaunchMatch(cache: cache, queue: DispatchQueue(label: "test.launchMatch"), readHead: {
            if let gate {
                _ = gate.wait(timeout: .now() + 5.0)
            }
            return head
        })
        return self.makeDataSource(PHFetchResult<PHAsset>(), launch: match)
    }

    func testMissingCacheFileDoesNotWaitForHeadRead() {
        let cache = self.makeStoredCache(ids: [])
        let gate = DispatchSemaphore(value: 0)
        let dataSource = self.makeLibraryDataSource(cache: cache, head: self.keys(["a", "b", "c"]), gate: gate)
        let start = CACurrentMediaTime()
        dataSource.waitForLaunchImages(timeout: 0.05)
        XCTAssertLessThan(CACurrentMediaTime() - start, 0.035)
        XCTAssertTrue(dataSource.isLaunchInstalled)
        XCTAssertNil(dataSource.launchImage(at: 0))
        XCTAssertEqual(dataSource.launchKeeper?.head, [])
        gate.signal()
        self.spin(until: { dataSource.launchKeeper?.head.isEmpty == false })
        XCTAssertEqual(dataSource.launchKeeper?.head, self.keys(["a", "b", "c"]))
    }

    func testTimedOutLaunchMatchInstallsLaterAndPostsIndices() {
        let cache = self.makeStoredCache(ids: ["a", "b", "c"])
        let gate = DispatchSemaphore(value: 0)
        let dataSource = self.makeLibraryDataSource(cache: cache, head: self.keys(["a", "b", "c"]), gate: gate)
        var posted: [IndexSet] = []
        dataSource.onThumbnailsChanged = { posted.append($0) }
        dataSource.waitForLaunchImages(timeout: 0.05)
        XCTAssertFalse(dataSource.isLaunchInstalled)
        XCTAssertNil(dataSource.launchImage(at: 0))
        gate.signal()
        self.spin(until: { !posted.isEmpty })
        XCTAssertEqual(posted, [IndexSet([0, 1, 2])])
        XCTAssertNotNil(dataSource.launchImage(at: 1))
    }

    func testLaunchMatchForReplacedFetchResultRematchesFromCatalog() {
        let cache = self.makeStoredCache(ids: ["a", "b", "c"])
        let gate = DispatchSemaphore(value: 0)
        let initial = PHFetchResult<PHAsset>()
        let match = MediaGridLaunchMatch(cache: cache, queue: DispatchQueue(label: "test.launchMatch"), readHead: {
            _ = gate.wait(timeout: .now() + 5.0)
            return self.keys(["a", "b", "c"])
        })
        let dataSource = self.makeDataSource(initial, launch: match)
        var update = MediaGridPhotoLibraryDataSource.LibraryUpdate(previous: initial, fetchResult: PHFetchResult<PHAsset>(), changes: MediaGridChanges(removed: [], inserted: [], changed: []), invalidatesAll: false, changedIdentifiers: [], removedIdentifiers: [])
        update.catalog = ThumbnailCatalog(ids: ["x", "a", "b"], versions: ["1", "1", "1"])
        update.catalogGeneration = 5
        dataSource.apply(update)
        gate.signal()
        self.spin(until: { dataSource.isLaunchInstalled })
        XCTAssertEqual(dataSource.launchKeeper?.head, self.keys(["x", "a", "b"]))
        XCTAssertNil(dataSource.launchImage(at: 0))
        XCTAssertTrue(dataSource.launchImage(at: 1)?.image === cache.image(for: "a", version: "1"))
        XCTAssertTrue(dataSource.launchImage(at: 2)?.image === cache.image(for: "b", version: "1"))
    }

    func testPartialCatalogPrefixDoesNotReplaceHead() {
        let cache = self.makeStoredCache(ids: ["a", "b", "c"])
        let dataSource = self.makeLibraryDataSource(cache: cache, head: self.keys(["a", "b", "c"]), gate: nil)
        dataSource.waitForLaunchImages(timeout: 2.0)
        XCTAssertTrue(dataSource.isLaunchInstalled)
        XCTAssertEqual(dataSource.launchKeeper?.images.count, 3)
        dataSource.installCatalog(ThumbnailCatalog(ids: ["x", "a"], versions: ["1", "1"]), generation: 0)
        XCTAssertEqual(dataSource.launchKeeper?.head, self.keys(["a", "b", "c"]))
        XCTAssertEqual(dataSource.launchKeeper?.images.count, 3)
        dataSource.installCatalog(ThumbnailCatalog(ids: ["x", "a"], versions: ["1", "1"]), generation: 1)
        XCTAssertEqual(dataSource.launchKeeper?.head, self.keys(["x", "a"]))
        XCTAssertEqual(Set(dataSource.launchKeeper?.images.keys.map { $0 } ?? []), [1])
    }

    func testServicesUseInjectedDirectories() {
        let directory = self.makeDirectory()
        let launchDirectory = directory.appendingPathComponent("launch", isDirectory: true)
        let services = MediaGridPhotoLibraryServices(directory: directory, launchDirectory: launchDirectory, retryRegistryURL: nil, snapshotURL: nil, launchCoverage: {
            return MediaGridLaunchCache.Coverage(capacity: 3, pixelSize: 64)
        })
        XCTAssertEqual(services.launchCache.capacity, 3)
        XCTAssertTrue(services.launchCache === services.launchCache)
        let library = services.makeDataSource(fetchResult: PHFetchResult<PHAsset>(), reversed: true, isLibrary: true)
        XCTAssertTrue(library.filler === services.filler)
        XCTAssertTrue(library.store === services.store)
        XCTAssertNotNil(library.launchKeeper)
        let album = services.makeDataSource(fetchResult: PHFetchResult<PHAsset>(), reversed: false, isLibrary: false)
        XCTAssertNil(album.filler)
        XCTAssertNil(album.launchKeeper)
        XCTAssertFalse(album.reversed)
        XCTAssertTrue(album.store === services.store)
    }

    func testLaunchCoverageIsInjectableUntilTheCacheExists() {
        let directory = self.makeDirectory()
        let services = MediaGridPhotoLibraryServices(directory: directory, launchDirectory: directory.appendingPathComponent("launch", isDirectory: true), retryRegistryURL: nil, snapshotURL: nil)
        XCTAssertTrue(services.configureLaunchCoverage {
            return MediaGridLaunchCache.Coverage(capacity: 5, pixelSize: 80)
        })
        XCTAssertEqual(services.launchCache.capacity, 5)
        XCTAssertFalse(services.configureLaunchCoverage {
            return MediaGridLaunchCache.Coverage(capacity: 7, pixelSize: 80)
        })
        XCTAssertEqual(services.launchCache.capacity, 5)
    }

    func testDefaultFileNamesAreNeutral() {
        XCTAssertEqual(MediaGridPhotoLibraryServices.defaultRetryRegistryURL.lastPathComponent, "MediaGridThumbnailRetries.plist")
        XCTAssertEqual(MediaGridPhotoLibraryServices.defaultSnapshotURL.lastPathComponent, "MediaGridLaunchSnapshot.plist")
    }

    func testOnlyTheLatestDataSourceOwnsTheStoreHook() {
        let store = MediaGridThumbnailStore(directory: nil)
        weak var weakFirst: MediaGridPhotoLibraryDataSource?
        weak var weakSecond: MediaGridPhotoLibraryDataSource?
        autoreleasepool {
            let first = MediaGridPhotoLibraryDataSource(fetchResult: PHFetchResult<PHAsset>(), reversed: true, store: store, launch: nil)
            weakFirst = first
            XCTAssertNotNil(store.onThumbnailsChanged)
            let second = MediaGridPhotoLibraryDataSource(fetchResult: PHFetchResult<PHAsset>(), reversed: false, store: store, launch: nil)
            weakSecond = second
            XCTAssertTrue(store.hookOwner === second)
        }
        let deadline = Date(timeIntervalSinceNow: 2.0)
        while (weakFirst != nil || weakSecond != nil) && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertNil(weakFirst)
        XCTAssertNil(weakSecond)
        XCTAssertNil(store.hookOwner)
        XCTAssertNil(store.onThumbnailsChanged)
    }
}
