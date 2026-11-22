#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A non-focusable render surface for ONE block. The canvas owns it (pooled by `BlockID`); its frame is
/// the block's full drawn extent (`box.blockViewFrame`), and it draws the block in local coordinates by
/// translating the context by `-box.blockViewFrame.origin` and reusing the block's existing canvas-space
/// `draw`. It NEVER becomes first responder and (Step 1) takes no touches.
@available(iOS 13.0, *)
class BlockBackingView: UIView {
    weak var canvas: DocumentCanvasView?
    var box: CanvasBlock?

    /// The `BlockBox.renderSignature` at the last `setNeedsDisplay` driven by `syncBlockViews`. Lets the
    /// canvas skip repainting an unchanged paragraph view. nil = never rendered (forces the first paint).
    var lastRenderedSignature: Int?

    /// Test-only: counts repaint requests so a test can assert a reused view was actually asked to
    /// repaint after a structural edit (the split/merge stale-bitmap regression — a reused view keeps
    /// its old layer bitmap unless `setNeedsDisplay` is called). Passive; no production behavior change.
    var setNeedsDisplayCountForTesting = 0
    override func setNeedsDisplay() {
        setNeedsDisplayCountForTesting += 1
        super.setNeedsDisplay()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false   // Step 1: pure passthrough; Step 2 enables an inner scroll view
        clipsToBounds = true               // safe: the frame (box.blockViewFrame) covers the full drawn extent
        isOpaque = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        drawBlockContents(in: ctx)
    }

    /// Draws the block translated from canvas coords into local coords. Selection visuals (cell wash, image
    /// wash, handles) are NOT drawn here — they render ON TOP via the canvas overlays
    /// (`SelectionHighlightView` / `CellSelectionView`) and the own-drawn caret/`SelectionHandleView`
    /// subviews, so they sit above cell text + emoji and ride scroll. Reused by `TableContentView`.
    func drawBlockContents(in ctx: CGContext) {
        guard let box = box, let canvas = canvas else { return }
        ctx.translateBy(x: -box.blockViewFrame.minX, y: -box.blockViewFrame.minY)   // canvas coords -> local
        box.draw(in: ctx, imageProvider: canvas.imageProvider)
    }

    /// Mirrors `DocumentCanvasView.selectionRects` (keep the clamp/offset/alpha in lock-step).
    /// Selection highlight for THIS block's leaf regions. Rects are in canvas coordinates; the caller
    /// has already translated the context to local. Now used only by `TableBackingView.drawCellSelection`
    /// to paint the cell wash ON TOP (in the `CellSelectionView`, above cell text + emoji), not behind.
    func drawBlockSelection(in ctx: CGContext, box: CanvasBlock, from: Int, to: Int) {
        guard from != to else { return }
        let lo = min(from, to), hi = max(from, to)
        (canvas?.mapper.theme.accent ?? .systemBlue).withAlphaComponent(0.30).setFill()   // .tintColor is iOS 15+
        for region in box.leafRegions() {
            let a = max(lo, region.globalStart), b = min(hi, region.globalStart + region.length)
            guard a < b else { continue }
            for seg in region.layout.selectionRects(start: a - region.globalStart, end: b - region.globalStart) {
                ctx.fill(seg.offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y))
            }
        }
    }

}
#endif
