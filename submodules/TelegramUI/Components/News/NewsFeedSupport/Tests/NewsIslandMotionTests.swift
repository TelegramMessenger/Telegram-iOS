import XCTest
import CoreGraphics
@testable import NewsFeedSupport

/// The channel island's curves (BottomBar.swift: `Dye`, `LabelRoll`, `RollRenderer`, `press`; spec §2).
final class NewsIslandMotionTests: XCTestCase {
    // MARK: springs

    func testCriticalSpringProgressIsTheClosedForm() {
        let spring = NewsSpring.islandMorph
        let omega = 2.0 * Double.pi / 0.6
        XCTAssertEqual(spring.progress(at: 0.0), 0.0)
        XCTAssertEqual(spring.progress(at: 1.0 / omega), CGFloat(1.0 - 2.0 / M_E), accuracy: 1e-4)
        XCTAssertEqual(spring.progress(at: spring.settlingDuration), 1.0, accuracy: 0.01)
    }

    // The release's damping fraction is 0.32: it overshoots by about a third, which is the island's bounce.
    func testReleaseSpringOvershoots() {
        let spring = NewsSpring.islandPressUp
        let peak = stride(from: 0.0, through: 1.0, by: 0.005).map { spring.progress(at: $0) }.max() ?? 0.0
        XCTAssertGreaterThan(peak, 1.3)
        XCTAssertLessThan(peak, 1.4)
        XCTAssertEqual(spring.progress(at: spring.settlingDuration), 1.0, accuracy: 0.01)
    }

    // `.spring(response: r, dampingFraction: ζ)` is duration r, bounce 1 − ζ.
    func testPressSpringsAreTheMockups() {
        XCTAssertEqual(NewsSpring.islandPressDown.dampingRatio, 0.7, accuracy: 1e-4)
        XCTAssertEqual(NewsSpring.islandPressDown.stiffness, CGFloat(pow(2.0 * Double.pi / 0.14, 2.0)), accuracy: 0.01)
        XCTAssertEqual(NewsSpring.islandPressUp.dampingRatio, 0.32, accuracy: 1e-4)
        XCTAssertEqual(NewsSpring.islandPressUp.stiffness, CGFloat(pow(2.0 * Double.pi / 0.34, 2.0)), accuracy: 0.01)
        XCTAssertEqual(NewsSpring.titleBadge.dampingRatio, 0.9, accuracy: 1e-4)
    }

    // MARK: size and placement

    func testIslandIsTheMockupsWidthForAShortLabel() {
        XCTAssertEqual(newsIslandWidth(labelWidth: 100.0, available: 300.0), 185.0)
    }

    func testIslandGrowsForALongLabel() {
        XCTAssertEqual(newsIslandWidth(labelWidth: 170.0, available: 300.0), 210.0)
    }

    func testIslandNarrowsToTheRoomButNotBelowItsLabel() {
        XCTAssertEqual(newsIslandWidth(labelWidth: 100.0, available: 150.0), 150.0)
        XCTAssertEqual(newsIslandWidth(labelWidth: 170.0, available: 190.0), 202.0)
    }

    func testCapsuleIsCentredWhenItFits() {
        XCTAssertEqual(newsIslandCapsuleFrame(boundsWidth: 386.0, height: 40.0, width: 185.0, leftLimit: 48.0, rightLimit: 338.0), CGRect(x: 100.5, y: 0.0, width: 185.0, height: 40.0))
    }

    // Suggest post and gift on the left, search on the right, on a 320 pt phone: centring would cross the gift button.
    func testCapsuleMovesBetweenTheButtonsWhenCentringWouldCrossOne() {
        XCTAssertEqual(newsIslandCapsuleFrame(boundsWidth: 304.0, height: 40.0, width: 168.0, leftLimit: 88.0, rightLimit: 256.0), CGRect(x: 88.0, y: 0.0, width: 168.0, height: 40.0))
    }

    // An island squeezed wider than the room (its label needs it) still leaves the side buttons their taps.
    func testHitAreaStopsAtTheSideButtons() {
        let capsule = CGRect(x: 81.0, y: 0.0, width: 182.0, height: 40.0)
        XCTAssertEqual(newsIslandHitFrame(capsuleFrame: capsule, leftLimit: 88.0, rightLimit: 256.0), CGRect(x: 88.0, y: 0.0, width: 168.0, height: 40.0))
    }

    func testHitAreaIsTheCapsuleWhenItFits() {
        let capsule = CGRect(x: 100.5, y: 0.0, width: 185.0, height: 40.0)
        XCTAssertEqual(newsIslandHitFrame(capsuleFrame: capsule, leftLimit: 48.0, rightLimit: 338.0), capsule)
    }

    // MARK: paint

    func testPaintStartsAndEndsStill() {
        XCTAssertEqual(NewsIslandDye.at(0.0, toPaint: true).fill, 0.0, accuracy: 1e-6)
        XCTAssertEqual(NewsIslandDye.at(0.0, toPaint: false).fill, 1.0, accuracy: 1e-6)
        XCTAssertEqual(NewsIslandDye.at(0.42, toPaint: true).fill, 1.0, accuracy: 1e-6)
        XCTAssertEqual(NewsIslandDye.at(0.42, toPaint: false).fill, 0.0, accuracy: 1e-6)
        XCTAssertEqual(NewsIslandDye.still(paint: true), NewsIslandDye(fill: 1.0, shine: -1.0, shineAlpha: 0.0))
        XCTAssertEqual(NewsIslandDye.still(paint: false), NewsIslandDye(fill: 0.0, shine: -1.0, shineAlpha: 0.0))
    }

