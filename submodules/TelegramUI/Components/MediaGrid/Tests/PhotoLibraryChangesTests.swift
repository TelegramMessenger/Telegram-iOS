import XCTest
import MediaGrid
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
}
