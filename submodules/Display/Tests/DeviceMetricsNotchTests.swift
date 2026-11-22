import XCTest
import UIKit
@testable import Display

/// `hasTopNotch` is what the in-call status bar, the app badge and a few screens read to keep clear of a notch. Since
/// devices are matched by model identifier, the iPhone 13 family (and the 14, 16e and 17e that share its profiles) is
/// reached by its own profiles, which the notch list did not include: the in-call bar's text sat under the 16e's notch.
final class DeviceMetricsNotchTests: XCTestCase {
    func test_iPhone16e_hasTopNotch() {
        let metrics = DeviceMetrics(screenSize: CGSize(width: 390.0, height: 844.0), scale: 3.0, statusBarHeight: 47.0, onScreenNavigationHeight: 34.0, modelIdentifier: "iPhone17,5")
        XCTAssertEqual(metrics, .iPhone13)
        XCTAssertTrue(metrics.hasTopNotch)
        XCTAssertFalse(metrics.hasDynamicIsland)
    }

    /// The minis matched the iPhone X by screen size before devices were matched by model identifier, and the app
    /// badge in the notch was never shown on them.
    func test_minis_showNoAppBadge() {
        let miniIdentifiers = ["iPhone13,1", "iPhone14,4"]
        for identifier in miniIdentifiers {
            let metrics = DeviceMetrics(screenSize: CGSize(width: 375.0, height: 812.0), scale: 3.0, statusBarHeight: 50.0, onScreenNavigationHeight: 34.0, modelIdentifier: identifier)
            XCTAssertTrue(metrics.hasTopNotch, identifier)
            XCTAssertFalse(metrics.showAppBadge, identifier)
        }
    }

    /// Every phone with a top cutout that is not a Dynamic Island has a notch.
    func test_everyCutoutThatIsNotAnIsland_isANotch() {
        for device in DeviceMetrics.allCases {
            guard device.cutoutFrame != nil, !device.hasDynamicIsland else {
                continue
            }
            XCTAssertTrue(device.hasTopNotch, "\(device)")
        }
    }
}
