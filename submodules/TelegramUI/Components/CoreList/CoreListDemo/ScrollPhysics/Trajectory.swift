import CoreGraphics
import Foundation

/// A precomputed scroll deceleration/bounce path — `(time → offset)` sampled forward from a released
/// `ScrollAxis`. Pure value type: built offline, baked into a `CAKeyframeAnimation`, and sampled back
/// by layer-local time. See docs/plans/2026-05-24-keyframe-deceleration-design.md.
struct Trajectory {
    struct Sample {
        let t: TimeInterval   // seconds from launch; t == 0 is the release position
        let offset: CGFloat   // content offset (pixel-rounded write, except the t == 0 release sample)
        let velocity: CGFloat // pts/ms, full precision
    }

    let samples: [Sample]

    /// Seconds from this path's own `t == 0` at which the integrator ended its deceleration —
    /// entering the bounce spring or settling — which is where `_getBouncingDecelerationOffset`
    /// clears `_fastScrollMultiplier` (`0x17a87bc` / `0x17a8844`). `nil` if the path never gets there.
    ///
    /// A baked path has no per-frame hook, so the engine's sampling tick clears the streak when it
    /// passes this time. **`spliced` and `truncated` must carry it**: a rebake that loses it leaves
    /// the streak armed through a settle that should have cleared it, so the next flick inside the
    /// 1 s window compounds on a multiplier it did not earn — a chat that flings further each time
    /// until the user pauses.
    let multiplierResetTime: TimeInterval?

    init(samples: [Sample], multiplierResetTime: TimeInterval? = nil) {
        self.samples = samples
        self.multiplierResetTime = multiplierResetTime
    }

    var duration: TimeInterval { samples.last?.t ?? 0 }
    var finalOffset: CGFloat { samples.last?.offset ?? samples.first?.offset ?? 0 }

    /// The offset band the path occupies from `t` (seconds, clamped) onward, including any rubber-band
    /// excursion beyond an edge. Since `Deceleration.step` is edge-INDEPENDENT until the offset crosses an
    /// edge, this band is what decides whether a given edge takes part in the motion at all (see
    /// `KeyframeFlight.noteEdgesChanged`). The interpolated position AT `t` is included, so the band is
    /// continuous with what has already played.
    func offsetExtent(from t: TimeInterval = 0) -> (min: CGFloat, max: CGFloat) {
        var lo = offset(at: t)
        var hi = lo
        for s in samples where s.t > t {
            lo = Swift.min(lo, s.offset)
            hi = Swift.max(hi, s.offset)
        }
        return (lo, hi)
    }

    /// Content offset at `t` (seconds), clamped to `[0, duration]` and linearly interpolated between
    /// bracketing samples — matching the `.linear` keyframe animation's own interpolation, so the
    /// sampler tracks what the render server shows at any display refresh rate.
    func offset(at t: TimeInterval) -> CGFloat { interpolate(at: t) { $0.offset } }

    /// Velocity (pts/ms) at `t`, clamped + linearly interpolated the same way. NOTE the last sample's
    /// velocity is the integrator's residual at settle (below the 0.01 pts/ms floor), NOT snapped to 0.
    func velocity(at t: TimeInterval) -> CGFloat { interpolate(at: t) { $0.velocity } }

    private func interpolate(at t: TimeInterval, _ field: (Sample) -> CGFloat) -> CGFloat {
        guard let first = samples.first, let last = samples.last else { return 0 }
        if t <= first.t { return field(first) }
        if t >= last.t { return field(last) }
        for i in 1..<samples.count {           // strictly increasing t; linear scan (paths are short)
            let hi = samples[i]
            if t <= hi.t {
                let lo = samples[i - 1]
                let span = hi.t - lo.t
                guard span > 0 else { return field(hi) }
                let frac = CGFloat((t - lo.t) / span)
                return field(lo) + (field(hi) - field(lo)) * frac
            }
        }
        return field(last)
    }
}

extension Trajectory {
    /// Max carried history when rebaking, in seconds. Caps the spliced keyframe count while giving CA
    /// a well-defined recent past across the animation swap. (Design §3.)
    static let historyWindow: TimeInterval = 1.0

    /// This path up to `t` (seconds from launch), coming to rest there — every vertex before `t`
    /// verbatim, then the interpolated sample AT `t` as the endpoint. `offset(at:)` is therefore
    /// UNCHANGED for every time ≤ `t` and constant after it.
    ///
    /// That exactness is the whole point: replayed as a keyframe animation on the SAME `beginTime`,
    /// this presents pixel-for-pixel what the full path presents until `t`, so swapping one for the
    /// other mid-flight is invisible no matter which frame the swap lands on. `KeyframeFlight.braked`
    /// uses it to stop a caught flight without the render server ever stepping backward.
    func truncated(at t: TimeInterval) -> Trajectory {
        guard let first = samples.first else { return self }
        // A cut before the reset means the path no longer reaches it; a cut after it retains it.
        let retainedReset = multiplierResetTime.flatMap { $0 <= t + 1e-9 ? $0 : nil }
        if t <= first.t { return Trajectory(samples: [first], multiplierResetTime: retainedReset) }
        if t >= duration { return self }
        var out = samples.filter { $0.t < t - 1e-9 }
        out.append(Sample(t: t, offset: offset(at: t), velocity: velocity(at: t)))
        return Trajectory(samples: out, multiplierResetTime: retainedReset)
    }
}

