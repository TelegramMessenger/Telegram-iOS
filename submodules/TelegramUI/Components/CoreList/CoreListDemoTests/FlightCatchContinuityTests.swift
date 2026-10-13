import XCTest
import UIKit
@testable import CoreListDemo

/// Catching a `.keyframe` deceleration must not move the content BACKWARD.
///
/// `catchFlight` freezes the list at `trajectory.offset(catchInstant)` and drops the animation. Both
/// reach the render server in the same transaction, and that transaction is presented at the next
/// frame the pipeline can produce — never the frame the sample was taken in. Until it lands the render
/// server keeps playing the flight, so the last animated frame the user sees is ahead of the value that
/// replaces it, and the content snaps back by `velocity × (that gap)`. The gap is the rest of the
/// main-thread turn plus commit-to-display, which is exactly what grows on a slower device.
final class FlightCatchContinuityTests: XCTestCase {

    // MARK: - Fixture

    /// A real flung flight (the physics core's own bake), launched at layer-local time 0 — matching
    /// `launchFlight`, which emits `boundsOriginKeyframeAnimation(beginTime: localNow())` and parks the
    /// model at `trajectory.finalOffset`.
    private func makeFlungFlight(velocity: CGFloat = -3000) -> KeyframeFlight {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        let core = PhysicsScrollCore(contentHost: host)
        core.setEdges(min: nil, max: nil)
        core.beginDrag()
        core.drag(translation: 0, velocity: velocity)
        core.drag(translation: 0, velocity: velocity)
        _ = core.endDrag(recognizerVelocity: velocity, at: 0)
        return KeyframeFlight(core: core, startTime: 0)
    }

    /// What the render server shows for an ADDITIVE `bounds.origin.y` keyframe animation at layer-local
    /// `t`: the layer's model value plus the animation's own interpolated contribution. Evaluates the
    /// real emitted `CAKeyframeAnimation` (`.linear`, explicit `beginTime`, normalised `keyTimes`) the
    /// way Core Animation does, so this is the presented position and not a re-derivation of the model.
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

    // MARK: - The defect

    /// Non-vacuity witness AND magnitude: the value a catch at `t` installs is behind what the flight is
    /// still presenting one and two frames later, by the travel in between. This is the backward step,
    /// stated in points, from the shipping physics.
    func testAHardStopAtTheCatchInstantIsBehindWhatTheFlightKeepsPresenting() {
        let flight = makeFlungFlight()
        let model = flight.trajectory.finalOffset          // launchFlight parks it here
        let anim = flight.trajectory.boundsOriginKeyframeAnimation(beginTime: flight.startTime)
        let catchAt: TimeInterval = 0.10                   // well inside the flight

        // Exactly `catchFlight`: the trajectory sampled on the main thread's clock.
        let installed = flight.liveOffset(now: catchAt)
        let frame = 1.0 / 60.0
        let oneFrameLate = presented(model: model, anim, at: catchAt + frame)
        let twoFramesLate = presented(model: model, anim, at: catchAt + 2 * frame)

        print("""
        === catch backward step, shipping physics (release velocity 3000 pt/s) ===
        catch installs        \(String(format: "%9.2f", installed))
        still presenting +1f  \(String(format: "%9.2f", oneFrameLate))  \
        step \(String(format: "%.1f", abs(oneFrameLate - installed)))pt
        still presenting +2f  \(String(format: "%9.2f", twoFramesLate))  \
        step \(String(format: "%.1f", abs(twoFramesLate - installed)))pt
        """)

        XCTAssertGreaterThan(abs(oneFrameLate - installed), 10,
                             "one frame of pipeline latency already puts the caught value behind the screen")
        XCTAssertGreaterThan(abs(twoFramesLate - installed), abs(oneFrameLate - installed),
                             "and the step grows with the latency — which is why a slower device is worse")
    }

    // MARK: - The brake

