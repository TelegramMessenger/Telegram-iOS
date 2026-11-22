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

    // Data and Storage in Russian on a 390pt iPhone 16e: «Использование трафика» lays out at 196pt (195.1 rounded up).
    // The compact size format's widest Russian value is "888 МБ" (60.6pt); before it, "48,8 МБ" (64.1pt) and
    // "1000 МБ" (67.6pt). The legacy reserve leaves the value 53pt; 6pt of spacing leaves 63pt at 390pt, 66pt at 393pt.
    func testRussianDataUsageFitsWithSixPointSpacing() {
        XCTAssertLessThan(self.labelWidth(width: 390.0, titleWidth: 196.0, minimumSpacing: nil), 54.4)
        XCTAssertEqual(self.labelWidth(width: 390.0, titleWidth: 196.0, minimumSpacing: 6.0), 63.0)
        XCTAssertGreaterThan(self.labelWidth(width: 390.0, titleWidth: 196.0, minimumSpacing: 6.0), 60.6)
        XCTAssertGreaterThan(self.labelWidth(width: 393.0, titleWidth: 196.0, minimumSpacing: 6.0), 60.6)
    }

    // On 375pt the title and a size cannot share the line (as agreed for #64, the value truncates there).
    func testRussianDataUsageDoesNotFitAt375() {
        XCTAssertLessThan(self.labelWidth(width: 375.0, titleWidth: 196.0, minimumSpacing: 6.0), 54.4)
    }

    // «Использование памяти» (185.8pt, 186 laid out).
    func testRussianStorageUsageFitsWithSixPointSpacing() {
        XCTAssertGreaterThan(self.labelWidth(width: 390.0, titleWidth: 186.0, minimumSpacing: 6.0), 60.6)
    }
}
