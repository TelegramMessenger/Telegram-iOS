#if canImport(UIKit)
import UIKit

/// The app's OWN text caret — a thin tint-colored bar with a self-driven blink. We draw it ourselves
/// (the canvas installs no `UITextSelectionDisplayInteraction`, so there is no OS cursor view to begin with —
/// see `installSelectionInteractions`) so that, when the caret sits inside a horizontally-scrollable table
/// cell, it can be hosted INSIDE the table's scrolling content view and ride the scroll/overscroll bounce —
/// exactly like the selection fill and handles already do. We own the blink here.
@available(iOS 13.0, *)
final class CaretView: UIView {
    private static let blinkKey = "caretBlink"

    /// Incremented every time the blink is reset (solid-then-resume). Exposed for unit tests to assert the
    /// idempotency of `DocumentCanvasView.updateCaretView` — a no-op update must not restart the blink.
    private(set) var blinkResetCount = 0

    /// The caret fill color. Defaults to `.systemBlue` (the editor theme's accent overrides it; `.tintColor`
    /// would be iOS 15+ and a stored-property default can't be availability-gated).
    var accentColor: UIColor = .systemBlue {
        didSet { backgroundColor = accentColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = accentColor
        layer.cornerRadius = 1
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        backgroundColor = accentColor
    }

    /// Adds the repeating opacity blink (1 → 0, autoreversing) if it isn't already running. Solid at first.
    func startBlink() {
        guard layer.animation(forKey: Self.blinkKey) == nil else { return }
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1
        anim.toValue = 0
        anim.duration = 0.5
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: Self.blinkKey)
    }

    /// Restarts the blink so the caret shows SOLID immediately, then resumes blinking — approximating iOS's
    /// pause-on-move behaviour. Called only when the caret actually moves (a real position change), never on
    /// a no-op refresh (e.g. a scroll tick), so the blink isn't perpetually reset.
    func resetBlink() {
        layer.removeAnimation(forKey: Self.blinkKey)
        layer.opacity = 1
        blinkResetCount += 1
        startBlink()
    }

    /// Hides the caret and stops the blink (no caret to show, e.g. a ranged/structural selection).
    func stopBlink() {
        layer.removeAnimation(forKey: Self.blinkKey)
        isHidden = true
    }

    /// Shows the caret SOLID with no blink. Used as the dimmed "landing" indicator during a floating-cursor
    /// gesture (the caller sets `alpha` for the dim); the blink is removed so it doesn't pulse the landing.
    func freezeSolid() {
        layer.removeAnimation(forKey: Self.blinkKey)
        layer.opacity = 1
        isHidden = false
    }

    /// Whether the blink animation is currently running (read by `UITextCursorView` below).
    var isBlinkingNow: Bool { layer.animation(forKey: Self.blinkKey) != nil }
}

/// Adopt `UITextCursorView` (iOS 17+) so `UITextLoupeSession.begin(at:fromSelectionWidgetView:in:)` treats our
/// own caret as a real insertion-point view and animates the magnifier from / around it. Apple documents
/// `fromSelectionWidgetView` as "the view associated with the insertion point" — normally a
/// `UITextSelectionDisplayInteraction`'s `cursorView`, which is `UIView & UITextCursorView`. We own-draw the
/// caret and deliberately install no such interaction (it leaks orphaned selection lollipops on iOS 18+/26 —
/// see `installSelectionInteractions`), so we conform our caret view to the protocol directly instead. A bare
/// `UIView` passed as the widget is accepted but ignored by the loupe's grow animation (device-verified).
@available(iOS 17.0, *)
extension CaretView: UITextCursorView {
    /// `readwrite` per the protocol: the loupe reads it and may drive it to steady the cursor while magnifying.
    var isBlinking: Bool {
        get { isBlinkingNow }
        set { if newValue { startBlink() } else { freezeSolid() } }
    }
    func resetBlinkAnimation() { resetBlink() }
}
#endif
