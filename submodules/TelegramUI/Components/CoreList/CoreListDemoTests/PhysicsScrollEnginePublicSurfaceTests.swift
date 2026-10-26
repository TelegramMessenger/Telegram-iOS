import XCTest
@testable import CoreListDemo

final class PhysicsScrollEnginePublicSurfaceTests: XCTestCase {
    func testDisablingScrollHaltsAndBlocksPan() {
        let engine = PhysicsScrollEngine()
        engine.setEdges(min: 0, max: 10_000)
        engine.setOffset(500)
        XCTAssertTrue(engine.isScrollEnabled)

        engine.isScrollEnabled = false

        XCTAssertEqual(engine.offset, 500)
        XCTAssertFalse(engine.isDecelerating)
        XCTAssertEqual(engine.contentHost.gestureRecognizers?.first?.isEnabled, false)
        XCTAssertFalse(engine.isScrollEnabled)
    }
}
