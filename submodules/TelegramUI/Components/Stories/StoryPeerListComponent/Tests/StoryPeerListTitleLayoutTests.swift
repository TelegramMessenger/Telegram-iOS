import XCTest
import CoreGraphics

/// The chat list header's collapsed content (stories or spinner, then the title) between the bar's buttons.
final class StoryPeerListTitleLayoutTests: XCTestCase {
    // iPhone 16e, Edit on the left, two capsules on the right: the band runs from 76 to 229 on a 390 pt row, its middle
    // 42.5 pt left of the row's.
    private let narrowWidth: CGFloat = 390.0
    private let narrowMinX: CGFloat = 76.0
    private let narrowMaxX: CGFloat = 229.0

    // iPhone 18 Pro, Edit on the left, one capsule and the compose button on the right.
    private let wideWidth: CGFloat = 402.0
    private let wideMinX: CGFloat = 75.0
    private let wideMaxX: CGFloat = 282.0

    // iPhone 18 Pro with a proxy: the proxy button joins the capsule on the right, which takes the band's right side in
    // by the button's width.
    private let proxyMaxX: CGFloat = 238.0

    private func origin(_ contentWidth: CGFloat, width: CGFloat, minX: CGFloat, maxX: CGFloat) -> CGFloat {
        return StoryPeerListTitleLayout.contentOrigin(containerWidth: width, contentWidth: contentWidth, minX: minX, maxX: maxX)
    }

    // With room on both sides the content is centred in the row, as it was.
    func test_contentOrigin_centredWithRoom() {
        XCTAssertEqual(self.origin(80.0, width: self.wideWidth, minX: self.wideMinX, maxX: self.wideMaxX), 161.0)
        XCTAssertEqual(self.origin(100.0, width: 358.0, minX: 70.0, maxX: 288.0), 129.0)
    }

    // Content that cannot be centred clear of the buttons stands in the middle of the band, as far from either side.
    func test_contentOrigin_balancedBetweenTheButtons_whenItCannotBeCentred() {
        XCTAssertEqual(self.origin(100.0, width: self.narrowWidth, minX: self.narrowMinX, maxX: self.narrowMaxX), 102.5)
        XCTAssertEqual(self.origin(145.0, width: self.narrowWidth, minX: self.narrowMinX, maxX: self.narrowMaxX), 80.0)
    }

    // From centred to balanced it moves on a smooth curve, without a corner: as the content widens a quarter point at a
    // time, its origin never jumps and its rate of change never turns abruptly.
    func test_contentOrigin_movesSmoothlyFromCentredToBalanced() {
        let step: CGFloat = 0.25
        var previousOrigin: CGFloat?
        var previousSlope: CGFloat?
        var contentWidth: CGFloat = 20.0
        while contentWidth <= 200.0 {
            let origin = self.origin(contentWidth, width: self.wideWidth, minX: self.wideMinX, maxX: self.wideMaxX)
            if let previousOrigin {
                let slope = (origin - previousOrigin) / step
                XCTAssertLessThan(abs(origin - previousOrigin), 0.5, "jump at \(contentWidth)")
                if let previousSlope {
                    XCTAssertLessThan(abs(slope - previousSlope), 0.05, "corner at \(contentWidth)")
                }
                previousSlope = slope
            }
            previousOrigin = origin
            contentWidth += step
        }
    }

    // Content that fits the band stays inside it, 4 pt clear of either side, whichever side is the wider.
    func test_contentOrigin_keepsContentThatFitsInsideTheBand() {
        let bands: [(width: CGFloat, minX: CGFloat, maxX: CGFloat)] = [
            (self.narrowWidth, self.narrowMinX, self.narrowMaxX),
            (self.wideWidth, self.wideMinX, self.wideMaxX),
            (self.wideWidth, 120.0, 360.0)
        ]
        for band in bands {
            let available = band.maxX - band.minX - StoryPeerListTitleLayout.leadingMargin - StoryPeerListTitleLayout.trailingMargin
            var contentWidth: CGFloat = 10.0
            while contentWidth <= available {
                let origin = self.origin(contentWidth, width: band.width, minX: band.minX, maxX: band.maxX)
                XCTAssertGreaterThanOrEqual(origin, band.minX + StoryPeerListTitleLayout.leadingMargin - 0.001, "\(band) \(contentWidth)")
                XCTAssertLessThanOrEqual(origin + contentWidth, band.maxX - StoryPeerListTitleLayout.trailingMargin + 0.001, "\(band) \(contentWidth)")
                contentWidth += 1.0
            }
        }
    }

