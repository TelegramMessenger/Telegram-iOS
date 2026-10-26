#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Every BlockQuoteBox frame in the document (root + nested inside quote children / table cells),
    /// in canvas coordinates, for the fill underlay. This recursive walk is now the underlay's ONLY
    /// feed: code blocks left it when they stopped being a quote variant and started painting their
    /// own plain band, which is also what made a NESTED code block filled at all — the walk this
    /// replaced only ever saw top-level boxes.
    func blockQuoteFillRects() -> [CGRect] {
        var out: [CGRect] = []
        func walk(_ boxes: [CanvasBlock]) {
            for b in boxes {
                if let bq = b as? BlockQuoteBox {
                    out.append(bq.frame)
                    walk(bq.children.boxes)                          // nested quotes inside this quote
                } else if let t = b as? TableBlockBox {
                    for row in t.cells { for cell in row { walk(cell.boxes) } }   // quotes inside cells
                }
            }
        }
        walk(boxes)
        return out
    }

    /// Blockquote fill corner radius (measured from the reference design). Consumed by the
    /// `BlockquoteUnderlay` image factory (the fills are drawn by a stretchable-image underlay, not
    /// into the canvas context); `blockQuoteFillRects()` above supplies the run rects.
    static let blockquoteCornerRadius: CGFloat = 2.5

    /// One centered, content-hugging pill rect per PullQuoteBox (canvas coords). Width = the box's widest laid-out
    /// line + symmetric horizontal padding, floored at `pullQuoteStyle.minWidth` (so corner marks + placeholder fit),
    /// clamped to the box's content width, centered on the box's mid-x. Height spans the box (its topInset/bottomInset
    /// already pad above/below the text). Fed to the barless pull-quote underlay.
    func pullQuotePillRects() -> [CGRect] {
        boxes.compactMap { box in
            guard let pq = box as? PullQuoteBox else { return nil }
            let hPad = pullQuoteStyle.horizontalPadding
            let w = min(max(pq.pillContentWidth + hPad * 2, pullQuoteStyle.minWidth), box.frame.width)
            return CGRect(x: box.frame.midX - w / 2, y: box.frame.minY, width: w, height: box.frame.height)
        }
    }

    /// Pure geometry seam: anchor the open mark at each pill's top-left and the close mark at the bottom-right,
    /// each at its OWN (possibly non-square) size, inset from the corner by `inset`. Taking the two sizes
    /// explicitly keeps the non-square anchoring unit-testable without bundle images.
    static func pullQuoteMarkRects(pills: [CGRect], inset: CGFloat,
                                   openSize: CGSize, closeSize: CGSize) -> [(open: CGRect, close: CGRect)] {
        pills.map { pill in
            (open: CGRect(x: pill.minX + inset, y: pill.minY + inset,
                          width: openSize.width, height: openSize.height),
             close: CGRect(x: pill.maxX - inset - closeSize.width, y: pill.maxY - inset - closeSize.height,
                           width: closeSize.width, height: closeSize.height))
        }
    }

    /// Open (top-left) + close (bottom-right) quote-mark rects per pull-quote pill (canvas coords). Each mark's
    /// size is DERIVED FROM ITS IMAGE's natural size (`RichText/QuoteOpen` / `RichText/QuoteClose`, or the
    /// generated stub where unavailable), so a non-square glyph is not letterboxed into a square. The corner
    /// inset is `pullQuoteStyle.markInset`.
    func pullQuoteMarkRects() -> [(open: CGRect, close: CGRect)] {
        // Corner marks bracket the QUOTE TEXT only — the close mark sits at the last text line, EXCLUDING the
        // author line (the pill background still spans the full box height). Use each pill's x/width but the
        // box's author-less height.
        let pills = pullQuotePillRects()
        let pullBoxes = boxes.compactMap { $0 as? PullQuoteBox }
        let markBounds = zip(pills, pullBoxes).map { pill, pq in
            CGRect(x: pill.minX, y: pill.minY, width: pill.width, height: pq.quoteOnlyHeight)
        }
        return DocumentCanvasView.pullQuoteMarkRects(
            pills: markBounds,
            inset: pullQuoteStyle.markInset,
            openSize: PullQuoteMarksView.openImageNaturalSize,
            closeSize: PullQuoteMarksView.closeImageNaturalSize)
    }

    // MARK: - BlockQuoteBox collapse button geometry constants

    /// Minimum height (pts) of a `BlockQuoteBox` for the collapse glyph to be shown. A short quote reads
    /// fine expanded; only a tall one earns the affordance.
    static let collapseButtonMinRunHeight: CGFloat = 60
    /// Side length of the collapse/expand SF-Symbol square.
    static let collapseButtonSize: CGFloat = 18

}

@available(iOS 13.0, *)
extension DocumentCanvasView {
    struct PlaceholderDraw { let text: String; let origin: CGPoint; let font: UIFont }

    /// Test/geometry seam: one entry per EMPTY top-level paragraph whose style has placeholder text.
    /// Production draws each placeholder in `BlockBox.draw`; this delegates to the same per-box
    /// `BlockBox.placeholderDraw()` so assertions match where it actually renders.
    func placeholderDraws() -> [PlaceholderDraw] {
        boxes.compactMap { box in
            guard let p = box as? BlockBox, let d = p.placeholderDraw() else { return nil }
            return PlaceholderDraw(text: d.text, origin: d.origin, font: d.font)
        }
    }
}
#endif
