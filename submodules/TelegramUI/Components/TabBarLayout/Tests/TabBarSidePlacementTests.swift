import XCTest
import UIKit
import Display
import TabBarLayout

final class TabBarSidePlacementTests: XCTestCase {
    private func layout(size: CGSize, safeInsets: UIEdgeInsets, corners: ContainerViewLayoutCorners) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    private var coverPortrait: ContainerViewLayout {
        return self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil))
    }
    private var coverLandscapeLeft: ContainerViewLayout {
        return self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)))
    }
    private var coverLandscapeRight: ContainerViewLayout {
        return self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 34.0, right: 0.0), corners: ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 84.0), topRight: nil, bottomLeft: nil, bottomRight: nil))
    }

    // The three cover postures, four tabs (spec section 3).

    func test_coverPortrait_bottomAnchoredUnderTheClock() {
        XCTAssertEqual(tabBarSidePlacement(layout: self.coverPortrait, itemCount: 4), TabBarSidePlacement(edge: .right, frame: CGRect(x: 396.0, y: 424.0, width: 48.0, height: 232.0)))
    }

    func test_coverLandscapeLeft_endsJustAboveTheBottomBlock() {
        XCTAssertEqual(tabBarSidePlacement(layout: self.coverLandscapeLeft, itemCount: 4), TabBarSidePlacement(edge: .right, frame: CGRect(x: 608.0, y: 144.0, width: 48.0, height: 232.0)))
    }

    func test_coverLandscapeRight_leftStrip() {
        XCTAssertEqual(tabBarSidePlacement(layout: self.coverLandscapeRight, itemCount: 4), TabBarSidePlacement(edge: .left, frame: CGRect(x: 22.0, y: 212.0, width: 48.0, height: 232.0)))
    }

    func test_unfoldedLandscapeFullWidth_rightStrip() {
        let l = self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil))
        XCTAssertEqual(tabBarSidePlacement(layout: l, itemCount: 4), TabBarSidePlacement(edge: .right, frame: CGRect(x: 881.0, y: 415.0, width: 48.0, height: 232.0)))
    }

    // Item counts (Review Focus 3: the Calls tab can be hidden).

    func test_threeTabs_shorterCapsuleStillBottomAnchored() {
        XCTAssertEqual(tabBarSidePlacement(layout: self.coverPortrait, itemCount: 3), TabBarSidePlacement(edge: .right, frame: CGRect(x: 396.0, y: 480.0, width: 48.0, height: 176.0)))
    }

    func test_fiveTabs_landscapeLeft_stillFits() {
        XCTAssertEqual(tabBarSidePlacement(layout: self.coverLandscapeLeft, itemCount: 5), TabBarSidePlacement(edge: .right, frame: CGRect(x: 608.0, y: 88.0, width: 48.0, height: 288.0)))
    }

    func test_sevenTabs_landscapeLeft_doesNotFit_nil() {
        // 7 * 56 + 8 = 400 would start at 376 - 400 = -24, above the strip's top + 8.
        XCTAssertNil(tabBarSidePlacement(layout: self.coverLandscapeLeft, itemCount: 7))
    }

    func test_noItems_nil() {
        XCTAssertNil(tabBarSidePlacement(layout: self.coverPortrait, itemCount: 0))
    }

    // No strip (Review Focus 1: the split view's master pane after unfolding).

    func test_splitMasterPane_nil() {
        let l = self.layout(size: CGSize(width: 320.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 0.0), corners: .none)
        XCTAssertNil(tabBarSidePlacement(layout: l, itemCount: 4))
    }

    func test_stripNarrowerThanMarginPlusBar_nil() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 60.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 60.0, height: 100.0), bottomLeft: nil, bottomRight: nil))
        XCTAssertNil(tabBarSidePlacement(layout: l, itemCount: 4))
    }

    func test_frameSize_isTheVerticalCompactItemsLayoutSize() {
        let placement = tabBarSidePlacement(layout: self.coverPortrait, itemCount: 4)
        let itemsLayout = tabBarItemsLayout(axis: .vertical, isCompact: true, unboundItemWidths: [0.0, 0.0, 0.0, 0.0], availableLength: 0.0)
        XCTAssertEqual(placement?.frame.size, itemsLayout.size)
    }

    // Hidden (Review Focus 2: past the strip's own edge, whichever side it is on).

    func test_hiddenFrame_rightEdge_pastTheRightEdge() {
        let placement = TabBarSidePlacement(edge: .right, frame: CGRect(x: 396.0, y: 424.0, width: 48.0, height: 232.0))
        XCTAssertEqual(placement.hiddenFrame(containerWidth: 466.0), CGRect(x: 466.0, y: 424.0, width: 48.0, height: 232.0))
    }

    func test_hiddenFrame_leftEdge_pastTheLeftEdge() {
        let placement = TabBarSidePlacement(edge: .left, frame: CGRect(x: 22.0, y: 212.0, width: 48.0, height: 232.0))
        XCTAssertEqual(placement.hiddenFrame(containerWidth: 678.0), CGRect(x: -48.0, y: 212.0, width: 48.0, height: 232.0))
    }

    // The edit-mode toolbar beside a side bar.

    func test_sideToolbar_landscapeLeft_stopsAtTheRightInset() {
        let frame = tabBarSideToolbarFrame(layout: self.coverLandscapeLeft, sideMargin: 12.0, bottomInset: 34.0, height: 44.0)
        XCTAssertEqual(frame, CGRect(x: 12.0, y: 388.0, width: 582.0, height: 44.0))
        XCTAssertLessThanOrEqual(frame.maxX, 678.0 - 84.0)
    }

    // Folded landscape-right's corner block is at the top left, so the toolbar at the bottom spans the strip.
    func test_sideToolbar_landscapeRight_spansTheLeftStrip() {
        XCTAssertEqual(tabBarSideToolbarFrame(layout: self.coverLandscapeRight, sideMargin: 12.0, bottomInset: 34.0, height: 44.0), CGRect(x: 12.0, y: 388.0, width: 654.0, height: 44.0))
    }
}
