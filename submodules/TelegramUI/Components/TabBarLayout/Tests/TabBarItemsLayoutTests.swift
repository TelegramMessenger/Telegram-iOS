import XCTest
import UIKit
import Display
import TabBarLayout

final class TabBarItemsLayoutTests: XCTestCase {
    // Horizontal regular: today's algorithm, pinned before TabBarComponent switches to it.

    func test_horizontalRegular_equalLengthsWhenEveryItemFits() {
        // 500 - 8 = 492 over four items = 123 each; every unbound width is <= 123.
        let result = tabBarItemsLayout(axis: .horizontal, isCompact: false, unboundItemWidths: [60.0, 70.0, 80.0, 90.0], availableLength: 500.0)
        XCTAssertEqual(result.size, CGSize(width: 500.0, height: 64.0))
        XCTAssertEqual(result.itemFrames, [
            CGRect(x: 4.0, y: 4.0, width: 123.0, height: 56.0),
            CGRect(x: 127.0, y: 4.0, width: 123.0, height: 56.0),
            CGRect(x: 250.0, y: 4.0, width: 123.0, height: 56.0),
            CGRect(x: 373.0, y: 4.0, width: 123.0, height: 56.0)
        ])
    }

    func test_horizontalRegular_weightedLengthsWhenAnItemDoesNotFit() {
        // 400 - 8 = 392; 392 > 392 / 3, so weights apply: 392 / 784 = 0.5 of each unbound width.
        let result = tabBarItemsLayout(axis: .horizontal, isCompact: false, unboundItemWidths: [98.0, 392.0, 294.0], availableLength: 400.0)
        XCTAssertEqual(result.size, CGSize(width: 400.0, height: 64.0))
        XCTAssertEqual(result.itemFrames, [
            CGRect(x: 4.0, y: 4.0, width: 49.0, height: 56.0),
            CGRect(x: 53.0, y: 4.0, width: 196.0, height: 56.0),
            CGRect(x: 249.0, y: 4.0, width: 147.0, height: 56.0)
        ])
    }

    func test_horizontalRegular_noItems_insetsOnly() {
        let result = tabBarItemsLayout(axis: .horizontal, isCompact: false, unboundItemWidths: [], availableLength: 500.0)
        XCTAssertEqual(result.size, CGSize(width: 8.0, height: 64.0))
        XCTAssertEqual(result.itemFrames, [])
    }

    // Every other mode: 56pt per item, the bar hugs its items, widths and available length unused.

    func test_verticalCompact_fourItems_48x232() {
        let result = tabBarItemsLayout(axis: .vertical, isCompact: true, unboundItemWidths: [300.0, 10.0, 10.0, 10.0], availableLength: 1000.0)
        XCTAssertEqual(result.size, CGSize(width: 48.0, height: 232.0))
        XCTAssertEqual(result.itemFrames, [
            CGRect(x: 4.0, y: 4.0, width: 40.0, height: 56.0),
            CGRect(x: 4.0, y: 60.0, width: 40.0, height: 56.0),
            CGRect(x: 4.0, y: 116.0, width: 40.0, height: 56.0),
            CGRect(x: 4.0, y: 172.0, width: 40.0, height: 56.0)
        ])
    }

    func test_verticalRegular_fourItems_64x232() {
        let result = tabBarItemsLayout(axis: .vertical, isCompact: false, unboundItemWidths: [60.0, 70.0, 80.0, 90.0], availableLength: 1000.0)
        XCTAssertEqual(result.size, CGSize(width: 64.0, height: 232.0))
        XCTAssertEqual(result.itemFrames[2], CGRect(x: 4.0, y: 116.0, width: 56.0, height: 56.0))
    }

