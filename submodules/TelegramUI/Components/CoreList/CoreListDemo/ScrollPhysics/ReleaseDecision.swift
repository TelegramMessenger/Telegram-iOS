import CoreGraphics
import Foundation

/// `UIScrollView`'s gesture-release path, decoded from `-[UIScrollView _endPanNormal:]` and the
/// velocity bookkeeping at the head of `-[UIScrollView _updatePanGesture]`. Pure value type: no
/// UIKit, no clock — timestamps arrive as parameters.
///
/// **This is a 2-D decision and deliberately does not live in `ScrollAxis`.** The decelerate/stop
/// threshold is `vx² + vy²`, and the low-pass guard tests both axes jointly; a per-axis home would
/// force each half to answer a question it cannot see the whole of. CoreList pins x to zero today,
/// so the 1-D and 2-D forms coincide — keeping the exact predicate keeps this a faithful model
/// rather than a y-only special case.
///
/// Velocity is points/MILLISECOND, content-signed (`-recognizerVelocity * 0.001`), matching the
/// `_horizontalVelocity` / `_verticalVelocity` ivars. API parameters named `recognizerVelocity` are
/// points/SECOND, finger-signed, exactly as `UIPanGestureRecognizer.velocity(in:)` reports them.
struct ReleaseDecision {
    enum Outcome: Equatable {
        /// `vScale` is `_fastScrollMultiplier`, the free-deceleration distance multiplier.
        case decelerate(velocity: CGPoint, vScale: CGFloat)
        case stop
    }

    /// `|v|² >= 0.0625` (|v| >= 0.25 pts/ms) decelerates. `0x179f6d8`.
    static let decelerateThresholdSquared: CGFloat = 0.0625
    /// Low-pass weights. `0x179f97c` (0.75, on `previous`) and `0x179f974` (0.25, on `latest`).
    static let previousWeight: CGFloat = 0.75
    static let latestWeight: CGFloat = 0.25
    /// pts/s → pts/ms. `_updatePanGesture`, `0x179d20c`.
    static let recognizerVelocityScale: CGFloat = 0.001
    /// `|v|² >= 0.36` (|v| >= 0.6 pts/ms) counts as a fast flick. `0x179fc7c`.
    static let fastFlickThresholdSquared: CGFloat = 0.36
    /// Slowing below |v| = 0.13 pts/ms mid-drag breaks the streak. `0x179d61c`.
    static let streakBreakThresholdSquared: CGFloat = 0.0169
    /// Seconds after release the streak survives. `_beginTrackingWithEvent:`, `0x17b1488`.
    static let streakTimeout: TimeInterval = 1.0
    /// Drag distance that saturates the growth term. `0x179d918`.
    static let streakDistanceScale: CGFloat = 240.0
    /// The growth term's own clamp. `0x179d924`.
    static let streakDistanceCap: CGFloat = 0.9
    /// `0x179d940`.
    static let multiplierCap: CGFloat = 16.0
    /// Growth starts once the streak reaches this many consecutive fast flicks. `0x179d8cc`.
    static let streakGrowthFloor = 3

    /// `_horizontalVelocity` / `_verticalVelocity` — the most recent pan callback's sample.
    private(set) var latest: CGPoint = .zero
    /// `_previousHorizontalVelocity` / `_previousVerticalVelocity` — the one before it.
    private(set) var previous: CGPoint = .zero

    /// `_fastScrollCount`.
    private(set) var streakCount: Int = 0
    /// `_fastScrollMultiplier` — the free-deceleration distance multiplier.
    private(set) var multiplier: CGFloat = 1
    /// `_fastScrollStartMultiplier` — the value carried in at touch-down; growth adds to it.
    private(set) var startMultiplier: CGFloat = 1
    /// Where the streak was last cleared, for diagnosis: the counter reaching 3 is the precondition
    /// for any acceleration at all, so knowing WHICH reset fires is the whole question.
    private(set) var lastResetReason: String = "-"

    /// `_fastScrollEndTime` — stamped at RELEASE, which is what makes the timeout mean "since you
    /// last let go" rather than "since you last touched". Its `nil` also stands in for UIKit's
    /// `_scrollViewFlags` bit 23 gate at `0x17b146c`: that bit means "the previous gesture was a
    /// real drag with velocity", and a gesture that never stamped an end time is exactly one that
    /// was not.
    private var streakEndTime: TimeInterval?
    /// The sign recorded from the previous pan callback (`_scrollViewFlags` bit 11 — the VERTICAL
    /// axis; bit 10 holds the horizontal one, and the touch path's reversal test reads bit 11).
    /// `nil` means no previous sample this gesture, so there is nothing to reverse against.
    private var lastSignY: FloatingPointSign?

    init() {}

    /// `-[UIScrollView handlePan:]` case 1: `.began` zeroes BOTH pairs, and does so *before* its own
    /// `_updatePanGesture`. That ordering is load-bearing — it is what leaves `previous == .zero` for
    /// a flick that never produces a `.changed`, which is what arms the guard in `release`.
    mutating func beginGesture() {
        latest = .zero
        previous = .zero
        lastSignY = nil
    }

