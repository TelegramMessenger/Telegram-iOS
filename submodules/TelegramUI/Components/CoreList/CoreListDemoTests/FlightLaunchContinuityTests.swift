import XCTest
import UIKit
@testable import CoreListDemo

/// Launching a `.keyframe` deceleration must not step the content FORWARD at the release.
///
/// The drag drives content by model writes (`PhysicsScrollCore.writeOffset` →
/// `contentHost.bounds.origin.y`), so a value computed in one main-thread turn is presented a
/// commit-to-display delay later and the screen advances by exactly one drag step per frame.
/// `launchFlight` then hands the render server a `CAKeyframeAnimation` anchored at `localNow()`,
/// which is evaluated at each frame's own PRESENTATION time — so the first frame the launch
/// transaction lands on is already that same delay into the path. That delay is UIScrollView's
/// synchronous release hand-off, arriving for free. Baking from the handed-off state as well
/// double-counts it and the content jumps forward at the moment the finger lifts.
///
/// This is `FlightCatchContinuityTests` with the sign flipped: there the caught value was BEHIND
/// what the render server was still presenting; here the launched path is AHEAD of what it last
/// presented. Same seam, same cause — a main-thread instant is not a presented instant.
final class FlightLaunchContinuityTests: XCTestCase {

    // MARK: - Fixture

    /// What the render server shows for an ADDITIVE `bounds.origin.y` keyframe animation at layer-local
    /// `t`: the layer's model value plus the animation's own interpolated contribution. Evaluates the
    /// real emitted `CAKeyframeAnimation` (`.linear`, explicit `beginTime`, normalised `keyTimes`) the
    /// way Core Animation does, so this is the presented position and not a re-derivation of the model.
    /// Identical to `FlightCatchContinuityTests`' evaluator.
    private func presented(model: CGFloat, _ anim: CAKeyframeAnimation, at t: CFTimeInterval) -> CGFloat {
        let values = (anim.values as? [NSNumber] ?? []).map { CGFloat($0.doubleValue) }
        let keyTimes = (anim.keyTimes ?? []).map { CGFloat(truncating: $0) }
        guard !values.isEmpty, values.count == keyTimes.count, anim.duration > 0 else { return model }
        let phase = CGFloat((t - anim.beginTime) / anim.duration)
        if phase <= keyTimes[0] { return model + values[0] }
        if phase >= keyTimes[keyTimes.count - 1] { return model + values[values.count - 1] }
        for i in 1..<keyTimes.count where phase <= keyTimes[i] {
            let span = keyTimes[i] - keyTimes[i - 1]
            guard span > 0 else { return model + values[i] }
            let f = (phase - keyTimes[i - 1]) / span
            return model + values[i - 1] + (values[i] - values[i - 1]) * f
        }
        return model + values[values.count - 1]
    }

    /// The last frame of a constant-speed drag: the offset the screen is showing when the finger
    /// lifts, the per-frame step it took to get there (the motion the eye is tracking), and a core
    /// left in exactly the state `handlePan(.ended)` hands `launchFlight`.
    private func dragToRelease(velocity vPerSec: CGFloat,
                               hz: Double) -> (core: PhysicsScrollCore, releaseOffset: CGFloat, stepPerFrame: CGFloat) {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        let core = PhysicsScrollCore(contentHost: host)
        core.setEdges(min: nil, max: nil)
        core.beginDrag()
        var translation: CGFloat = 0
        var writes: [CGFloat] = []
        for _ in 0..<12 {                                  // .began then .changed, one per display frame
            core.drag(translation: translation, velocity: vPerSec)
            writes.append(core.offset)                     // == the host bounds write, i.e. the screen
            translation += vPerSec * CGFloat(1.0 / hz)
        }
        let releaseOffset = core.offset
        let stepPerFrame = writes[writes.count - 1] - writes[writes.count - 2]
        XCTAssertTrue(core.endDrag(recognizerVelocity: vPerSec, at: 0))
        return (core, releaseOffset, stepPerFrame)
    }

    /// `launchFlight`'s bake, with the hand-off applied or rewound.
    private func launchAnimation(core: PhysicsScrollCore,
                                 hz: Double,
                                 handOffFrames: CGFloat,
                                 rewound: Bool) -> (anim: CAKeyframeAnimation, model: CGFloat) {
        let releaseState = (offset: core.offset, velocity: core.decelerationVelocity)
        if handOffFrames > 0 {
            core.applyDecelerationHandOff(frameMs: CGFloat(1000.0 / hz) * handOffFrames)
        }
        if rewound {
            core.reseedDeceleration(offset: releaseState.offset, velocity: releaseState.velocity)
        }
        let traj = core.bakeTrajectory()
        return (traj.boundsOriginKeyframeAnimation(beginTime: 0), traj.finalOffset)   // beginTime = localNow()
    }

    // MARK: - The contract

