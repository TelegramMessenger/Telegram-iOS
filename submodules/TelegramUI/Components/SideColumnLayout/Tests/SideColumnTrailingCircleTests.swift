import XCTest
import UIKit
import SideColumnLayout

/// The accent checkmark's circle below the back circle and the capsule (ItemList spec, section 1.2).
final class SideColumnTrailingCircleTests: XCTestCase {
    func test_backCapsuleAndCircle() {
        let result = sideColumnItemsLayout(regionLength: 478.0, hasBack: true, priorities: [nil], hasTrailingCircle: true)
        XCTAssertEqual(result?.backFrame, CGRect(x: 0.0, y: 0.0, width: 48.0, height: 48.0))
        XCTAssertEqual(result?.capsuleFrame, CGRect(x: 0.0, y: 60.0, width: 48.0, height: 48.0))
        XCTAssertEqual(result?.trailingFrame, CGRect(x: 0.0, y: 120.0, width: 48.0, height: 48.0))
    }

    func test_backAndCircle_108Fits() {
        let result = sideColumnItemsLayout(regionLength: 108.0, hasBack: true, priorities: [], hasTrailingCircle: true)
        XCTAssertNil(result?.capsuleFrame)
        XCTAssertEqual(result?.trailingFrame, CGRect(x: 0.0, y: 60.0, width: 48.0, height: 48.0))
    }

    func test_backAndCircle_107_nil() {
        XCTAssertNil(sideColumnItemsLayout(regionLength: 107.0, hasBack: true, priorities: [], hasTrailingCircle: true))
    }

    func test_circleAlone() {
        let result = sideColumnItemsLayout(regionLength: 48.0, hasBack: false, priorities: [], hasTrailingCircle: true)
        XCTAssertEqual(result, SideColumnItemsLayout(backFrame: nil, capsuleFrame: nil, cellFrames: [], visibleItems: [], overflowItems: [], trailingFrame: CGRect(x: 0.0, y: 0.0, width: 48.0, height: 48.0)))
    }

    func test_twoCellsAndCircle_148FitsExactly() {
        let result = sideColumnItemsLayout(regionLength: 148.0, hasBack: false, priorities: [nil, nil], hasTrailingCircle: true)
        XCTAssertEqual(result?.capsuleFrame, CGRect(x: 0.0, y: 0.0, width: 48.0, height: 88.0))
        XCTAssertEqual(result?.trailingFrame, CGRect(x: 0.0, y: 100.0, width: 48.0, height: 48.0))
    }

    func test_twoCellsAndCircle_147_nil() {
        // The circle never overflows: the capsule only has the room above it, which holds one cell.
        XCTAssertNil(sideColumnItemsLayout(regionLength: 147.0, hasBack: false, priorities: [nil, nil], hasTrailingCircle: true))
    }

    func test_withoutTheCircle_unchanged() {
        let result = sideColumnItemsLayout(regionLength: 478.0, hasBack: true, priorities: [nil])
        XCTAssertNil(result?.trailingFrame)
        XCTAssertEqual(result?.capsuleFrame, CGRect(x: 0.0, y: 60.0, width: 48.0, height: 48.0))
    }
}
