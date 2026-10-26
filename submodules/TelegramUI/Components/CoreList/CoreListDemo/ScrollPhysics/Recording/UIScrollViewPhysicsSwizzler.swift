import UIKit
import ObjectiveC.runtime

/// Event-sources ground-truth frames for ONE attached UIScrollView from its actual
/// `setContentOffset:` writes (every write, no resampling), reading the pan recognizer atomically so
/// each offset is paired with the exact translation/velocity that produced it. Debug-only.
final class CaptureSink {
    private(set) var frames: [GestureRecording.Frame] = []
    private(set) var touches: [GestureRecording.TouchSample] = []
    private(set) var rubberBandSamples: [GestureRecording.RubberBandSample] = []
    private weak var target: UIScrollView?
    private var startTime: CFTimeInterval = 0

    /// The currently-attached sink. Swizzled IMPs route here, gated by instance identity.
    static weak var current: CaptureSink?

    /// Seconds since `attach` — the baseline for frame and release timestamps.
    func elapsed() -> TimeInterval { CACurrentMediaTime() - startTime }

    func attach(to scrollView: UIScrollView) {
        UIScrollViewPhysicsSwizzler.installIfNeeded()   // self-contained: arming the sink installs the hooks
        target = scrollView
        frames.removeAll()
        touches.removeAll()
        rubberBandSamples.removeAll()
        startTime = CACurrentMediaTime()
        CaptureSink.current = self
    }

    func detach() {
        if CaptureSink.current === self { CaptureSink.current = nil }
        target = nil
    }

    /// Called from the `setContentOffset:` swizzle with the value about to be written, BEFORE it is
    /// applied — so the pan recognizer still holds the translation/velocity UIKit used this pass.
    fileprivate func recordOffsetWrite(_ offset: CGPoint, from obj: AnyObject) {
        guard let sv = obj as? UIScrollView, sv === target else { return }
        let pan = sv.panGestureRecognizer
        let dragging = pan.state == .began || pan.state == .changed
        frames.append(.init(
            t: elapsed(),
            phase: dragging ? .dragging : .decelerating,
            translation: dragging ? pan.translation(in: sv) : .zero,
            recognizerVelocity: dragging ? pan.velocity(in: sv) : .zero,
            groundTruthOffset: offset))
    }

    /// Called from a touch-delivery swizzle AFTER the recognizer has processed the event, so its
    /// translation/velocity/state reflect this touch. `eventTime` is the UIEvent timestamp (the
    /// recognizer's clock), rebased to recording start to match `frames`.
    fileprivate func recordTouch(phase: GestureRecording.TouchSample.Phase, from obj: AnyObject, eventTime: TimeInterval) {
        guard let pan = obj as? UIPanGestureRecognizer, let sv = target, pan.view === sv else { return }
        touches.append(.init(
            t: eventTime - startTime,
            // WINDOW coords (a fixed reference) — NOT location(in: sv): the scroll view's bounds.origin
            // is the content offset, so location(in: sv) scrolls under a moving finger and contaminates
            // the centroid's finite-difference velocity. The recognizer samples in scene-ref (≈ window).
            centroid: pan.location(in: nil),
            phase: phase,
            translation: pan.translation(in: sv),
            velocity: pan.velocity(in: sv),
            state: pan.state.rawValue))
    }

    fileprivate func recordRubberBand(_ s: GestureRecording.RubberBandSample, from obj: AnyObject) {
        guard obj === target else { return }
        rubberBandSamples.append(s)
    }
}

/// Installs IMP swizzles on UIScrollView that route captures to `CaptureSink.current`.
/// Debug-only; never shipped. Idempotent. Call from the main thread (the `installed` flag
/// is unsynchronized — fine for a hand-driven recorder, never used concurrently).
enum UIScrollViewPhysicsSwizzler {
    private static var installed = false

    static func installIfNeeded() {
        guard !installed else { return }
        installed = true
        swizzleSetContentOffset()
        swizzleRubberBand()
        swizzleTouches()
    }

    /// Swizzle the pan recognizer's touch delivery (Layer 0/1 capture). Gated by instance in the sink,
    /// so swizzling the base class is harmless. The original runs first (it builds the velocity sample),
    /// then we read the recognizer's resulting centroid/translation/velocity/state.
    private static func swizzleTouches() {
        let phases: [(String, GestureRecording.TouchSample.Phase)] = [
            ("touchesBegan:withEvent:", .began), ("touchesMoved:withEvent:", .moved),
            ("touchesEnded:withEvent:", .ended), ("touchesCancelled:withEvent:", .cancelled),
        ]
        for (name, phase) in phases {
            let sel = NSSelectorFromString(name)
            guard let method = class_getInstanceMethod(UIPanGestureRecognizer.self, sel) else { continue }
            typealias Fn = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Void
            let original = unsafeBitCast(method_getImplementation(method), to: Fn.self)
            let block: @convention(block) (AnyObject, AnyObject, AnyObject) -> Void = { obj, touches, event in
                original(obj, sel, touches, event)
                let t = (event as? UIEvent)?.timestamp ?? CACurrentMediaTime()
                CaptureSink.current?.recordTouch(phase: phase, from: obj, eventTime: t)
            }
            method_setImplementation(method, imp_implementationWithBlock(block))
        }
    }

    private static func swizzleSetContentOffset() {
        let sel = NSSelectorFromString("setContentOffset:")
        guard let method = class_getInstanceMethod(UIScrollView.self, sel) else { return }
        typealias Fn = @convention(c) (AnyObject, Selector, CGPoint) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Fn.self)
        let block: @convention(block) (AnyObject, CGPoint) -> Void = { obj, offset in
            CaptureSink.current?.recordOffsetWrite(offset, from: obj)
            original(obj, sel, offset)
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func swizzleRubberBand() {
        let sel = NSSelectorFromString("_rubberBandOffsetForOffset:maxOffset:minOffset:range:outside:")
        guard let method = class_getInstanceMethod(UIScrollView.self, sel) else { return } // private; tolerate absence
        typealias Fn = @convention(c) (AnyObject, Selector, CGFloat, CGFloat, CGFloat, CGFloat, UnsafeMutablePointer<ObjCBool>?) -> CGFloat
        let original = unsafeBitCast(method_getImplementation(method), to: Fn.self)
        let block: @convention(block) (AnyObject, CGFloat, CGFloat, CGFloat, CGFloat, UnsafeMutablePointer<ObjCBool>?) -> CGFloat = {
            obj, offset, maxOff, minOff, range, outside in
            let out = original(obj, sel, offset, maxOff, minOff, range, outside)
            CaptureSink.current?.recordRubberBand(
                .init(offset: offset, min: minOff, max: maxOff, range: range, out: out), from: obj)
            return out
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }
}
