#if canImport(UIKit)
import UIKit

/// A `UIScrollView` subclass whose pan gesture yields to the canvas's selection-handle / table-knob drag when
/// the touch lands on a selection grip. Used for BOTH the outer document scroll (`RichTextEditorView`) and each
/// table's inner horizontal scroll (`TableBackingView`), so a vertical knob drag near a handle isn't raced by
/// scrolling.
///
/// UIKit requires that `UIScrollView.panGestureRecognizer.delegate` stays the scroll view itself, so we
/// override `gestureRecognizerShouldBegin` here (on the owning view) rather than replacing the delegate.
/// Gate-only: no `require(toFail:)` / simultaneous recognition — consistent with the project policy.
@available(iOS 13.0, *)
final class GripYieldingScrollView: UIScrollView {
    weak var canvas: DocumentCanvasView?

    /// Whether a touch at `point` (canvas coordinates) is on a selection-handle / table-knob grip, in which
    /// case this scroll yields its pan so the canvas's handle-drag wins. Extracted for testability.
    func yieldsToGrip(at point: CGPoint) -> Bool {
        canvas?.isSelectionDragTouch(point) ?? false
    }

    // Called by UIKit before the pan recognizer starts. We yield only when the touch is near a
    // selection-handle / table-knob grip so the canvas's handle-pan wins; otherwise return super's
    // answer so normal horizontal-scroll / inner-vs-outer vertical-scroll arbitration is unchanged.
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard g === panGestureRecognizer, canvas != nil else { return super.gestureRecognizerShouldBegin(g) }
        let point = g.location(in: canvas)   // canvas-space touch (UIKit keeps locations consistent across views)
        if yieldsToGrip(at: point) { return false }
        return super.gestureRecognizerShouldBegin(g)
    }
}
#endif
