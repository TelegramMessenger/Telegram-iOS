#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A `BlockBackingView` specialization for TABLES that can scroll horizontally. It hosts a real
/// `UIScrollView` whose single content view draws the grid at full `gridWidth`; the scroll view supplies
/// native horizontal scrolling and its `contentOffset.x` is the single source of truth for the table's
/// scroll position (pooled by `BlockID`, so it survives box rebuilds/undo). The canvas stays the sole
/// `UITextInput`; this view never becomes first responder.
@available(iOS 13.0, *)
final class TableBackingView: BlockBackingView, UIScrollViewDelegate {
    let scroll = GripYieldingScrollView()
    private let content = TableContentView()
    /// Selection wash for this table's cells, hosted in `content` above the cell text + emoji so it reads
    /// on top and rides the horizontal scroll/overscroll. Kept frontmost (below the caret) in `hostEmoji`/
    /// `layoutSubviews`.
    private let cellSelection = CellSelectionView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true            // the scroll view needs touches (Task 5 gates them)
        clipsToBounds = true                       // load-bearing now: clips the overflowing grid
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = true
        scroll.delaysContentTouches = false        // protect tap-to-caret latency (matches the outer scroll)
        scroll.bounces = true
        scroll.alwaysBounceHorizontal = false
        scroll.delegate = self
        content.owner = self
        content.backgroundColor = .clear
        content.isOpaque = false
        scroll.addSubview(content)
        cellSelection.owner = self
        content.addSubview(cellSelection)   // above the grid/text; kept above emoji in hostEmoji/layout
        addSubview(scroll)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private var lastContentSize: CGSize = .zero

    /// Set by the canvas when it creates a FRESH view for a culled→re-realized table; Task 4 consumes it
    /// in `layoutSubviews` to restore the saved horizontal offset from the box. Harmless until then.
    var pendingOffsetRestore = false

    /// Pooled backing views for this table's cell PARAGRAPHS, hosted inside the scrolling content view at
    /// CONTENT-LOCAL frames (canvas frame − blockViewFrame.origin) so they ride the horizontal scroll. The
    /// table's `draw` no longer paints cell paragraph text — these views do (each reusing the inherited
    /// `drawBlockContents`, which translates by the cell box's own canvas frame so text lands locally).
    private(set) var cellBlockViews: [BlockID: BlockBackingView] = [:]

    /// Reconciles `cellBlockViews` against the current table's cell paragraph boxes: pools by `BlockID`,
    /// positions each at its content-local frame (behind the cell wash/emoji/caret), and tears down any
    /// view whose cell no longer exists. Called at the end of `layoutSubviews`.
    private func syncCellBlockViews() {
        guard let t = box as? TableBlockBox else { return }
        let wanted = t.cellParagraphBoxes()
        let wantedIDs = Set(wanted.map { $0.box.id })
        let origin = t.blockViewFrame.origin
        for (cellBox, frame) in wanted {
            let view = cellBlockViews[cellBox.id] ?? {
                let v = BlockBackingView(); v.canvas = canvas
                cellBlockViews[cellBox.id] = v; content.insertSubview(v, at: 0)   // behind cell wash/emoji/caret
                return v
            }()
            view.box = cellBox
            view.frame = frame.offsetBy(dx: -origin.x, dy: -origin.y)   // content-local
            view.setNeedsDisplay()
        }
        for (id, view) in cellBlockViews where !wantedIDs.contains(id) {
            view.removeFromSuperview(); cellBlockViews[id] = nil
        }
        content.bringSubviewToFront(cellSelection)   // keep the wash above cell text
    }

