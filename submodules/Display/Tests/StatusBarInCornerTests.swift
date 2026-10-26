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

    // Folded portrait: a modal card (top 10pt below the top) covers the 84x170 status block until a drag down moves its
    // top past the block's bottom, and an edge swipe aside until its left edge passes the block's right one.
    func test_cardCoversTopRightBlock_untilItLeavesIt() {
        let layout = self.layout(corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil))
        let card = CGRect(x: 0.0, y: 10.0, width: 466.0, height: 668.0)
        XCTAssertTrue(layout.coversStatusCorner(frame: card))
        XCTAssertTrue(layout.coversStatusCorner(frame: card.offsetBy(dx: 0.0, dy: 159.0)))
        XCTAssertFalse(layout.coversStatusCorner(frame: card.offsetBy(dx: 0.0, dy: 160.0)))
        XCTAssertTrue(layout.coversStatusCorner(frame: card.offsetBy(dx: 465.0, dy: 0.0)))
        XCTAssertFalse(layout.coversStatusCorner(frame: card.offsetBy(dx: 466.0, dy: 0.0)))
    }

    // Folded landscape-left: the block is at the bottom, so a card dragged down covers it to the end.
    func test_cardCoversBottomRightBlock_whileItIsOnScreen() {
        let layout = ContainerViewLayout(size: CGSize(width: 678.0, height: 466.0), metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), reservedCorners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)), division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: 0.0, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
        let card = CGRect(x: 0.0, y: 0.0, width: 678.0, height: 466.0)
        XCTAssertTrue(layout.coversStatusCorner(frame: card.offsetBy(dx: 0.0, dy: 383.0)))
        XCTAssertFalse(layout.coversStatusCorner(frame: card.offsetBy(dx: 0.0, dy: 466.0)))
    }

    func test_noCornerBlocks_nothingCovered() {
        XCTAssertFalse(self.layout(corners: .none).coversStatusCorner(frame: CGRect(x: 0.0, y: 0.0, width: 466.0, height: 678.0)))
    }
}
