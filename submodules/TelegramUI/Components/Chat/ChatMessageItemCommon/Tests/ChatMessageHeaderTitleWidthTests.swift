import XCTest
import UIKit
import ChatMessageItemCommon

/// A floating topic (or peer) header's pill is its title plus `chrome` and is centred between the list's side insets
/// (the side topic panel, the Duo's strip). Its title is capped so the pill always stays `margin` inside that band.
final class ChatMessageHeaderTitleWidthTests: XCTestCase {
    private let chrome: CGFloat = 41.0
    private let margin: CGFloat = 8.0

    private func maxWidth(_ width: CGFloat, left: CGFloat, right: CGFloat) -> CGFloat {
        return chatMessageHeaderTitleMaxWidth(width: width, leftInset: left, rightInset: right, chromeWidth: self.chrome, margin: self.margin)
    }

    /// A full-width list on a regular phone keeps the old fixed 320pt cap.
    func testWideBandKeepsFixedCap() {
        XCTAssertEqual(self.maxWidth(402.0, left: 0.0, right: 0.0), 320.0)
        XCTAssertEqual(self.maxWidth(951.0, left: 0.0, right: 84.0), 320.0)
    }

    /// iPhone 18 Pro with the side topic panel (92pt): the band is 310pt.
    func testSidePanelBand() {
        XCTAssertEqual(self.maxWidth(402.0, left: 92.0, right: 0.0), 310.0 - 41.0 - 16.0)
    }

    /// Folded Duo portrait with the side panel: the 84pt strip on the right narrows the band to 290pt.
    func testDuoFoldedStripAndSidePanel() {
        XCTAssertEqual(self.maxWidth(466.0, left: 92.0, right: 84.0), 290.0 - 41.0 - 16.0)
    }

    /// Both sides count, whichever side the inset is on.
    func testAsymmetricInsetsAreSymmetricInEffect() {
        XCTAssertEqual(self.maxWidth(678.0, left: 84.0 + 92.0, right: 0.0), self.maxWidth(678.0, left: 92.0, right: 84.0))
    }

    /// The pill (title + chrome) never leaves the band, margin included.
    func testPillFitsBand() {
        for width: CGFloat in [320.0, 375.0, 402.0, 466.0, 669.0] {
            for (left, right): (CGFloat, CGFloat) in [(0.0, 0.0), (92.0, 0.0), (92.0, 84.0), (176.0, 0.0)] {
                let title = self.maxWidth(width, left: left, right: right)
                XCTAssertLessThanOrEqual(title + self.chrome + 2.0 * self.margin, max(width - left - right, self.chrome + 2.0 * self.margin) + 0.001)
            }
        }
    }

    /// A band too narrow for any title gives a zero width, never a negative one.
    func testNeverNegative() {
        XCTAssertEqual(self.maxWidth(100.0, left: 92.0, right: 0.0), 0.0)
    }
}
