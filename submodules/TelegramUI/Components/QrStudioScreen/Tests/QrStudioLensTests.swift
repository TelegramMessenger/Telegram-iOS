import XCTest
@testable import QrStudioScreen

final class QrStudioLensTests: XCTestCase {
    func testSizeIsADropAtTheStart() {
        let size = QrStudioLens.size(0.2, width: 280.0, height: 48.0)
        XCTAssertEqual(size.width, size.height, accuracy: 4.0)
        XCTAssertLessThan(size.height, 48.0)
    }

    func testSizeIsTheCapsuleAtOne() {
        let size = QrStudioLens.size(1.0, width: 280.0, height: 48.0)
        XCTAssertEqual(size.width, 280.0, accuracy: 0.001)
        XCTAssertEqual(size.height, 48.0, accuracy: 0.001)
    }

    func testOvershootMakesItLarger() {
        let size = QrStudioLens.size(1.08, width: 280.0, height: 48.0)
        XCTAssertGreaterThan(size.width, 280.0)
        XCTAssertGreaterThan(size.height, 48.0)
    }

    func testSizeIsZeroBelowZero() {
        XCTAssertEqual(QrStudioLens.size(-0.1, width: 280.0, height: 48.0), .zero)
    }

    func testOpeningOvershootsAndSettles() {
        XCTAssertEqual(QrStudioLens.opening(0.0), 0.0, accuracy: 0.0001)
        var peak: CGFloat = 0.0
        for i in 0 ... 100 {
            peak = max(peak, QrStudioLens.opening(Double(i) / 100.0 * 0.8))
        }
        XCTAssertGreaterThan(peak, 1.02)
        XCTAssertEqual(QrStudioLens.opening(QrStudioLens.openDuration * 1.6), 1.0)
    }

    func testClosingEndsAtZero() {
        XCTAssertEqual(QrStudioLens.closing(0.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(QrStudioLens.closing(QrStudioLens.closeDuration), 0.0)
        XCTAssertGreaterThan(QrStudioLens.closing(0.1), QrStudioLens.closing(0.3))
    }

    func testOrdinaryToastClosesAfterTheHold() {
        XCTAssertFalse(QrStudioLens.closesAfterHold(holding: 1.0))
        XCTAssertTrue(QrStudioLens.closesAfterHold(holding: 2.0))
    }

    func testWidthApproachesTheTarget() {
        var width: CGFloat = 200.0
        for _ in 0 ..< 30 {
            width = QrStudioLens.approach(width, to: 260.0, dt: 1.0 / 60.0)
        }
        XCTAssertGreaterThan(width, 250.0)
        XCTAssertLessThanOrEqual(width, 260.0)
        XCTAssertEqual(QrStudioLens.approach(259.95, to: 260.0, dt: 1.0 / 60.0), 260.0)
    }

    func testToastGlassColor() {
        let ink = QrStudioColor(0.2, 0.1, 0.4)
        XCTAssertEqual(QrStudioToastView.glassColor(ink: ink, isLight: true), UIColor.black.withAlphaComponent(0.55))
        XCTAssertEqual(QrStudioToastView.glassColor(ink: ink, isLight: false), ink.uiColor.withAlphaComponent(0.55))
    }
}
