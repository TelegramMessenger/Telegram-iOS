import XCTest
import UIKit
import Display
import TabBarLayout

final class TabBarPlacementChangeTests: XCTestCase {
    private let portrait = CGSize(width: 466.0, height: 678.0)
    private let landscape = CGSize(width: 678.0, height: 466.0)
    private let portraitRight = TabBarSidePlacement(edge: .right, frame: CGRect(x: 396.0, y: 424.0, width: 48.0, height: 232.0))
    private let landscapeLeftRight = TabBarSidePlacement(edge: .right, frame: CGRect(x: 608.0, y: 144.0, width: 48.0, height: 232.0))
    private let landscapeRightLeft = TabBarSidePlacement(edge: .left, frame: CGRect(x: 22.0, y: 212.0, width: 48.0, height: 232.0))

    private func applied(_ placement: TabBarSidePlacement?, _ size: CGSize, hidden: Bool = false) -> TabBarAppliedPlacement {
        return TabBarAppliedPlacement(placement: placement, containerSize: size, isHidden: hidden)
    }

    // Nothing moves the bar to another place: frames follow the layout's transition, as before.

    func test_firstLayout_animate() {
        XCTAssertEqual(tabBarPlacementChange(from: nil, to: self.applied(self.portraitRight, self.portrait)), .animate)
    }

    func test_horizontalStaysHorizontal_animate() {
        XCTAssertEqual(tabBarPlacementChange(from: self.applied(nil, self.portrait), to: self.applied(nil, self.landscape)), .animate)
    }

    func test_hideToggle_sameEdgeSameSize_animate() {
        XCTAssertEqual(tabBarPlacementChange(from: self.applied(self.portraitRight, self.portrait), to: self.applied(self.portraitRight, self.portrait, hidden: true)), .animate)
    }

    // Folding and unfolding switch the axis: no animation (spec section 3).

    func test_gainingPlacement_immediate() {
        XCTAssertEqual(tabBarPlacementChange(from: self.applied(nil, CGSize(width: 320.0, height: 669.0)), to: self.applied(self.portraitRight, self.portrait)), .immediate)
    }

    func test_losingPlacement_immediate() {
        XCTAssertEqual(tabBarPlacementChange(from: self.applied(self.portraitRight, self.portrait), to: self.applied(nil, CGSize(width: 320.0, height: 669.0))), .immediate)
    }

    // A rotation moves the bar to another place: it fades instead of flying across the screen.

    func test_rotationToTheOtherEdge_crossfade() {
        XCTAssertEqual(tabBarPlacementChange(from: self.applied(self.portraitRight, self.portrait), to: self.applied(self.landscapeRightLeft, self.landscape)), .crossfade)
    }

    func test_rotationKeepingTheEdge_crossfade() {
        XCTAssertEqual(tabBarPlacementChange(from: self.applied(self.portraitRight, self.portrait), to: self.applied(self.landscapeLeftRight, self.landscape)), .crossfade)
    }

    func test_rotationWhileHiddenBeforeAndAfter_immediate() {
        XCTAssertEqual(tabBarPlacementChange(from: self.applied(self.portraitRight, self.portrait, hidden: true), to: self.applied(self.landscapeRightLeft, self.landscape, hidden: true)), .immediate)
    }

    func test_rotationThatAlsoHides_crossfade() {
        XCTAssertEqual(tabBarPlacementChange(from: self.applied(self.portraitRight, self.portrait), to: self.applied(self.landscapeRightLeft, self.landscape, hidden: true)), .crossfade)
    }

    // Where the fading snapshot of the old bar sits in the new layout: the same distance from its own
    // side edge and from the bottom edge.

    func test_movedFrame_rightEdge_portraitToLandscape() {
        XCTAssertEqual(self.portraitRight.movedFrame(from: self.portrait, to: self.landscape), CGRect(x: 608.0, y: 212.0, width: 48.0, height: 232.0))
    }

    func test_movedFrame_leftEdge_landscapeToPortrait() {
        XCTAssertEqual(self.landscapeRightLeft.movedFrame(from: self.landscape, to: self.portrait), CGRect(x: 22.0, y: 424.0, width: 48.0, height: 232.0))
    }
}