    func test_horizontalCompact_fourItems_232x48() {
        let result = tabBarItemsLayout(axis: .horizontal, isCompact: true, unboundItemWidths: [60.0, 70.0, 80.0, 90.0], availableLength: 1000.0)
        XCTAssertEqual(result.size, CGSize(width: 232.0, height: 48.0))
        XCTAssertEqual(result.itemFrames, [
            CGRect(x: 4.0, y: 4.0, width: 56.0, height: 40.0),
            CGRect(x: 60.0, y: 4.0, width: 56.0, height: 40.0),
            CGRect(x: 116.0, y: 4.0, width: 56.0, height: 40.0),
            CGRect(x: 172.0, y: 4.0, width: 56.0, height: 40.0)
        ])
    }

    // Horizontal compact: a bar that would hug its items within 60pt of the width available to it
    // takes the whole width instead, its items sharing it equally.

    func test_horizontalCompact_within60OfTheAvailableWidth_fillsIt() {
        // 280 - 232 = 48 < 60: (280 - 8) / 4 = 68 per item.
        let result = tabBarItemsLayout(axis: .horizontal, isCompact: true, unboundItemWidths: [60.0, 70.0, 80.0, 90.0], availableLength: 280.0)
        XCTAssertEqual(result.size, CGSize(width: 280.0, height: 48.0))
        XCTAssertEqual(result.itemFrames, [
            CGRect(x: 4.0, y: 4.0, width: 68.0, height: 40.0),
            CGRect(x: 72.0, y: 4.0, width: 68.0, height: 40.0),
            CGRect(x: 140.0, y: 4.0, width: 68.0, height: 40.0),
            CGRect(x: 208.0, y: 4.0, width: 68.0, height: 40.0)
        ])
    }

    func test_horizontalCompact_exactly60Short_hugsItsItems() {
        let result = tabBarItemsLayout(axis: .horizontal, isCompact: true, unboundItemWidths: [60.0, 70.0, 80.0, 90.0], availableLength: 292.0)
        XCTAssertEqual(result.size, CGSize(width: 232.0, height: 48.0))
    }

    func test_horizontalCompact_narrowerThanItsItems_fitsTheAvailableWidth() {
        // (200 - 8) / 4 = 48 per item.
        let result = tabBarItemsLayout(axis: .horizontal, isCompact: true, unboundItemWidths: [60.0, 70.0, 80.0, 90.0], availableLength: 200.0)
        XCTAssertEqual(result.size, CGSize(width: 200.0, height: 48.0))
        XCTAssertEqual(result.itemFrames[1], CGRect(x: 52.0, y: 4.0, width: 48.0, height: 40.0))
    }

    func test_verticalCompact_ignoresTheAvailableLength() {
        let result = tabBarItemsLayout(axis: .vertical, isCompact: true, unboundItemWidths: [60.0, 70.0, 80.0, 90.0], availableLength: 240.0)
        XCTAssertEqual(result.size, CGSize(width: 48.0, height: 232.0))
    }

    // The lens selection rect.

    func test_lens_horizontalSelectedItem_growsByTheInsetAlongTheAxis() {
        let frame = tabBarLensSelectionFrame(axis: .horizontal, barSize: CGSize(width: 500.0, height: 64.0), selectedItemFrame: CGRect(x: 127.0, y: 4.0, width: 123.0, height: 56.0), drag: nil)
        XCTAssertEqual(frame, CGRect(x: 123.0, y: 0.0, width: 131.0, height: 64.0))
    }

    func test_lens_horizontalNarrowItem_widenedTo1_2TimesItsHeight() {
        // 56 * 1.2 = 67.2; the item widens by floor((67.2 - 40) * -0.5) = -14 on each side: (86, 68).
        let frame = tabBarLensSelectionFrame(axis: .horizontal, barSize: CGSize(width: 300.0, height: 64.0), selectedItemFrame: CGRect(x: 100.0, y: 4.0, width: 40.0, height: 56.0), drag: nil)
        XCTAssertEqual(frame, CGRect(x: 82.0, y: 0.0, width: 76.0, height: 64.0))
    }

