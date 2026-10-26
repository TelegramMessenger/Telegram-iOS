import XCTest
import CoreGraphics
import Foundation
import QuartzCore
@testable import CoreListDemo

final class TrajectoryTests: XCTestCase {
    /// The trajectory vertices are `ScrollAxis.step`'s pixel-rounded writes, so the rounding `scale`
    /// sets the vertex granularity. The list engine must round to DEVICE PIXELS (like UIScrollView and
    /// the physics demo), not whole points — `PhysicsScrollEngine.refreshScale` feeds the host's real
    /// display scale into the core (it used to default to scale 1 = whole-point vertices). This pins
    /// that scale is the lever for vertex granularity.
    func test_decelGranularity_scale1IsWholePoints_displayScaleIsFiner() {
        func bake(scale: CGFloat) -> Trajectory {
            var p = ScrollPhysics(
                x: ScrollAxis(offset: 0, min: 0, max: 0, range: 400, rate: 0.998, scale: scale),
                y: ScrollAxis(offset: 0, min: -10_000_000, max: 10_000_000, range: 800, rate: 0.998, scale: scale))
            p.beginDrag()
            // Two zero-translation frames load endDrag's velocity low-pass without moving the offset.
            p.drag(translation: .zero)
            p.applyRelease(velocity: CGPoint(x: 0, y: 0.7))   // was drag(-700)×2 + endDrag
            return Trajectory.build(from: p.y)
        }
        func minNonzeroStep(_ t: Trajectory) -> CGFloat {
            var m = CGFloat.greatestFiniteMagnitude
            for i in 1..<t.samples.count {
                let d = abs(t.samples[i].offset - t.samples[i - 1].offset)
                if d > 1e-6 { m = Swift.min(m, d) }
            }
            return m
        }
        // scale 1 quantizes every vertex to a whole point → the smallest move is a 1pt SNAP.
        XCTAssertEqual(minNonzeroStep(bake(scale: 1)), 1.0, accuracy: 1e-6)
        // a real display scale (e.g. 3x) rounds to 1/scale pt → finer smallest move, no whole-point snap.
        XCTAssertEqual(minNonzeroStep(bake(scale: 3)), 1.0 / 3, accuracy: 1e-6)
    }

    func testInterpolatesAndClampsLinearly() {
        let traj = Trajectory(samples: [
            .init(t: 0,   offset: 0,  velocity: 2),
            .init(t: 0.5, offset: 50, velocity: 1),
            .init(t: 1.0, offset: 75, velocity: 0),
        ])
        XCTAssertEqual(traj.duration, 1.0, accuracy: 1e-12)
        XCTAssertEqual(traj.finalOffset, 75, accuracy: 1e-12)

        // LINEAR: interpolated between bracketing vertices (matching the `.linear` keyframe playback).
        XCTAssertEqual(traj.offset(at: -1),   0,    accuracy: 1e-12) // clamp below
        XCTAssertEqual(traj.offset(at: 0.25), 25,   accuracy: 1e-9)  // midway in [0, 0.5]
        XCTAssertEqual(traj.offset(at: 0.75), 62.5, accuracy: 1e-9)  // midway in [0.5, 1.0]
        XCTAssertEqual(traj.offset(at: 2),    75,   accuracy: 1e-12) // clamp above

        XCTAssertEqual(traj.velocity(at: 0.25), 1.5, accuracy: 1e-9)
    }

    func testEmptyAndSingleSampleAreSafe() {
        let empty = Trajectory(samples: [])
        XCTAssertEqual(empty.duration, 0, accuracy: 1e-12)
        XCTAssertEqual(empty.offset(at: 0.3), 0, accuracy: 1e-12)

        let one = Trajectory(samples: [.init(t: 0, offset: 42, velocity: 0)])
        XCTAssertEqual(one.finalOffset, 42, accuracy: 1e-12)
        XCTAssertEqual(one.offset(at: 5), 42, accuracy: 1e-12)
    }

    /// A released axis in its post-endDrag .decelerate state.
    private func releasedAxis(offset: CGFloat = 100, velocityPtsPerSec: CGFloat = -2000) -> ScrollAxis {
        var a = ScrollAxis(offset: offset, min: 0, max: 2000, range: 600, rate: 0.998, scale: 2)
        a.beginDrag()
        a.drag(translation: 0)
        a.applyRelease(velocity: -velocityPtsPerSec * 0.001)  // was drag(v)×2 + endDrag: 0.75·v + 0.25·v
        return a
    }

    func testBuildVerticesAreScrollAxisStepWrites() {
        let axis = releasedAxis()
        let traj = Trajectory.build(from: axis, stepMs: 1000.0 / 120.0)

        // t == 0 vertex is the exact release offset (no jump at launch).
        XCTAssertEqual(traj.samples.first!.t, 0, accuracy: 1e-12)
        XCTAssertEqual(traj.samples.first!.offset, axis.offset, accuracy: 1e-9)

        // Every later vertex is ScrollAxis.step's pixel-rounded write, frame-for-frame (exact).
        var ref = axis
        for i in 1..<traj.samples.count {
            let (written, _, _) = ref.step(dtMs: 1000.0 / 120.0)
            XCTAssertEqual(traj.samples[i].offset, written, accuracy: 1e-9)
            XCTAssertEqual(traj.samples[i].t, Double(i) * (1000.0 / 120.0) / 1000.0, accuracy: 1e-9)
        }
        XCTAssertGreaterThan(traj.duration, 0)
        XCTAssertGreaterThan(traj.finalOffset, axis.offset) // flicked forward, so it moved forward
    }