    func testPaintComesInOverTheMockupsSpan() {
        XCTAssertEqual(NewsIslandDye.at(0.02, toPaint: true).fill, 0.0, accuracy: 1e-6)
        XCTAssertEqual(NewsIslandDye.at(0.16, toPaint: true).fill, 0.5, accuracy: 1e-6)
        XCTAssertEqual(NewsIslandDye.at(0.30, toPaint: true).fill, 1.0, accuracy: 1e-6)
    }

    func testPaintGoesOutOverTheMockupsSpan() {
        XCTAssertEqual(NewsIslandDye.at(0.06, toPaint: false).fill, 1.0, accuracy: 1e-6)
        XCTAssertEqual(NewsIslandDye.at(0.20, toPaint: false).fill, 0.5, accuracy: 1e-6)
        XCTAssertEqual(NewsIslandDye.at(0.34, toPaint: false).fill, 0.0, accuracy: 1e-6)
    }

    func testShineSweepsAcrossInAThirdOfASecond() {
        let start = NewsIslandDye.at(0.0, toPaint: true)
        XCTAssertEqual(start.shine, -0.25, accuracy: 1e-6)
        XCTAssertEqual(start.shineAlpha, 0.0, accuracy: 1e-6)
        let middle = NewsIslandDye.at(0.16, toPaint: true)
        XCTAssertEqual(middle.shine, 0.5, accuracy: 1e-6)
        XCTAssertEqual(middle.shineAlpha, 1.0, accuracy: 1e-6)
        let end = NewsIslandDye.at(0.32, toPaint: false)
        XCTAssertEqual(end.shine, 1.25, accuracy: 1e-6)
        XCTAssertEqual(end.shineAlpha, 0.0, accuracy: 1e-6)
    }

    // sin^0.6 is a wide plateau, not a sharp peak: already 0.73 a fifth of the way in.
    func testShineHasAWidePlateau() {
        XCTAssertEqual(NewsIslandDye.at(0.064, toPaint: true).shineAlpha, 0.727, accuracy: 0.001)
    }

    func testShineBandsAreTheMockups() {
        XCTAssertEqual(NewsIslandDye.bands.map { $0.halfWidth }, [0.36, 0.14])
        XCTAssertEqual(NewsIslandDye.bands.map { $0.peak }, [0.35, 0.95])
    }

    // MARK: label roll

    func testRollProgressIsTheMockupsEase() {
        XCTAssertEqual(NewsLabelRoll.progress(0.0), 0.0)
        XCTAssertEqual(NewsLabelRoll.progress(1.0), 1.0)
        XCTAssertEqual(NewsLabelRoll.progress(0.5), CGFloat(1.0 - pow(0.5, 2.2)), accuracy: 1e-6)
        XCTAssertEqual(NewsLabelRoll.progress(2.0), 1.0)
    }

    func testGlyphsRollInAWaveFromLeftToRight() {
        XCTAssertEqual(NewsLabelRoll.local(0.5, index: 0, count: 11), 0.775, accuracy: 1e-6)
        XCTAssertEqual(NewsLabelRoll.local(0.5, index: 10, count: 11), 0.225, accuracy: 1e-6)
        XCTAssertEqual(NewsLabelRoll.local(0.3, index: 10, count: 11), 0.0, accuracy: 1e-6)
        XCTAssertEqual(NewsLabelRoll.local(1.0, index: 10, count: 11), 1.0, accuracy: 1e-6)
        XCTAssertEqual(NewsLabelRoll.local(0.5, index: 0, count: 1), 0.775, accuracy: 1e-6)
    }

    func testOutgoingGlyphLeavesUpwardFadingAndBlurring() {
        let rest = NewsLabelRoll.outgoing(0.0)
        XCTAssertEqual(rest.dy, 0.0, accuracy: 1e-6)
        XCTAssertEqual(rest.alpha, 1.0, accuracy: 1e-6)
        XCTAssertEqual(rest.blur, 0.0, accuracy: 1e-6)
        let half = NewsLabelRoll.outgoing(0.5)
        XCTAssertEqual(half.dy, -4.0, accuracy: 1e-6)
        XCTAssertEqual(half.alpha, 0.3, accuracy: 1e-6)
        XCTAssertEqual(half.blur, 1.75, accuracy: 1e-6)
        let gone = NewsLabelRoll.outgoing(1.0)
        XCTAssertEqual(gone.dy, -16.0, accuracy: 1e-6)
        XCTAssertEqual(gone.alpha, 0.0, accuracy: 1e-6)
        XCTAssertEqual(gone.blur, 3.5, accuracy: 1e-6)
    }

    func testIncomingGlyphArrivesFromBelowAndSnapsPastItsPlace() {
        let start = NewsLabelRoll.incoming(0.0)
        XCTAssertEqual(start.dy, 16.0, accuracy: 1e-6)
        XCTAssertEqual(start.alpha, 0.0, accuracy: 1e-6)
        XCTAssertEqual(start.blur, 3.5, accuracy: 1e-6)
        // The back-out overshoot: just above its place before settling.
        XCTAssertEqual(NewsLabelRoll.incoming(0.8).dy, -0.7424, accuracy: 1e-4)
        let rest = NewsLabelRoll.incoming(1.0)
        XCTAssertEqual(rest.dy, 0.0, accuracy: 1e-6)
        XCTAssertEqual(rest.alpha, 1.0, accuracy: 1e-6)
        XCTAssertEqual(rest.blur, 0.0, accuracy: 1e-6)
    }
}
