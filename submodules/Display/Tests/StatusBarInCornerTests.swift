import XCTest
import UIKit
@testable import Display

/// iPhone Duo keeps its status bar in a corner block, not across the top: the window must not lay
/// scroll-to-top views over the top row there (they swallowed taps on the navigation bar's buttons).
final class StatusBarInCornerTests: XCTestCase {
    private func layout(corners: ContainerViewLayoutCorners) -> ContainerViewLayout {
        return ContainerViewLayout(size: CGSize(width: 466.0, height: 678.0), metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), reservedCorners: corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: 44.0, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    func test_topCornerBlock_inCorner() {
        XCTAssertTrue(self.layout(corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil)).statusBarIsInCorner)
    }

    func test_bottomCornerBlock_inCorner() {
        XCTAssertTrue(self.layout(corners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0))).statusBarIsInCorner)
    }

    func test_noCornerBlocks_notInCorner() {
        XCTAssertFalse(self.layout(corners: .none).statusBarIsInCorner)
    }
}
