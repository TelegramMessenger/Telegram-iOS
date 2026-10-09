import XCTest
import UIKit
import Display
import SideColumnLayout

/// A bottom panel's side insets beside the column (ItemList spec, section 2.3).
final class SideColumnBandInsetsTests: XCTestCase {
    private func layout(size: CGSize, safeInsets: UIEdgeInsets, corners: ContainerViewLayoutCorners) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: corners, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    private var coverPortrait: ContainerViewLayout {
        return self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil))
    }

    private var coverLandscapeLeft: ContainerViewLayout {
        return self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0), corners: ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)))
    }

    func test_bandBelowTheColumn_runsIntoTheStrip() {
        XCTAssertEqual(sideColumnBandInsets(layout: self.coverPortrait, bandMinY: 600.0, bandMaxY: 644.0, column: (edge: .right, maxY: 346.0)).right, 0.0)
    }

    func test_bandReachingTheColumn_keepsTheStrip() {
        XCTAssertEqual(sideColumnBandInsets(layout: self.coverPortrait, bandMinY: 300.0, bandMaxY: 350.0, column: (edge: .right, maxY: 346.0)).right, 84.0)
    }

    func test_noColumn_bottomBlock_keepsTheStrip() {
        XCTAssertEqual(sideColumnBandInsets(layout: self.coverLandscapeLeft, bandMinY: 390.0, bandMaxY: 432.0, column: nil).right, 84.0)
    }
}
