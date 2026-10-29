import XCTest
import CoreGraphics
import Display
@testable import EntityKeyboard

// iPhone Duo folded portrait: a 466pt wide window, safe insets left 0 / right 84, so the band is x 0...382.
final class EntityKeyboardSideInsetsTests: XCTestCase {
    private let foldedWidth: CGFloat = 466.0
    private let foldedRightStrip: CGFloat = 84.0

    // The sticker grid (5 columns, 362pt) is centred on the band, not on the screen: before, it sat at 52...414,
    // 32pt into the strip, with 52pt of empty space on the left.
    func testGridIsCentredOnTheBandBesideTheStrip() {
        let insets = entityKeyboardGridSideInsets(width: self.foldedWidth, gridWidth: 362.0, leftInset: 0.0, rightInset: self.foldedRightStrip)
        XCTAssertEqual(insets.left, 10.0)
        XCTAssertEqual(insets.right, 94.0)
        XCTAssertEqual(insets.left + 362.0 + insets.right, self.foldedWidth)
    }

    func testGridIsCentredOnTheBandBesideALeftStrip() {
        let insets = entityKeyboardGridSideInsets(width: self.foldedWidth, gridWidth: 362.0, leftInset: self.foldedRightStrip, rightInset: 0.0)
        XCTAssertEqual(insets.left, 94.0)
        XCTAssertEqual(insets.right, 10.0)
    }

    // With equal side insets the grid keeps its old placement: centred on the width, the same inset on both sides.
    func testGridKeepsTheOldPlacementWithEqualInsets() {
        for (width, gridWidth, inset) in [(402.0, 380.0, 0.0), (402.0, 377.0, 0.0), (874.0, 731.0, 62.0), (1024.0, 1001.0, 0.0)] as [(CGFloat, CGFloat, CGFloat)] {
            let old = floorToScreenPixels((width - gridWidth) / 2.0)
            let insets = entityKeyboardGridSideInsets(width: width, gridWidth: gridWidth, leftInset: inset, rightInset: inset)
            XCTAssertEqual(insets.left, old)
            XCTAssertEqual(insets.right, old)
        }
    }

    // The GIFs / Stickers / Emoji switcher is centred on the band, on the grid's axis, clear of the settings button.
    func testCentredControlSitsOnTheBandAxis() {
        let tabsWidth: CGFloat = 170.0
        let x = entityKeyboardBandCenteredX(width: tabsWidth, containerWidth: self.foldedWidth, leftInset: 16.0, rightInset: self.foldedRightStrip + 16.0)
        XCTAssertEqual(x + tabsWidth / 2.0, (self.foldedWidth - self.foldedRightStrip) / 2.0)
    }

    func testCentredControlKeepsTheOldPlacementWithEqualInsets() {
        XCTAssertEqual(entityKeyboardBandCenteredX(width: 171.0, containerWidth: 402.0, leftInset: 16.0, rightInset: 16.0), (402.0 - 171.0) / 2.0)
    }

    func testSideStrips() {
        XCTAssertTrue(entityKeyboardSideStrips(leftInset: 0.0, rightInset: 84.0) == (left: 0.0, right: 84.0))
        XCTAssertTrue(entityKeyboardSideStrips(leftInset: 84.0, rightInset: 0.0) == (left: 84.0, right: 0.0))
        XCTAssertTrue(entityKeyboardSideStrips(leftInset: 62.0, rightInset: 62.0) == (left: 0.0, right: 0.0))
        XCTAssertTrue(entityKeyboardSideStrips(leftInset: 0.0, rightInset: 0.0) == (left: 0.0, right: 0.0))
    }
}