    // The title's text shows while the content fits the band, and goes once it does not.
    func test_text_showsWhileTheContentFitsTheBand() {
        XCTAssertTrue(StoryPeerListTitleLayout.showsTitleText(contentWidth: 145.0, minX: self.narrowMinX, maxX: self.narrowMaxX))
        XCTAssertFalse(StoryPeerListTitleLayout.showsTitleText(contentWidth: 146.0, minX: self.narrowMinX, maxX: self.narrowMaxX))
    }

    // The wider side being the left one (a back button) does not hide text that fits.
    func test_text_showsWhenOnlyTheLeftSideIsTight() {
        XCTAssertTrue(StoryPeerListTitleLayout.showsTitleText(contentWidth: 232.0, minX: 120.0, maxX: 360.0))
        XCTAssertFalse(StoryPeerListTitleLayout.showsTitleText(contentWidth: 233.0, minX: 120.0, maxX: 360.0))
    }

    // Expanded stories leave the title alone on its row. Without a proxy it is centred in the row, as it was.
    func test_expandedTitle_centredWithRoom() {
        let origin = StoryPeerListTitleLayout.expandedTitleOrigin(containerWidth: self.wideWidth, titleWidth: 80.0, minX: self.wideMinX, maxX: self.wideMaxX)
        XCTAssertEqual(origin, 161.0)
    }

    // With a proxy, the centred title (and the status after it) would run under the right buttons (issue #8): it stands
    // between the buttons instead, as the collapsed content does.
    func test_expandedTitle_staysClearOfTheProxyButton() {
        let titleWidth: CGFloat = 80.0
        let origin = StoryPeerListTitleLayout.expandedTitleOrigin(containerWidth: self.wideWidth, titleWidth: titleWidth, minX: self.wideMinX, maxX: self.proxyMaxX)
        XCTAssertLessThanOrEqual(origin + titleWidth, self.proxyMaxX - StoryPeerListTitleLayout.trailingMargin)
        XCTAssertGreaterThanOrEqual(origin, self.wideMinX + StoryPeerListTitleLayout.leadingMargin)
        XCTAssertEqual(origin, StoryPeerListTitleLayout.contentOrigin(containerWidth: self.wideWidth, contentWidth: titleWidth, minX: self.wideMinX, maxX: self.proxyMaxX))
    }

    // On a narrow phone (iPhone 16e) the band is narrow even without a proxy, and the expanded title follows the same
    // balanced rule as the collapsed content: it leaves the row's centre once it comes within the ramp of the right
    // buttons. Plain "Chats" (47 pt) is only 6.5 pt inside the band's margin when centred, so it moves about 32 pt left
    // of centre; with an emoji status (73 pt) it would overlap them centred, so it stands in the middle of the band.
    func test_expandedTitle_narrowPhoneWithoutProxy_followsTheBalancedRule() {
        let centred = (self.narrowWidth - 47.0) * 0.5
        let plain = StoryPeerListTitleLayout.expandedTitleOrigin(containerWidth: self.narrowWidth, titleWidth: 47.0, minX: self.narrowMinX, maxX: self.narrowMaxX)
        XCTAssertEqual(centred, 171.5)
        XCTAssertEqual(plain, 139.55, accuracy: 0.01)

        let withStatus = StoryPeerListTitleLayout.expandedTitleOrigin(containerWidth: self.narrowWidth, titleWidth: 73.0, minX: self.narrowMinX, maxX: self.narrowMaxX)
        XCTAssertEqual(withStatus, 116.0)
        XCTAssertLessThanOrEqual(withStatus + 73.0, self.narrowMaxX - StoryPeerListTitleLayout.trailingMargin)
    }
}
