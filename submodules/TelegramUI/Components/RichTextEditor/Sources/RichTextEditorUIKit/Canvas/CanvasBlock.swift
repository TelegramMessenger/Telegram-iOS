#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A block rendered by `DocumentCanvasView`. Conformers: `BlockBox` (paragraph), `MediaBlockBox`
/// (image + caption), and `TableBlockBox` (a grid of cells). The canvas treats every block uniformly:
/// span math via `nodeStart`/`nodeSize`, and selection/caret/text/draw via `leafRegions()` (each
/// block's editable text regions, recursing into table cells) + `draw(in:imageProvider:)`. The
/// single-text-region members are a convenience for leaf blocks; a table supplies degenerate values.
@available(iOS 13.0, *)
protocol CanvasBlock: AnyObject {
    var id: BlockID { get }
    /// The mapper this block renders with. A block created as a replacement/sibling of another (a
    /// paragraph split or merge) inherits its source block's mapper, so context-specific styling — a
    /// table cell's smaller base font — propagates without the editing engine tracking table membership.
    var mapper: AttributedStringMapper { get }
    /// When true, the canvas renders this block via a persistent, non-focusable `BlockBackingView`
    /// subview (pooled by `BlockID`) instead of drawing it into the shared canvas `CGContext`.
    /// Default false (see the extension below). Will be overridden to true by `MediaBlockBox` (Task 3) and `TableBlockBox` (Task 6).
    var rendersAsBlockView: Bool { get }
    /// The canvas-coordinate rect this block's `BlockBackingView` occupies. Defaults to `frame`; a block
    /// that draws PAST its layout frame (a full-bleed image; a table whose grid border extends a few px
    /// past the content strip) overrides this so the view's backing store covers everything it draws.
    /// (A UIView's own `draw(_:)` is confined to its bounds-sized backing store, so a too-small frame
    /// silently clips the overflow — `clipsToBounds` does NOT affect a view's own draw.)
    var blockViewFrame: CGRect { get }
    /// Token contribution to the position model. Paragraph: `textLength + 2`. Image: `textLength + 5`.
    var nodeSize: Int { get }
    /// Global position of the block's first inner position (before the image atom, for an image).
    /// Assigned by `recomputeSpans`.
    var nodeStart: Int { get set }
    /// The block's single editable text region.
    var textLayout: BlockLayoutEngine { get }
    /// Global position where the editable text begins (`== nodeStart` for a paragraph; `nodeStart + 2` for an image).
    var textStart: Int { get }
    /// UTF-16 length of the editable text (`== textLayout.length`).
    var textLength: Int { get }
    /// Model ref for the editable text region.
    var textRef: TextNodeRef { get }
    /// Canvas-coordinate origin of the editable text region.
    var textOrigin: CGPoint { get }
    var frame: CGRect { get set }
    var height: CGFloat { get }
    func setWidth(_ width: CGFloat)
    /// The block height at box `width`, computed WITHOUT mutating the block (a stateless companion to
    /// `height`/`setWidth`): width-dependent text via `BlockLayoutEngine.boundingHeight(forWidth:)`,
    /// structural insets read from current state. Valid once the block has been laid out at least once.
    func measuredHeight(forWidth width: CGFloat) -> CGFloat
    /// Round-trips this block back to the Core model.
    func currentBlock() -> Block
    /// Maps a point in canvas coordinates to the closest global position this block can host
    /// (paragraph → a text offset; image → a gap or a caption offset).
    func closestPosition(toCanvasPoint point: CGPoint) -> Int
    /// Editable text regions inside this block, with absolute global ranges + canvas origins.
    /// Valid after layout (frame assigned). Leaf blocks return one; a table flat-maps over its cells.
    func leafRegions() -> [LeafTextRegion]
    /// Draws this block (decoration/grid + text) in canvas coordinates.
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?)

    /// What this block becomes when the document is rendered as an InstantPage — the classification
    /// the vertical-rhythm rules are written in. **Deliberately has no default implementation:** a
    /// conservative default would compile everywhere while silently giving a new block type the wrong
    /// rhythm, which no diff review catches. It must agree with what `InstantPageBuilder` emits for the
    /// same block; `//submodules/InstantPageUI:InstantPageUITests` is that check.
    var spacingKind: RichTextBlockSpacingKind { get }

    /// The block's height at `width` EXCLUDING any inter-block gap the enclosing `BlockStack` owns.
    /// For a `BlockBox` this is its text height without `topInset`/`bottomInset`; for every other block
    /// the insets are internal padding, so this is just `measuredHeight(forWidth:)`.
    func measuredContentHeight(forWidth width: CGFloat) -> CGFloat
}

@available(iOS 13.0, *)
extension CanvasBlock {
    func measuredContentHeight(forWidth width: CGFloat) -> CGFloat {
        return measuredHeight(forWidth: width)
    }

    var rendersAsBlockView: Bool { false }
    var blockViewFrame: CGRect { frame }
}
#endif