    /// `-[UIScrollView _beginTrackingWithEvent:]` — touch-down, which is a different moment from
    /// `.began` and the only place the cross-gesture streak carry is decided.
    mutating func beginTouchTracking(at t: TimeInterval) {
        previous = .zero
        if let end = streakEndTime, t > end + Self.streakTimeout {
            streakCount = 0
            multiplier = 1
            lastResetReason = "timeout"
        }
        startMultiplier = multiplier
    }

    /// The integrator reached the bounce spring or settled (`0x17a87bc` / `0x17a8844`). Every
    /// deceleration ends in one of the two, so the streak only ever survives into a gesture that
    /// starts BEFORE the previous flight finished — which is exactly the repeated flick this exists
    /// for. Losing this call leaves a streak armed through a settle that should have cleared it.
    mutating func resetStreakAfterDeceleration() {
        if streakCount > 0 { lastResetReason = "decel-ended" }
        streakCount = 0
        multiplier = 1
    }

    /// One pan callback — `.began` or `.changed`. The head of `_updatePanGesture` (`0x179d1f4`)
    /// shifts `latest` into `previous`, then stores the fresh sample.
    ///
    /// `translation` is the recognizer's cumulative translation in points — which is what UIKit's
    /// `d10 - _startOffsetX` reduces to, since `d10` starts at `_startOffsetX` and has the
    /// translation subtracted from it.
    mutating func note(recognizerVelocity: CGPoint, translation: CGPoint) {
        previous = latest
        latest = CGPoint(x: -recognizerVelocity.x * Self.recognizerVelocityScale,
                         y: -recognizerVelocity.y * Self.recognizerVelocityScale)

        // Streak maintenance (`0x179d5d8`–`0x179d628`): a reversal on the scrolling axis, or slowing
        // to a near-stop, breaks the run of consecutive fast flicks. Both the reader (`0x179d5ec`)
        // and the writer (`0x179d6a0`) guard on the sample being non-zero, so a zero sample neither
        // tests nor updates.
        if latest.y != 0 {
            let sign = latest.y.sign
            let reversed = lastSignY.map { $0 != sign } ?? false
            let magnitudeSquared = latest.x * latest.x + latest.y * latest.y
            if reversed || magnitudeSquared < Self.streakBreakThresholdSquared {
                if streakCount > 0 { lastResetReason = reversed ? "reversal" : "slow-drag-sample" }
                streakCount = 0
                multiplier = 1
            }
            lastSignY = sign
        }

        // Growth (`0x179d8d4`). The sqrt really is single-precision on the touch path
        // (fcvt s0 / fsqrt s0 / fcvt d0, `0x179d904`); the discrete path uses double `hypot`.
        if streakCount >= Self.streakGrowthFloor {
            let distance = CGFloat(Float(translation.x * translation.x
                                       + translation.y * translation.y).squareRoot())
            let steps = 1 + CGFloat(streakCount - Self.streakGrowthFloor) / 2
            let term = steps * Swift.min(distance / Self.streakDistanceScale, Self.streakDistanceCap)
            multiplier = Swift.min(startMultiplier + term, Self.multiplierCap)
        }
    }

    /// `_endPanNormal:`. `t` is the release timestamp on `CACurrentMediaTime`'s timebase (UIKit uses
    /// `event.timestamp`, which shares it).
    mutating func release(recognizerVelocity: CGPoint, at t: TimeInterval) -> Outcome {
        // 1. `0x179f5e0` — UIKit re-reads `velocityInView` here rather than trusting the stored ivar,
        //    and an exact CGPointZero zeroes the sample.
        if recognizerVelocity == .zero {
            latest = .zero
        }

        // 2. `0x179f6d8` — the threshold reads the RAW latest sample, in 2-D, BEFORE the blend.
        //    Below it there is no deceleration at all and every stored velocity is cleared.
        let magnitudeSquared = latest.x * latest.x + latest.y * latest.y
        guard magnitudeSquared >= Self.decelerateThresholdSquared else {
            latest = .zero
            previous = .zero
            if streakCount > 0 { lastResetReason = "below-decel-threshold" }
            streakCount = 0
            multiplier = 1
            return .stop
        }

        // 3. `0x179fc7c` — only a genuinely fast release extends the streak. (UIKit skips the
        //    increment when `pagingEnabled` is set, `0x179fcb8`; CoreList never pages.)
        if magnitudeSquared < Self.fastFlickThresholdSquared {
            if streakCount > 0 { lastResetReason = "slow-release" }
            streakCount = 0
            multiplier = 1
        } else {
            streakCount += 1
            streakEndTime = t
        }

        // 4. `0x179f94c` — the low-pass, GUARDED. With both previous-axis samples still zero (a
        //    gesture that reached release with no `.changed`), UIKit skips it and releases raw.
        if previous != .zero {
            latest = CGPoint(x: Self.previousWeight * previous.x + Self.latestWeight * latest.x,
                             y: Self.previousWeight * previous.y + Self.latestWeight * latest.y)
        }

        return .decelerate(velocity: latest, vScale: multiplier)
    }
}
