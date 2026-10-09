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
}
