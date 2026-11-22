import XCTest
import UIKit
@testable import Display

/// The screen's four corner radii in a layout's coordinates. iPhone Duo's cover screen has 8pt corners on
/// the hinge side and 59pt ones on the outer side (the simulator profile's `cornerRadiusUL/UR/LL/LR` for
/// the "primary" display, native portrait: hinge on the left); the inner screen is 55pt all round.
final class ScreenCornerRadiiTests: XCTestCase {
    private func layout(size: CGSize, deviceMetrics: DeviceMetrics = .iPhoneDuo, safeInsets: UIEdgeInsets) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    func test_coverPortrait_hingeOnTheLeft() {
        let l = self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
        XCTAssertEqual(l.screenCornerRadii, CornerRadii(topLeft: 8.0, topRight: 59.0, bottomLeft: 8.0, bottomRight: 59.0))
    }

    func test_coverLandscapeLeft_stripOnTheRight_hingeOnTop() {
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))
        XCTAssertEqual(l.screenCornerRadii, CornerRadii(topLeft: 8.0, topRight: 8.0, bottomLeft: 59.0, bottomRight: 59.0))
    }

    func test_coverLandscapeRight_stripOnTheLeft_hingeAtTheBottom() {
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0))
        XCTAssertEqual(l.screenCornerRadii, CornerRadii(topLeft: 59.0, topRight: 59.0, bottomLeft: 8.0, bottomRight: 8.0))
    }

    func test_coverLandscape_unknownSide_uniform() {
        // No strip yet (a transitional layout): the side is unknown, so no corner is claimed small.
        let l = self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets())
        XCTAssertEqual(l.screenCornerRadii, CornerRadii(uniform: 55.0))
    }

    func test_innerScreen_uniform55() {
        XCTAssertEqual(self.layout(size: CGSize(width: 669.0, height: 951.0), safeInsets: UIEdgeInsets(top: 82.0, left: 0.0, bottom: 0.0, right: 0.0)).screenCornerRadii, CornerRadii(uniform: 55.0))
        XCTAssertEqual(self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)).screenCornerRadii, CornerRadii(uniform: 55.0))
    }

    func test_duoPartialWindow_uniform() {
        // A layout that does not fill a screen (a split pane) has no screen corners of its own to follow.
        let l = self.layout(size: CGSize(width: 320.0, height: 669.0), safeInsets: UIEdgeInsets())
        XCTAssertEqual(l.screenCornerRadii, CornerRadii(uniform: 55.0))
    }

    func test_otherDevice_uniformScreenRadius() {
        let l = self.layout(size: CGSize(width: 402.0, height: 874.0), deviceMetrics: .iPhone16Pro, safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0))
        XCTAssertEqual(l.screenCornerRadii, CornerRadii(uniform: DeviceMetrics.iPhone16Pro.screenCornerRadius))
    }
}
