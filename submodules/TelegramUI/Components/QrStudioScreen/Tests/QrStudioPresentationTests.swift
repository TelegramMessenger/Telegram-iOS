import XCTest
@testable import QrStudioScreen

final class QrStudioPresentationTests: XCTestCase {
    func testShortSlowPullSpringsBack() {
        XCTAssertFalse(QrStudioPresentation.shouldDismiss(offset: 60.0, velocity: 200.0, height: 874.0))
    }

    func testLongPullDismisses() {
        XCTAssertTrue(QrStudioPresentation.shouldDismiss(offset: 160.0, velocity: 0.0, height: 874.0))
    }

    func testFlickDismisses() {
        XCTAssertTrue(QrStudioPresentation.shouldDismiss(offset: 40.0, velocity: 900.0, height: 874.0))
    }

    func testUpwardFlickNeverDismisses() {
        XCTAssertFalse(QrStudioPresentation.shouldDismiss(offset: 160.0, velocity: -900.0, height: 874.0))
    }

    func testDragFollowsTheFingerDownAndResistsUp() {
        XCTAssertEqual(QrStudioPresentation.offset(translation: 120.0), 120.0)
        let up = QrStudioPresentation.offset(translation: -120.0)
        XCTAssertLessThan(up, 0.0)
        XCTAssertGreaterThan(up, -40.0)
    }
}
