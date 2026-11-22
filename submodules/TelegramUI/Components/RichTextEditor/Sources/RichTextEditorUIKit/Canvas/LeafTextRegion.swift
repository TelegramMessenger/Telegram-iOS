#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One editable text region produced by a block's recursive enumeration. `globalStart`/`length`
/// are absolute positions in the document; `canvasOrigin` is where `layout` offset 0 draws in
/// canvas coordinates. (A paragraph yields one; an image yields its caption; a table flat-maps
/// over its cells' stacks.)
@available(iOS 13.0, *)
struct LeafTextRegion {
    let layout: BlockLayoutEngine
    let globalStart: Int
    let length: Int
    let ref: TextNodeRef
    let canvasOrigin: CGPoint
    /// Leading indent to add to this region's caret *when it is empty* (a list/quote inset that TextKit
    /// only applies to real glyphs). 0 once text exists or for regions without an inset. See
    /// `BlockBox.emptyLineLeadingIndent`.
    var emptyLineLeadingIndent: CGFloat = 0
    /// The real line height (font.lineHeight × lineHeightMultiple) to use for this region's caret *when it
    /// is empty*. `BlockLayout.caretRect` falls back to a fixed 20pt bar for an empty line (TextKit lays out
    /// no fragment), so without this the empty-line caret is shorter than — and misaligned with — a typed
    /// line and its placeholder. 0 once text exists. Mirrors `emptyLineLeadingIndent`.
    var emptyLineHeight: CGFloat = 0

    /// The caret rect at `local` in the region's own (unoffset) coordinates, with the empty-line height
    /// applied. For an EMPTY line `BlockLayout.caretRect` returns a fixed 20pt bar at the line top; replace
    /// its height with the real line height so the caret matches a typed line (and the placeholder sitting
    /// on that line). Identical to `layout.caretRect(atOffset:)` once any text exists.
    func caretRect(atLocal local: Int) -> CGRect {
        var rect = layout.caretRect(atOffset: local)
        if length == 0, emptyLineHeight > 0 { rect.size.height = emptyLineHeight }
        return rect
    }
}
#endif
