import XCTest
import UIKit
@testable import CoreListDemo

/// `KeyframeFlight` asserts it is built from a core in `.decelerating` state, and
/// `PhysicsScrollEngine.launchFlight` is the only production site that builds one. Between
/// `endDrag` returning `.decelerate` and that construction sits `applyDecelerationHandOff` — a REAL
/// integration frame, so it can also END the deceleration it was handed, reaching
/// `KeyframeFlight(core:)` with the core already back at `.idle`.
///
/// Two releases decelerate with no motion left to spend, and both settle inside that one step:
///
/// - the low-pass cancels. The decelerate/stop threshold reads the RAW latest sample and the
///   0.75/0.25 blend runs AFTER it, so a finger that reverses just before lifting releases above the
///   threshold at a blended velocity of ~0 — below the integrator's own `velocityFloor`;
/// - a release while overscrolled by less than `Deceleration.settleTolerance`, which springs back
///   inside the tolerance in one frame.
final class FlightLaunchPreconditionTests: XCTestCase {

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

    // MARK: - The two releases that decelerate with nothing left to spend

    func test_aReleaseWhoseLowPassCancelsSettlesInsteadOfLaunchingAFlight() {
        let engine = makeKeyframeEngine()
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        // The finger reverses on its last sample: latest = 0.3 pts/ms clears the 0.25 threshold, and
        // 0.75·(−0.1) + 0.25·(0.3) == 0 is what the release actually carries.
        pan(engine, .began, translation: 5, velocity: 100)
        pan(engine, .changed, translation: -10, velocity: -300)
        let atRelease = engine.offset
        pan(engine, .ended, translation: -10, velocity: -300)

        XCTAssertFalse(engine.isDecelerating, "no motion left — the release settles where it lifted")
        XCTAssertNil(published.compactMap { $0 }.first, "a settled release publishes no flight")
        XCTAssertEqual(engine.offset, atRelease, accuracy: 0.5, "and does not jump")
        engine.tearDown()
    }

    func test_aReleaseOverscrolledInsideTheSettleToleranceSettlesInsteadOfLaunchingAFlight() {
        let engine = makeKeyframeEngine()
        engine.setEdges(min: 0, max: 1000)
        engine.setOffset(10)                         // 10pt short of the top edge
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        // Drag to the edge and pause before lifting — the everyday way to reach an edge. 10.5pt of
        // finger travel from 10pt out lands 0.5pt past it, which the rubber band compresses to
        // ~0.27pt, and the pause releases below the decelerate threshold. That is `.stop`, but an
        // overscrolled release springs back regardless, so `endDrag` still reports deceleration —
        // for a bounce one hand-off frame brings inside `Deceleration.settleTolerance`.
        pan(engine, .began, translation: 10.5, velocity: 0)
        pan(engine, .ended, translation: 10.5, velocity: 0)

        XCTAssertFalse(engine.isDecelerating, "the spring-back finished inside the hand-off frame")
        XCTAssertNil(published.compactMap { $0 }.first, "a settled release publishes no flight")
        engine.tearDown()
    }

    // MARK: - Non-vacuity

    func test_aRealFlickStillLaunchesAFlight() {
        let engine = makeKeyframeEngine()
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        pan(engine, .began, translation: -20, velocity: -3000)
        pan(engine, .changed, translation: -60, velocity: -3000)
        pan(engine, .ended, translation: -60, velocity: -3000)

        XCTAssertTrue(engine.isDecelerating)
        XCTAssertNotNil(published.compactMap { $0 }.first, "a real release still flies")
        engine.tearDown()
    }

    // MARK: - Why: the hand-off is an integration frame, and it can settle what it is handed

    func test_theHandOffCanEndTheDecelerationItWasHanded_lowPassCancels() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let core = PhysicsScrollCore(contentHost: host)
        core.setEdges(min: nil, max: nil)
        core.beginDrag()
        core.drag(translation: 5, velocity: 100)
        core.drag(translation: -10, velocity: -300)

