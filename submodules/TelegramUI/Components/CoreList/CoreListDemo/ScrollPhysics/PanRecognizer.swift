import CoreGraphics
import Foundation

/// Pure reproduction of `UIScrollViewPanGestureRecognizer`'s `translationInView` / `velocityInView`
/// (analysis-doc §7), driven from raw touch centroids (window coords) + timestamps. No UIKit.
///
/// Per touch-move, the recognizer records a velocity **sample** = the centroid finite-difference
/// `(end − start)/dt`, shifting the prior sample to `previous`. `velocityInView` is then a two-event
/// weighted blend, and `translationInView` is the cumulative centroid delta since the gesture began:
/// ```
///   sample.v   = (end − start) / dt
///   velocity   = W1·current.v + W2·previous.v        (previous only if its dt > a tiny epsilon)
///   translation = currentCentroid − startCentroid
/// ```
/// `W1 = 0.2`, `W2 = 0.8` were calibrated to machine precision from recorded touches (the
/// scroll-uncontaminated X axis — see `PanRecognizerTests`).
struct PanRecognizer {
    /// Velocity-blend weights (§7): `velocity = 0.2·current + 0.8·previous`.
    static let currentWeight: CGFloat = 0.2     // W1
    static let previousWeight: CGFloat = 0.8    // W2
    /// A previous sample contributes only if its `dt` exceeds this — the `2⁻²³` gate in `velocityInView`.
    static let minPreviousSampleDt: TimeInterval = 0x1p-23   // ≈ 1.19e-7 s
    /// Pan begins once the touch moves this far (`_hysteresis`); the same amount is then removed from
    /// the translation (`_removeHysteresisFromTranslation`, §7) so it starts near zero at recognition.
    static let hysteresis: CGFloat = 10

    /// One per-event velocity sample: the centroid moved `start → end` over `dt`.
    struct Sample {
        var start: CGPoint
        var end: CGPoint
        var dt: TimeInterval
        var velocity: CGPoint {
            guard dt > 0 else { return .zero }
            return CGPoint(x: (end.x - start.x) / CGFloat(dt), y: (end.y - start.y) / CGFloat(dt))
        }
    }

    private(set) var startCentroid: CGPoint = .zero   // touch-down centroid
    private(set) var currentCentroid: CGPoint = .zero
    private(set) var isRecognized = false             // true once the touch has moved past the hysteresis
    private var refCentroid: CGPoint = .zero          // start of the in-progress sample (prior centroid)
    private var lastTime: TimeInterval = 0
    private var current: Sample?
    private var previous: Sample?
    private var hysteresisOffset: CGPoint = .zero      // removed from translation at recognition

    /// Touch-down: resets the translation reference and clears velocity samples.
    mutating func begin(centroid: CGPoint, t: TimeInterval) {
        startCentroid = centroid
        currentCentroid = centroid
        refCentroid = centroid
        lastTime = t
        current = nil
        previous = nil
        isRecognized = false
        hysteresisOffset = .zero
    }

    /// Touch-move: builds the per-event velocity sample (when `dt > 0`), advances the reference, and
    /// — on first crossing the hysteresis — recognizes the pan and captures the hysteresis offset.
    mutating func move(centroid: CGPoint, t: TimeInterval) {
        currentCentroid = centroid
        let dt = t - lastTime
        if dt > 0 {
            previous = current
            current = Sample(start: refCentroid, end: centroid, dt: dt)
            refCentroid = centroid
            lastTime = t
        }
        if !isRecognized {
            let raw = CGPoint(x: centroid.x - startCentroid.x, y: centroid.y - startCentroid.y)
            if (raw.x * raw.x + raw.y * raw.y).squareRoot() > Self.hysteresis {
                isRecognized = true
                hysteresisOffset = CGPoint(x: Self.deadzone(raw.x), y: Self.deadzone(raw.y))
            }
        }
    }

    /// `translationInView` — cumulative centroid delta since recognition, hysteresis removed. Zero
    /// until the pan is recognized (the scroll view doesn't move during the pre-recognition slop).
    var translation: CGPoint {
        guard isRecognized else { return .zero }
        return CGPoint(x: (currentCentroid.x - startCentroid.x) - hysteresisOffset.x,
                       y: (currentCentroid.y - startCentroid.y) - hysteresisOffset.y)
    }

    /// Per-axis hysteresis removal (§7): `sign(v)·min(|v|, hysteresis)`.
    private static func deadzone(_ v: CGFloat) -> CGFloat {
        (v > 0 ? 1 : (v < 0 ? -1 : 0)) * Swift.min(abs(v), hysteresis)
    }

    /// `velocityInView` (pts/s) — the two-event weighted blend of centroid finite-differences.
    var velocity: CGPoint {
        guard let c = current else { return .zero }
        var v = CGPoint(x: Self.currentWeight * c.velocity.x, y: Self.currentWeight * c.velocity.y)
        if let p = previous, p.dt > Self.minPreviousSampleDt {
            v.x += Self.previousWeight * p.velocity.x
            v.y += Self.previousWeight * p.velocity.y
        }
        return v
    }
}
