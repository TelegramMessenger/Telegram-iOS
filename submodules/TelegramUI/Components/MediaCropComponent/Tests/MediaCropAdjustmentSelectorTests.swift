import XCTest
import CoreGraphics
import MediaEditor
import MediaCropComponent

final class MediaCropAdjustmentSelectorTests: XCTestCase {
    func testLimits() {
        XCTAssertEqual(mediaCropAdjustmentLimit(.straighten), mediaCropMaximumWheelAngle)
        XCTAssertEqual(mediaCropAdjustmentLimit(.vertical), mediaEditorCropMaximumPerspectiveAngle)
        XCTAssertEqual(mediaCropAdjustmentLimit(.horizontal), mediaEditorCropMaximumPerspectiveAngle)
        XCTAssertEqual(mediaEditorCropMaximumPerspectiveAngle, 30.0)
    }

    func testLabel() {
        XCTAssertNil(mediaCropAdjustmentLabel(degrees: 0.0))
        XCTAssertNil(mediaCropAdjustmentLabel(degrees: 0.4))
        XCTAssertNil(mediaCropAdjustmentLabel(degrees: -0.4))
        XCTAssertEqual(mediaCropAdjustmentLabel(degrees: 12.0), "12")
        XCTAssertEqual(mediaCropAdjustmentLabel(degrees: -12.3), "-12")
        XCTAssertEqual(mediaCropAdjustmentLabel(degrees: 29.6), "30")
    }

    func testRingProgress() {
        XCTAssertEqual(mediaCropAdjustmentRingProgress(degrees: 0.0, limit: 30.0), 0.0)
        XCTAssertEqual(mediaCropAdjustmentRingProgress(degrees: 30.0, limit: 30.0), 1.0)
        XCTAssertEqual(mediaCropAdjustmentRingProgress(degrees: -15.0, limit: 30.0), 0.5)
        XCTAssertEqual(mediaCropAdjustmentRingProgress(degrees: 40.0, limit: 30.0), 1.0)
    }

    func testDialKeepsTwentyTicksPerSideForEveryLimit() {
        XCTAssertEqual(mediaCropDialDegrees(dialDegrees: mediaCropDialDegreesPerTick, limit: 30.0), 1.5, accuracy: 1e-9)
        XCTAssertEqual(mediaCropDialDegrees(dialDegrees: mediaCropMaximumWheelAngle, limit: 30.0), 30.0, accuracy: 1e-9)
        XCTAssertEqual(mediaCropDialDegrees(dialDegrees: -mediaCropMaximumWheelAngle, limit: mediaCropMaximumWheelAngle), -45.0, accuracy: 1e-9)
        XCTAssertEqual(mediaCropDialDegrees(value: 12.0, limit: 30.0), 18.0, accuracy: 1e-9)
        XCTAssertEqual(mediaCropDialDegrees(dialDegrees: mediaCropDialDegrees(value: -7.25, limit: 30.0), limit: 30.0), -7.25, accuracy: 1e-9)
        XCTAssertEqual(mediaCropDialTicks().filter { $0.degrees > 0.0 }.count, 20)
    }

    func testZeroDotHiddenAtZero() {
        XCTAssertFalse(mediaCropDialShowsZeroDot(visualDegrees: 0.0))
        XCTAssertTrue(mediaCropDialShowsZeroDot(visualDegrees: 2.25))
        XCTAssertTrue(mediaCropDialShowsZeroDot(visualDegrees: -1.2))
    }

    func testTickHapticOnEveryTickButNotOnDetent() {
        XCTAssertTrue(mediaCropDialPlaysTickHaptic(previousIndex: 3, currentIndex: 4, detentReached: false))
        XCTAssertTrue(mediaCropDialPlaysTickHaptic(previousIndex: -2, currentIndex: -5, detentReached: false))
        XCTAssertFalse(mediaCropDialPlaysTickHaptic(previousIndex: 4, currentIndex: 4, detentReached: false))
        XCTAssertFalse(mediaCropDialPlaysTickHaptic(previousIndex: 1, currentIndex: 0, detentReached: true))
    }
}
