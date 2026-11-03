import XCTest
import UIKit
@testable import Display

final class HorizontallyCenteredOriginTests: XCTestCase {
    func test_fits_centeredOnTheFullWidth() {
        // 466 wide, 100 wide element: centered at 183, inside [36, 346].
        XCTAssertEqual(horizontallyCenteredOrigin(width: 100.0, containerWidth: 466.0, minX: 36.0, maxX: 346.0), 183.0)
    }

    func test_crossesTheRightBound_shiftedLeft() {
        // Centered at 133 it would end at 333 > 310.
        XCTAssertEqual(horizontallyCenteredOrigin(width: 200.0, containerWidth: 466.0, minX: 36.0, maxX: 310.0), 110.0)
    }

    func test_crossesTheLeftBound_shiftedRight() {
        XCTAssertEqual(horizontallyCenteredOrigin(width: 200.0, containerWidth: 466.0, minX: 150.0, maxX: 430.0), 150.0)
    }

    func test_widerThanTheBounds_pinnedToTheLeadingBound() {
        XCTAssertEqual(horizontallyCenteredOrigin(width: 400.0, containerWidth: 466.0, minX: 36.0, maxX: 346.0), 36.0)
    }
}
