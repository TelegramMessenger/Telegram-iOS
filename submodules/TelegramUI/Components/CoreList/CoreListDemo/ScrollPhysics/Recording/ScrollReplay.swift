import CoreGraphics
import Foundation

/// Replays a recorded gesture against the pure ScrollPhysics core. Pure (no UIKit).
enum ScrollReplay {
    /// Build a 2-axis ScrollPhysics from recorded geometry, anchored at `startOffset`.
    /// `c` is the rubber-band coefficient (0.55 touch / 0.715 trackpad — see `replay`).
    static func makePhysics(_ g: GestureRecording.Geometry, startOffset: CGPoint,
                            c: CGFloat = RubberBand.touchCoefficient) -> ScrollPhysics {
        let minX = OffsetMath.minOffset(insetLeadingTop: g.insetLeft, scale: g.scale)
        let maxX = OffsetMath.maxOffset(contentSize: g.contentWidth, insetTrailingBottom: g.insetRight,
                                        boundsSize: g.boundsWidth, minOffset: minX, scale: g.scale)
        let minY = OffsetMath.minOffset(insetLeadingTop: g.insetTop, scale: g.scale)
        let maxY = OffsetMath.maxOffset(contentSize: g.contentHeight, insetTrailingBottom: g.insetBottom,
                                        boundsSize: g.boundsHeight, minOffset: minY, scale: g.scale)
        return ScrollPhysics(
            x: ScrollAxis(offset: startOffset.x, min: minX, max: maxX, range: g.boundsWidth,
                          rate: g.decelerationRate, scale: g.scale, c: c),
            y: ScrollAxis(offset: startOffset.y, min: minY, max: maxY, range: g.boundsHeight,
                          rate: g.decelerationRate, scale: g.scale, c: c))
    }

    /// The replayable span: frames from the first `.dragging` frame onward. Leading idle frames
    /// (captured between tapping Record and the gesture actually starting) carry no input and
    /// must be dropped, or the fold would `endDrag` before any drag occurred.
    static func replayableFrames(_ rec: GestureRecording) -> ArraySlice<GestureRecording.Frame> {
        guard let start = rec.frames.firstIndex(where: { $0.phase == .dragging }) else { return [] }
        return rec.frames[start...]
    }

    /// Drive ScrollPhysics through the replayable frames; return the replayed offset per frame
    /// (index-aligned with `replayableFrames(rec)`).
    static func replay(_ rec: GestureRecording) -> [CGPoint] {
        let frames = replayableFrames(rec)
        guard let first = frames.first else { return [] }
        // translationInView is cumulative from touch-down: offset₀ = anchor − translation₀
        // ⇒ anchor = offset₀ + translation₀.
        let anchor = CGPoint(x: first.groundTruthOffset.x + first.translation.x,
                             y: first.groundTruthOffset.y + first.translation.y)
        // Indirect (trackpad) gestures deliver no touches and use a looser overscroll rubber-band.
        // The signal is `touches.isEmpty`: every trackpad recording has `touches == 0`, every touch
        // recording has many. (Caveat: a pre-`touches`-field recording also decodes to `[]` — see
        // GestureRecording's `decodeIfPresent ?? []`; none are committed, and the touch fixtures'
        // c=0.55 replay bounds in ScrollPhysicsRegressionTests would break loudly if one slipped in.)
        let c = rec.touches.isEmpty ? RubberBand.trackpadCoefficient : RubberBand.touchCoefficient
        var p = makePhysics(rec.geometry, startOffset: anchor, c: c)
        p.beginDrag()
        var released = false
        // The frame-level driver keeps its own velocity pair: it samples per DISPLAY FRAME, so its
        // (previous, latest) are frame velocities, not the per-EVENT ivars UIKit actually blends.
        // `replayEvents` is the driver that reproduces those; this one remains the integrator oracle.
        var latestVelocity = CGPoint.zero
        var prevVelocity = CGPoint.zero
        var prevT = first.t
        let firstDecelStepMs = decelFrameDurationMs(frames)
        var out: [CGPoint] = []
        out.reserveCapacity(frames.count)
        for f in frames {
            switch f.phase {
            case .dragging:
                prevVelocity = latestVelocity
                latestVelocity = CGPoint(x: -f.recognizerVelocity.x * 0.001,
                                         y: -f.recognizerVelocity.y * 0.001)
                p.drag(translation: f.translation)
                out.append(CGPoint(x: p.x.offset, y: p.y.offset))
            case .decelerating:
                // UIScrollView's first decel step always integrates exactly one display frame:
                // `_endPanNormal` sets lastUpdateTime = now − 1/maxFPS then steps to now, regardless of
                // the actual release-to-first-frame gap. That one-frame decay (`rate^(1/maxFPS)`, ≈0.967
                // at 60Hz) scales the hand-off velocity before the bulk of the decel — without it the
                // landing overshoots ~3%. So the first step uses the steady decel-frame cadence, NOT
                // the recorded gap.
                let dtMs: CGFloat
                if !released {
                    // Frame-level release: the same guarded low-pass `ReleaseDecision` applies, over
                    // frame velocities. Guarded for the same reason — a one-frame drag has no previous.
                    p.applyRelease(velocity: prevVelocity == .zero ? latestVelocity : CGPoint(
                        x: 0.75 * prevVelocity.x + 0.25 * latestVelocity.x,
                        y: 0.75 * prevVelocity.y + 0.25 * latestVelocity.y))
                    released = true
                    dtMs = firstDecelStepMs
                } else {
                    dtMs = CGFloat((f.t - prevT) * 1000)
                }
                out.append(p.step(dtMs: dtMs).written)
            }
            prevT = f.t
        }
        return out
    }

