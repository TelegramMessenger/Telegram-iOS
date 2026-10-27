import XCTest
import CoreGraphics

final class MediaGridPaneDecisionsTests: XCTestCase {
    func testStoredLevelMapping() {
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: nil), 3)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 2), 3)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 3), 3)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 4), 5)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 7), 5)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 8), 15)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 12), 15)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 15), 15)
    }

    func testPreviewWidths() {
        XCTAssertEqual(mediaGridPanePreviewWidths, [64, 150, 200, 280])
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 30.0), 64)
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 50.0), 64)
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 51.0), 150)
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 100.0), 150)
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 140.0), 200)
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 141.0), 280)
    }

    func testHoleToLoadNilWhenAllLoaded() {
        let holes = [MediaGridPaneHole(anchorIndex: 0), MediaGridPaneHole(anchorIndex: 100)]
        XCTAssertNil(mediaGridPaneHoleToLoad(visible: 10 ..< 30, isLoaded: { _ in true }, holes: holes))
    }

    func testHoleToLoadNilWithoutHoles() {
        XCTAssertNil(mediaGridPaneHoleToLoad(visible: 10 ..< 30, isLoaded: { _ in false }, holes: []))
    }

    func testHoleToLoadPicksNearestToFirstEmpty() {
        let holes = [MediaGridPaneHole(anchorIndex: 0), MediaGridPaneHole(anchorIndex: 35), MediaGridPaneHole(anchorIndex: 100)]
        let hole = mediaGridPaneHoleToLoad(visible: 20 ..< 60, isLoaded: { $0 < 40 }, holes: holes)
        XCTAssertEqual(hole?.anchorIndex, 35)
    }

    func testHoleToLoadTiePrefersUpper() {
        let holes = [MediaGridPaneHole(anchorIndex: 50), MediaGridPaneHole(anchorIndex: 30)]
        let hole = mediaGridPaneHoleToLoad(visible: 40 ..< 60, isLoaded: { _ in false }, holes: holes)
        XCTAssertEqual(hole?.anchorIndex, 50)
    }

    func testDateIndexUsesLowerAnchor() {
        let anchors: [(index: Int, timestamp: Int32)] = [(10, 1000), (50, 500), (90, 100)]
        XCTAssertEqual(mediaGridPaneDateIndex(at: 60, anchors: anchors), 500)
        XCTAssertEqual(mediaGridPaneDateIndex(at: 50, anchors: anchors), 500)
        XCTAssertEqual(mediaGridPaneDateIndex(at: 95, anchors: anchors), 100)
    }

    func testDateIndexBeforeFirstUsesFirst() {
        let anchors: [(index: Int, timestamp: Int32)] = [(10, 1000), (50, 500)]
        XCTAssertEqual(mediaGridPaneDateIndex(at: 3, anchors: anchors), 1000)
    }

    func testDateIndexEmpty() {
        XCTAssertNil(mediaGridPaneDateIndex(at: 3, anchors: []))
    }
}
