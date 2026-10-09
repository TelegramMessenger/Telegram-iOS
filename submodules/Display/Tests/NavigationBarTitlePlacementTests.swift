import XCTest
import UIKit
@testable import Display

/// Navigation bar titles are centered in the band between the side safe insets and kept clear of the
/// buttons. iPhone Duo's folded portrait: a 466pt bar with the strip's 84pt inset on the right; a back
/// button gives a left title inset of 70, an Edit button a right one of 170 (84 + 16 + 60 + 10).
final class NavigationBarTitlePlacementTests: XCTestCase {
    // MARK: - Title insets when only one side has buttons

    func test_titleInsets_bothSidesHaveButtons_unchanged() {
        let insets = navigationBarTitleInsets(leftInset: 0.0, rightInset: 84.0, leftTitleInset: 70.0, rightTitleInset: 170.0)
        XCTAssertEqual(insets.left, 70.0)
        XCTAssertEqual(insets.right, 170.0)
    }

    func test_titleInsets_noButtons_unchanged() {
        let insets = navigationBarTitleInsets(leftInset: 0.0, rightInset: 84.0, leftTitleInset: 0.0, rightTitleInset: 84.0)
        XCTAssertEqual(insets.left, 0.0)
        XCTAssertEqual(insets.right, 84.0)
    }

    func test_titleInsets_onlyRightButtons_leftMirrorsTheButtonsNotTheStrip() {
        // The right buttons take 86pt beyond the strip; the left mirrors those 86pt, not 170.
        let insets = navigationBarTitleInsets(leftInset: 0.0, rightInset: 84.0, leftTitleInset: 0.0, rightTitleInset: 170.0)
        XCTAssertEqual(insets.left, 86.0)
        XCTAssertEqual(insets.right, 170.0)
    }

    func test_titleInsets_onlyRightButtons_equalInsets_sameAsBefore() {
        // iPhone landscape: 59pt on both sides; the mirrored inset is the right one, as before.
        let insets = navigationBarTitleInsets(leftInset: 59.0, rightInset: 59.0, leftTitleInset: 59.0, rightTitleInset: 145.0)
        XCTAssertEqual(insets.left, 145.0)
        XCTAssertEqual(insets.right, 145.0)
    }

    func test_titleInsets_onlyLeftButtons_rightKeepsAtLeast16() {
        let insets = navigationBarTitleInsets(leftInset: 0.0, rightInset: 0.0, leftTitleInset: 70.0, rightTitleInset: 0.0)
        XCTAssertEqual(insets.left, 70.0)
        XCTAssertEqual(insets.right, 16.0)
    }

    func test_titleInsets_onlyLeftButtons_rightKeepsTheStrip() {
        let insets = navigationBarTitleInsets(leftInset: 0.0, rightInset: 84.0, leftTitleInset: 70.0, rightTitleInset: 84.0)
        XCTAssertEqual(insets.left, 70.0)
        XCTAssertEqual(insets.right, 84.0)
    }

    // MARK: - Text title

    func test_textTitle_duoPortrait_centeredInTheBand() {
        // Band 0...382, centered at 191 (full-width centering put it at 233).
        XCTAssertEqual(navigationBarTextTitleOriginX(width: 466.0, leftInset: 0.0, rightInset: 84.0, leftTitleInset: 70.0, rightTitleInset: 170.0, titleWidth: 100.0), 141.0)
    }

    func test_textTitle_duoLandscapeRight_centeredInTheBand() {
        // Strip on the left: band 84...678, centered at 381.
        XCTAssertEqual(navigationBarTextTitleOriginX(width: 678.0, leftInset: 84.0, rightInset: 0.0, leftTitleInset: 154.0, rightTitleInset: 86.0, titleWidth: 100.0), 331.0)
    }

    func test_textTitle_tooWideForTheSymmetricBand_centeredBetweenTheButtons() {
        // 220 > 382 - 2 * 86: centered between 70 and 296.
        XCTAssertEqual(navigationBarTextTitleOriginX(width: 466.0, leftInset: 0.0, rightInset: 84.0, leftTitleInset: 70.0, rightTitleInset: 170.0, titleWidth: 220.0), 73.0)
    }

    func test_textTitle_equalInsets_sameAsFullWidthCentering() {
        XCTAssertEqual(navigationBarTextTitleOriginX(width: 402.0, leftInset: 0.0, rightInset: 0.0, leftTitleInset: 70.0, rightTitleInset: 86.0, titleWidth: 100.0), 151.0)
    }

    // MARK: - NavigationBarTitleView

    func test_titleView_duoPortrait_centeredInTheBand() {
        XCTAssertEqual(navigationBarTitleViewOriginX(width: 466.0, leftInset: 0.0, rightInset: 84.0, leftTitleInset: 70.0, rightTitleInset: 170.0, titleWidth: 150.0), 116.0)
    }

    func test_titleView_duoPortrait_crossesTheRightButtons_shiftedLeft() {
        // Centered in the band at 81 it would end at 301 > 296.
        XCTAssertEqual(navigationBarTitleViewOriginX(width: 466.0, leftInset: 0.0, rightInset: 84.0, leftTitleInset: 70.0, rightTitleInset: 170.0, titleWidth: 220.0), 76.0)
    }

    func test_titleView_equalInsets_sameAsFullWidthCentering() {
        XCTAssertEqual(navigationBarTitleViewOriginX(width: 402.0, leftInset: 0.0, rightInset: 0.0, leftTitleInset: 70.0, rightTitleInset: 86.0, titleWidth: 150.0), 126.0)
    }

    // MARK: - Other title views (fill a band symmetric about the band's center)

    func test_fillingTitle_duoPortrait_symmetricInTheBand() {
        // The larger button margin (86 beyond the strip) on both sides of the band: 86...296, 210 wide.
        // Symmetric about the full width it was 170...296, 126 wide.
        let frame = navigationBarFillingTitleFrame(width: 466.0, leftInset: 0.0, rightInset: 84.0, leftTitleInset: 70.0, rightTitleInset: 170.0)
        XCTAssertEqual(frame.x, 86.0)
        XCTAssertEqual(frame.width, 210.0)
    }

    func test_fillingTitle_equalInsets_sameAsBefore() {
        let frame = navigationBarFillingTitleFrame(width: 402.0, leftInset: 0.0, rightInset: 0.0, leftTitleInset: 70.0, rightTitleInset: 86.0)
        XCTAssertEqual(frame.x, 86.0)
        XCTAssertEqual(frame.width, 230.0)
    }
}
