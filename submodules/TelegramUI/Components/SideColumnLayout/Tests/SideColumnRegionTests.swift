import XCTest
import UIKit
import Display
import SideColumnLayout

final class SideColumnRegionTests: XCTestCase {
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

    // The vertical tab bar's frames for four tabs (TabBarSidePlacementTests).
    private let portraitTabBar = CGRect(x: 396.0, y: 424.0, width: 48.0, height: 232.0)
    private let landscapeLeftTabBar = CGRect(x: 608.0, y: 144.0, width: 48.0, height: 232.0)
    private let landscapeRightTabBar = CGRect(x: 22.0, y: 212.0, width: 48.0, height: 232.0)

    // Root list: 8pt below a block above, 12pt above the tab bar (spec section 1 table).

    func test_coverPortrait_root_belowTheBlockAboveTheTabBar() {
        XCTAssertEqual(sideColumnRegion(layout: self.coverPortrait, minY: 8.0, reservedBelow: self.portraitTabBar), SideColumnRegion(edge: .right, frame: CGRect(x: 396.0, y: 178.0, width: 48.0, height: 234.0)))
    }

    func test_coverLandscapeLeft_root_fromMinY() {
        XCTAssertEqual(sideColumnRegion(layout: self.coverLandscapeLeft, minY: 8.0, reservedBelow: self.landscapeLeftTabBar), SideColumnRegion(edge: .right, frame: CGRect(x: 608.0, y: 8.0, width: 48.0, height: 124.0)))
    }

    func test_coverLandscapeRight_root_leftStrip() {
        XCTAssertEqual(sideColumnRegion(layout: self.coverLandscapeRight, minY: 8.0, reservedBelow: self.landscapeRightTabBar), SideColumnRegion(edge: .left, frame: CGRect(x: 22.0, y: 92.0, width: 48.0, height: 108.0)))
    }

    // Pushed list (archive, forum): no tab bar below.

    func test_coverPortrait_pushed_toTheBottomMargin() {
        XCTAssertEqual(sideColumnRegion(layout: self.coverPortrait, minY: 8.0, reservedBelow: nil), SideColumnRegion(edge: .right, frame: CGRect(x: 396.0, y: 178.0, width: 48.0, height: 478.0)))
    }

    func test_coverLandscapeLeft_pushed_clearOfTheBottomBlock() {
        XCTAssertEqual(sideColumnRegion(layout: self.coverLandscapeLeft, minY: 8.0, reservedBelow: nil), SideColumnRegion(edge: .right, frame: CGRect(x: 608.0, y: 8.0, width: 48.0, height: 368.0)))
    }

    func test_coverLandscapeRight_pushed_toTheBottomMargin() {
        XCTAssertEqual(sideColumnRegion(layout: self.coverLandscapeRight, minY: 8.0, reservedBelow: nil), SideColumnRegion(edge: .left, frame: CGRect(x: 22.0, y: 92.0, width: 48.0, height: 352.0)))
    }

    func test_minYBelowTheBlock_wins() {
        XCTAssertEqual(sideColumnRegion(layout: self.coverPortrait, minY: 300.0, reservedBelow: nil), SideColumnRegion(edge: .right, frame: CGRect(x: 396.0, y: 300.0, width: 48.0, height: 356.0)))
    }

    // No column.

    func test_noStrip_nil() {
        let l = self.layout(size: CGSize(width: 669.0, height: 951.0), safeInsets: UIEdgeInsets(top: 82.0, left: 0.0, bottom: 34.0, right: 0.0), corners: .none)
        XCTAssertNil(sideColumnRegion(layout: l, minY: 90.0, reservedBelow: nil))
    }

    func test_stripNarrowerThan70_nil() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 60.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 60.0, height: 170.0), bottomLeft: nil, bottomRight: nil))
        XCTAssertNil(sideColumnRegion(layout: l, minY: 8.0, reservedBelow: nil))
    }

    func test_lessThan48Left_nil() {
        // Limit 60 - 12 = 48, top 8: 40pt left.
        XCTAssertNil(sideColumnRegion(layout: self.coverLandscapeLeft, minY: 8.0, reservedBelow: CGRect(x: 608.0, y: 60.0, width: 48.0, height: 232.0)))
    }
}
