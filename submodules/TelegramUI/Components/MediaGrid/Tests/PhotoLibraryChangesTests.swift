import XCTest
import MediaGrid
import Photos
@testable import MediaGridDemo

final class PhotoLibraryChangesTests: XCTestCase {
    func testFetchChangesReverseToNewestFirst() {
        let changes = PhotoLibraryDataSource.gridChanges(removed: [0, 1], inserted: [8, 9], changed: [3], oldCount: 10, newCount: 10)
        XCTAssertEqual(changes.removed, [8, 9])
        XCTAssertEqual(changes.inserted, [0, 1])
        XCTAssertEqual(changes.changed, [6])
        XCTAssertTrue(changes.isValid(oldCount: 10, newCount: 10))
    }

    func testFetchChangesWithCountChange() {
        let changes = PhotoLibraryDataSource.gridChanges(removed: [4], inserted: [9, 10, 11], changed: [], oldCount: 10, newCount: 12)
        XCTAssertEqual(changes.removed, [5])
        XCTAssertEqual(changes.inserted, [0, 1, 2])
        XCTAssertTrue(changes.isValid(oldCount: 10, newCount: 12))
    }

    private func update(previous: PHFetchResult<PHAsset>, changes: MediaGridChanges?, invalidatesAll: Bool = false, changed: [String] = []) -> PhotoLibraryDataSource.LibraryUpdate {
        return PhotoLibraryDataSource.LibraryUpdate(previous: previous, fetchResult: PHFetchResult<PHAsset>(), changes: changes, invalidatesAll: invalidatesAll, changedIdentifiers: changed, removedIdentifiers: [])
    }

    func testChangesWithUnchangedVersionAreDropped() {
        let previous = ThumbnailCatalog(ids: ["a", "b", "c", "d"], versions: ["1", "1", "1", "1"])
        let changes = MediaGridChanges(removed: [3], inserted: [0], changed: [1, 3])
        let filtered = PhotoLibraryDataSource.droppingUnversionedChanges(changes, changedIdentifiers: ["a", "c"], newVersions: ["a": "1", "c": "2"], previous: previous)
        XCTAssertEqual(filtered.changes.changed, [3])
        XCTAssertEqual(filtered.changes.removed, [3])
        XCTAssertEqual(filtered.changes.inserted, [0])
        XCTAssertEqual(filtered.changedIdentifiers, ["c"])
        let availability = PhotoLibraryDataSource.droppingUnversionedChanges(MediaGridChanges(removed: [], inserted: [], changed: [2]), changedIdentifiers: ["c"], newVersions: ["c": "1"], previous: previous)
        XCTAssertTrue(availability.changes.isEmpty)
        XCTAssertTrue(availability.changedIdentifiers.isEmpty)
    }

    func testAvailabilityOnlyUpdateSwapsWithoutNotifying() {
        let initial = PHFetchResult<PHAsset>()
        let dataSource = PhotoLibraryDataSource(fetchResult: initial, thumbnailDirectory: nil, registryURL: nil, snapshotURL: nil)
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
        let dataSource = PhotoLibraryDataSource(fetchResult: initial, thumbnailDirectory: nil, registryURL: nil, snapshotURL: nil)
        var update = self.update(previous: initial, changes: MediaGridChanges(removed: [], inserted: [], changed: []))
        update.isAvailabilityOnly = true
        update.availabilityIdentifiers = ["a"]
        update.plan = dataSource.filler.makePlan(for: ThumbnailCatalog(ids: ["a"], versions: ["1"]))
        dataSource.apply(update)
        XCTAssertEqual(dataSource.planInstallCount, 0)
        XCTAssertEqual(dataSource.catalog.count, 0)
    }

    func testCatalogInstallPostsOnlyNewAndMismatchedSnapshotIndices() {
        let dataSource = PhotoLibraryDataSource(fetchResult: PHFetchResult<PHAsset>(), thumbnailDirectory: nil, registryURL: nil, snapshotURL: nil)
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
        let dataSource = PhotoLibraryDataSource(fetchResult: initial, thumbnailDirectory: nil, registryURL: nil, snapshotURL: nil)
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
        let dataSource = PhotoLibraryDataSource(fetchResult: initial, thumbnailDirectory: nil, registryURL: nil, snapshotURL: nil)
        var received: [MediaGridChanges?] = []
        dataSource.onChange = { received.append($0) }
        dataSource.apply(self.update(previous: PHFetchResult<PHAsset>(), changes: MediaGridChanges(removed: [], inserted: [], changed: [])))
        XCTAssertEqual(received.count, 1)
        XCTAssertNil(received[0] ?? nil)
        XCTAssertEqual(dataSource.imageRevision(for: "a"), 1)
        let full = PhotoLibraryDataSource(fetchResult: initial, thumbnailDirectory: nil, registryURL: nil, snapshotURL: nil)
        full.apply(self.update(previous: initial, changes: nil, invalidatesAll: true))
        XCTAssertEqual(full.imageRevision(for: "a"), 1)
    }
}
