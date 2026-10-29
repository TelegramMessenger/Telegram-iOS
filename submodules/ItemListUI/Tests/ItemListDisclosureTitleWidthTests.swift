import XCTest
import UIKit
@testable import ItemListUI

final class ItemListDisclosureTitleWidthTests: XCTestCase {
    // An iPhone 16e row with an icon: the title may span 295, title and value share 265.
    private let maxTitleWidth: CGFloat = 295.0
    private let sharedWidth: CGFloat = 265.0

    // Data and Storage in Russian: "Использование трафика" (195) + "23,9 ГБ" (63) leave the value too
    // little room when the title takes its full width first. The short value keeps its width; the title gets the rest.
    func testShortValueKeepsItsWidth() {
        let titleWidth = itemListDisclosureTitleConstrainedWidth(maxTitleWidth: self.maxTitleWidth, sharedWidth: self.sharedWidth, labelWidth: 63.0)
        XCTAssertEqual(titleWidth, 202.0)
        XCTAssertGreaterThanOrEqual(self.sharedWidth - titleWidth, 63.0)
    }

    func testFractionalSharedWidthIsFloored() {
        let titleWidth = itemListDisclosureTitleConstrainedWidth(maxTitleWidth: self.maxTitleWidth, sharedWidth: 265.67, labelWidth: 63.0)
        XCTAssertEqual(titleWidth, 202.0)
    }

    // Without a value the title keeps the whole row, as before.
    func testNoValueKeepsFullTitleWidth() {
        XCTAssertEqual(itemListDisclosureTitleConstrainedWidth(maxTitleWidth: self.maxTitleWidth, sharedWidth: self.sharedWidth, labelWidth: 0.0), self.maxTitleWidth)
    }

    // A value wider than half the shared space is long on purpose (a list of names, a description): the title keeps
    // its width and the value truncates, as before.
    func testLongValueLeavesTitleUnchanged() {
        XCTAssertEqual(itemListDisclosureTitleConstrainedWidth(maxTitleWidth: self.maxTitleWidth, sharedWidth: self.sharedWidth, labelWidth: 140.0), self.maxTitleWidth)
    }

    func testValueOfExactlyHalfStillKeepsItsWidth() {
        XCTAssertEqual(itemListDisclosureTitleConstrainedWidth(maxTitleWidth: self.maxTitleWidth, sharedWidth: 260.0, labelWidth: 130.0), 130.0)
    }

    // The title's own limit (a title badge, a badge label) still applies when it is the narrower one.
    func testNeverWiderThanTitleLimit() {
        XCTAssertEqual(itemListDisclosureTitleConstrainedWidth(maxTitleWidth: 150.0, sharedWidth: self.sharedWidth, labelWidth: 40.0), 150.0)
    }
}
