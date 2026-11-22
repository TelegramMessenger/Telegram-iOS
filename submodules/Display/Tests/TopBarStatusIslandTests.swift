import XCTest
import UIKit
@testable import Display

/// iPhone Duo, unfolded screen in portrait: the top bar stays near the top beside the status island, its trailing
/// buttons clear of it. Every other layout keeps its status bar height and buttons.
final class TopBarStatusIslandTests: XCTestCase {
    private func layout(size: CGSize, safeInsets: UIEdgeInsets, corners: ContainerViewLayoutCorners, statusBarHeight: CGFloat?) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: statusBarHeight, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    func test_unfoldedPortrait_barBesideTheIsland() {
        let l = self.layout(size: CGSize(width: 669.0, height: 951.0), safeInsets: UIEdgeInsets(top: 82.0, left: 0.0, bottom: 0.0, right: 0.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 134.0, height: 82.0), bottomLeft: nil, bottomRight: nil), statusBarHeight: 82.0)
        XCTAssertEqual(l.topBarStatusIsland, CGSize(width: 134.0, height: 82.0))
        XCTAssertEqual(l.navigationBarStatusBarHeight, 16.0)
        XCTAssertEqual(l.navigationBarTrailingButtonsInset, 134.0)
        // Everything that is not a top bar keeps the full status height.
        XCTAssertEqual(l.statusBarHeight, 82.0)
    }

    func test_foldedPortrait_blockAtTheStripEnd_unchanged() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil), statusBarHeight: 0.0)
        XCTAssertNil(l.topBarStatusIsland)
        XCTAssertEqual(l.navigationBarStatusBarHeight, 0.0)
        XCTAssertEqual(l.navigationBarTrailingButtonsInset, 0.0)
    }

    func test_unfoldedLandscape_blockAtTheStripEnd_unchanged() {
        let l = self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil), statusBarHeight: 20.0)
        XCTAssertNil(l.topBarStatusIsland)
        XCTAssertEqual(l.navigationBarStatusBarHeight, 20.0)
        XCTAssertEqual(l.navigationBarTrailingButtonsInset, 0.0)
    }

    func test_otherPhones_unchanged() {
        let l = self.layout(size: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), corners: .none, statusBarHeight: 62.0)
        XCTAssertNil(l.topBarStatusIsland)
        XCTAssertEqual(l.navigationBarStatusBarHeight, 62.0)
        XCTAssertEqual(l.navigationBarTrailingButtonsInset, 0.0)
    }

    // MARK: statusIslandTrailingShift

    func test_sheetControl_besideTheIsland_movesTheWholeInset() {
        XCTAssertEqual(statusIslandTrailingShift(rowMinY: 30.0, rowHeight: 44.0, islandHeight: 82.0, inset: 134.0), 134.0)
        XCTAssertEqual(statusIslandTrailingShift(rowMinY: 82.0, rowHeight: 44.0, islandHeight: 82.0, inset: 134.0), 134.0)
    }

    func test_sheetControl_approachingTheIsland_slidesIn() {
        XCTAssertEqual(statusIslandTrailingShift(rowMinY: 104.0, rowHeight: 44.0, islandHeight: 82.0, inset: 134.0), 67.0)
    }

    func test_sheetControl_belowTheIsland_staysAtTheEdge() {
        XCTAssertEqual(statusIslandTrailingShift(rowMinY: 126.0, rowHeight: 44.0, islandHeight: 82.0, inset: 134.0), 0.0)
        XCTAssertEqual(statusIslandTrailingShift(rowMinY: 400.0, rowHeight: 44.0, islandHeight: 82.0, inset: 134.0), 0.0)
    }

    func test_sheetControl_noIsland_unchanged() {
        XCTAssertEqual(statusIslandTrailingShift(rowMinY: 30.0, rowHeight: 44.0, islandHeight: 82.0, inset: 0.0), 0.0)
    }
}
