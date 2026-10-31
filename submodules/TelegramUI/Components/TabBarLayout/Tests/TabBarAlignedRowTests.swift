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
}
