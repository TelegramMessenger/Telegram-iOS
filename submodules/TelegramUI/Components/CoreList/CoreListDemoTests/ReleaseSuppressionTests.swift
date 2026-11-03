import XCTest
import UIKit
@testable import CoreListDemo

/// `ScrollEngine.shouldStopScrollingOnRelease` — the seam a host uses to say "this release was already
/// spent elsewhere, do not fling".
///
/// It exists for the chat: one downward drag both scrolls the history and interactively dismisses the
/// keyboard, because the window's keyboard `WindowPanRecognizer` recognizes simultaneously with the
/// list's pan. The dismissal is decided in touch DELIVERY and the list's release arrives later, in
/// gesture action dispatch, so by the time this predicate is consulted the answer is already known.
///
/// The suppression is expressed as a ZERO-velocity release rather than as "skip deceleration", and the
/// difference is load-bearing: `ReleaseDecision` answers `.stop` for a zero sample, and `.stop` still
/// springs back when the content was released overscrolled. Skipping the release outright would strand
/// an overscrolled list off its edge — the case `test_anOverscrolledSuppressedReleaseStillSpringsBack`
/// pins.
final class ReleaseSuppressionTests: XCTestCase {

    private func makeKeyframeEngine() -> PhysicsScrollEngine {
        let engine = PhysicsScrollEngine()
        engine.contentHost.bounds.size = CGSize(width: 390, height: 844)
        engine.decelerationMode = .keyframe
        engine.setEdges(min: nil, max: nil)
        return engine
    }

    private func pan(_ engine: PhysicsScrollEngine, _ state: UIGestureRecognizer.State,
                     translation: CGFloat, velocity: CGFloat) {
        engine.applyPanUpdate(state: state,
                              translation: CGPoint(x: 0, y: translation),
                              velocity: CGPoint(x: 0, y: velocity),
                              forced: false,
                              isIndirect: false)
    }

    /// A flick fast enough to fly, so every test below is measured against motion that really would
    /// have happened. Matches `FlightLaunchPreconditionTests.test_aRealFlickStillLaunchesAFlight`.
    private func flick(_ engine: PhysicsScrollEngine) {
        pan(engine, .began, translation: -20, velocity: -3000)
        pan(engine, .changed, translation: -60, velocity: -3000)
        pan(engine, .ended, translation: -60, velocity: -3000)
    }

    // MARK: - The suppression itself

    func test_aSuppressedFlickLaunchesNoFlightAndRestsWhereTheFingerLifted() {
        let engine = makeKeyframeEngine()
        engine.shouldStopScrollingOnRelease = { _ in true }
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        pan(engine, .began, translation: -20, velocity: -3000)
        pan(engine, .changed, translation: -60, velocity: -3000)
        let atRelease = engine.offset
        pan(engine, .ended, translation: -60, velocity: -3000)

        XCTAssertFalse(engine.isDecelerating, "the release was claimed elsewhere — nothing carries on")
        XCTAssertNil(published.compactMap { $0 }.first, "and no flight is published")
        XCTAssertEqual(engine.offset, atRelease, accuracy: 0.5, "the content rests where it lifted")
        engine.tearDown()
    }

    func test_theSameFlickFliesWhenTheHostDoesNotClaimIt() {
        let engine = makeKeyframeEngine()
        engine.shouldStopScrollingOnRelease = { _ in false }
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        flick(engine)

        XCTAssertTrue(engine.isDecelerating, "a false predicate changes nothing")
        XCTAssertNotNil(published.compactMap { $0 }.first)
        engine.tearDown()
    }

    func test_noPredicateInstalledIsTheUnchangedBehaviour() {
        let engine = makeKeyframeEngine()
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        flick(engine)

        XCTAssertTrue(engine.isDecelerating)
        XCTAssertNotNil(published.compactMap { $0 }.first)
        engine.tearDown()
    }

    // MARK: - What the suppression must NOT take away

    func test_anOverscrolledSuppressedReleaseStillSpringsBack() {
        let engine = makeKeyframeEngine()
        engine.setEdges(min: 0, max: 1000)
        engine.setOffset(10)                             // 10pt short of the top edge
        engine.shouldStopScrollingOnRelease = { _ in true }

        // Drag well past the edge and flick away from it. Suppressed or not, the content cannot be left
        // outside its edges: `endDrag` reports `.stop`, and `.stop` while overscrolled still installs the
        // spring-back. The distance is large enough that one hand-off frame cannot finish it, so this
        // asserts a live bounce rather than a settle.
        pan(engine, .began, translation: 40, velocity: 1200)
        pan(engine, .changed, translation: 90, velocity: 1200)
        XCTAssertTrue(engine.offset < 0, "released past the min edge")
        pan(engine, .ended, translation: 90, velocity: 1200)

        XCTAssertTrue(engine.isDecelerating, "the bounce is the one motion suppression may not cancel")
        engine.tearDown()
    }

    // MARK: - Lifetime

    func test_thePredicateIsConsultedOnlyAtTheRelease() {
        let engine = makeKeyframeEngine()
        var velocities: [CGFloat] = []
        engine.shouldStopScrollingOnRelease = { velocity in
            velocities.append(velocity)
            return true
        }

        flick(engine)

        XCTAssertEqual(velocities.count, 1, "not on .began, not on each .changed — once, at .ended")
        XCTAssertEqual(velocities.first ?? 0, -3000, accuracy: 1e-9, "and it is handed the release velocity")
        engine.tearDown()
    }

    func test_aSuppressedReleaseDoesNotSuppressTheNextOne() {
        let engine = makeKeyframeEngine()
        var claimNext = true
        engine.shouldStopScrollingOnRelease = { _ in claimNext }

        flick(engine)
        XCTAssertFalse(engine.isDecelerating, "first release claimed")

        // The suppression is a pull, so there is no latch to leak. The zero-velocity release also
        // expires the repeated-flick streak, exactly as a genuinely slow release would — so the second
        // flick flies on its own merits rather than inheriting a compounded multiplier.
        claimNext = false
        flick(engine)

        XCTAssertTrue(engine.isDecelerating, "the following release is unaffected")
        engine.tearDown()
    }
}