    func testBuildTerminatesAndSettles() {
        let traj = Trajectory.build(from: releasedAxis(velocityPtsPerSec: -4000))
        XCTAssertLessThan(traj.duration, 10.0)              // under the safety cap
        XCTAssertGreaterThanOrEqual(traj.samples.count, 2)
    }

    /// The offline 1/120 build and a 60Hz stepping loop on the same released axis settle to the same
    /// point — ≤0.5px observed (the scale-2 grid); the 2px assertion tolerance is headroom.
    func testKeyframeBuildMatchesSteppedLoopAtSettle() {
        let axis = releasedAxis(velocityPtsPerSec: -3000)

        // (a) offline keyframe build at 1/120
        let traj = Trajectory.build(from: axis, stepMs: 1000.0 / 120.0)

        // (b) the current per-frame driver: step the same release at 60Hz to settle
        var stepped = axis
        var lastWritten = stepped.offset
        var guardCount = 0
        while guardCount < 100_000 {
            let (written, settled, _) = stepped.step(dtMs: 1000.0 / 60.0)
            lastWritten = written
            guardCount += 1
            if settled { break }
        }

        XCTAssertEqual(traj.finalOffset, lastWritten, accuracy: 2.0)
    }

    func testKeyframeAnimationIsAdditiveAndEndsAtZero() {
        let traj = Trajectory(samples: [
            .init(t: 0,   offset: 0,  velocity: 2),
            .init(t: 0.5, offset: 60, velocity: 1),
            .init(t: 1.0, offset: 80, velocity: 0),
        ])
        let anim = traj.positionKeyframeAnimation(beginTime: 7)

        XCTAssertEqual(anim.keyPath, "position.y")
        XCTAssertTrue(anim.isAdditive)
        XCTAssertEqual(anim.calculationMode, .linear)   // interpolated to each frame — rate-agnostic
        XCTAssertEqual(anim.duration, 1.0, accuracy: 1e-12)
        XCTAssertEqual(anim.beginTime, 7, accuracy: 1e-12)

        // Additive values are (finalOffset - offset(t)): 80-0, 80-60, 80-80 -> ends at 0.
        let values = (anim.values as! [NSNumber]).map { CGFloat($0.doubleValue) }
        XCTAssertEqual(values, [80, 20, 0])

        let keyTimes = (anim.keyTimes ?? []).map { $0.doubleValue }
        XCTAssertEqual(keyTimes, [0, 0.5, 1.0])
    }

    // MARK: - The fast-scroll reset, re-timed onto a baked path

    /// A released axis carrying a fast-scroll multiplier.
    private func scaledAxis(max: CGFloat, velocity: CGFloat = 3.0, vScale: CGFloat = 4) -> ScrollAxis {
        var a = ScrollAxis(offset: 0, min: -1_000_000, max: max, range: 800,
                           rate: 0.998, scale: 1, vScale: vScale)
        a.beginDrag()
        a.applyRelease(velocity: velocity)
        return a
    }

    func test_buildRecordsWhenTheIntegratorEndedTheDeceleration() throws {
        let traj = Trajectory.build(from: scaledAxis(max: 1_000_000))
        let reset = try XCTUnwrap(traj.multiplierResetTime,
                                  "a free flick settles, and settling clears the multiplier")
        XCTAssertEqual(reset, traj.duration, accuracy: 1e-9,
                       "for a free flick the reset IS the settle, at the end of the path")
    }

    func test_buildRecordsAnEarlyResetWhenThePathHitsAnEdge() throws {
        let traj = Trajectory.build(from: scaledAxis(max: 200))
        let reset = try XCTUnwrap(traj.multiplierResetTime)
        XCTAssertLessThan(reset, traj.duration * 0.5,
                          "entering the spring resets long before the bounce finishes (0x17a87bc)")
    }

    func test_truncatedDropsAResetItCutAway() throws {
        let traj = Trajectory.build(from: scaledAxis(max: 1_000_000))
        let reset = try XCTUnwrap(traj.multiplierResetTime)
        let cut = traj.truncated(at: reset * 0.5)

        XCTAssertNil(cut.multiplierResetTime,
                     "the cut precedes the reset, so the path no longer reaches it")
    }

    func test_truncatedKeepsAResetItRetains() throws {
        let traj = Trajectory.build(from: scaledAxis(max: 200))
        let reset = try XCTUnwrap(traj.multiplierResetTime)
        let cut = traj.truncated(at: (reset + traj.duration) * 0.5)

        XCTAssertEqual(try XCTUnwrap(cut.multiplierResetTime), reset, accuracy: 1e-12,
                       "the reset survives a cut after it")
    }
}
