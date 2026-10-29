import XCTest
import UIKit
@testable import ItemListUI

final class ItemListDisclosureLabelWidthTests: XCTestCase {
    // A glass row with an icon: params insets 16, the title starts at 16 + 16 + 43 = 75, the value ends 34pt before
    // the row's right inset (the disclosure arrow).
    private let leftInset: CGFloat = 75.0
    private let rightInset: CGFloat = 16.0
    private let labelRightInset: CGFloat = 50.0

    private func labelWidth(width: CGFloat, titleWidth: CGFloat, minimumSpacing: CGFloat?, hasIconPeer: Bool = false) -> CGFloat {
        return itemListDisclosureLabelConstrainedWidth(width: width, rightInset: self.rightInset, labelRightInset: self.labelRightInset, leftInset: self.leftInset, titleWidth: titleWidth, hasIconPeer: hasIconPeer, minimumSpacing: minimumSpacing)
    }

    // Rows that name no spacing keep the legacy reserve: 16pt between title and value before an arrow.
    func testDefaultKeepsLegacyReserve() {
        XCTAssertEqual(self.labelWidth(width: 390.0, titleWidth: 196.0, minimumSpacing: nil), 390.0 - 16.0 - 75.0 - 50.0 - 196.0)
        XCTAssertEqual(self.labelWidth(width: 390.0, titleWidth: 196.0, minimumSpacing: nil, hasIconPeer: true), 390.0 - 16.0 - 75.0 - 56.0 - 196.0)
    }

    // Data and Storage in Russian on a 390pt iPhone 16e: «Использование трафика» lays out at 196pt (195.1 rounded up),
    // and a size without a decimal is at most "999 МБ" (60.5pt). The legacy reserve leaves the value 53pt and truncates
    // it; with 8pt of spacing it has 61pt and fits.
    func testRussianDataUsageFitsAt390WithEightPointSpacing() {
        XCTAssertLessThan(self.labelWidth(width: 390.0, titleWidth: 196.0, minimumSpacing: nil), 54.4)
        XCTAssertEqual(self.labelWidth(width: 390.0, titleWidth: 196.0, minimumSpacing: 8.0), 61.0)
        XCTAssertGreaterThan(self.labelWidth(width: 390.0, titleWidth: 196.0, minimumSpacing: 8.0), 60.5)
        XCTAssertGreaterThan(self.labelWidth(width: 393.0, titleWidth: 196.0, minimumSpacing: 8.0), 60.5)
    }

    // «Использование памяти» (185.8pt, 186 laid out) beside "999 МБ" or "27,2 ГБ" (55.3pt).
    func testRussianStorageUsageFitsAt390WithEightPointSpacing() {
        XCTAssertGreaterThan(self.labelWidth(width: 390.0, titleWidth: 186.0, minimumSpacing: 8.0), 60.5)
    }
}
