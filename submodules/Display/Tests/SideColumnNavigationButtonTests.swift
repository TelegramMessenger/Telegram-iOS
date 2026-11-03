import XCTest
import UIKit
@testable import Display

/// iPhone Duo: where a screen's back or close button goes in the side strip
/// (docs/iphone-duo-layout.md).
final class SideColumnNavigationButtonTests: XCTestCase {
    private func layout(size: CGSize, safeInsets: UIEdgeInsets, corners: ContainerViewLayoutCorners, statusBarHeight: CGFloat?, presentedInFormSheet: Bool = false) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: statusBarHeight, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: presentedInFormSheet)
    }

    func test_coverPortrait_belowTheStatusCorner() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil), statusBarHeight: 0.0)
        XCTAssertEqual(l.sideColumnNavigationButtonFrame, CGRect(x: 396.0, y: 178.0, width: 48.0, height: 48.0))
    }

    func test_coverLandscapeLeft_belowTheStatusBar() {
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)), statusBarHeight: 20.0)
        XCTAssertEqual(l.sideColumnNavigationButtonFrame, CGRect(x: 608.0, y: 28.0, width: 48.0, height: 48.0))
    }

    func test_coverLandscapeRight_leftStripBelowTheBlock() {
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 34.0, right: 0.0), corners: ContainerViewLayoutCorners(topLeft: CGSize(width: 84.0, height: 84.0), topRight: nil, bottomLeft: nil, bottomRight: nil), statusBarHeight: 0.0)
        XCTAssertEqual(l.sideColumnNavigationButtonFrame, CGRect(x: 22.0, y: 92.0, width: 48.0, height: 48.0))
    }

    func test_formSheet_staysInTheBar() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil), statusBarHeight: 0.0, presentedInFormSheet: true)
        XCTAssertNil(l.sideColumnNavigationButtonFrame)
    }

    func test_noStrip_staysInTheBar() {
        let l = self.layout(size: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), corners: .none, statusBarHeight: 62.0)
        XCTAssertNil(l.sideColumnNavigationButtonFrame)
    }
}
