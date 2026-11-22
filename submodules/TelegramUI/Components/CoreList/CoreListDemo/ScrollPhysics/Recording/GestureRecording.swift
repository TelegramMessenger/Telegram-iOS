import CoreGraphics
import Foundation

/// A recorded real-UIScrollView gesture, replayable against the pure ScrollPhysics core. Pure (no UIKit).
struct GestureRecording: Codable {
    enum Phase: String, Codable { case dragging, decelerating }

    /// One display-link frame of the real gesture.
    struct Frame: Codable {
        var t: TimeInterval                 // seconds, monotonic
        var phase: Phase
        var translation: CGPoint            // pan recognizer translationInView (valid when .dragging)
        var recognizerVelocity: CGPoint     // pan recognizer velocityInView, pts/s (valid when .dragging)
        var groundTruthOffset: CGPoint      // the real UIScrollView contentOffset at this frame
    }

    /// One touch event delivered to the pan recognizer (the recognizer's INPUT), plus the
    /// recognizer's resulting outputs (ground truth for the PanRecognizer reproduction — analysis §7).
    struct TouchSample: Codable {
        enum Phase: String, Codable { case began, moved, ended, cancelled }
        var t: TimeInterval                 // event timestamp, seconds since recording start
        var centroid: CGPoint               // panGR.location(in: nil) — window coords (fixed reference)
        var phase: Phase
        var translation: CGPoint            // panGR.translation(in:) after the event — ground truth
        var velocity: CGPoint               // panGR.velocity(in:) after the event, pts/s — ground truth
        var state: Int                      // UIGestureRecognizer.State rawValue

        /// `UIGestureRecognizer.State.possible.rawValue`. Spelled as a constant because this file and
        /// `ScrollReplay` are deliberately UIKit-free.
        static let possibleStateRawValue = 0

        /// Whether the recognizer had recognized by the time this event was processed. The recorder
        /// samples `panGR.state` AFTER the recognizer handles the event, so a sample still reading
        /// `.possible` is pre-hysteresis and UIKit's scroll view receives no `handlePan` for it.
        ///
        /// Identify the `.began` as the FIRST sample where this is true, rather than by
        /// `state == .began`: `medium-flick.json` records two consecutive `state == 1`, so the raw
        /// value is not a reliable discriminator.
        var hasRecognized: Bool { state != Self.possibleStateRawValue }
    }

    /// One captured `_rubberBandOffsetForOffset:…` call (per-formula ground truth, axis-agnostic).
    struct RubberBandSample: Codable {
        var offset: CGFloat
        var min: CGFloat
        var max: CGFloat
        var range: CGFloat
        var out: CGFloat
    }

    struct Geometry: Codable {
        var contentWidth: CGFloat
        var contentHeight: CGFloat
        var boundsWidth: CGFloat
        var boundsHeight: CGFloat
        var insetTop: CGFloat
        var insetLeft: CGFloat
        var insetBottom: CGFloat
        var insetRight: CGFloat
        var scale: CGFloat
        var decelerationRate: CGFloat
    }

    var name: String
    var geometry: Geometry
    var frames: [Frame]
    var rubberBandSamples: [RubberBandSample]
    /// Touch events delivered to the pan recognizer (Layer 0/1 — the recognizer's input + outputs).
    var touches: [TouchSample]
    /// Touch-up timestamp (seconds since recording start). The deceleration clock starts here, so the
    /// first decelerating frame's dt is `t − releaseTime` — this is what removes the one-frame
    /// decel-start lead.
    var releaseTime: TimeInterval?

    init(name: String, geometry: Geometry, frames: [Frame], rubberBandSamples: [RubberBandSample],
         touches: [TouchSample] = [], releaseTime: TimeInterval? = nil) {
        self.name = name; self.geometry = geometry; self.frames = frames
        self.rubberBandSamples = rubberBandSamples; self.touches = touches; self.releaseTime = releaseTime
    }

    // Custom decode so `touches` / `releaseTime` are optional in the JSON — fixtures recorded before
    // those fields existed still load (synthesized Decodable throws on a missing non-optional key).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        geometry = try c.decode(Geometry.self, forKey: .geometry)
        frames = try c.decode([Frame].self, forKey: .frames)
        rubberBandSamples = try c.decode([RubberBandSample].self, forKey: .rubberBandSamples)
        touches = try c.decodeIfPresent([TouchSample].self, forKey: .touches) ?? []
        releaseTime = try c.decodeIfPresent(TimeInterval.self, forKey: .releaseTime)
    }
}
