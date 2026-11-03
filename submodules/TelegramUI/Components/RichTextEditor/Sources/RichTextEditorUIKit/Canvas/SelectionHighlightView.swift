#if canImport(UIKit)
import UIKit

/// A dedicated, non-interactive overlay that draws the selection highlight (and image-atom washes) ON TOP
/// of all NON-TABLE content — body/caption text, emoji subviews, and image atoms — rather than behind the
/// text in the canvas's own `draw(_:)`. It is a canvas subview kept above the emoji overlay (and below the
/// table chrome), so the highlight reads over everything and rides vertical scroll. Table-cell highlights
/// live in each table's scrolling content view instead (so they ride horizontal overscroll) — see
/// `CellSelectionView`.
@available(iOS 13.0, *)
final class SelectionHighlightView: UIView {
    weak var canvas: DocumentCanvasView?
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isOpaque = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), let canvas = canvas else { return }
        canvas.drawNonTableSelectionHighlight(in: ctx)
        canvas.drawMarkedTextUnderline(in: ctx)
        canvas.drawSpellingUnderlines(in: ctx)
    }
}

/// A dedicated selection-highlight surface hosted INSIDE a table's scrolling content view, kept above the
/// cell text + cell emoji subviews, so a cell selection draws on top and rides the table's horizontal
/// scroll/overscroll. The owning `TableBackingView` keeps it frontmost and feeds it the cell rects.
@available(iOS 13.0, *)
final class CellSelectionView: UIView {
    weak var owner: TableBackingView?
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isOpaque = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        owner?.drawCellSelection(in: ctx)
        owner?.drawCellSpelling(in: ctx)
    }
}

/// One own-drawn selection-handle "lollipop": a vertical stem spanning the endpoint caret height plus a
/// filled knob just past the caret's open end (above the top for START, below the bottom for END). One
/// instance per endpoint; the canvas positions + hosts it in the right coordinate space (the canvas, or a
/// table's scrolling content view) so it sits ON TOP of the wash and rides the right scroll — replacing
/// the old CGContext blit. Non-interactive: the handle DRAG is a proximity-gated pan on the canvas
/// (`isSelectionDragTouch`), independent of this view.
@available(iOS 13.0, *)
final class SelectionHandleView: UIView {
    static let knobRadius: CGFloat = 5.5
    static let stemWidth: CGFloat = 2
    /// The interactive hit area extends this far past the endpoint caret — matched to the canvas selection-
    /// drag gate (`isSelectionDragTouch`) so a touch that hits this view is exactly a touch that would start a
    /// handle drag. Lets a host scope dismiss-gesture flags (`disablesInteractiveModalDismiss` /
    /// `…KeyboardGestureRecognizer`, set via the canvas `configureSelectionHandleView` hook) to knob interaction.
    static let dragHitTolerance: CGFloat = 22
    let isStart: Bool

    /// The endpoint caret rect in THIS view's own coordinates (set by the canvas when positioning). Drives the
    /// extended interactive hit area in `point(inside:with:)`.
    private var caretLocalRect: CGRect = .zero

    init(isStart: Bool) {
        self.isStart = isStart
        super.init(frame: .zero)
        backgroundColor = .clear
        // Hit-testable (no recognizers of its own — the drag is still the canvas pan, which receives the touch
        // as an ancestor). Being the hit-test target for a knob touch lets a host-set dismiss-gesture flag on
        // this view be consulted (Display walks UP from the hit-test view), scoped to knob interaction.
        isUserInteractionEnabled = true
        isOpaque = false
        contentMode = .redraw   // re-render the lollipop whenever the frame/bounds change
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// The lollipop's bounding box for an endpoint `caret` rect (in the host container's coords): the caret
    /// height plus room for the knob past its open end.
    func boundingFrame(forCaret caret: CGRect) -> CGRect {
        let r = Self.knobRadius
        return CGRect(x: caret.midX - r, y: caret.minY - (isStart ? 2 * r : 0),
                      width: 2 * r, height: caret.height + 2 * r)
    }

    /// The endpoint `caret` expressed in this view's own coordinate space (i.e. relative to `boundingFrame`).
    func caretLocalRect(forCaret caret: CGRect) -> CGRect {
        let bf = boundingFrame(forCaret: caret)
        return caret.offsetBy(dx: -bf.minX, dy: -bf.minY)
    }

    /// Records the endpoint caret rect (in this view's coords) so the interactive hit area can match the
    /// canvas drag gate. Set by the canvas alongside the frame.
    func setCaretLocalRect(_ rect: CGRect) { caretLocalRect = rect }

    /// Extends the hit area past the drawn lollipop to `dragHitTolerance` around the endpoint caret — matching
    /// `isSelectionDragTouch` — so a knob/grip touch resolves to this view (and its host dismiss-gesture flags)
    /// while a touch elsewhere falls through to the canvas. The hit area can exceed `bounds`; UIKit still
    /// consults `point(inside:)` for the point the parent forwards.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        caretLocalRect.insetBy(dx: -Self.dragHitTolerance, dy: -Self.dragHitTolerance).contains(point)
    }

    /// The handle fill color. Defaults to `.systemBlue` (the editor theme's accent overrides it; `.tintColor`
    /// is iOS 15+ and a stored-property default can't be availability-gated).
    var accentColor: UIColor = .systemBlue {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let r = Self.knobRadius, sw = Self.stemWidth
        accentColor.setFill()
        // Stem: the caret-height portion of the bounds (the remaining 2r is the knob's room).
        ctx.fill(CGRect(x: bounds.midX - sw / 2, y: isStart ? 2 * r : 0, width: sw, height: bounds.height - 2 * r))
        // Knob: a filled circle at the top (START) or bottom (END).
        ctx.addArc(center: CGPoint(x: bounds.midX, y: isStart ? r : bounds.height - r),
                   radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.fillPath()
    }
}
#endif