    // Suppress base drawing; TableContentView is the drawing surface (it scrolls inside `scroll`).
    override func draw(_ rect: CGRect) {}

    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        content.setNeedsDisplay()      // the grid + cell text live in the content view
        cellSelection.setNeedsDisplay() // the on-top cell selection wash is a separate content subview
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let box = box as? TableBlockBox else { return }
        scroll.canvas = canvas     // keep the scroll view's canvas reference in sync (set once; cheap thereafter)
        scroll.frame = bounds
        let size = CGSize(width: box.gridWidth, height: bounds.height)
        if content.frame.size != size { content.frame = CGRect(origin: .zero, size: size) }
        if scroll.contentSize != size { scroll.contentSize = size }   // setting this can clamp contentOffset
        if pendingOffsetRestore {
            let maxX = max(scroll.contentSize.width - scroll.bounds.width, 0)
            scroll.contentOffset.x = min(max(box.contentOffsetX, 0), maxX)
            pendingOffsetRestore = false
        }
        if size != lastContentSize {                                   // redraw the grid only when geometry changed
            lastContentSize = size
            content.setNeedsDisplay()
        }
        cellSelection.frame = CGRect(origin: .zero, size: size)   // cover the whole grid in content space
        content.bringSubviewToFront(cellSelection)                // stay above the cell text + emoji
        // Authoritative post-clamp sync: after contentSize may have clamped contentOffset, push it to the box.
        box.contentOffsetX = max(0, scroll.contentOffset.x)
        syncCellBlockViews()   // host this table's cell paragraphs as views inside the scrolling content
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        canvas?.tableDidScroll(self)
    }

    /// Hosts the canvas's caret view INSIDE the scrolling content view (above the drawn text) at the given
    /// CONTENT-LOCAL frame, so the caret rides the table's horizontal scroll/overscroll. `content` is
    /// private, so the canvas reaches it through this seam. Idempotent: re-adds only if reparented.
    func hostCaret(_ v: UIView, at contentFrame: CGRect) {
        if v.superview !== content { content.addSubview(v) }
        content.bringSubviewToFront(v)   // above the drawn text/fill
        v.frame = contentFrame
    }

    /// Hosts an emoji view INSIDE the scrolling content view at a CONTENT-LOCAL frame, so it rides the
    /// table's horizontal scroll/overscroll (like `hostCaret`, but emoji aren't brought above the caret).
    /// Idempotent: re-adds only if reparented.
    func hostEmoji(_ v: UIView, at contentFrame: CGRect) {
        if v.superview !== content { content.addSubview(v) }
        v.frame = contentFrame
        content.bringSubviewToFront(cellSelection)   // keep the selection wash above newly-added emoji
    }

    /// Hosts a selection-handle view INSIDE the scrolling content view at a CONTENT-LOCAL frame, brought to
    /// front (above the cell wash + emoji) so it reads on top and rides the horizontal scroll/overscroll.
    /// A handle (ranged selection) and the caret (collapsed) are never co-visible, so front-order is safe.
    func hostHandle(_ v: UIView, at contentFrame: CGRect) {
        if v.superview !== content { content.addSubview(v) }
        content.bringSubviewToFront(v)
        v.frame = contentFrame
    }

    /// Draws this table's cell selection wash into the `CellSelectionView` (content-local coords). Reuses
    /// the inherited `drawBlockSelection`, translated from canvas coords by `-blockViewFrame.origin` (the
    /// same transform the grid uses), so it lands in content space and rides the scroll.
    func drawCellSelection(in ctx: CGContext) {
        guard let box = box, let canvas = canvas else { return }
        ctx.saveGState()
        ctx.translateBy(x: -box.blockViewFrame.minX, y: -box.blockViewFrame.minY)
        drawBlockSelection(in: ctx, box: box, from: canvas.selFrom, to: canvas.selTo)
        ctx.restoreGState()
    }

    /// Draw spelling underlines for this table's cells, in the content view's own coordinate space (so they
    /// ride horizontal overscroll). Mirrors `drawCellSelection`'s transform; ranges come from the canvas
    /// `spellResults`, keyed by each cell paragraph's BlockID via `spellCheckableRef(region.ref)`.
    func drawCellSpelling(in ctx: CGContext) {
        guard let box = box, let canvas = canvas, canvas.isSpellCheckingEnabled else { return }
        ctx.saveGState()
        ctx.translateBy(x: -box.blockViewFrame.minX, y: -box.blockViewFrame.minY)
        ctx.setLineCap(.round)
        var byStyle: [DocumentCanvasView.SpellStyle: [CGRect]] = [:]
        for region in box.leafRegions() {                            // cell paragraph regions (recurses cells)
            guard let id = canvas.spellCheckableRef(region.ref), let entry = canvas.spellResults[id] else { continue }
            for (range, style) in entry.ranges {
                for seg in region.layout.selectionRects(start: range.location, end: range.location + range.length) {
                    let line = seg.offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y)
                    byStyle[style, default: []].append(line)
                }
            }
        }
        for (style, lines) in byStyle {
            ctx.setStrokeColor(canvas.spellingUnderlineColor(style).cgColor)
            ctx.setLineWidth(canvas.underlineWidth(for: style))
            ctx.setLineDash(phase: 0, lengths: canvas.underlineDash(for: style))
            for line in lines {
                ctx.move(to: CGPoint(x: line.minX, y: line.maxY - 1))
                ctx.addLine(to: CGPoint(x: line.maxX, y: line.maxY - 1))
            }
            ctx.strokePath()   // stroke per style group
        }
        ctx.restoreGState()
    }

}

/// The single scrolling content view inside a `TableBackingView`; draws the whole grid.
@available(iOS 13.0, *)
final class TableContentView: UIView {
    weak var owner: TableBackingView?
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        owner?.drawBlockContents(in: ctx)
    }
}
#endif
