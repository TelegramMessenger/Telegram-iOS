import XCTest
import UIKit
@testable import Display

/// A list's side margins beside iPhone Duo's side strip: at least 16pt clear of the strip, `base` elsewhere.
final class ListSideMarginsTests: XCTestCase {
    private func layout(size: CGSize, safeInsets: UIEdgeInsets, corners: ContainerViewLayoutCorners) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    func test_coverPortrait_rightClearOfTheStrip() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil))
        let margins = l.listSideMargins(base: 16.0)
        XCTAssertEqual(margins.left, 16.0)
        XCTAssertEqual(margins.right, 100.0)
    }

    func test_coverLandscapeLeft_rightClearOfTheStrip() {
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)))
        let margins = l.listSideMargins(base: 16.0)
        XCTAssertEqual(margins.left, 16.0)
        XCTAssertEqual(margins.right, 100.0)
    }

    func test_coverLandscapeRight_leftClearOfTheStrip() {
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 34.0, right: 0.0), corners: ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 84.0), topRight: nil, bottomLeft: nil, bottomRight: nil))
        let margins = l.listSideMargins(base: 16.0)
        XCTAssertEqual(margins.left, 100.0)
        XCTAssertEqual(margins.right, 16.0)
    }

    func test_unfoldedDetailPane_rightClearOfTheStrip() {
        let l = self.layout(size: CGSize(width: 631.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil))
        let margins = l.listSideMargins(base: 16.0)
        XCTAssertEqual(margins.left, 16.0)
        XCTAssertEqual(margins.right, 100.0)
    }

    func test_unfoldedFullWidth_wideBaseAlreadyClear() {
        let l = self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil))
        let margins = l.listSideMargins(base: 138.0)
        XCTAssertEqual(margins.left, 138.0)
        XCTAssertEqual(margins.right, 138.0)
    }

    func test_notchedLandscape_noStrip_base() {
        // Safe insets without corner blocks are not a strip: today's margins.
        let l = self.layout(size: CGSize(width: 874.0, height: 402.0), safeInsets: UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0), corners: .none)
        let margins = l.listSideMargins(base: 100.0)
        XCTAssertEqual(margins.left, 100.0)
        XCTAssertEqual(margins.right, 100.0)
    }

    func test_noStrip_zeroBase_zero() {
        let l = self.layout(size: CGSize(width: 300.0, height: 568.0), safeInsets: UIEdgeInsets(), corners: .none)
        let margins = l.listSideMargins(base: 0.0)
        XCTAssertEqual(margins.left, 0.0)
        XCTAssertEqual(margins.right, 0.0)
    }
}
