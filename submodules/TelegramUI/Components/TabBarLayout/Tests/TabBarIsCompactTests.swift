import XCTest
import UIKit
import Display
import TabBarLayout

final class TabBarIsCompactTests: XCTestCase {
    private func layout(size: CGSize, widthClass: ContainerViewLayoutSizeClass, deviceMetrics: DeviceMetrics) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: widthClass, heightClass: widthClass, orientation: nil), deviceMetrics: deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    // Master-detail: the tab bar sits in the master pane of a regular-width layout.

    func test_unfoldedDuoMasterPane_compact() {
        XCTAssertTrue(tabBarIsCompact(layout: self.layout(size: CGSize(width: 320.0, height: 669.0), widthClass: .regular, deviceMetrics: .iPhoneDuo), sidePlacement: nil))
    }

    func test_iPadMasterPane_compact() {
        XCTAssertTrue(tabBarIsCompact(layout: self.layout(size: CGSize(width: 375.0, height: 1194.0), widthClass: .regular, deviceMetrics: .iPadPro11Inch), sidePlacement: nil))
    }

    // Single pane: the bar keeps its labels.

    func test_unfoldedDuoPortrait_regular() {
        XCTAssertFalse(tabBarIsCompact(layout: self.layout(size: CGSize(width: 669.0, height: 951.0), widthClass: .compact, deviceMetrics: .iPhoneDuo), sidePlacement: nil))
    }

    func test_iPhone_regular() {
        XCTAssertFalse(tabBarIsCompact(layout: self.layout(size: CGSize(width: 402.0, height: 874.0), widthClass: .compact, deviceMetrics: .iPhone16Pro), sidePlacement: nil))
    }

    // The vertical bar is always compact.

    func test_sidePlacement_compact() {
        let placement = TabBarSidePlacement(edge: .right, frame: CGRect(x: 396.0, y: 424.0, width: 48.0, height: 232.0))
        XCTAssertTrue(tabBarIsCompact(layout: self.layout(size: CGSize(width: 466.0, height: 678.0), widthClass: .compact, deviceMetrics: .iPhoneDuo), sidePlacement: placement))
    }
}
