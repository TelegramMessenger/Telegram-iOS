import UIKit
import UIKit.UIGestureRecognizerSubclass

/// A pan recognizer that also reports raw touch-down / touch-up. A scroll view uses these to "catch"
/// moving content the instant a finger lands — the pan itself only begins after the ~10px hysteresis,
/// so it can't do this — and to resume a bounce when a tap lifts without a drag. Pan behaviour is
/// otherwise unchanged (we always call `super`).
///
/// Trackpad (indirect) scroll sends no `UITouch`, so the touch-down catch above doesn't fire for it;
/// the scroll view catches a trackpad finger-down via the public `UIGestureRecognizerDelegate`
/// `gestureRecognizer(_:shouldReceive:)` (UIEvent) callback instead.
final class PhysicsPanGestureRecognizer: UIPanGestureRecognizer {
    /// Fired the instant a finger lands (before the pan recognizes a drag), carrying the touch
    /// event's timestamp — the analogue of `-[UIScrollView _beginTrackingWithEvent:]` reading
    /// `event.timestamp`, which shares `CACurrentMediaTime`'s timebase.
    var onTouchDown: ((TimeInterval) -> Void)?
    /// Fired when a finger lifts / the touch is cancelled.
    var onTouchUp: (() -> Void)?

    /// `true` while the current gesture has delivered no `UITouch` — i.e. a trackpad / indirect
    /// continuous scroll (which fires no `touchesBegan`). The scroll view uses it to pick the looser
    /// trackpad overscroll rubber-band coefficient. Assumed `true` at gesture start and cleared by the
    /// first real touch; `reset()` restores it between gestures.
    private(set) var isIndirectScroll = true

    /// When this returns `true`, the recognizer recognizes immediately on touch-down (no ~10px
    /// hysteresis) — the scroll view/engine sets it while content is MOVING, so a finger landing on
    /// moving content grabs the scroll at once (UIScrollView's no-deadzone behaviour). The forced
    /// `.began` is also what lets a stopping tap be absorbed: the engine grants no gesture
    /// simultaneity, so UIKit's plain exclusion fails the content recognizer the moment this pan
    /// begins. A `nil`/`false` closure leaves the normal pan hysteresis intact, so taps with the
    /// content at rest pass through.
    var shouldBeginImmediately: (() -> Bool)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        if #available(iOS 13.4, *) {
            allowedScrollTypesMask = .continuous   // recognize trackpad two-finger (continuous) indirect scroll
        }
    }

    override func reset() {
        super.reset()
        isIndirectScroll = true                // next gesture is indirect until a touch proves otherwise
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        isIndirectScroll = false               // a real touch landed → this is a direct (finger) gesture
        onTouchDown?(event.timestamp)
        // Grab moving content the instant the finger lands (no hysteresis). Evaluated AFTER onTouchDown
        // so onTouchDown must not have already stopped the motion — the engine no longer catches there.
        if shouldBeginImmediately?() == true { state = .began }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        onTouchUp?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        onTouchUp?()
    }
}
