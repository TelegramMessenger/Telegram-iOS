import XCTest
import UIKit
import Display
@testable import InstantPageUI

final class InstantPageMetricsTests: XCTestCase {
    /// The load-bearing invariant: at scale 1.0 every field equals the literal it replaced, so
    /// every page outside a quote lays out exactly as it did before this type existed.
    func testUnscaledMetricsMatchOriginalLiterals() {
        let m = InstantPageMetrics.unscaled

        XCTAssertEqual(m.baseBlockSpacing, 8.0)
        XCTAssertEqual(m.blockVerticalPadding, 4.0)
        XCTAssertEqual(m.headingVerticalPadding, 8.0)
        XCTAssertEqual(m.dividerVerticalPadding, 4.0)
        XCTAssertEqual(m.detailsAdjacentSpacing, 4.0)

        XCTAssertEqual(m.captionTopPad, 9.0)
        XCTAssertEqual(m.creditTopPad, 10.0)
        XCTAssertEqual(m.coverCaptionExtraPad, 14.0)

        XCTAssertEqual(m.quoteVerticalInset, 6.0)
        XCTAssertEqual(m.pullQuoteVerticalInset, 12.0)
        XCTAssertEqual(m.quoteLineInset, 9.0)
        XCTAssertEqual(m.quoteLeadingInset, 9.0)
        XCTAssertEqual(m.quoteTrailingInset, 16.0)
        XCTAssertEqual(m.pullQuotePadding, 30.0)
        XCTAssertEqual(m.quoteAttributionGap, 3.0)

        XCTAssertEqual(m.codeBlockVerticalInset, 14.0)
        XCTAssertEqual(m.codeBlockFontSize, 15.0)
        XCTAssertEqual(m.codeBlockLanguageSpacing, 3.0)

        XCTAssertEqual(m.listIndexSpacing, 8.0)
        XCTAssertEqual(m.checklistMarkerSize, CGSize(width: 18.0, height: 18.0))
        XCTAssertEqual(m.bulletDiameter, 5.0)
        XCTAssertEqual(m.listItemTextwardOffset, 2.0)
        XCTAssertEqual(m.numberMarkerTextwardOffset, 5.0)

        XCTAssertEqual(m.tableCellInsets, UIEdgeInsets(top: 7.0, left: 13.0, bottom: 7.0, right: 13.0))
        // Halved, then pixel-snapped by `s(...)` — so the exact value depends on the screen scale
        // (3.5 at 2x, 3.333… at 3x). The accuracy admits one snapping step.
        XCTAssertEqual(m.tableCompactCellInsets.top, 3.5, accuracy: 0.5)
        XCTAssertEqual(m.tableCompactCellInsets.bottom, 3.5, accuracy: 0.5)
        XCTAssertEqual(m.tableCompactCellInsets.left, 6.5, accuracy: 0.5)
        XCTAssertEqual(m.tableCompactCellInsets.right, 6.5, accuracy: 0.5)
        XCTAssertEqual(m.tableMinCompressedColumnWidth, 60.0)

        XCTAssertEqual(m.detailsMinTitleHeight, 36.0)
        XCTAssertEqual(m.detailsTitleVerticalPad, 15.0)
        XCTAssertEqual(m.detailsChevronReserve, 32.0)
        XCTAssertEqual(m.detailsTitleHorizontalInset, 23.0)

        XCTAssertEqual(m.blockButtonHeight, 40.0)
        XCTAssertEqual(m.blockButtonSpacing, 6.0)
    }

    /// The quote scale actually shrinks, and geometry lands on the screen-pixel grid rather than on
    /// arbitrary fractions. The grid is pinned to 3x: the test process reports a 1x screen (see
    /// `InstantPageContentScaleTests`), on which a pixel snap is indistinguishable from a floor. The
    /// code FONT size is the one exception — a whole-point floor like every other font, so it stays
    /// equal to the table and quote-body sizes.
    func testQuoteScaleShrinksAndSnapsToScreenPixels() {
        let scale = InstantPageMetrics.quoteScale
        let m = InstantPageMetrics(scale: scale, screenScale: 3.0)

        XCTAssertEqual(m.baseBlockSpacing, floor(8.0 * scale * 3.0) / 3.0)
        XCTAssertEqual(m.captionTopPad, floor(9.0 * scale * 3.0) / 3.0)
        XCTAssertEqual(m.codeBlockFontSize, floor(15.0 * scale))
        XCTAssertEqual(m.quoteLineInset, floor(9.0 * scale * 3.0) / 3.0)

        XCTAssertLessThan(m.baseBlockSpacing, InstantPageMetrics.unscaled.baseBlockSpacing)
        XCTAssertLessThan(m.captionTopPad, InstantPageMetrics.unscaled.captionTopPad)
        XCTAssertLessThan(m.codeBlockFontSize, InstantPageMetrics.unscaled.codeBlockFontSize)
    }

    /// Idempotence is enforced at the call sites (assign, never multiply), but the arithmetic
    /// backing it belongs here: applying the quote scale twice is NOT the quote scale.
    func testQuoteScaleAppliedTwiceWouldDiffer() {
        let once = InstantPageMetrics(scale: InstantPageMetrics.quoteScale)
        let twice = InstantPageMetrics(scale: InstantPageMetrics.quoteScale * InstantPageMetrics.quoteScale)
        XCTAssertNotEqual(once.baseBlockSpacing, twice.baseBlockSpacing)
    }
}
