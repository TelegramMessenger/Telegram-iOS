import XCTest
import UIKit
import Display
import PeerInfoPaneNode

/// iPhone Duo: the panes stop at the side strip, and the gifts cover's icons must stay off the navigation
/// buttons (which now sit between the safe insets) and out of the strip.
final class PeerInfoStripLayoutTests: XCTestCase {
    // MARK: A touch in the strip belongs to the pane beside it

    func test_touchInRightStrip_movesIntoThePaneAtTheSameHeight() {
        let point = peerInfoStripTouchForwardingPoint(CGPoint(x: 420.0, y: 300.0), containerWidth: 466.0, stripLeft: 0.0, stripRight: 84.0, paneFrame: CGRect(x: 0.0, y: -100.0, width: 382.0, height: 900.0))
        XCTAssertEqual(point, CGPoint(x: 381.0, y: 300.0))
    }

    func test_touchInLeftStrip_movesIntoThePaneAtTheSameHeight() {
        let point = peerInfoStripTouchForwardingPoint(CGPoint(x: 20.0, y: 300.0), containerWidth: 678.0, stripLeft: 84.0, stripRight: 0.0, paneFrame: CGRect(x: 84.0, y: -100.0, width: 594.0, height: 600.0))
        XCTAssertEqual(point, CGPoint(x: 84.0, y: 300.0))
    }

    func test_touchOnThePane_isNotForwarded() {
        XCTAssertNil(peerInfoStripTouchForwardingPoint(CGPoint(x: 200.0, y: 300.0), containerWidth: 466.0, stripLeft: 0.0, stripRight: 84.0, paneFrame: CGRect(x: 0.0, y: -100.0, width: 382.0, height: 900.0)))
    }

    func test_noStrip_neverForwards() {
        let paneFrame = CGRect(x: 0.0, y: -100.0, width: 402.0, height: 900.0)
        XCTAssertNil(peerInfoStripTouchForwardingPoint(CGPoint(x: 401.0, y: 300.0), containerWidth: 402.0, stripLeft: 0.0, stripRight: 0.0, paneFrame: paneFrame))
        XCTAssertNil(peerInfoStripTouchForwardingPoint(CGPoint(x: 0.0, y: 300.0), containerWidth: 402.0, stripLeft: 0.0, stripRight: 0.0, paneFrame: paneFrame))
    }

    func test_touchInTheStripBelowThePane_isNotForwarded() {
        XCTAssertNil(peerInfoStripTouchForwardingPoint(CGPoint(x: 420.0, y: 850.0), containerWidth: 466.0, stripLeft: 0.0, stripRight: 84.0, paneFrame: CGRect(x: 0.0, y: -100.0, width: 382.0, height: 900.0)))
    }

    // MARK: Gifts cover exclusions

    private func sideInsets(stripLeft: CGFloat = 0.0, stripRight: CGFloat = 0.0, navigationLeft: CGFloat = 0.0, navigationRight: CGFloat = 0.0) -> PeerInfoSideInsets {
        return PeerInfoSideInsets(base: 16.0, stripLeft: stripLeft, stripRight: stripRight, navigationLeft: navigationLeft, navigationRight: navigationRight, sectionLeft: 16.0, sectionRight: 16.0, paneSideInset: 0.0)
    }

    func test_giftsExclusions_noStrip_buttonsAtTheScreenEdges() {
        let rects = peerInfoGiftsCoverSideExclusionRects(width: 402.0, height: 300.0, statusBarHeight: 54.0, topLeftButtonsSize: CGSize(width: 47.0, height: 46.0), topRightButtonsSize: CGSize(width: 76.0, height: 46.0), sideInsets: self.sideInsets())
        XCTAssertEqual(rects, [CGRect(x: 0.0, y: 54.0, width: 47.0, height: 46.0), CGRect(x: 326.0, y: 54.0, width: 76.0, height: 46.0)])
    }

    func test_giftsExclusions_noStrip_ignoresSymmetricSafeInsets() {
        let rects = peerInfoGiftsCoverSideExclusionRects(width: 874.0, height: 300.0, statusBarHeight: 0.0, topLeftButtonsSize: CGSize(width: 47.0, height: 46.0), topRightButtonsSize: CGSize(width: 76.0, height: 46.0), sideInsets: self.sideInsets(navigationLeft: 62.0, navigationRight: 62.0))
        XCTAssertEqual(rects, [CGRect(x: 0.0, y: 0.0, width: 47.0, height: 46.0), CGRect(x: 798.0, y: 0.0, width: 76.0, height: 46.0)])
    }

    func test_giftsExclusions_rightStrip_buttonsBetweenTheSafeInsets_stripKeptClear() {
        let rects = peerInfoGiftsCoverSideExclusionRects(width: 466.0, height: 300.0, statusBarHeight: 0.0, topLeftButtonsSize: CGSize(width: 47.0, height: 46.0), topRightButtonsSize: CGSize(width: 76.0, height: 46.0), sideInsets: self.sideInsets(stripRight: 84.0, navigationRight: 84.0))
        XCTAssertEqual(rects, [CGRect(x: 0.0, y: 0.0, width: 47.0, height: 46.0), CGRect(x: 306.0, y: 0.0, width: 76.0, height: 46.0), CGRect(x: 382.0, y: 0.0, width: 84.0, height: 300.0)])
    }

    func test_giftsExclusions_leftStrip_buttonsBetweenTheSafeInsets_stripKeptClear() {
        let rects = peerInfoGiftsCoverSideExclusionRects(width: 678.0, height: 300.0, statusBarHeight: 0.0, topLeftButtonsSize: CGSize(width: 47.0, height: 46.0), topRightButtonsSize: CGSize(width: 76.0, height: 46.0), sideInsets: self.sideInsets(stripLeft: 84.0, navigationLeft: 84.0))
        XCTAssertEqual(rects, [CGRect(x: 84.0, y: 0.0, width: 47.0, height: 46.0), CGRect(x: 602.0, y: 0.0, width: 76.0, height: 46.0), CGRect(x: 0.0, y: 0.0, width: 84.0, height: 300.0)])
    }
}