    /// The steady deceleration-frame cadence (≈ 1/maxFPS) — the median dt between consecutive
    /// decelerating frames. Used for the first decel step (see `replay`). Falls back to 1/60s.
    private static func decelFrameDurationMs(_ frames: ArraySlice<GestureRecording.Frame>) -> CGFloat {
        var dts: [CGFloat] = []
        var prev: GestureRecording.Frame?
        for f in frames {
            if let p = prev, p.phase == .decelerating, f.phase == .decelerating {
                dts.append(CGFloat((f.t - p.t) * 1000))
            }
            prev = f
        }
        guard !dts.isEmpty else { return 1000.0 / 60.0 }
        dts.sort()
        return dts[dts.count / 2]
    }

    /// Per-axis maximum absolute divergence between replay and recorded ground truth, over the
    /// replayable span (leading idle frames excluded).
    static func maxDivergence(_ rec: GestureRecording) -> CGPoint {
        let frames = replayableFrames(rec)
        let replayed = replay(rec)
        var mx: CGFloat = 0, my: CGFloat = 0
        for (f, r) in zip(frames, replayed) {
            mx = Swift.max(mx, abs(r.x - f.groundTruthOffset.x))
            my = Swift.max(my, abs(r.y - f.groundTruthOffset.y))
        }
        return CGPoint(x: mx, y: my)
    }

