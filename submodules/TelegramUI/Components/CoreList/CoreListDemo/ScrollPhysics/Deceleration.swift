import CoreGraphics
import Foundation // pow, exp

/// UIScrollView deceleration stepper. See analysis doc §2.
/// `offset`/`velocity` are mutated in place; `velocity` is points/millisecond.
/// `rate` is the per-ms deceleration factor and must be in (0, 1) — 0.998 normal,
/// 0.99 fast (it divides `1 - rate`, so `rate == 1` would produce NaN).
struct Deceleration {
    var offset: CGFloat
    var velocity: CGFloat
    let min: CGFloat
    let max: CGFloat
    let rate: CGFloat
    let vScale: CGFloat

    /// Below this the integrator calls a free deceleration finished. Not private: `ScrollAxis.step`
    /// needs the same threshold to tell a deceleration that was RUNNING from an axis already at rest.
    static let velocityFloor: CGFloat = 0.01              // pts/ms (§5/§2)
    private static let settleTolerance: CGFloat = 0.5     // px (§2)
    private static let bounceLnRate: CGFloat = -0.01005033585350145 // ln(0.99), fixed spring stiffness (§2)

    static func decay(dtMs: CGFloat, rate: CGFloat) -> CGFloat { pow(rate, dtMs) }

    /// Advance one frame. `settled` means the scroll has come to rest and the driver should stop.
    /// `endedDeceleration` means this step entered the bounce spring or settled — the two points at
    /// which `_getBouncingDecelerationOffset` clears `_fastScrollCount` / `_fastScrollMultiplier`
    /// (`0x17a87bc` and `0x17a8844`). Every deceleration ends in one of the two, which is why the
    /// fast-scroll streak only survives into a gesture that starts before the flight finishes.
    mutating func step(dtMs: CGFloat) -> (settled: Bool, endedDeceleration: Bool) {
        guard dtMs > 0 else { let s = settleIfNeeded(); return (s, s) }
        let hi = Swift.max(max, min)
        let lo = min

        if offset >= lo, offset <= hi {
            // §2-A: in-bounds free deceleration
            guard velocity != 0 else { let s = settleIfNeeded(); return (s, s) }
            let decay = Self.decay(dtMs: dtMs, rate: rate)
            let dx = velocity * rate * (1 - decay) / (1 - rate) * vScale
            let proposed = offset + dx
            if proposed >= lo, proposed <= hi {
                offset = proposed
                velocity *= decay
                let s = settleIfNeeded()
                return (s, s)
            }
            // crosses an edge mid-frame: integrate to the edge, hand the remainder to the spring
            let edge = proposed > hi ? hi : lo
            let frac = (edge - offset) / (proposed - offset)        // distance-proportional time
            let timeToBound = dtMs * frac
            let decayE = Self.decay(dtMs: timeToBound, rate: rate)
            offset += velocity * rate * (1 - decayE) / (1 - rate) * vScale // ≈ edge (frac approximates time, per §2)
            velocity *= decayE
            spring(dtMs: dtMs - timeToBound)
            return (settleIfNeeded(), true)
        } else {
            // §2-B: overscrolled — spring toward the crossed edge
            spring(dtMs: dtMs)
            return (settleIfNeeded(), true)
        }
    }

    private mutating func spring(dtMs: CGFloat) {
        guard dtMs > 0 else { return }
        let hi = Swift.max(max, min)
        let edge = offset < min ? min : hi
        let springK = exp(Self.bounceLnRate * dtMs)         // fixed 0.99/ms stiffness
        let decayRem = Self.decay(dtMs: dtMs, rate: rate)
        offset = edge + springK * (offset - edge)
        // NO vScale here. `_getBouncingDecelerationOffset`'s spring term (`0x17a8784`) carries no
        // `_fastScrollMultiplier`, unlike the free-decel term (`0x17a85f8`) and its to-the-edge
        // sub-step (`0x17a86a4`). Invisible while vScale == 1, which is how it went unnoticed.
        offset += velocity * rate * springK * (1 - decayRem) / (1 - rate)
        velocity *= decayRem * springK
    }

    /// `settled()` plus the snap that has to accompany it. Every `step` exit goes through this rather
    /// than through `settled()` directly.
    ///
    /// Out of bounds, `settled()` accepts a rest position anywhere within `settleTolerance` of the
    /// edge — so WITHOUT the clamp the integrator legitimately comes to a permanent stop up to half a
    /// point overscrolled, and nothing ever moves it again. A real `UIScrollView` cannot do that: its
    /// bounce lands exactly on `-contentInset`, and every consumer downstream is written against that
    /// guarantee.
    ///
    /// Measured, not theorised. A spring-back on a 3x device walks the pixel grid in ⅓pt steps and
    /// stops on the first sample inside the tolerance: `… -1.00, -0.67, -0.33` — and stays at -0.33
    /// forever. The chat history reads `visibleContentOffset() < -0.1` as "still overscrolled" and
    /// keeps its next-channel control alive on that basis, so a resting -0.33 pinned a 94pt
    /// transparent host view over the bottom of every affected chat and swallowed taps there
    /// permanently. The control rendered at zero expansion (`max(0.33 - 12, 0)`), which is why it
    /// looked like nothing was there.
    ///
    /// The tolerance itself is deliberately unchanged — it is what lets the spring stop in finite
    /// time. It just may not leave the offset where it stopped.
    private mutating func settleIfNeeded() -> Bool {
        guard settled() else { return false }
        offset = Swift.min(Swift.max(offset, min), Swift.max(max, min))
        return true
    }

    private func settled() -> Bool {
        let hi = Swift.max(max, min)
        let slow = abs(velocity) < Self.velocityFloor
        if offset >= min, offset <= hi { return slow }       // in bounds: settled once velocity dies
        let nearEdge = abs(offset - min) <= Self.settleTolerance
            || abs(offset - hi) <= Self.settleTolerance
        return slow && nearEdge
    }
}
