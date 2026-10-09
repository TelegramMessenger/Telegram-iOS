import XCTest
import UIKit
@testable import Display

/// Centered sheets and banners (share sheet, in-app notifications, peek previews) beside iPhone Duo's side strip,
/// and that equal side insets keep the placement they always had.
final class HorizontalContainerFillingPlacementTests: XCTestCase {
    private func layout(size: CGSize, safeInsets: UIEdgeInsets, widthClass: ContainerViewLayoutSizeClass = .compact) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: widthClass, heightClass: .regular, orientation: nil), deviceMetrics: .iPhoneDuo, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    func test_coverPortrait_keepsToTheBandBesideTheStrip() {
        let p = horizontalContainerFillingPlacementForLayout(layout: self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 84.0)), margin: 10.0, includesSafeInsets: true)
        XCTAssertEqual(p.left, 10.0)
        XCTAssertEqual(p.width, 362.0)
        XCTAssertEqual(p.right, 94.0)
    }

    func test_coverLandscapeRight_centersInTheBand() {
        let p = horizontalContainerFillingPlacementForLayout(layout: self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 21.0, right: 0.0)), margin: 10.0, includesSafeInsets: true)
        XCTAssertEqual(p.width, 420.0)
        XCTAssertEqual(p.left, 84.0 + 87.0)
        XCTAssertEqual(p.left + p.width + p.right, 678.0)
    }

    func test_equalInsets_unchanged() {
        let landscape = self.layout(size: CGSize(width: 932.0, height: 430.0), safeInsets: UIEdgeInsets(top: 0.0, left: 59.0, bottom: 21.0, right: 59.0))
        let withInsets = horizontalContainerFillingPlacementForLayout(layout: landscape, margin: 10.0, includesSafeInsets: true)
        XCTAssertEqual(withInsets.width, horizontalContainerFillingSizeForLayout(layout: landscape, sideInset: 10.0 + 59.0))
        XCTAssertEqual(withInsets.left, floor((932.0 - withInsets.width) / 2.0))
        XCTAssertEqual(withInsets.right, withInsets.left)

        let withoutInsets = horizontalContainerFillingPlacementForLayout(layout: landscape, margin: 0.0, includesSafeInsets: false)
        XCTAssertEqual(withoutInsets.width, horizontalContainerFillingSizeForLayout(layout: landscape, sideInset: 0.0))
        XCTAssertEqual(withoutInsets.right, withoutInsets.left)

        let portrait = horizontalContainerFillingPlacementForLayout(layout: self.layout(size: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)), margin: 0.0, includesSafeInsets: false)
        XCTAssertEqual(portrait.left, 0.0)
        XCTAssertEqual(portrait.width, 402.0)
    }
}