    /// Replay a recording at the EVENT level — the per-touch stream the recognizer actually
    /// delivered — driving the physics exactly as `PhysicsScrollEngine.applyPanUpdate` does.
    ///
    /// This exists because `replay` above folds every recorded DISPLAY FRAME through `drag(...)`,
    /// including the first, so it behaves like UIKit whether or not the live engine feeds its
    /// `.began` sample. That is precisely why a suite holding the integrator to 3px could not see a
    /// 4× error in the release: no fixture crossed the engine↔core seam. `replay` remains the
    /// INTEGRATOR oracle; this is the SEAM oracle.
    ///
    /// Output is index-aligned with `replayableFrames(rec)` — the frames are the output axis, and
    /// the touch events are consumed by timestamp as those frames advance.
    ///
    /// TOUCH recordings only. A trackpad recording carries no touch stream at all (`touches == []`),
    /// so there is nothing to drive the drag with and the result stays parked at the anchor. That is
    /// deliberately loud rather than silently falling back to `replay`: substituting one driver for
    /// the other is exactly the confusion this function exists to remove.
    static func replayEvents(_ rec: GestureRecording) -> [CGPoint] {
        let frames = replayableFrames(rec)
        guard let first = frames.first else { return [] }
        let anchor = CGPoint(x: first.groundTruthOffset.x + first.translation.x,
                             y: first.groundTruthOffset.y + first.translation.y)
        let c = rec.touches.isEmpty ? RubberBand.trackpadCoefficient : RubberBand.touchCoefficient
        var p = makePhysics(rec.geometry, startOffset: anchor, c: c)

        // **The touch stream's `translation` is only usable as drag input for a REAL gesture.** It is
        // captured before UIScrollView's `setTranslation:inView:` reconciliation, so it is the value
        // the recognizer held, not necessarily the value `_updatePanGesture` fed to its offset math.
        // For every human-finger fixture the two are identical event-for-event (verified on
        // `medium-flick`: 7 dragging frames, 7 driving touch moves, translations equal to the
        // hundredth). They diverge only when a whole gesture lands INSIDE the pan's hysteresis window
        // — which a `simctl`-synthesized swipe does, compressing the flick into one touch move that
        // UIKit then discards entirely (recorded: frame translation 0, touch translation −190, and a
        // real UIScrollView that released from offset 0). That case exercises the `setTranslation`
        // reconciliation CoreList deliberately does not model, not the release path, so it is not a
        // usable fixture here — record short flicks with a finger.
        //
        // EVERY touch sample is walked, not just the recognized ones, because the two carry different
        // duties. A `.began` PHASE sample is the finger LANDING: `_beginTrackingWithEvent:` decides the
        // fast-scroll carry there and stops any in-flight deceleration there — both before the pan has
        // recognized anything. Only samples past the hysteresis (`TouchSample.hasRecognized`) are drag
        // callbacks that feed velocity. Conflating the two costs a whole flight of deceleration on any
        // recording where a gesture catches moving content — which is exactly what a repeat-flick burst
        // is, and the reason this walks gestures rather than assuming one.
        var touchIndex = 0
        var dragging = false
        var release = ReleaseDecision()
        var pendingFirstDecelStep = false

        func feed(_ sample: GestureRecording.TouchSample) {
            switch sample.phase {
            case .began:
                // Touch-down: carry-or-expire the streak, and park the physics at the current offset,
                // which both halts an in-flight deceleration and anchors the drag — `translation(in:)`
                // is measured from here, so the anchor has to be captured here too.
                release.beginTouchTracking(at: sample.t)
                p.beginDrag()
                release.beginGesture()
                dragging = true
            case .moved:
                guard sample.hasRecognized else { break }   // pre-hysteresis: no handlePan behind it
                if !dragging {                              // defensive: a recording with no `.began`
                    release.beginTouchTracking(at: sample.t)
                    p.beginDrag()
                    release.beginGesture()
                    dragging = true
                }
                release.note(recognizerVelocity: sample.velocity, translation: sample.translation)
                p.drag(translation: sample.translation)
            case .ended, .cancelled:
                guard dragging else { break }
                dragging = false                            // the NEXT touch-down starts a fresh gesture
                pendingFirstDecelStep = true
                if case let .decelerate(velocity, vScale) = release.release(
                    recognizerVelocity: sample.velocity, at: sample.t) {
                    p.x.vScale = vScale
                    p.y.vScale = vScale
                    p.applyRelease(velocity: velocity)
                } else {
                    p.applyRelease(velocity: .zero)   // overscrolled releases still spring back
                }
            }
        }

        /// Feed every touch event at or before `t`. Frames are the output axis; the touch stream is
        /// consumed against it by timestamp, so a burst's later gestures interleave correctly with the
        /// deceleration frames between them.
        func consume(upTo t: TimeInterval) {
            while touchIndex < rec.touches.count, rec.touches[touchIndex].t <= t + 1e-9 {
                feed(rec.touches[touchIndex])
                touchIndex += 1
            }
        }

        /// A `.decelerating` frame means the gesture has ended, but the `ended` touch event's own
        /// timestamp can trail that frame slightly. Drain forward to it so the release lands BEFORE the
        /// first deceleration step rather than one frame late.
        func drainPendingRelease() {
            while dragging, touchIndex < rec.touches.count {
                feed(rec.touches[touchIndex])
                touchIndex += 1
            }
        }

        var prevT = first.t
        let firstDecelStepMs = decelFrameDurationMs(frames)
        var out: [CGPoint] = []
        out.reserveCapacity(frames.count)

        for f in frames {
            switch f.phase {
            case .dragging:
                consume(upTo: f.t)
                out.append(CGPoint(x: p.x.offset, y: p.y.offset))
            case .decelerating:
                consume(upTo: f.t)
                drainPendingRelease()
                // See `replay`: `_endPanNormal` sets `lastUpdateTime = now − 1/maxFPS` and steps to
                // `now`, so the FIRST step of EVERY deceleration integrates exactly one display frame
                // regardless of the recorded release-to-first-frame gap. In a burst that applies once
                // per release, not once per recording.
                let dtMs: CGFloat
                if pendingFirstDecelStep {
                    pendingFirstDecelStep = false
                    dtMs = firstDecelStepMs
                } else {
                    dtMs = CGFloat((f.t - prevT) * 1000)
                }
                out.append(p.step(dtMs: dtMs).written)
            }
            prevT = f.t
        }
        return out
    }

    /// Per-axis maximum absolute divergence between the EVENT-level replay and recorded ground
    /// truth, over the replayable span. The seam-oracle counterpart of `maxDivergence`.
    static func maxEventDivergence(_ rec: GestureRecording) -> CGPoint {
        let frames = replayableFrames(rec)
        let replayed = replayEvents(rec)
        var mx: CGFloat = 0, my: CGFloat = 0
        for (f, r) in zip(frames, replayed) {
            mx = Swift.max(mx, abs(r.x - f.groundTruthOffset.x))
            my = Swift.max(my, abs(r.y - f.groundTruthOffset.y))
        }
        return CGPoint(x: mx, y: my)
    }
}
