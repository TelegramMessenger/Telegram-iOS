import XCTest
@testable import CoreListDemo

final class TestableScrollViewTests: XCTestCase {
    func testProgrammaticAnimatedScroll_advancesOverTime() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        sv.contentSize = CGSize(width: 390, height: 5000)

        sv.setContentOffset(CGPoint(x: 0, y: 1000), animated: true)
        // Initial offset unchanged before any tick
        XCTAssertEqual(sv.bounds.origin.y, 0)

        // Default duration is 0.3s; tick halfway
        clock.advance(by: 0.15)
        sv.tick(dt: 0.15)
        XCTAssertGreaterThan(sv.bounds.origin.y, 0)
        XCTAssertLessThan(sv.bounds.origin.y, 1000)

        // Tick the rest
        clock.advance(by: 0.15)
        sv.tick(dt: 0.15)
        XCTAssertEqual(sv.bounds.origin.y, 1000, accuracy: 0.5)
    }

    func testProgrammaticAnimatedScroll_firesDelegate() {
        final class Captor: NSObject, UIScrollViewDelegate {
            var count = 0
            func scrollViewDidScroll(_ scrollView: UIScrollView) { count += 1 }
        }
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        sv.contentSize = CGSize(width: 390, height: 5000)

        let captor = Captor()
        sv.delegate = captor

        sv.setContentOffset(CGPoint(x: 0, y: 1000), animated: true)
        clock.advance(by: 0.05)
        sv.tick(dt: 0.05)
        clock.advance(by: 0.05)
        sv.tick(dt: 0.05)

        XCTAssertEqual(captor.count, 2)
    }

    func testNonAnimatedSetContentOffset_isImmediate() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        sv.contentSize = CGSize(width: 390, height: 5000)

        sv.setContentOffset(CGPoint(x: 0, y: 500), animated: false)
        XCTAssertEqual(sv.bounds.origin.y, 500)
    }

    func testTickWithoutActiveScroll_isNoOp() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        sv.contentSize = CGSize(width: 390, height: 5000)

        let initialY = sv.bounds.origin.y
        clock.advance(by: 0.5)
        sv.tick(dt: 0.5)

        XCTAssertEqual(sv.bounds.origin.y, initialY)
    }

    func testStartingNewAnimatedScroll_cancelsPrevious() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        sv.contentSize = CGSize(width: 390, height: 5000)

        sv.setContentOffset(CGPoint(x: 0, y: 1000), animated: true)
        clock.advance(by: 0.1)
        sv.tick(dt: 0.1)
        let midScroll = sv.bounds.origin.y

        sv.setContentOffset(CGPoint(x: 0, y: 200), animated: true)
        // After starting the new animation, the bounds reflects the cancellation start
        XCTAssertEqual(sv.bounds.origin.y, midScroll, accuracy: 0.5)

        clock.advance(by: 0.3)
        sv.tick(dt: 0.3)
        XCTAssertEqual(sv.bounds.origin.y, 200, accuracy: 0.5)
    }

    func testFlick_advancesByVelocity() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        sv.contentSize = CGSize(width: 390, height: 5000)

        sv.simulateFlick(velocity: 1000)  // 1000 pt/s downward
        clock.advance(by: 0.1)
        sv.tick(dt: 0.1)

        // With deceleration 2000 pt/s²: v(0.1) = 1000 - 200 = 800
        // distance = (1000 + 800) / 2 * 0.1 = 90 pt
        XCTAssertEqual(sv.bounds.origin.y, 90, accuracy: 1)
    }

    func testFlick_decelerationStopsAtZeroVelocity() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        sv.contentSize = CGSize(width: 390, height: 5000)

        sv.simulateFlick(velocity: 1000)
        // v / a = 1000 / 2000 = 0.5 s to stop. Total distance = v² / (2a) = 250 pt.
        clock.advance(by: 1.0)
        sv.tick(dt: 1.0)

        XCTAssertEqual(sv.bounds.origin.y, 250, accuracy: 1)
        XCTAssertFalse(sv.isActive)
    }

    func testFlick_negativeVelocityScrollsUp() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.contentSize = CGSize(width: 390, height: 5000)
        sv.bounds = CGRect(x: 0, y: 500, width: 390, height: 800)

        sv.simulateFlick(velocity: -1000)
        clock.advance(by: 1.0)
        sv.tick(dt: 1.0)

        XCTAssertEqual(sv.bounds.origin.y, 250, accuracy: 1)
    }

    func testFlick_firesDelegate() {
        final class Captor: NSObject, UIScrollViewDelegate {
            var count = 0
            func scrollViewDidScroll(_ scrollView: UIScrollView) { count += 1 }
        }
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        sv.contentSize = CGSize(width: 390, height: 5000)
        let captor = Captor()
        sv.delegate = captor

        sv.simulateFlick(velocity: 500)
        clock.advance(by: 0.05); sv.tick(dt: 0.05)
        clock.advance(by: 0.05); sv.tick(dt: 0.05)

        XCTAssertEqual(captor.count, 2)
    }

    func testDragWithinBounds_writesDirectly() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.contentSize = CGSize(width: 390, height: 5000)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)

        sv.simulateDrag(by: 300)
        XCTAssertEqual(sv.bounds.origin.y, 300, accuracy: 0.01)
    }

    func testDragPastTopEdge_appliesResistance() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.contentSize = CGSize(width: 390, height: 5000)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)

        sv.simulateDrag(by: -100)  // pull above top edge by 100 pt

        // With resistance k=2: overshoot' = 100 / (1 + 2*100/800) = 100 / 1.25 = 80 pt
        XCTAssertEqual(sv.bounds.origin.y, -80, accuracy: 1)
    }

    func testDragPastBottomEdge_appliesResistance() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.contentSize = CGSize(width: 390, height: 5000)
        sv.bounds = CGRect(x: 0, y: 4200, width: 390, height: 800)
        sv.simulateDrag(by: 100)  // 100 pt past bottom

        // overshoot' = 100 / 1.25 = 80 → final y = 4200 + 80 = 4280
        XCTAssertEqual(sv.bounds.origin.y, 4280, accuracy: 1)
    }

    func testReleaseAtRest_isNoOp() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.contentSize = CGSize(width: 390, height: 5000)
        sv.bounds = CGRect(x: 0, y: 100, width: 390, height: 800)

        sv.simulateRelease()
        XCTAssertFalse(sv.isActive)
        XCTAssertEqual(sv.bounds.origin.y, 100)
    }

    func testReleasePastTopEdge_rubberBandsReturnToEdge() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.contentSize = CGSize(width: 390, height: 5000)
        sv.bounds = CGRect(x: 0, y: 0, width: 390, height: 800)
        sv.simulateDrag(by: -100)
        let dragged = sv.bounds.origin.y
        XCTAssertLessThan(dragged, 0)

        sv.simulateRelease()
        XCTAssertTrue(sv.isActive)

        // Tick generously; rubber-band should return to edge and settle
        for _ in 0..<200 {
            clock.advance(by: 1.0 / 60)
            sv.tick(dt: 1.0 / 60)
        }
        XCTAssertEqual(sv.bounds.origin.y, 0, accuracy: 0.5)
        XCTAssertFalse(sv.isActive)
    }

    func testReleasePastBottomEdge_rubberBandsToEdge() {
        let clock = SyntheticClock()
        let sv = TestableScrollView(clock: clock)
        sv.contentSize = CGSize(width: 390, height: 5000)
        sv.bounds = CGRect(x: 0, y: 4280, width: 390, height: 800)

        sv.simulateRelease()
        for _ in 0..<200 {
            clock.advance(by: 1.0 / 60)
            sv.tick(dt: 1.0 / 60)
        }
        XCTAssertEqual(sv.bounds.origin.y, 4200, accuracy: 0.5)
        XCTAssertFalse(sv.isActive)
    }
}
