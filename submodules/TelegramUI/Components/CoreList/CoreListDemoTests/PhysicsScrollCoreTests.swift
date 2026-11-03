import XCTest
import UIKit
@testable import CoreListDemo

final class PhysicsScrollCoreTests: XCTestCase {

    private func makeCore(viewport: CGSize = CGSize(width: 390, height: 800)) -> (PhysicsScrollCore, UIView) {
        let host = UIView(frame: CGRect(origin: .zero, size: viewport))
        let core = PhysicsScrollCore(contentHost: host)
        return (core, host)
    }

    func test_offset_isThePhysicsPosition_notTheHostBounds() {
        // `applyShiftPhysicsOnly` is the one method that deliberately decouples the two (a keyframe flight owns
        // the layer model, which is the additive animation's base). `offset` must follow the PHYSICS, or the
        // list reads the flight's destination as its scroll position — the mid-flight mutation lurch.
        let (core, host) = makeCore()
        core.setOffset(100)
        XCTAssertEqual(core.offset, 100, accuracy: 0.001)
        XCTAssertEqual(host.bounds.origin.y, 100, accuracy: 0.001)

        core.applyShiftPhysicsOnly(250)
        XCTAssertEqual(core.offset, 350, accuracy: 0.001, "offset follows the physics axis")
        XCTAssertEqual(host.bounds.origin.y, 100, accuracy: 0.001, "the layer model is deliberately untouched")
    }

    func test_offset_seedsFromTheHostAtConstruction() {
        // The identity "offset == host bounds origin while nothing is in flight" must hold by construction,
        // not because every caller happens to pass a zero-origin host.
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        host.bounds.origin.y = 420
        let core = PhysicsScrollCore(contentHost: host)
        XCTAssertEqual(core.offset, 420, accuracy: 0.001)
    }

    func test_setOffset_writesHostBounds_doesNotFireOnScroll() {
        let (core, host) = makeCore()
        var fired: [CGFloat] = []
        core.onScroll = { fired.append($0) }
        core.setOffset(120)
        XCTAssertEqual(host.bounds.origin.y, 120, accuracy: 0.001)
        XCTAssertEqual(core.offset, 120, accuracy: 0.001)
        XCTAssertTrue(fired.isEmpty, "programmatic setOffset must not fire onScroll")
    }

    func test_applyShift_addsToOffset_doesNotFireOnScroll() {
        let (core, host) = makeCore()
        core.setOffset(100)
        var fired: [CGFloat] = []
        core.onScroll = { fired.append($0) }
        core.applyShift(30)
        XCTAssertEqual(host.bounds.origin.y, 130, accuracy: 0.001)
        XCTAssertTrue(fired.isEmpty, "programmatic applyShift must not fire onScroll")
    }

    func test_drag_firesOnScroll_andMovesOffset() {
        let (core, _) = makeCore()
        var fired: [CGFloat] = []
        core.onScroll = { fired.append($0) }
        core.beginDrag()
        core.drag(translation: -100, velocity: -800)   // finger up → offset increases
        XCTAssertGreaterThan(core.offset, 0, "dragging up increases the offset")
        XCTAssertFalse(fired.isEmpty, "drag fires onScroll")
        XCTAssertEqual(fired.last!, core.offset, accuracy: 0.001)
    }

    func test_openEdges_freeFlick_decelerates_andSettles() {
        let (core, _) = makeCore()
        core.setEdges(min: nil, max: nil)               // neither edge loaded → free travel both ways
        core.beginDrag()
        core.drag(translation: 0, velocity: -3000)
        core.drag(translation: 0, velocity: -3000)
        XCTAssertTrue(core.endDrag(recognizerVelocity: -3000, at: 0), "a flick decelerates")
        XCTAssertTrue(core.isDecelerating)

        var settled = false
        for _ in 0..<600 where !settled { settled = core.step(dtMs: 1000.0 / 60) }
        XCTAssertTrue(settled, "free flick settles when velocity dies")
        XCTAssertGreaterThan(core.offset, 100, "it coasted forward a meaningful distance")
        XCTAssertFalse(core.isDecelerating)
    }

    func test_cancelDeceleration_stopsDecel_withoutMovingOffset() {
        let (core, _) = makeCore()
        core.setEdges(min: nil, max: nil)
        core.beginDrag()
        core.drag(translation: 0, velocity: -3000)
        core.drag(translation: 0, velocity: -3000)
        XCTAssertTrue(core.endDrag(recognizerVelocity: -3000, at: 0))
        _ = core.step(dtMs: 1000.0 / 60)
        XCTAssertTrue(core.isDecelerating)

        let offsetBefore = core.offset
        core.cancelDeceleration()
        XCTAssertFalse(core.isDecelerating, "deceleration cancelled")
        XCTAssertEqual(core.offset, offsetBefore, accuracy: 0.001, "content held where it caught")
    }