        XCTAssertTrue(core.endDrag(recognizerVelocity: -300, at: 0), "raw 0.3 pts/ms clears the threshold")
        XCTAssertTrue(core.isDecelerating, "…so the release installs a deceleration")
        XCTAssertEqual(core.decelerationVelocity, 0, accuracy: 1e-9, "carrying the cancelled blend")

        core.applyDecelerationHandOff(frameMs: 1000.0 / 120.0 * 0.5)
        XCTAssertFalse(core.isDecelerating, "one integration frame settles it — the flight's precondition is gone")
    }

    func test_theHandOffCanEndTheDecelerationItWasHanded_aBounceAlreadyInsideTheTolerance() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let core = PhysicsScrollCore(contentHost: host)
        core.setEdges(min: 0, max: 1000)
        core.setOffset(10)
        core.beginDrag()
        core.drag(translation: 10.5, velocity: 0)          // 0.5pt past the edge, banded to ~0.27pt
        XCTAssertTrue(core.isOverscrolled)

        XCTAssertTrue(core.endDrag(recognizerVelocity: 0, at: 0), "an overscrolled release springs back")
        XCTAssertTrue(core.isDecelerating)

        core.applyDecelerationHandOff(frameMs: 1000.0 / 120.0 * 0.5)
        XCTAssertFalse(core.isDecelerating, "the spring landed inside the tolerance in that one frame")
    }

    func test_aBounceRestsExactlyAtTheEdgeAtDevicePixelScale() {
        // This asserted the OPPOSITE until `Deceleration.settleIfNeeded` clamped the settle. The
        // spring's rest is pixel-ROUNDED and on a 3× device that grid has no vertex at the edge from
        // the outside, so every bounce at every release speed came to rest at exactly −1/3 pt and
        // STAYED there — `settled()` accepts anything within `settleTolerance` and nothing moved it
        // afterwards.
        //
        // It is a real `UIScrollView` divergence: its bounce lands exactly on `-contentInset`, and
        // consumers are written against that. It shipped as a chat bug. `ChatHistoryListNodeImpl`
        // reads `visibleContentOffset() < -0.1` as "still overscrolled" and kept its next-channel
        // control — a transparent 94pt host view — alive over the bottom of the chat permanently,
        // swallowing every tap there. Nothing ever re-reported a corrected offset, because the list
        // was genuinely at rest and this backend has no per-frame hook there. The control drew at
        // zero expansion (`max(0.333 - 12, 0)`), so it looked like nothing was on screen at all.
        //
        // The tolerance is unchanged — it is what lets the spring stop in finite time. It just may
        // not leave the offset where it stopped.
        //
        // This does NOT retire the overscrolled-release precondition above: a drag can still be
        // RELEASED while inside the tolerance, which is what those tests construct. It only stops a
        // bounce from parking there on its own, which is what made it an everyday gesture.
        for v in [800.0, 1500.0, 3000.0, 5000.0] as [CGFloat] {
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let core = PhysicsScrollCore(contentHost: host)
            core.updateScale(3)
            core.setEdges(min: 0, max: 1000)
            core.setOffset(300)
            core.beginDrag()
            core.drag(translation: 100, velocity: v)           // finger down ⇒ content toward the min edge
            core.drag(translation: 200, velocity: v)
            XCTAssertTrue(core.endDrag(recognizerVelocity: v, at: 0))

            XCTAssertEqual(core.bakeTrajectory().finalOffset, 0.0, accuracy: 1e-6,
                           "v=\(v): the bounce comes to rest exactly on the edge")
        }
    }

    func test_aBounceRestsExactlyAtItsEdge_atEveryDeviceScaleAndBothEdges() {
        // The ⅓pt grid at 3× is what made the residue visible, but the clamp is scale- and
        // edge-symmetric and nothing may reintroduce a resting overscroll at any of them. Scale 1 is
        // what the rest of the suite runs at, where the old rounding landed on −0.0 and hid the
        // defect completely; scale 2 is the other shipping grid.
        func makeCore(scale: CGFloat) -> PhysicsScrollCore {
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let core = PhysicsScrollCore(contentHost: host)
            core.updateScale(scale)
            core.setEdges(min: 0, max: 1000)
            return core
        }

        for scale in [CGFloat(1), 2, 3] {
            for v in [800.0, 3000.0, 5000.0] as [CGFloat] {
                let low = makeCore(scale: scale)
                low.setOffset(300)
                low.beginDrag()
                low.drag(translation: 100, velocity: v)      // finger down ⇒ content toward the min edge
                low.drag(translation: 200, velocity: v)
                XCTAssertTrue(low.endDrag(recognizerVelocity: v, at: 0))
                XCTAssertEqual(low.bakeTrajectory().finalOffset, 0.0, accuracy: 1e-6,
                               "scale=\(scale) v=\(v): the min-edge bounce rests on the edge")

                let high = makeCore(scale: scale)
                high.setOffset(700)
                high.beginDrag()
                high.drag(translation: -100, velocity: -v)   // and the mirror, toward the max edge
                high.drag(translation: -200, velocity: -v)
                XCTAssertTrue(high.endDrag(recognizerVelocity: -v, at: 0))
                XCTAssertEqual(high.bakeTrajectory().finalOffset, 1000.0, accuracy: 1e-6,
                               "scale=\(scale) v=\(v): the max-edge bounce rests on the edge")
            }
        }
    }

    func test_theSteppedDriverAlsoComesToRestInsideItsEdges() {
        // The clamp lives in `Deceleration`, which both drivers step, so `.stepped` must inherit it —
        // and it is the mode a host can select at runtime. Stated as the invariant the chat actually
        // depends on ("at rest ⇒ not overscrolled") rather than as an offset, since that is what a
        // consumer comparing against a small threshold is really asking.
        for scale in [CGFloat(1), 2, 3] {
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let core = PhysicsScrollCore(contentHost: host)
            core.updateScale(scale)
            core.setEdges(min: 0, max: 1000)
            core.setOffset(300)
            core.beginDrag()
            core.drag(translation: 100, velocity: 3000)
            core.drag(translation: 200, velocity: 3000)
            XCTAssertTrue(core.endDrag(recognizerVelocity: 3000, at: 0))

            var steps = 0
            while !core.step(dtMs: 1000.0 / 120.0), steps < 2000 { steps += 1 }
            XCTAssertLessThan(steps, 2000, "scale=\(scale): the deceleration settled")
            XCTAssertFalse(core.isOverscrolled, "scale=\(scale): and it settled INSIDE its edges")
        }
    }

    func test_aBareTouchOnContentRestingPastTheEdgeSettlesInsideTheHandOff() {
        // The widest form of the same trigger: nothing about the gesture is unusual, the content is
        // simply already sitting inside the tolerance. `PhysicsScrollEngine.handleTouchUp` routes a
        // bare tap here, and `endDrag`'s `.stop` branch reaches it for any sub-threshold release.
        //
        // The offset is constructed directly. A bounce no longer parks here (see
        // `test_aBounceRestsExactlyAtTheEdgeAtDevicePixelScale`), but a release inside the tolerance
        // still reaches this state, so the precondition it guards is live.
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let core = PhysicsScrollCore(contentHost: host)
        core.updateScale(3)
        core.setEdges(min: 0, max: 1000)
        core.setOffset(-1.0 / 3.0)                             // inside `settleTolerance`, outside the edge

        XCTAssertTrue(core.resumeBounceIfOverscrolled(), "still overscrolled ⇒ spring back")
        XCTAssertTrue(core.isDecelerating)

        core.applyDecelerationHandOff(frameMs: 1000.0 / 120.0 * 0.5)
        XCTAssertFalse(core.isDecelerating, "one third of a point springs home in that one frame")
    }
}