    func test_lens_verticalSelectedItem_fullThicknessAcross() {
        let frame = tabBarLensSelectionFrame(axis: .vertical, barSize: CGSize(width: 48.0, height: 232.0), selectedItemFrame: CGRect(x: 4.0, y: 116.0, width: 40.0, height: 56.0), drag: nil)
        XCTAssertEqual(frame, CGRect(x: 0.0, y: 112.0, width: 48.0, height: 64.0))
    }

    func test_lens_verticalNarrowItem_notWidened() {
        // The 1.2x widening is horizontal only: a compact vertical item is narrower than tall.
        let frame = tabBarLensSelectionFrame(axis: .vertical, barSize: CGSize(width: 48.0, height: 232.0), selectedItemFrame: CGRect(x: 4.0, y: 4.0, width: 40.0, height: 56.0), drag: nil)
        XCTAssertEqual(frame, CGRect(x: 0.0, y: 0.0, width: 48.0, height: 64.0))
    }

    func test_lens_verticalDragPastTheEnd_clampedToTheBar() {
        let frame = tabBarLensSelectionFrame(axis: .vertical, barSize: CGSize(width: 48.0, height: 232.0), selectedItemFrame: nil, drag: (origin: 200.0, itemLength: 56.0))
        XCTAssertEqual(frame, CGRect(x: 0.0, y: 168.0, width: 48.0, height: 64.0))
    }

    func test_lens_horizontalDrag_followsTheOrigin() {
        let frame = tabBarLensSelectionFrame(axis: .horizontal, barSize: CGSize(width: 500.0, height: 64.0), selectedItemFrame: CGRect(x: 4.0, y: 4.0, width: 123.0, height: 56.0), drag: (origin: 50.0, itemLength: 123.0))
        XCTAssertEqual(frame, CGRect(x: 50.0, y: 0.0, width: 131.0, height: 64.0))
    }

    func test_lens_noSelection_firstItemLengthAtTheStart() {
        XCTAssertEqual(tabBarLensSelectionFrame(axis: .horizontal, barSize: CGSize(width: 500.0, height: 64.0), selectedItemFrame: nil, drag: nil), CGRect(x: 0.0, y: 0.0, width: 56.0, height: 64.0))
        XCTAssertEqual(tabBarLensSelectionFrame(axis: .vertical, barSize: CGSize(width: 48.0, height: 232.0), selectedItemFrame: nil, drag: nil), CGRect(x: 0.0, y: 0.0, width: 48.0, height: 56.0))
    }

    // The item under a finger.

    private let verticalFrames = tabBarItemsLayout(axis: .vertical, isCompact: true, unboundItemWidths: [0.0, 0.0, 0.0, 0.0], availableLength: 0.0).itemFrames

    func test_itemIndex_insideAnItem_thatItem() {
        XCTAssertEqual(tabBarItemIndex(at: CGPoint(x: 20.0, y: 70.0), axis: .vertical, itemFrames: self.verticalFrames), 1)
    }

    func test_itemIndex_verticalOutsideEveryItem_nearestAlongY() {
        // x is outside every item; by y, 150 is nearest the third item's midpoint (144).
        XCTAssertEqual(tabBarItemIndex(at: CGPoint(x: 100.0, y: 150.0), axis: .vertical, itemFrames: self.verticalFrames), 2)
    }

    func test_itemIndex_horizontalOutsideEveryItem_nearestAlongX() {
        let frames = tabBarItemsLayout(axis: .horizontal, isCompact: true, unboundItemWidths: [0.0, 0.0, 0.0, 0.0], availableLength: 1000.0).itemFrames
        // y is outside every item; by x, 180 is nearest the fourth item's midpoint (200).
        XCTAssertEqual(tabBarItemIndex(at: CGPoint(x: 180.0, y: -30.0), axis: .horizontal, itemFrames: frames), 3)
    }

    func test_itemIndex_noItems_nil() {
        XCTAssertNil(tabBarItemIndex(at: CGPoint(x: 10.0, y: 10.0), axis: .vertical, itemFrames: []))
    }
}