    func test_containerOrigin_parksAtNaturalBaseZero() {
        let (core, _) = makeCore()
        let h: CGFloat = 1000
        XCTAssertEqual(core.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: false), 0, accuracy: 0.001)
        XCTAssertEqual(core.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: true), 0, accuracy: 0.001)
        XCTAssertEqual(core.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: true), -h, accuracy: 0.001)
        XCTAssertEqual(core.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: false), -h / 2, accuracy: 0.001)
    }

    func test_bakeTrajectory_fromFlick_settles() {
        let (core, _) = makeCore()
        core.setEdges(min: nil, max: nil)              // free travel both ways
        core.beginDrag()
        core.drag(translation: 0, velocity: -3000)
        core.drag(translation: 0, velocity: -3000)
        XCTAssertTrue(core.endDrag(recognizerVelocity: -3000, at: 0))
        let traj = core.bakeTrajectory()
        XCTAssertGreaterThan(traj.duration, 0)
        XCTAssertGreaterThan(traj.finalOffset, 100, "coasted forward")
    }

    func test_reseedDeceleration_reAnchors_andBakesFromThere() {
        let (core, _) = makeCore()
        core.setEdges(min: nil, max: nil)
        core.reseedDeceleration(offset: 500, velocity: 2.0)   // 2.0 pts/ms
        let traj = core.bakeTrajectory()
        XCTAssertEqual(traj.samples.first!.offset, 500, accuracy: 0.5, "bakes from the reseeded offset")
        XCTAssertGreaterThan(traj.finalOffset, 500, "continues forward from the reseeded state")
    }

    func test_loadedTopEdge_overscrollDrag_rubberBands_andSpringsBack() {
        let (core, _) = makeCore()
        core.setEdges(min: 0, max: nil)                 // top loaded at offset 0, bottom open
        core.beginDrag()
        core.drag(translation: 200, velocity: 400)      // finger down past the top → offset < 0, resisted
        XCTAssertLessThan(core.offset, 0, "overscrolled past the top")
        XCTAssertGreaterThan(core.offset, -200, "rubber-band resisted (less than the raw 200)")
        XCTAssertTrue(core.endDrag(recognizerVelocity: 400, at: 0), "released while overscrolled → spring back")

        var settled = false
        for _ in 0..<600 where !settled { settled = core.step(dtMs: 1000.0 / 60) }
        XCTAssertTrue(settled)
        XCTAssertEqual(core.offset, 0, accuracy: 0.5, "sprang back to the top edge")
    }

    func test_resumeBounceIfOverscrolled_fromOverscrolledIdle_springsBackToEdge() {
        // Simulate the engine's trackpad-finger-rest catch: physics is .idle (cancelDeceleration was
        // called) but the offset is left overscrolled. resumeBounceIfOverscrolled is the engine's lift
        // handler — it must put the core into .decelerating and spring back to the edge.
        let (core, _) = makeCore()
        core.setEdges(min: 0, max: nil)              // top loaded at offset 0, bottom open
        core.setOffset(-40)                          // overscrolled 40pt past the top, .idle
        XCTAssertFalse(core.isDecelerating, "precondition: idle")
        XCTAssertTrue(core.isOverscrolled, "precondition: overscrolled")

        XCTAssertTrue(core.resumeBounceIfOverscrolled(), "overscrolled idle → decelerating (spring back)")
        XCTAssertTrue(core.isDecelerating)

        var settled = false
        for _ in 0..<600 where !settled { settled = core.step(dtMs: 1000.0 / 60) }
        XCTAssertTrue(settled)
        XCTAssertEqual(core.offset, 0, accuracy: 0.5, "sprang back to the top edge")
    }

    func test_resumeBounceIfOverscrolled_withinEdges_isNoOp() {
        // A trackpad lift on non-overscrolled content must NOT spuriously start a deceleration.
        let (core, _) = makeCore()
        core.setEdges(min: 0, max: 1000)
        core.setOffset(200)                          // well within edges
        XCTAssertFalse(core.isOverscrolled, "precondition: within edges")

        XCTAssertFalse(core.resumeBounceIfOverscrolled(), "within edges: nothing to resume")
        XCTAssertFalse(core.isDecelerating)
        XCTAssertEqual(core.offset, 200, accuracy: 0.001, "offset is unchanged")
    }

    func test_trackpadCoefficient_loosensOverscrollRubberBand_andSpringsBack() {
        // Touch core: default coefficient (0.55).
        let (touch, _) = makeCore()
        touch.setEdges(min: 0, max: nil)                 // top loaded at offset 0, bottom open
        touch.beginDrag()
        touch.drag(translation: 200, velocity: 400)      // finger down past the top → offset < 0, resisted

        // Trackpad core: same geometry/drag, but the looser indirect coefficient (0.715).
        let (trackpad, _) = makeCore()
        trackpad.updateRubberBandCoefficient(RubberBand.trackpadCoefficient)   // BEFORE beginDrag → makePhysics uses it
        trackpad.setEdges(min: 0, max: nil)
        trackpad.beginDrag()
        trackpad.drag(translation: 200, velocity: 400)

        XCTAssertLessThan(touch.offset, 0, "touch overscrolled past the top")
        XCTAssertLessThan(trackpad.offset, 0, "trackpad overscrolled past the top")
        XCTAssertLessThan(trackpad.offset, touch.offset,
                          "trackpad's looser rubber-band (0.715 > 0.55) resists less → further overscroll")

        // The looser drag still springs back to the edge (spring-back is c-independent).
        XCTAssertTrue(trackpad.endDrag(recognizerVelocity: 0, at: 0), "released while overscrolled → spring back")
        var settled = false
        for _ in 0..<600 where !settled { settled = trackpad.step(dtMs: 1000.0 / 60) }
        XCTAssertTrue(settled)
        XCTAssertEqual(trackpad.offset, 0, accuracy: 0.5, "sprang back to the top edge")
    }

    // MARK: - UIScrollView release-path parity

    func test_singleDragFlick_releasesAtFullVelocity_notAQuarter() {
        // The short-flick case: one pan callback (the .began sample) and no .changed. UIKit's guard
        // skips the low-pass entirely, so the release carries the whole velocity.
        let (core, _) = makeCore()
        core.setEdges(min: nil, max: nil)
        core.beginTouchTracking(at: 0)
        core.beginDrag()
        core.drag(translation: -40, velocity: -3000)                 // 3.0 pts/ms of content velocity
        XCTAssertTrue(core.endDrag(recognizerVelocity: -3000, at: 0.05))

        var settled = false
        var steps = 0
        while !settled && steps < 2000 { settled = core.step(dtMs: 1000.0 / 60); steps += 1 }
        XCTAssertTrue(settled)
        // 3.0 pts/ms projects (3.0 − 0.01)/|ln 0.998| ≈ 1493 pt from the release position (offset 40).
        XCTAssertGreaterThan(core.offset, 1400, "a full-strength release coasts ~1.5k points")
    }

    func test_singleDragFlick_nonVacuity_theQuarterStrengthReleaseWouldStopFarShort() {
        // The control: 0.25 · 3.0 = 0.75 pts/ms projects ≈ 370 pt, a quarter of the distance.
        let quarterProjection = (0.25 * 3.0 - 0.01) / abs(log(0.998))
        XCTAssertLessThan(quarterProjection, 400, "the defect's landing, for contrast")
    }

    func test_twoDragFlick_isUnchanged_soEveryExistingFixtureStillAgrees() {
        // Two callbacks at the same velocity: previous == latest, so 0.75p + 0.25l == l either way.
        let (a, _) = makeCore()
        a.setEdges(min: nil, max: nil)
        a.beginTouchTracking(at: 0)
        a.beginDrag()
        a.drag(translation: 0, velocity: -3000)
        a.drag(translation: 0, velocity: -3000)
        XCTAssertTrue(a.endDrag(recognizerVelocity: -3000, at: 0.05))
        let traj = a.bakeTrajectory()
        XCTAssertEqual(traj.finalOffset, 1493, accuracy: 25, "unchanged from the pre-parity model")
    }

    func test_releasedWhileOverscrolled_springsBackEvenWhenTheOutcomeIsStop() {
        let (core, _) = makeCore()
        core.setEdges(min: 0, max: nil)
        core.beginTouchTracking(at: 0)
        core.beginDrag()
        core.drag(translation: 200, velocity: 0)                     // dragged past the top, no flick
        XCTAssertLessThan(core.offset, 0)
        XCTAssertTrue(core.endDrag(recognizerVelocity: 0, at: 0.05),
                      "an overscrolled release springs back regardless of the release outcome")

        var settled = false
        var steps = 0
        while !settled && steps < 2000 { settled = core.step(dtMs: 1000.0 / 60); steps += 1 }
        XCTAssertEqual(core.offset, 0, accuracy: 0.5, "sprang back to the edge")
    }

    /// Four flicks 0.4s apart, each caught mid-deceleration — the repeated-flick burst the fast-scroll
    /// multiplier exists for.
    private func burstOfFourFlicks(_ core: PhysicsScrollCore,
                                   betweenFlicks: (PhysicsScrollCore) -> Void = { _ in }) {
        core.setEdges(min: nil, max: nil)
        for i in 0..<4 {
            core.beginTouchTracking(at: TimeInterval(i) * 0.4)
            core.beginDrag()
            core.drag(translation: -150, velocity: -3000)
            core.drag(translation: -300, velocity: -3000)
            _ = core.endDrag(recognizerVelocity: -3000, at: TimeInterval(i) * 0.4 + 0.05)
            betweenFlicks(core)
        }
    }

    /// The `.stepped` driver's shape. The burst above builds the streak whether or not anything runs
    /// between the flicks — so a test that only flicks proves nothing about the driver. Actually
    /// STEPPING between them is what caught the dead-x-axis defect: `ScrollPhysics.step` ORs the two
    /// axes' "ended a deceleration" flags, and the pinned x axis settles on frame one of every flight,
    /// so the first step after each release cleared the streak and the multiplier stayed at 1 forever.
    func test_decelerationFramesBetweenFlicksDoNotClearTheStreak() {
        let (core, _) = makeCore()
        burstOfFourFlicks(core) { core in
            // ~0.35s of coasting: enough frames to expose a per-frame reset, far short of settling.
            for _ in 0..<21 { _ = core.step(dtMs: 1000.0 / 60) }
        }
        XCTAssertTrue(core.isDecelerating, "still running — nothing legitimately reset the streak")
        XCTAssertGreaterThan(core.decelerationVelocityScale, 1.0,
                             "a deceleration that is still running has not ended")
    }

    /// The `.keyframe` driver's shape — the one the chat ships. It steps the physics exactly once per
    /// release (the hand-off frame) and then bakes; everything after that is a `Trajectory`, so this
    /// single step was the only per-frame reset opportunity, and it fired every time.
    func test_theKeyframeHandOffDoesNotClearTheStreak() {
        let (core, _) = makeCore()
        burstOfFourFlicks(core) { core in
            core.applyDecelerationHandOff(frameMs: 1000.0 / 120.0 * 0.5)
            _ = core.bakeTrajectory()
        }
        XCTAssertGreaterThan(core.decelerationVelocityScale, 1.0,
                             "the hand-off frame must not be what clears the streak")
    }

    /// The same defect stated as the user sees it — distance, not a multiplier. Three consecutive fast
    /// flicks arm the growth and the fourth is the first to spend it, so a burst must carry visibly
    /// farther than the identical flick made alone. While the streak was being cleared every frame the
    /// two were indistinguishable, which is the reported "UIScrollView scrolls much farther".
    func test_theFourthFlickOfABurstTravelsFartherThanTheSameFlickAlone() {
        let (burst, _) = makeCore()
        burstOfFourFlicks(burst) { core in
            core.applyDecelerationHandOff(frameMs: 1000.0 / 120.0 * 0.5)
            _ = core.bakeTrajectory()
        }
        let burstTravel = abs(burst.projectedTarget() - burst.offset)

        let (alone, _) = makeCore()
        alone.setEdges(min: nil, max: nil)
        alone.beginTouchTracking(at: 0)
        alone.beginDrag()
        alone.drag(translation: -150, velocity: -3000)
        alone.drag(translation: -300, velocity: -3000)
        _ = alone.endDrag(recognizerVelocity: -3000, at: 0.05)
        let soloTravel = abs(alone.projectedTarget() - alone.offset)

        // 300pt of drag saturates the growth term (`min(300/240, 0.9)`), and the fourth flick spends
        // exactly one step of it: 1 + 0.9.
        XCTAssertEqual(burstTravel / soloTravel, 1.9, accuracy: 0.02,
                       "burst \(burstTravel) vs solo \(soloTravel)")
    }

    func test_theIntegratorReachingSettleClearsTheStreak() {
        let (core, _) = makeCore()
        burstOfFourFlicks(core)
        XCTAssertGreaterThan(core.decelerationVelocityScale, 1.0, "four fast flicks built a streak")

        var settled = false
        var steps = 0
        while !settled && steps < 20000 { settled = core.step(dtMs: 1000.0 / 60); steps += 1 }
        XCTAssertTrue(settled)
        XCTAssertEqual(core.decelerationVelocityScale, 1.0, accuracy: 1e-9,
                       "settling clears it (0x17a8844), so the carry only survives a catch")
    }
}