/// A rebaked trajectory plus the layer-local time it should be played from.
struct SplicedTrajectory {
    let trajectory: Trajectory
    let beginTime: TimeInterval
    func offset(atGlobal g: TimeInterval) -> CGFloat { trajectory.offset(at: g - beginTime) }
    func velocity(atGlobal g: TimeInterval) -> CGFloat { trajectory.velocity(at: g - beginTime) }
}

extension Trajectory {
    /// Seamless rebake (design §3). `current` began at `prevBeginTime` (layer-local); `now` is the
    /// layer-local instant of the coordinate change; `future` is a freshly-built trajectory whose own
    /// `t == 0` is the re-based live offset (NEW coordinate). `shift` is the re-base applied to the
    /// coordinate (NEW = OLD + shift). Produces a trajectory whose history [newBegin, now] replays
    /// `current` (re-expressed by +shift) and whose future [now, …] is `future`, anchored at
    /// `newBegin = max(prevBeginTime, now − historyWindow)`. The splice point sits at `now` carrying the
    /// EXACT (interpolated) live offset, so it's continuous in offset+velocity under the `.linear`
    /// keyframe playback (which interpolates to each frame). Rebakes only happen on an edge/shape change
    /// now (a pure coordinate shift rides the layer-model translation instead), so this is infrequent.
    static func spliced(current: Trajectory, prevBeginTime: TimeInterval, now: TimeInterval,
                        future: Trajectory, shift: CGFloat) -> SplicedTrajectory {
        let newBegin = Swift.max(prevBeginTime, now - historyWindow)
        let localNow = now - prevBeginTime
        var out: [Sample] = []
        // History: each `current` sample with prevBeginTime+t in (newBegin, now), re-timed to start at
        // newBegin and re-expressed into the NEW coordinate (+shift).
        for s in current.samples {
            let global = prevBeginTime + s.t
            if global > newBegin - 1e-9 && global < now - 1e-9 {
                out.append(Sample(t: global - newBegin, offset: s.offset + shift, velocity: s.velocity))
            }
        }
        // Splice point at `now`: the live sample in the NEW coordinate (== future.samples[0]).
        let liveNew = current.offset(at: localNow) + shift
        out.append(Sample(t: now - newBegin, offset: liveNew, velocity: future.samples.first?.velocity ?? 0))
        // Future: future's t is relative to its own launch (now); re-time to newBegin. Skip its t==0
        // (already appended as the splice point) to keep t strictly increasing.
        for s in future.samples where s.t > 1e-9 {
            out.append(Sample(t: (now - newBegin) + s.t, offset: s.offset, velocity: s.velocity))
        }
        // Re-time the reset onto the spliced axis. The FUTURE path owns everything after `now`, so
        // its reset wins; the history's only counts if it already happened inside the retained
        // window, in which case the multiplier is already 1 and the exact instant is moot but kept
        // exact anyway.
        let resetOnSplicedAxis: TimeInterval?
        if let futureReset = future.multiplierResetTime {
            resetOnSplicedAxis = (now - newBegin) + futureReset
        } else if let currentReset = current.multiplierResetTime {
            let global = prevBeginTime + currentReset
            resetOnSplicedAxis = global > newBegin - 1e-9 ? global - newBegin : 0
        } else {
            resetOnSplicedAxis = nil
        }
        return SplicedTrajectory(trajectory: Trajectory(samples: out,
                                                       multiplierResetTime: resetOnSplicedAxis),
                                 beginTime: newBegin)
    }
}

extension Trajectory {
    /// Simulate a released axis forward to settle, recording one sample per `stepMs` step.
    /// `axis` MUST be in its post-`applyRelease(velocity:)` `.decelerating` state. Drives `ScrollAxis.step` verbatim,
    /// so the vertices are the integrator's own outputs — parity is exact by construction.
    static func build(from axis: ScrollAxis, stepMs: CGFloat = 1000.0 / 120.0) -> Trajectory {
        var a = axis
        // t == 0 is the exact (full-precision) release offset so the path starts with no jump.
        var samples: [Sample] = [Sample(t: 0, offset: a.offset, velocity: a.velocity)]
        var t: TimeInterval = 0
        var multiplierResetTime: TimeInterval?
        let stepSeconds = TimeInterval(stepMs) / 1000.0
        let capSeconds: TimeInterval = 10.0          // safety: real paths settle well before this
        while t < capSeconds {
            let (written, settled, endedDeceleration) = a.step(dtMs: stepMs)
            t += stepSeconds
            if endedDeceleration, multiplierResetTime == nil { multiplierResetTime = t }
            samples.append(Sample(t: t, offset: written, velocity: a.velocity))
            if settled { break }
        }
        return Trajectory(samples: samples, multiplierResetTime: multiplierResetTime)
    }
}
