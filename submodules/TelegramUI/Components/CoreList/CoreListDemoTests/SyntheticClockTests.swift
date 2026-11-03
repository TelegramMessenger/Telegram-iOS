import XCTest
@testable import CoreListDemo

final class SyntheticClockTests: XCTestCase {
    func testInitialNowIsZero() {
        let clock = SyntheticClock()
        XCTAssertEqual(clock.now, 0)
    }

    func testAdvanceAdds() {
        let clock = SyntheticClock()
        clock.advance(by: 1.5)
        XCTAssertEqual(clock.now, 1.5, accuracy: 1e-9)
    }

    func testAdvanceAccumulates() {
        let clock = SyntheticClock()
        clock.advance(by: 0.5)
        clock.advance(by: 0.25)
        clock.advance(by: 0.125)
        XCTAssertEqual(clock.now, 0.875, accuracy: 1e-9)
    }

    func testNegativeAdvanceMovesBackward() {
        let clock = SyntheticClock()
        clock.advance(by: 1.0)
        clock.advance(by: -0.4)
        XCTAssertEqual(clock.now, 0.6, accuracy: 1e-9)
    }
}
