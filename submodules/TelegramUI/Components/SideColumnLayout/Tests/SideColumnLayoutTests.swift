import XCTest
import UIKit
import SideColumnLayout

final class SideColumnLayoutTests: XCTestCase {
    // Root list buttons in order: compose (3), story (1), proxy (2).
    private let rootPriorities: [Int?] = [3, 1, 2]

    func test_threeItems_fit_132() {
        let result = sideColumnItemsLayout(regionLength: 234.0, hasBack: false, priorities: self.rootPriorities)
        XCTAssertEqual(result, SideColumnItemsLayout(
            backFrame: nil,
            capsuleFrame: CGRect(x: 0.0, y: 0.0, width: 48.0, height: 132.0),
            cellFrames: [
                CGRect(x: 0.0, y: 0.0, width: 48.0, height: 44.0),
                CGRect(x: 0.0, y: 44.0, width: 48.0, height: 44.0),
                CGRect(x: 0.0, y: 88.0, width: 48.0, height: 44.0)
            ],
            visibleItems: [0, 1, 2],
            overflowItems: []
        ))
    }

    func test_oneItem_isACircle() {
        let result = sideColumnItemsLayout(regionLength: 100.0, hasBack: false, priorities: [nil])
        XCTAssertEqual(result?.capsuleFrame, CGRect(x: 0.0, y: 0.0, width: 48.0, height: 48.0))
        XCTAssertEqual(result?.cellFrames, [CGRect(x: 0.0, y: 2.0, width: 48.0, height: 44.0)])
    }

    func test_twoItems_88() {
        let result = sideColumnItemsLayout(regionLength: 124.0, hasBack: false, priorities: [3, 1])
        XCTAssertEqual(result?.capsuleFrame, CGRect(x: 0.0, y: 0.0, width: 48.0, height: 88.0))
        XCTAssertEqual(result?.visibleItems, [0, 1])
        XCTAssertEqual(result?.overflowItems, [])
    }

    func test_back_capsule12Below() {
        let result = sideColumnItemsLayout(regionLength: 478.0, hasBack: true, priorities: [nil])
        XCTAssertEqual(result?.backFrame, CGRect(x: 0.0, y: 0.0, width: 48.0, height: 48.0))
        XCTAssertEqual(result?.capsuleFrame, CGRect(x: 0.0, y: 60.0, width: 48.0, height: 48.0))
        XCTAssertEqual(result?.cellFrames, [CGRect(x: 0.0, y: 2.0, width: 48.0, height: 44.0)])
    }

    // Overflow (the folded landscapes: 2 slots).

    func test_overflow_threeInTwoSlots_keepsComposeThenEllipsis() {
        let result = sideColumnItemsLayout(regionLength: 124.0, hasBack: false, priorities: self.rootPriorities)
        XCTAssertEqual(result, SideColumnItemsLayout(
            backFrame: nil,
            capsuleFrame: CGRect(x: 0.0, y: 0.0, width: 48.0, height: 88.0),
            cellFrames: [
                CGRect(x: 0.0, y: 0.0, width: 48.0, height: 44.0),
                CGRect(x: 0.0, y: 44.0, width: 48.0, height: 44.0)
            ],
            visibleItems: [0],
            overflowItems: [1, 2]
        ))
    }

    func test_overflow_tiesKeepTheOriginalOrder() {
        let result = sideColumnItemsLayout(regionLength: 124.0, hasBack: false, priorities: [1, 1, 1])
        XCTAssertEqual(result?.visibleItems, [0])
        XCTAssertEqual(result?.overflowItems, [1, 2])
    }

    func test_overflow_laterItemWithHigherPriorityStays() {
        let result = sideColumnItemsLayout(regionLength: 124.0, hasBack: false, priorities: [1, 5, 3])
        XCTAssertEqual(result?.visibleItems, [1])
        XCTAssertEqual(result?.overflowItems, [0, 2])
    }

    func test_oneSlot_severalItems_ellipsisAlone() {
        let result = sideColumnItemsLayout(regionLength: 60.0, hasBack: false, priorities: [3, 1])
        XCTAssertEqual(result, SideColumnItemsLayout(
            backFrame: nil,
            capsuleFrame: CGRect(x: 0.0, y: 0.0, width: 48.0, height: 48.0),
            cellFrames: [CGRect(x: 0.0, y: 2.0, width: 48.0, height: 44.0)],
            visibleItems: [],
            overflowItems: [0, 1]
        ))
    }

    func test_neverOverflowingItemsExceedTheSlots_nil() {
        XCTAssertNil(sideColumnItemsLayout(regionLength: 60.0, hasBack: false, priorities: [nil, 1]))
    }

    func test_noSlotForTheItems_nil() {
        // 100 - 60 = 40pt below the back circle.
        XCTAssertNil(sideColumnItemsLayout(regionLength: 100.0, hasBack: true, priorities: [nil]))
    }

    func test_noItems_backOnly() {
        let result = sideColumnItemsLayout(regionLength: 100.0, hasBack: true, priorities: [])
        XCTAssertEqual(result, SideColumnItemsLayout(backFrame: CGRect(x: 0.0, y: 0.0, width: 48.0, height: 48.0), capsuleFrame: nil, cellFrames: [], visibleItems: [], overflowItems: []))
    }

    func test_noItems_noBack_nil() {
        XCTAssertNil(sideColumnItemsLayout(regionLength: 100.0, hasBack: false, priorities: []))
    }

    func test_overflow_neverOverflowingItemStaysBesideTheHighestPriority() {
        // 132pt: 3 slots; 4 items: keep 2 — the nil-priority item, then the highest priority (index 2).
        let result = sideColumnItemsLayout(regionLength: 132.0, hasBack: false, priorities: [1, nil, 3, 2])
        XCTAssertEqual(result?.visibleItems, [1, 2])
        XCTAssertEqual(result?.overflowItems, [0, 3])
        XCTAssertEqual(result?.capsuleFrame, CGRect(x: 0.0, y: 0.0, width: 48.0, height: 132.0))
    }

    func test_back_overflowingCapsuleBelowTheCircle() {
        // 148 - 60 = 88pt below the back circle: 2 slots for 3 items.
        let result = sideColumnItemsLayout(regionLength: 148.0, hasBack: true, priorities: [3, 1, 2])
        XCTAssertEqual(result, SideColumnItemsLayout(
            backFrame: CGRect(x: 0.0, y: 0.0, width: 48.0, height: 48.0),
            capsuleFrame: CGRect(x: 0.0, y: 60.0, width: 48.0, height: 88.0),
            cellFrames: [
                CGRect(x: 0.0, y: 0.0, width: 48.0, height: 44.0),
                CGRect(x: 0.0, y: 44.0, width: 48.0, height: 44.0)
            ],
            visibleItems: [0],
            overflowItems: [1, 2]
        ))
    }

    // The profile's buttons never overflow: two fit two slots, three fall back (nil).

    func test_neverOverflowingItems_twoInTwoSlots_fit() {
        let result = sideColumnItemsLayout(regionLength: 124.0, hasBack: false, priorities: [nil, nil])
        XCTAssertEqual(result?.capsuleFrame, CGRect(x: 0.0, y: 0.0, width: 48.0, height: 88.0))
        XCTAssertEqual(result?.visibleItems, [0, 1])
        XCTAssertEqual(result?.overflowItems, [])
    }

    func test_neverOverflowingItems_threeInTwoSlots_nil() {
        XCTAssertNil(sideColumnItemsLayout(regionLength: 124.0, hasBack: false, priorities: [nil, nil, nil]))
    }
}