    /// The contract. Whichever frame the catch's transaction is presented on, up to the stop, the layer
    /// shows EXACTLY what the uninterrupted flight would have shown — so there is no step in either
    /// direction, only motion the eye was already tracking. After the stop it holds at the rest offset.
    func testABrakingCatchPresentsTheSameValueAsTheFlightUntilItStops() throws {
        let flight = makeFlungFlight()
        let model = flight.trajectory.finalOffset
        let anim = flight.trajectory.boundsOriginKeyframeAnimation(beginTime: flight.startTime)

        let catchAt: TimeInterval = 0.10
        let stopAt = catchAt + 2.0 / 60.0                  // two frames of pipeline latency
        let brake = try XCTUnwrap(flight.braked(stoppingAt: stopAt))
        let brakeAnim = brake.trajectory.boundsOriginKeyframeAnimation(beginTime: flight.startTime)

        for step in 0...24 {
            let t = catchAt + (stopAt - catchAt) * TimeInterval(step) / 24
            XCTAssertEqual(presented(model: brake.offset, brakeAnim, at: t),
                           presented(model: model, anim, at: t), accuracy: 0.001,
                           "presented value diverges at +\(String(format: "%.1f", (t - catchAt) * 1000))ms")
        }
        // Landing EARLY is the common case on a fast pipeline, and it must be continuous too — this is
        // what a plain forward-projected snap could not give: it would jump ahead by the unspent lead.
        XCTAssertEqual(presented(model: brake.offset, brakeAnim, at: catchAt),
                       presented(model: model, anim, at: catchAt), accuracy: 0.001)
        // …and it comes to rest there rather than carrying on.
        XCTAssertEqual(presented(model: brake.offset, brakeAnim, at: stopAt + 1.0), brake.offset, accuracy: 0.001)
    }

    /// The physics position the engine adopts (the drag baseline, and what the list reads as the scroll
    /// offset) is the flight sampled at the stop — not at the catch. Otherwise the model and the layer
    /// disagree by the whole brake.
    func testTheBrakeRestsAtTheFlightsOwnOffsetForTheStopInstant() throws {
        let flight = makeFlungFlight()
        let stopAt: TimeInterval = 0.12
        let brake = try XCTUnwrap(flight.braked(stoppingAt: stopAt))
        XCTAssertEqual(brake.offset, flight.liveOffset(now: stopAt), accuracy: 0.001)
    }

    /// A coordinate re-base accrued mid-flight lives in `coordinateShift`, and the layer model was slid
    /// by it while the animation kept playing. The brake's rest offset must carry it; its trajectory must
    /// NOT, since the emitted animation is additive and its values are differences within the baked path.
    func testTheBrakeCarriesAnAccruedCoordinateShift() throws {
        let flight = makeFlungFlight()
        flight.beginTick(now: 0.05)
        flight.noteShift(140)
        let stopAt: TimeInterval = 0.12
        let brake = try XCTUnwrap(flight.braked(stoppingAt: stopAt))
        XCTAssertEqual(brake.offset, flight.liveOffset(now: stopAt), accuracy: 0.001)
        XCTAssertEqual(brake.offset - brake.trajectory.finalOffset, 140, accuracy: 0.001)
    }

    /// Nothing left to play — the stop is at or past the end — declines, and the caller keeps today's
    /// plain removal. Exact there: a settled flight already presents its rest offset.
    func testABrakeIsDeclinedWhenThereIsNoPathLeft() {
        let flight = makeFlungFlight()
        XCTAssertNil(flight.braked(stoppingAt: flight.startTime))
        XCTAssertNil(flight.braked(stoppingAt: flight.startTime - 1))
        XCTAssertNotNil(flight.braked(stoppingAt: flight.startTime + flight.duration + 1),
                        "past the end still brakes — it is the whole path, resting where the flight would")
    }

    // MARK: - Truncation

    func testTruncationKeepsThePathExactlyUpToTheCutAndFlatAfterIt() {
        let flight = makeFlungFlight()
        let full = flight.trajectory
        let cut = full.truncated(at: 0.12)

        XCTAssertEqual(cut.duration, 0.12, accuracy: 1e-9)
        for step in 0...48 {
            let t = 0.12 * TimeInterval(step) / 48
            XCTAssertEqual(cut.offset(at: t), full.offset(at: t), accuracy: 1e-9,
                           "history must replay verbatim at t=\(t)")
        }
        XCTAssertEqual(cut.offset(at: 0.5), full.offset(at: 0.12), accuracy: 1e-9, "flat after the cut")
        XCTAssertEqual(cut.finalOffset, full.offset(at: 0.12), accuracy: 1e-9)
        // Degenerate cuts collapse rather than producing an invalid (zero-duration) animation.
        XCTAssertEqual(full.truncated(at: 0).samples.count, 1)
        XCTAssertEqual(full.truncated(at: full.duration + 1).samples.count, full.samples.count)
    }
}
