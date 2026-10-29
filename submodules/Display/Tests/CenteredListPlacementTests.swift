import XCTest
import UIKit
@testable import Display

/// A list narrowed by `base` on each side (a blocks-style list centred on a wide screen): beside iPhone Duo's side
/// strip it keeps `listSideMargins(base:)` and its rows take no inset for the strip, which the margin already clears;
/// without a strip it is today's centred list with the safe insets unchanged.
final class CenteredListPlacementTests: XCTestCase {
    private func layout(size: CGSize, safeInsets: UIEdgeInsets, corners: ContainerViewLayoutCorners) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    func test_coverPortrait_listStopsBeforeTheStrip_rowsTakeNoStripInset() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil))
        let placement = l.centeredListPlacement(base: 16.0)
        XCTAssertEqual(placement.left, 16.0)
        XCTAssertEqual(placement.width, 350.0)
        XCTAssertEqual(placement.safeInsets, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 0.0))
    }

    func test_unfoldedLandscape_wideBaseCentred_rowsTakeNoStripInset() {
        let l = self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil))
        let placement = l.centeredListPlacement(base: 138.0)
        XCTAssertEqual(placement.left, 138.0)
        XCTAssertEqual(placement.width, 675.0)
        XCTAssertEqual(placement.safeInsets, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 0.0))
    }

    func test_coverLandscapeLeft_listStopsBeforeTheStrip_rowsTakeNoStripInset() {
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)))
        let placement = l.centeredListPlacement(base: 16.0)
        XCTAssertEqual(placement.left, 16.0)
        XCTAssertEqual(placement.width, 562.0)
        XCTAssertEqual(placement.safeInsets, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 0.0))
    }

    func test_coverLandscapeRight_listStartsAfterTheStrip_rowsTakeNoStripInset() {
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 34.0, right: 0.0), corners: ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 84.0), topRight: nil, bottomLeft: nil, bottomRight: nil))
        let placement = l.centeredListPlacement(base: 16.0)
        XCTAssertEqual(placement.left, 100.0)
        XCTAssertEqual(placement.width, 562.0)
        XCTAssertEqual(placement.safeInsets, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 0.0))
    }

    func test_notchedLandscape_noStrip_todaysCentredListAndSafeInsets() {
        let l = self.layout(size: CGSize(width: 874.0, height: 402.0), safeInsets: UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0), corners: .none)
        let placement = l.centeredListPlacement(base: 100.0)
        XCTAssertEqual(placement.left, 100.0)
        XCTAssertEqual(placement.width, 674.0)
        XCTAssertEqual(placement.safeInsets, UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0))
    }
}
