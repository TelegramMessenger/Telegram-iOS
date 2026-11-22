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

    func test_itemIndex_insideOverlappingItems_nearestMidpoint() {
        // 89.67…99 is inside both the first (4…99) and the second (89.67…184.67) system item.
        let frames = self.systemLayout([44.666666666666664, 28.0, 28.666666666666668, 41.333333333333336], 360.0).itemFrames
        XCTAssertEqual(tabBarItemIndex(at: CGPoint(x: 92.0, y: 30.0), axis: .horizontal, itemFrames: frames), 0)
        XCTAssertEqual(tabBarItemIndex(at: CGPoint(x: 97.0, y: 30.0), axis: .horizontal, itemFrames: frames), 1)
    }

    // The system layout: UIKit's iOS 27 frames, read from a UITabBarController in the iOS 27 simulator at scale 3,
    // for the content widths `-[_UITabButton sizeThatFits:]` reported there.

    private func systemLayout(_ widths: [CGFloat], _ availableLength: CGFloat) -> TabBarItemsLayout {
        return tabBarSystemItemsLayout(fittedItemWidths: widths, availableLength: availableLength, hasAccessory: false, scale: 3.0)
    }

    private func assertFrames(_ layout: TabBarItemsLayout, size: CGSize, xAndWidths: [(CGFloat, CGFloat)], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(layout.size, size, file: file, line: line)
        XCTAssertEqual(layout.itemFrames.count, xAndWidths.count, file: file, line: line)
        for (frame, expected) in zip(layout.itemFrames, xAndWidths) {
            XCTAssertEqual(frame.minX, expected.0, accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(frame.width, expected.1, accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(frame.minY, 4.0, file: file, line: line)
            XCTAssertEqual(frame.height, 54.0, file: file, line: line)
        }
    }

    func test_system_fourItems_402Wide_equalAndOverlapping() {
        // Contacts, Calls, Chats, Settings on a 402pt screen: the bar is 402 - 2 * 21 = 360.
        self.assertFrames(self.systemLayout([44.666666666666664, 28.0, 28.666666666666668, 41.333333333333336], 360.0), size: CGSize(width: 360.0, height: 62.0), xAndWidths: [(4.0, 95.0), (89.6667, 95.0), (175.3333, 95.0), (261.0, 95.0)])
    }

    func test_system_fourItems_320Wide_proportional() {
        self.assertFrames(self.systemLayout([44.666666666666664, 28.0, 28.666666666666668, 41.333333333333336], 278.0), size: CGSize(width: 278.0, height: 62.0), xAndWidths: [(4.0, 84.7866), (68.7866, 81.7378), (130.5244, 81.7378), (192.2622, 81.7378)])
    }

    func test_system_fourShortItems_widerItems() {
        self.assertFrames(self.systemLayout([28.0, 28.0, 28.0, 28.0], 360.0), size: CGSize(width: 360.0, height: 62.0), xAndWidths: [(4.0, 98.0), (88.6667, 98.0), (173.3333, 98.0), (258.0, 98.0)])
    }

    func test_system_fourItems_longTitle_proportional() {
        self.assertFrames(self.systemLayout([93.66666666666667, 28.0, 28.666666666666668, 41.333333333333336], 360.0), size: CGSize(width: 360.0, height: 62.0), xAndWidths: [(4.0, 155.9054), (131.9054, 93.3649), (197.2702, 93.3649), (262.6351, 93.3649)])
    }

    func test_system_fiveItems() {
        self.assertFrames(self.systemLayout([44.666666666666664, 28.0, 28.666666666666668, 41.333333333333336, 35.0], 360.0), size: CGSize(width: 360.0, height: 62.0), xAndWidths: [(4.0, 78.6667), (72.3333, 78.6667), (140.6667, 78.6667), (209.0, 78.6667), (277.3333, 78.6667)])
    }

    func test_system_twoAndThreeItems_hugTheirItems() {
        self.assertFrames(self.systemLayout([28.0, 41.333333333333336], 360.0), size: CGSize(width: 188.0, height: 62.0), xAndWidths: [(4.0, 94.0), (90.0, 94.0)])
        self.assertFrames(self.systemLayout([44.666666666666664, 28.666666666666668, 41.333333333333336], 360.0), size: CGSize(width: 274.0, height: 62.0), xAndWidths: [(4.0, 94.0), (90.0, 94.0), (176.0, 94.0)])
    }

    func test_system_threeItemsWithAccessory_fillTheLength() {
        // An accessory makes three items lay out like four or more: the bar takes the whole length.
        let layout = tabBarSystemItemsLayout(fittedItemWidths: [44.666666666666664, 28.666666666666668, 41.333333333333336], availableLength: 290.0, hasAccessory: true, scale: 3.0)
        XCTAssertEqual(layout.size, CGSize(width: 290.0, height: 62.0))
        XCTAssertEqual(layout.itemFrames.first?.minX ?? 0.0, 4.0, accuracy: 0.001)
        XCTAssertEqual(layout.itemFrames.last?.maxX ?? 0.0, 286.0, accuracy: 0.001)
    }
}
