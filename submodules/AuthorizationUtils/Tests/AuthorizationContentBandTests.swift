import XCTest
import UIKit
import Display
import AuthorizationUtils

final class AuthorizationContentBandTests: XCTestCase {
    private func layout(size: CGSize, safeInsets: UIEdgeInsets, deviceMetrics: DeviceMetrics = .iPhoneDuo) -> ContainerViewLayout {
        return ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .regular, orientation: nil), deviceMetrics: deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, reservedCorners: .none, division: nil, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false, presentedInFormSheet: false)
    }

    private func assertBand(_ band: (minX: CGFloat, width: CGFloat), _ minX: CGFloat, _ width: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(band.minX, minX, "minX", file: file, line: line)
        XCTAssertEqual(band.width, width, "width", file: file, line: line)
    }

    // Equal side insets (every other device): the full width, as before.

    func test_regularPhone_fullWidth() {
        self.assertBand(authorizationContentBand(layout: self.layout(size: CGSize(width: 402.0, height: 874.0), safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), deviceMetrics: .iPhone16Pro)), 0.0, 402.0)
    }

    func test_regularPhoneLandscape_fullWidth() {
        self.assertBand(authorizationContentBand(layout: self.layout(size: CGSize(width: 874.0, height: 402.0), safeInsets: UIEdgeInsets(top: 0.0, left: 62.0, bottom: 21.0, right: 62.0), deviceMetrics: .iPhone16Pro)), 0.0, 874.0)
    }

    func test_unfoldedPortrait_fullWidth() {
        self.assertBand(authorizationContentBand(layout: self.layout(size: CGSize(width: 669.0, height: 951.0), safeInsets: UIEdgeInsets(top: 82.0, left: 0.0, bottom: 0.0, right: 0.0))), 0.0, 669.0)
    }

    // Unfolded landscape: centred on the full width (in line with the bottom button and the keyboard), clear of
    // the strip on both sides.

    func test_unfoldedLandscape_centredOnScreen() {
        let band = authorizationContentBand(layout: self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)))
        self.assertBand(band, 84.0, 783.0)
        XCTAssertEqual(band.minX + band.width / 2.0, 951.0 / 2.0)
    }

    func test_unfoldedLandscapeLeftInset_centredOnScreen() {
        self.assertBand(authorizationContentBand(layout: self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0))), 84.0, 783.0)
    }

    func test_unfoldedWithoutRoomForTheColumn_keepsToTheBand() {
        self.assertBand(authorizationContentBand(layout: self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 300.0))), 0.0, 651.0)
    }

    // Folded: the band between the side insets, as before.

    func test_foldedPortrait_band() {
        self.assertBand(authorizationContentBand(layout: self.layout(size: CGSize(width: 466.0, height: 678.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0))), 0.0, 382.0)
    }

    func test_foldedLandscapeRight_band() {
        self.assertBand(authorizationContentBand(layout: self.layout(size: CGSize(width: 678.0, height: 466.0), safeInsets: UIEdgeInsets(top: 0.0, left: 84.0, bottom: 0.0, right: 0.0))), 84.0, 594.0)
    }

    // Another device of the same size with unequal insets is not the Duo's unfolded screen: the band.

    func test_otherDeviceUnequalInsets_band() {
        self.assertBand(authorizationContentBand(layout: self.layout(size: CGSize(width: 951.0, height: 669.0), safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0), deviceMetrics: .iPhone16Pro)), 0.0, 867.0)
    }

    // The component-environment form agrees with the layout form.

    func test_environmentForm_matchesLayoutForm() {
        let size = CGSize(width: 951.0, height: 669.0)
        let safeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)
        let layoutBand = authorizationContentBand(layout: self.layout(size: size, safeInsets: safeInsets))
        let environmentBand = authorizationContentBand(size: size, safeInsets: safeInsets, deviceMetrics: .iPhoneDuo)
        self.assertBand(environmentBand, layoutBand.minX, layoutBand.width)
        self.assertBand(environmentBand, 84.0, 783.0)
    }
}
