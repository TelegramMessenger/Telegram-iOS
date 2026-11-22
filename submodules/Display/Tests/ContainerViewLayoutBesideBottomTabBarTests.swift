import XCTest
import UIKit
@testable import Display

/// A split view's detail pane learns from its layout whether the master pane beside it shows a bottom tab bar (iPad), so
/// that a chat lines its bottom row up with the bar only then. The fact must survive every way a layout is derived on
/// the way to the chat (the keyboard, insets, size, metrics), or the row would jump by the bar's offset when one changes.
final class ContainerViewLayoutBesideBottomTabBarTests: XCTestCase {
    private func layout(isBesideBottomTabBar: Bool) -> ContainerViewLayout {
        return ContainerViewLayout(size: CGSize(width: 694.0, height: 1194.0), metrics: LayoutMetrics(widthClass: .regular, heightClass: .regular, orientation: nil), deviceMetrics: .iPadPro11Inch, intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 0.0), safeInsets: UIEdgeInsets(), reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: 24.0, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false, isBesideBottomTabBar: isBesideBottomTabBar)
    }

    func testDefaultsToFalse() {
        let layout = ContainerViewLayout(size: CGSize(width: 390.0, height: 844.0), metrics: LayoutMetrics(), deviceMetrics: .iPhone18Pro, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
        XCTAssertFalse(layout.isBesideBottomTabBar)
    }

    func testDerivedLayoutsKeepIt() {
        for value in [true, false] {
            let layout = self.layout(isBesideBottomTabBar: value)
            XCTAssertEqual(layout.withUpdatedInputHeight(300.0).isBesideBottomTabBar, value)
            XCTAssertEqual(layout.withUpdatedInputHeight(nil).isBesideBottomTabBar, value)
            XCTAssertEqual(layout.withUpdatedSize(CGSize(width: 500.0, height: 1194.0)).isBesideBottomTabBar, value)
            XCTAssertEqual(layout.withUpdatedIntrinsicInsets(UIEdgeInsets()).isBesideBottomTabBar, value)
            XCTAssertEqual(layout.withUpdatedSafeInsets(UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 0.0)).isBesideBottomTabBar, value)
            XCTAssertEqual(layout.withUpdatedAdditionalInsets(UIEdgeInsets(top: 0.0, left: 0.0, bottom: 10.0, right: 0.0)).isBesideBottomTabBar, value)
            XCTAssertEqual(layout.withUpdatedMetrics(LayoutMetrics()).isBesideBottomTabBar, value)
            XCTAssertEqual(layout.addedInsets(insets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 0.0, right: 0.0)).isBesideBottomTabBar, value)
        }
    }

    /// A change of what the master pane shows changes the detail's layout, which is what lays the chat out again.
    func testItTakesPartInEquality() {
        XCTAssertNotEqual(self.layout(isBesideBottomTabBar: true), self.layout(isBesideBottomTabBar: false))
    }
}
