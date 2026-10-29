import XCTest
import UIKit
@testable import ItemListUI

final class ItemListDisclosureTitleWidthTests: XCTestCase {
    // A 402pt-wide glass row with an icon: leftInset 75, so title and value share 402 - 16 - 75 - 50 = 261.
    private let sharedWidth: CGFloat = 261.0

    private func narrowed(titleWidth: CGFloat, labelWidth: CGFloat, labelSharedWidth: CGFloat? = nil, titleSharedWidth: CGFloat? = nil) -> CGFloat? {
        return itemListDisclosureNarrowedTitleWidth(titleWidth: titleWidth, labelWidth: labelWidth, labelSharedWidth: labelSharedWidth ?? self.sharedWidth, titleSharedWidth: titleSharedWidth ?? self.sharedWidth)
    }

    // Data and Storage in Russian: "Использование трафика" (195) next to "613.5 MB" (72) left the value "613.5…".
    // The value keeps its width and the title gets the rest.
    func testShortValueKeepsItsWidthUnderLongTitle() {
        let titleWidth = self.narrowed(titleWidth: 195.0, labelWidth: 72.0)
        XCTAssertEqual(titleWidth, 189.0)
        XCTAssertGreaterThanOrEqual(self.sharedWidth - titleWidth!, 72.0)
    }

    // When title and value already fit, the title keeps the layout it had.
    func testFittingRowIsUnchanged() {
        XCTAssertNil(self.narrowed(titleWidth: 120.0, labelWidth: 72.0))
        XCTAssertNil(self.narrowed(titleWidth: 189.0, labelWidth: 72.0))
    }

    // Without a value the title keeps the whole row.
    func testNoValueKeepsTitle() {
        XCTAssertNil(self.narrowed(titleWidth: 280.0, labelWidth: 0.0))
    }

    // A value needing more than two thirds of the room is long on purpose (a list of names, a description): the title
    // keeps its width and the value truncates, as before.
    func testLongValueKeepsTitleFirstSplit() {
        XCTAssertNil(self.narrowed(titleWidth: 150.0, labelWidth: 180.0))
    }

    // The largest text size on a 320pt screen: the room is 320 - 16 - 75 - 50 = 179 and "614.6 МБ" at 23pt is about
    // 100pt, more than half of it. The value must still win over the title.
    func testLargeTextOnNarrowScreenKeepsValue() {
        let titleWidth = self.narrowed(titleWidth: 230.0, labelWidth: 100.0, labelSharedWidth: 179.0, titleSharedWidth: 179.0)
        XCTAssertEqual(titleWidth, 79.0)
    }

    func testFractionalRoomIsFloored() {
        XCTAssertEqual(self.narrowed(titleWidth: 230.0, labelWidth: 72.0, labelSharedWidth: 261.67, titleSharedWidth: 261.67), 189.0)
    }

    // A title badge after the title takes its room from the title, not from the value.
    func testTitleBadgeNarrowsTitleFurther() {
        XCTAssertEqual(self.narrowed(titleWidth: 195.0, labelWidth: 72.0, titleSharedWidth: 261.0 - 30.0), 159.0)
    }
}
