import XCTest
import UIKit
@testable import Display

final class DeviceMetricsDuoTests: XCTestCase {
    /// Measured from the simulator's screen masks (iPhone Duo.simdevicetype): the unfolded screen's
    /// corners are about 55pt; the folded screen's outer corners about 58pt and its hinge side about 6pt.
    /// One value per device: the unfolded screen's. Zero made every rounded-corner layout treat the Duo as
    /// a square screen (the input panel's buttons ran into the display corners).
    func test_iPhoneDuo_screenCornerRadius_55() {
        XCTAssertEqual(DeviceMetrics.iPhoneDuo.screenCornerRadius, 55.0)
    }

    /// The unfolded inner screen in either orientation; not the cover screen, and no other device of that size.
    func test_isIPhoneDuoInnerScreen() {
        XCTAssertTrue(DeviceMetrics.iPhoneDuo.isIPhoneDuoInnerScreen(size: CGSize(width: 669.0, height: 951.0)))
        XCTAssertTrue(DeviceMetrics.iPhoneDuo.isIPhoneDuoInnerScreen(size: CGSize(width: 951.0, height: 669.0)))
        XCTAssertFalse(DeviceMetrics.iPhoneDuo.isIPhoneDuoInnerScreen(size: CGSize(width: 466.0, height: 678.0)))
        XCTAssertFalse(DeviceMetrics.iPhoneDuo.isIPhoneDuoInnerScreen(size: CGSize(width: 678.0, height: 466.0)))
        XCTAssertFalse(DeviceMetrics.iPhone18Pro.isIPhoneDuoInnerScreen(size: CGSize(width: 669.0, height: 951.0)))
    }
}
