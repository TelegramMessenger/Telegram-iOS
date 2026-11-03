import XCTest
@testable import CoreListDemo

final class TrajectorySpliceTests: XCTestCase {

    /// A simple constant-velocity trajectory in [0, dur] at 1/120 spacing: offset = v0·t.
    private func ramp(v0: CGFloat, dur: TimeInterval, step: TimeInterval = 1.0/120) -> Trajectory {
        var s: [Trajectory.Sample] = []
        var t: TimeInterval = 0
        while t <= dur + 1e-9 {
            s.append(.init(t: t, offset: v0 * CGFloat(t), velocity: v0 / 1000))
            t += step
        }
        return Trajectory(samples: s)
    }

    func test_splice_anchorsAtMaxPrevStartOrNowMinusWindow() {
        let current = ramp(v0: 1000, dur: 3.0)
        let future = ramp(v0: 1000, dur: 2.0)   // future path, its own t=0
        // now = 2.5 into a flight begun at prevBegin = 0.5 (layer-local).
        let r = Trajectory.spliced(current: current, prevBeginTime: 0.5, now: 2.5,
                                   future: future, shift: 0)
        // now - historyWindow(1.0) = 1.5 > prevBegin(0.5) → newBegin = 1.5
        XCTAssertEqual(r.beginTime, 1.5, accuracy: 1e-9)
    }

    func test_splice_clampsToPrevStartWhenFlightYoung() {
        let current = ramp(v0: 1000, dur: 3.0)
        let future = ramp(v0: 1000, dur: 2.0)
        // now=1.0, prevBegin=0.7 → now-1.0 = 0.0 < prevBegin → newBegin = prevBegin
        let r = Trajectory.spliced(current: current, prevBeginTime: 0.7, now: 1.0,
                                   future: future, shift: 0)
        XCTAssertEqual(r.beginTime, 0.7, accuracy: 1e-9)
        // Young-flight, shift=0: the spliced offset at `now` still equals the current path there.
        XCTAssertEqual(r.offset(atGlobal: 1.0), current.offset(at: 1.0 - 0.7), accuracy: 0.5)
    }

    func test_splice_isContinuousInOffsetAndVelocityAtNow() {
        let current = ramp(v0: 800, dur: 3.0)
        let prevBegin = 0.0, now = 1.7, shift: CGFloat = 250
        let localT = now - prevBegin
        let liveNew = current.offset(at: localT) + shift
        // future path continues from liveNew at the same velocity.
        var fs: [Trajectory.Sample] = []
        var t: TimeInterval = 0
        while t <= 2.0 { fs.append(.init(t: t, offset: liveNew + 800 * CGFloat(t), velocity: 0.8)); t += 1.0/120 }
        let future = Trajectory(samples: fs)

        let r = Trajectory.spliced(current: current, prevBeginTime: prevBegin, now: now,
                                   future: future, shift: shift)
        // Sampling the spliced trajectory at `now` is continuous and equals liveNew.
        let atNow = r.offset(atGlobal: now)
        XCTAssertEqual(atNow, liveNew, accuracy: 0.5)
        // Carried history (just before now) equals current(+shift), frame-aligned (no jump).
        let justBefore = r.offset(atGlobal: now - 1.0/120)
        XCTAssertEqual(justBefore, current.offset(at: localT - 1.0/120) + shift, accuracy: 0.5)
        // Velocity at the splice equals the future's launch velocity (the test's namesake).
        XCTAssertEqual(r.velocity(atGlobal: now), 0.8, accuracy: 0.01)
    }

    func test_splice_capsCarriedHistoryToOneSecond() {
        let current = ramp(v0: 1000, dur: 5.0)
        let future = ramp(v0: 1000, dur: 2.0)
        let r = Trajectory.spliced(current: current, prevBeginTime: 0.0, now: 4.0,
                                   future: future, shift: 0)
        // History window is [now-1, now] = [3,4]; future ~2s; at 1/120 that is < ~400 samples.
        XCTAssertLessThan(r.trajectory.samples.count, 400)
        XCTAssertEqual(r.beginTime, 3.0, accuracy: 1e-9)
    }

    func test_boundsOriginKeyframeAnimation_valuesAreNotNegated() {
        let traj = ramp(v0: 1000, dur: 0.5)
        let anim = traj.boundsOriginKeyframeAnimation(beginTime: 7.0)
        XCTAssertEqual(anim.keyPath, "bounds.origin.y")
        XCTAssertTrue(anim.isAdditive)
        XCTAssertEqual(anim.calculationMode, .linear)   // interpolated to each frame — rate-agnostic
        XCTAssertEqual(anim.beginTime, 7.0, accuracy: 1e-9)
        // value(i) = offset(tᵢ) − finalOffset  (NOT negated — bounds.origin.y rises with scroll)
        let first = (anim.values?.first as? NSNumber)?.doubleValue ?? .nan
        XCTAssertEqual(CGFloat(first), traj.samples.first!.offset - traj.finalOffset, accuracy: 0.001)
        let last = (anim.values?.last as? NSNumber)?.doubleValue ?? .nan
        XCTAssertEqual(last, 0, accuracy: 0.001)   // ends at 0 (resolves to model = finalOffset)
    }

    func test_splicedRetimesTheResetOntoTheNewBegin() throws {
        var a = ScrollAxis(offset: 0, min: -1_000_000, max: 1_000_000, range: 800,
                           rate: 0.998, scale: 1, vScale: 4)
        a.beginDrag()
        a.applyRelease(velocity: 3.0)
        let current = Trajectory.build(from: a)

        var b = ScrollAxis(offset: 500, min: -1_000_000, max: 1_000_000, range: 800,
                           rate: 0.998, scale: 1, vScale: 4)
        b.beginDrag()
        b.applyRelease(velocity: 2.0)
        let future = Trajectory.build(from: b)

        let now: TimeInterval = 0.2
        let spliced = Trajectory.spliced(current: current, prevBeginTime: 0, now: now,
                                         future: future, shift: 0)

        // The future path's reset, expressed on the spliced trajectory's own axis.
        let futureReset = try XCTUnwrap(future.multiplierResetTime)
        let expected = (now - spliced.beginTime) + futureReset
        XCTAssertEqual(try XCTUnwrap(spliced.trajectory.multiplierResetTime), expected, accuracy: 1e-9,
                       "a rebake that lost this leaves the streak armed through a settle")
    }
}
