#if canImport(UIKit)
import UIKit

/// The own-rendered FLOATING caret used by the spacebar-trackpad (floating-cursor) gesture — and, in a
/// later phase, by the drag-and-drop drop caret (`UITextCursorDropPositionAnimator.cursorView`). A dumb,
/// non-interactive bar: it owns only its accent and an animated show/hide. Positioning (including
/// reparenting into a table's scrolling content view) is done by the canvas via `hostOverlay(_:at:)`,
/// exactly like the steady `CaretView`, so the floating caret rides table horizontal scroll too.
@available(iOS 13.0, *)
final class TransientCaretView: UIView {
    /// The caret fill color. Pulled from the same themeable source as the steady `CaretView`.
    var accentColor: UIColor = .systemBlue {
        didSet { backgroundColor = accentColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = accentColor
        layer.cornerRadius = 1
        isHidden = true
        alpha = 0
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Lift-off: unhide and fade to opaque.
    func show(animated: Bool) {
        isHidden = false
        if animated {
            UIView.animate(withDuration: 0.12) { self.alpha = 1 }
        } else {
            alpha = 1
        }
    }

    /// Settle: fade to clear, then hide.
    func hide(animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.12, animations: { self.alpha = 0 }, completion: { _ in
                if self.alpha < 0.01 { self.isHidden = true }
            })
        } else {
            alpha = 0
            isHidden = true
        }
    }
}
#endif
