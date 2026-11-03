#if canImport(UIKit)
import UIKit

/// A topmost, non-interactive overlay that draws table structural chrome (selection outline, row/column
/// handles, resize knobs) ABOVE the block-view subviews — which would otherwise hide canvas-drawn chrome.
/// The canvas sizes its frame to extend LEFT of x=0 (with a matching `bounds.origin` shift) so it still draws
/// in canvas coordinates, but its draw context can paint the row grip at a negative x — the composer's zero
/// page margin puts the grip in the field's left padding. (A `draw(_:)` is always clipped to the frame, so the
/// wider frame is what un-clips it, not `clipsToBounds`.)
///
/// The canvas installs no `UITextSelectionDisplayInteraction` (it draws its own caret/wash/handles), so no OS
/// selection chrome competes for z-order here. The app's own caret/handle views sit above this overlay, which
/// is safe: table structural chrome is only visible during a structural selection, which parks a collapsed
/// degenerate caret (`caretRect` → `.zero`) and hides the caret view, so the text-caret and structural-chrome
/// rendering modes are mutually exclusive.
@available(iOS 13.0, *)
final class BlockChromeOverlay: UIView {
    weak var canvas: DocumentCanvasView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isOpaque = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        canvas?.drawTableChrome(in: ctx)
    }
}
#endif
