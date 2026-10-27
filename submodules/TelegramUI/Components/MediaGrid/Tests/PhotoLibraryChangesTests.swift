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

    func testConsecutiveUpdateAppliesIncrementally() {
        let initial = PHFetchResult<PHAsset>()
        let dataSource = PhotoLibraryDataSource(fetchResult: initial)
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
        let dataSource = PhotoLibraryDataSource(fetchResult: initial)
        var received: [MediaGridChanges?] = []
        dataSource.onChange = { received.append($0) }
        dataSource.apply(self.update(previous: PHFetchResult<PHAsset>(), changes: MediaGridChanges(removed: [], inserted: [], changed: [])))
        XCTAssertEqual(received.count, 1)
        XCTAssertNil(received[0] ?? nil)
        XCTAssertEqual(dataSource.imageRevision(for: "a"), 1)
        let full = PhotoLibraryDataSource(fetchResult: initial)
        full.apply(self.update(previous: initial, changes: nil, invalidatesAll: true))
        XCTAssertEqual(full.imageRevision(for: "a"), 1)
    }
}