    /// The first frame the launch transaction is presented on continues the drag's own per-frame step.
    /// One frame of commit-to-display delay is the pipeline's normal depth — the same depth every drag
    /// write already paid — so the flight must be exactly one frame of travel along at that point, not
    /// one frame plus a hand-off.
    func testTheFirstPresentedFlightFrameContinuesTheDragsOwnStep() {
        for hz in [60.0, 120.0] {
            for vPerSec in [CGFloat(-3000), CGFloat(-5700)] {   // a plain flick, and a repeated-flick streak
                let frame = 1.0 / hz
                let drag = dragToRelease(velocity: vPerSec, hz: hz)
                let launch = launchAnimation(core: drag.core, hz: hz,
                                             handOffFrames: PhysicsScrollEngine.releaseHandOffFrames,
                                             rewound: true)
                let step = presented(model: launch.model, launch.anim, at: frame) - drag.releaseOffset
                // The frame the flight covers is DECELERATING travel, so it is legitimately a hair
                // shorter than the constant-velocity drag step it continues (0.998^ms, plus the
                // integrator's pixel rounding). What this has to exclude is the hand-off, which is
                // half a step — an order of magnitude outside this band.
                XCTAssertEqual(step, drag.stepPerFrame, accuracy: Swift.max(1.0, drag.stepPerFrame * 0.05),
                               "\(Int(hz))Hz at \(-vPerSec) pt/s: the release stepped \(step)pt where "
                               + "the drag was stepping \(drag.stepPerFrame)pt")
            }
        }
    }

    /// Non-vacuity AND magnitude: keeping the hand-off in the baked state is the shipped defect, stated
    /// in points. The excess is exactly the hand-off's own travel, which is what identifies it as a
    /// double count rather than a rounding artifact.
    func testKeepingTheHandOffInTheBakedStateStepsTheReleaseForward() {
        for hz in [60.0, 120.0] {
            let frame = 1.0 / hz
            let drag = dragToRelease(velocity: -3000, hz: hz)
            let handOffFrames = PhysicsScrollEngine.releaseHandOffFrames
            let launch = launchAnimation(core: drag.core, hz: hz,
                                         handOffFrames: handOffFrames, rewound: false)
            let step = presented(model: launch.model, launch.anim, at: frame) - drag.releaseOffset
            let excess = step - drag.stepPerFrame
            XCTAssertEqual(excess, handOffFrames * drag.stepPerFrame,
                           accuracy: Swift.max(1.0, drag.stepPerFrame * 0.1),
                           "the forward step is the hand-off's own travel, double-counted")
            XCTAssertGreaterThan(abs(excess), 10, "and it is visible: \(abs(excess))pt at \(Int(hz))Hz")
        }
    }

    /// The core is rewound, not just the bake. `engine.offset` feeds the list's own window geometry, so
    /// it has to describe where the content IS at the launch — the release position — rather than lead
    /// it by the probe's frame. (That the probe still settles a release with nothing left to spend is
    /// `FlightLaunchPreconditionTests`, at the core and at this same seam; the rewind runs only after
    /// the guard has read the probe's verdict, so it cannot reach those cases.)
    func testTheEngineOffsetAtLaunchIsWhereTheContentActuallyIs() {
        let engine = PhysicsScrollEngine()
        engine.contentHost.bounds.size = CGSize(width: 390, height: 844)
        engine.decelerationMode = .keyframe
        engine.setEdges(min: nil, max: nil)
        func pan(_ state: UIGestureRecognizer.State, translation: CGFloat, velocity: CGFloat) {
            engine.applyPanUpdate(state: state,
                                  translation: CGPoint(x: 0, y: translation),
                                  velocity: CGPoint(x: 0, y: velocity),
                                  forced: false, isIndirect: false)
        }
        pan(.began, translation: -20, velocity: -3000)
        pan(.changed, translation: -60, velocity: -3000)
        let atRelease = engine.offset                      // the last value written to the host bounds
        pan(.ended, translation: -60, velocity: -3000)

        XCTAssertTrue(engine.isDecelerating, "non-vacuity: a real flick, so a flight was launched")
        XCTAssertEqual(engine.offset, atRelease, accuracy: 1e-9,
                       "the probe's displacement must not leak into the list's geometry")
        engine.tearDown()
    }

    /// The rewind restores the axis EXACTLY, so the baked path is the one a release with no hand-off
    /// at all would have produced. Full precision: the pixel rounding lives on the write, not on the
    /// integrator's state.
    func testTheRewindReproducesTheUntouchedReleaseBitForBit() {
        let untouched = launchAnimation(core: dragToRelease(velocity: -3000, hz: 120).core,
                                        hz: 120, handOffFrames: 0, rewound: false)
        let rewound = launchAnimation(core: dragToRelease(velocity: -3000, hz: 120).core,
                                      hz: 120, handOffFrames: PhysicsScrollEngine.releaseHandOffFrames,
                                      rewound: true)
        XCTAssertEqual(rewound.model, untouched.model, "same landing")
        let a = (untouched.anim.values as? [NSNumber] ?? []).map { $0.doubleValue }
        let b = (rewound.anim.values as? [NSNumber] ?? []).map { $0.doubleValue }
        XCTAssertEqual(a.count, b.count, "same number of vertices")
        XCTAssertFalse(a.isEmpty, "non-vacuity: there is a path to compare")
        for (i, (x, y)) in zip(a, b).enumerated() {
            XCTAssertEqual(x, y, accuracy: 1e-9, "vertex \(i) diverged")
        }
    }
}
