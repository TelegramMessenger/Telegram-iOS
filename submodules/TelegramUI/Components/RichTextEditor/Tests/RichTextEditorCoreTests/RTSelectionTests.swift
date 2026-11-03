import XCTest
@testable import RichTextEditorCore

final class RTSelectionTests: XCTestCase {
    func test_range_fromToAreOrderedRegardlessOfAnchorHead() {
        let forward = RTSelection.range(anchor: 2, head: 7)
        let backward = RTSelection.range(anchor: 7, head: 2)
        XCTAssertEqual(forward.from, 2); XCTAssertEqual(forward.to, 7)
        XCTAssertEqual(backward.from, 2); XCTAssertEqual(backward.to, 7)
    }

    func test_caret_isCollapsedWhenAnchorEqualsHead() {
        XCTAssertTrue(RTSelection.range(anchor: 3, head: 3).isCollapsed)
        XCTAssertFalse(RTSelection.range(anchor: 3, head: 4).isCollapsed)
    }

    func test_gap_reportsItsPositionAsFromAndTo() {
        let g = RTSelection.gap(5)
        XCTAssertEqual(g.from, 5); XCTAssertEqual(g.to, 5)
        XCTAssertTrue(g.isCollapsed)
    }
}
