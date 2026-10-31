import XCTest
import UIKit
import Display
import TabBarLayout

final class TabBarAlignedRowTests: XCTestCase {
    func test_compactBarThickness() {
        XCTAssertEqual(tabBarCompactBarThickness, 48.0)
    }

    func test_floatingBottomInset_atLeast8() {
        XCTAssertEqual(tabBarFloatingBottomInset(bottomInset: 0.0), 8.0)
        XCTAssertEqual(tabBarFloatingBottomInset(bottomInset: 5.0), 8.0)
        XCTAssertEqual(tabBarFloatingBottomInset(bottomInset: 20.0), 20.0)
    }

    // A chat's 40pt bottom panel row, 8pt above the bottom inset, beside the master pane's compact tab bar.

    private func rowCenterInset(bottomInset: CGFloat) -> CGFloat {
        let offset = tabBarAlignedRowBottomInsetOffset(bottomInset: bottomInset, rowSpacing: 8.0, rowHeight: 40.0)
        return bottomInset + offset + 8.0 + 20.0
    }

    private func barCenterInset(bottomInset: CGFloat) -> CGFloat {
        return tabBarFloatingBottomInset(bottomInset: bottomInset) + tabBarCompactBarThickness * 0.5
    }

    // iPad with a home indicator (20pt): the row was 48pt above the bottom edge, the bar's centre 44pt.
    func test_homeIndicatorIPad_rowMovesDown4() {
        XCTAssertEqual(tabBarAlignedRowBottomInsetOffset(bottomInset: 20.0, rowSpacing: 8.0, rowHeight: 40.0), -4.0)
        XCTAssertEqual(self.rowCenterInset(bottomInset: 20.0), 44.0)
        XCTAssertEqual(self.rowCenterInset(bottomInset: 20.0), self.barCenterInset(bottomInset: 20.0))
    }

    // iPad with a home button (no bottom inset): the bar floats 8pt up, its centre at 32pt; the row was at 28pt.
    func test_homeButtonIPad_rowMovesUp4() {
        XCTAssertEqual(tabBarAlignedRowBottomInsetOffset(bottomInset: 0.0, rowSpacing: 8.0, rowHeight: 40.0), 4.0)
        XCTAssertEqual(self.rowCenterInset(bottomInset: 0.0), 32.0)
    }

    func test_rowAsTallAsTheBar_flushWithIt() {
        XCTAssertEqual(tabBarAlignedRowBottomInsetOffset(bottomInset: 20.0, rowSpacing: 0.0, rowHeight: tabBarCompactBarThickness), 0.0)
    }

    // The compact bar in an iPad master pane (20pt side insets, so `masterWidth - 40` available), its search button
    // as tall and wide as the bar: the search must follow the items and stay inside the bar's size, which
    // `TabBarControllerNode` centres in the pane, whether the items fill the length or hug it.
    private func compactBarWithSearch(masterWidth: CGFloat, itemCount: Int) -> (barWidth: CGFloat, searchFrame: CGRect, tabsWidth: CGFloat) {
        let availableWidth = masterWidth - 40.0
        let searchLength = tabBarCompactBarThickness
        let items = tabBarItemsLayout(axis: .horizontal, isCompact: true, unboundItemWidths: Array(repeating: 60.0, count: itemCount), availableLength: availableWidth - searchLength - 8.0)
        let barWidth = items.size.width + searchLength + 8.0
        let searchX = tabBarSearchButtonOrigin(tabsLength: items.size.width, availableLength: availableWidth, buttonLength: searchLength, isCompact: true)
        return (barWidth, CGRect(x: searchX, y: 0.0, width: searchLength, height: searchLength), items.size.width)
    }

    func test_compactSearch_followsItems_insideBar() {
        // Portrait (master 320) fills; 11" iPads in landscape (393, 398, 403) and 13" (455) hug four items.
        for masterWidth: CGFloat in [320.0, 393.0, 398.0, 403.0, 455.0] {
            for itemCount in [3, 4] {
                let bar = self.compactBarWithSearch(masterWidth: masterWidth, itemCount: itemCount)
                XCTAssertEqual(bar.searchFrame.minX, bar.tabsWidth + 8.0, "master \(masterWidth), \(itemCount) items")
                XCTAssertEqual(bar.searchFrame.maxX, bar.barWidth, "master \(masterWidth), \(itemCount) items")
                XCTAssertLessThanOrEqual(bar.barWidth, masterWidth - 40.0, "master \(masterWidth), \(itemCount) items")
            }
        }
    }

    // iPad Pro 11" (M4/M5) in landscape: master 403, four tabs hug (232pt), the bar 288pt with its search.
    func test_compactSearch_iPadPro11Landscape_hugs() {
        let bar = self.compactBarWithSearch(masterWidth: 403.0, itemCount: 4)
        XCTAssertEqual(bar.tabsWidth, 232.0)
        XCTAssertEqual(bar.barWidth, 288.0)
        XCTAssertEqual(bar.searchFrame.minX, 240.0)
    }

    // The bars that always fill keep the search at the end of the available length.
    func test_regularSearch_atEnd() {
        XCTAssertEqual(tabBarSearchButtonOrigin(tabsLength: 290.0, availableLength: 362.0, buttonLength: 62.0, isCompact: false), 300.0)
    }
}
