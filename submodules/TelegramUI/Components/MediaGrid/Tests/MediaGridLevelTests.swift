import XCTest
@testable import MediaGrid

final class MediaGridLevelTests: XCTestCase {
    func testColumns() {
        XCTAssertEqual(MediaGridLevel.allCases.map(\.columns), [1, 3, 5, 15, 31])
    }

    func testCapabilities() {
        XCTAssertEqual(MediaGridLevel.allCases.filter(\.isInteractive).map(\.columns), [1, 3, 5])
        XCTAssertEqual(MediaGridLevel.allCases.filter(\.showsCamera).map(\.columns), [3])
    }

    func testZoomSteps() {
        XCTAssertEqual(MediaGridLevel.thirtyOne.zoomedIn, .fifteen)
        XCTAssertEqual(MediaGridLevel.fifteen.zoomedIn, .five)
        XCTAssertNil(MediaGridLevel.one.zoomedIn)
        XCTAssertNil(MediaGridLevel.thirtyOne.zoomedOut)
        XCTAssertEqual(MediaGridLevel.three.zoomedOut, .five)
    }

    func testDefaults() {
        XCTAssertEqual(MediaGridLevel.defaultLevel(isLandscape: false), .three)
        XCTAssertEqual(MediaGridLevel.defaultLevel(isLandscape: true), .five)
    }

    func testRotation() {
        XCTAssertEqual(MediaGridLevel.allCases.map { $0.rotated(toLandscape: true).columns }, [3, 5, 15, 31, 31])
        XCTAssertEqual(MediaGridLevel.allCases.map { $0.rotated(toLandscape: false).columns }, [1, 1, 3, 5, 15])
    }
}
