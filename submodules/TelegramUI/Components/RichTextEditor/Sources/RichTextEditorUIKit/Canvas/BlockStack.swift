#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A vertical run of `CanvasBlock`s — the shared engine for the document body and for each table
/// cell. Owns span math (relative to a `baseOffset`) and vertical layout (relative to an origin).
@available(iOS 13.0, *)
final class BlockStack {
    var boxes: [CanvasBlock]
    private(set) var baseOffset: Int = 0
    private(set) var contentHeight: CGFloat = 0

    init(boxes: [CanvasBlock] = []) { self.boxes = boxes }

    /// Assigns each box's `nodeStart` (= running tokens + 1, relative to `baseOffset`) and returns
    /// the stack's total token size.
    @discardableResult
    func recompute(baseOffset: Int) -> Int {
        self.baseOffset = baseOffset
        var pos = baseOffset
        for box in boxes {
            box.nodeStart = pos + 1
            pos += box.nodeSize
        }
        return pos - baseOffset
    }

    /// Extra inset a block reserves on the side facing a block that draws its own bounded background or
    /// border — a quote's fill, a collapsed quote's fill, a code block's fill, or a table's grid — so that
    /// framed block has visible separation from its neighbors. Lives on the neighbor (external to the framed
    /// block), since a quote/code/table fills its own frame; the framed block's own inset is its internal padding.
    private static let framedNeighborMargin: CGFloat = 8

    /// The external inset any block reserves on the side facing an adjacent media (image/video/audio/
    /// location) block — the body↔image spacing rule. Kept as its own constant, DECOUPLED from
    /// `verticalInsetBase` (the inter-paragraph gap), so tuning body↔body spacing never moves body↔image.
    /// The media block itself keeps its own internal `MediaBlockBox.verticalInset` padding around the image.
    private static let mediaNeighborInset: CGFloat = 6

    /// A block that draws its own bounded fill and is NOT a `BlockBox`, so `facingInset` never runs for
    /// it: a code block, a table, a pull quote, or a block-quote box. Its own top/bottom insets are INTERNAL
    /// padding (fill→text), not external margin — so two of these adjacent would sit with their fills flush.
    private static func isFramedAtom(_ box: CanvasBlock) -> Bool {
        box is CodeBlockBox || box is TableBlockBox || box is PullQuoteBox || box is BlockQuoteBox || box is DetailsBox
    }

    /// Which vertical-rhythm model this stack lays out with.
    enum SpacingModel {
        /// InstantPage V2's pairwise rhythm (`richTextSpacingBetweenBlocks`) — the document's top-level
        /// sequence, so the editor's block spacing matches the rendered message.
        case instantPageV2
        /// The editor's pre-parity facing-inset model, kept VERBATIM for a stack nested inside a
        /// container (table cell, details, block-quote children). Those interiors have no V2 reference
        /// yet — the container-interior cycles own them — so this cycle leaves them exactly as they were
        /// rather than half-migrating them.
        case containerInterior
    }

    var spacingModel: SpacingModel = .instantPageV2

    /// Which kind of sequence this stack is, for the V2 rule table. `.cell` mirrors the renderer's own
    /// (currently unread) `.cell`.
    var sequenceKind: RichTextBlockSequenceKind = .topLevel

    /// The render metrics the V2 rule table reads. Set from the canvas's mapper so a host's metrics
    /// reach the rhythm as well as the fonts.
    var metrics: RichTextRenderMetrics = .default

    /// The inset for `box` on the side facing `neighbor` (or the stack edge, when nil). The facing
    /// insets of two adjacent blocks together make their gap: list items stack tight (0); two body
    /// paragraphs sit at half the default; a block facing a quote or table reserves extra margin;
    /// otherwise the default. Used only by `.containerInterior`.
    /// The base inter-block vertical inset (each side; two facing insets make a gap). Defaults to the
    /// document metric (`BlockBox.defaultVerticalInset`, 8pt); nested stacks set 0.
    var verticalInsetBase: CGFloat = BlockBox.defaultVerticalInset

    private func facingInset(of box: BlockBox, toward neighbor: CanvasBlock?) -> CGFloat {
        let base = self.verticalInsetBase
        // A table, a code block, a pull quote, and a block-quote box all draw their own bounded fill,
        // so a neighbor reserves extra framed margin for visible separation.
        if neighbor is TableBlockBox || neighbor is CodeBlockBox || neighbor is PullQuoteBox || neighbor is BlockQuoteBox || neighbor is DetailsBox { return base + BlockStack.framedNeighborMargin }
        // Any block facing a media (image/video/audio/location) block uses the dedicated body↔image inset,
        // independent of `base`. (Media is not a `BlockBox`, so it would otherwise fall through to `base`.)
        if neighbor is MediaBlockBox { return BlockStack.mediaNeighborInset }
        guard let n = neighbor as? BlockBox else { return base }
        // Two list items stack tight (0).
        if box.listMembership != nil && n.listMembership != nil { return 0 }
        // Any two adjacent body-style flow boxes stack tight (no inter-paragraph gap) — this covers a plain
        // body↔body pair, a body↔list-item boundary, and body-styled list items. The visible break is the
        // line advance alone, not a block inset. The document's outer top/bottom margins are unaffected
        // (they face a nil neighbor → `base`), and non-body flows (headings, quotes) keep `base`.
        if box.style == .body && n.style == .body { return 0 }
        return base
    }

    /// The gap ABOVE each box, plus the trailing edge gap — `boxes.count + 1` entries. V2 model only.
    ///
    /// A run of adjacent list items is collapsed to the single `.list` block the renderer sees, so the
    /// run's OUTER boundaries classify as `.list` while gaps INSIDE it are computed with `kind: .list`.
    /// Without the collapse, two bullet items would take the paragraph-to-paragraph 1pt rule and a list
    /// next to a paragraph would take the wrong arm entirely.
    func gaps() -> [CGFloat] {
        guard !boxes.isEmpty else { return [0] }
        let kinds = boxes.map { $0.spacingKind }
        /// True when boxes i and i+1 are both members of the same list run.
        func insideListRun(_ i: Int) -> Bool {
            return i >= 0 && i + 1 < kinds.count && kinds[i] == .list && kinds[i + 1] == .list
        }
        var result: [CGFloat] = []
        result.reserveCapacity(kinds.count + 1)
        for i in 0...kinds.count {
            let upper: RichTextBlockSpacingKind? = i > 0 ? kinds[i - 1] : nil
            let lower: RichTextBlockSpacingKind? = i < kinds.count ? kinds[i] : nil
            if insideListRun(i - 1) {
                // Inside a list run the two neighbours are ITEMS of one block, so they are classified as
                // the paragraphs they are and measured with the in-list rule.
                result.append(richTextSpacingBetweenBlocks(upper: .paragraph, lower: .paragraph,
                                                           kind: .list, metrics: metrics))
            } else {
                result.append(richTextSpacingBetweenBlocks(upper: upper, lower: lower,
                                                           kind: sequenceKind, metrics: metrics))
            }
        }
        return result
    }

    /// The gap laid down as BARE space above box `i` — space that belongs to no box frame.
    ///
    /// **A height summed from box heights alone misses exactly this**, which is why it is a named
    /// quantity rather than an inline `y +=`: `layout` and `currentHeight` both read it, so the
    /// ownership rule has ONE expression and the laid-out extent and the reported content height cannot
    /// disagree. (They did: the scroll content came up short by every bare gap, so a document with
    /// non-paragraph blocks could not be scrolled to its end — the last block sat below the scrollable
    /// range, behind the host's bottom inset band.)
    private func bareGapAbove(_ i: Int, _ g: [CGFloat]) -> CGFloat {
        switch spacingModel {
        case .instantPageV2:
            // A framed block (table / code / quote / details) fills its own frame and has no external
            // inset to put a gap in, so the gap above it is owned by the PARAGRAPH above (as that box's
            // `bottomInset`). Only when there is no such paragraph — the sequence edge, or two adjacent
            // framed atoms — is it laid down as bare space.
            //
            // LOAD-BEARING: leaving it unowned in the paragraph case makes the canvas discontiguous, and
            // the arrow-key escape probe (`owner.frame.minY - step/2` in `+Navigation`) then lands in
            // dead space and the caret cannot leave a table.
            guard !(boxes[i] is BlockBox) else { return 0 }
            return (i == 0 || !(boxes[i - 1] is BlockBox)) ? g[i] : 0
        case .containerInterior:
            // Two adjacent framed atoms (code / table / collapsed quote) both fill their whole frames, so
            // neither's internal padding separates the two fills. The external gap between them matches
            // the separation a `BlockBox` neighbor reserves toward a framed atom (`facingInset` rule 1).
            guard i > 0, BlockStack.isFramedAtom(boxes[i - 1]), BlockStack.isFramedAtom(boxes[i]) else { return 0 }
            return self.verticalInsetBase + BlockStack.framedNeighborMargin
        }
    }

    /// The bare gap below the LAST box — a trailing framed atom cannot own the bottom edge gap either.
    private func bareTrailingGap(_ g: [CGFloat]) -> CGFloat {
        guard spacingModel == .instantPageV2, let last = boxes.last, !(last is BlockBox) else { return 0 }
        return g[boxes.count]
    }

    /// Lays boxes out top-to-bottom from `origin` at the given content `width`; returns total height.
    ///
    /// - Parameter codeBleed: How far a full-bleed child (today: only `CodeBlockBox`) may extend past
    ///   this stack's content column to reach the enclosing container's interior edges. GEOMETRIC
    ///   sides, mirroring the renderer's `InstantPageV2ChildBleed`. Defaults to none, so a container
    ///   that has not opted in keeps its children inside it.
    @discardableResult
    func layout(origin: CGPoint, width: CGFloat,
                codeBleed: (minXSide: CGFloat, maxXSide: CGFloat) = (0, 0)) -> CGFloat {
        var y = origin.y
        let g = spacingModel == .instantPageV2 ? gaps() : []
        for i in boxes.indices {
            let box = boxes[i]
            if let b = box as? BlockBox {
                switch spacingModel {
                case .instantPageV2:
                    // The gap is ONE quantity, carried by the LOWER block where it can be — so a tap in
                    // the gap lands in the block you are heading toward. The upper contributes nothing
                    // below it, so a gap is never counted twice.
                    b.topInset = g[i]
                    // The trailing edge gap, plus any gap the NEXT block cannot own itself.
                    let next: CanvasBlock? = i + 1 < boxes.count ? boxes[i + 1] : nil
                    b.bottomInset = next == nil ? g[boxes.count] : (next is BlockBox ? 0 : g[i + 1])
                case .containerInterior:
                    let prev: CanvasBlock? = i > 0 ? boxes[i - 1] : nil
                    let next: CanvasBlock? = i + 1 < boxes.count ? boxes[i + 1] : nil
                    b.topInset = facingInset(of: b, toward: prev)
                    b.bottomInset = facingInset(of: b, toward: next)
                }
            }
            if let code = box as? CodeBlockBox { code.horizontalBleed = codeBleed }
            y += bareGapAbove(i, g)
            box.setWidth(width)
            box.frame = CGRect(x: origin.x, y: y, width: width, height: box.height)
            y += box.height
        }
        y += bareTrailingGap(g)
        contentHeight = y - origin.y
        return contentHeight
    }

    /// The height this stack CURRENTLY occupies: each box's live `height` plus the bare gaps that belong
    /// to no box frame. The live counterpart of `layout`'s return value — same arithmetic over the same
    /// helpers — readable BEFORE a layout pass, which is what the canvas needs (it must size its frame
    /// before it can lay out into it). Distinct from `measuredHeight(forWidth:)`, which re-measures each
    /// box's content at a hypothetical width instead of reading the laid-out heights.
    var currentHeight: CGFloat {
        guard !boxes.isEmpty else { return 0 }
        let g = spacingModel == .instantPageV2 ? gaps() : []
        var total: CGFloat = 0
        for i in boxes.indices {
            total += bareGapAbove(i, g)
            total += boxes[i].height
        }
        return total + bareTrailingGap(g)
    }

    /// Stateless total height at content `width` — the measure analogue of `layout`'s returned height.
    /// Never mutates a box.
    ///
    /// In the V2 model it computes its own gaps rather than reading the boxes' insets, so it is correct
    /// BEFORE the first `layout` — a host that sizes its field from a measure taken before the editor is
    /// framed would otherwise get a height short by every gap.
    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        guard !boxes.isEmpty else { return 0 }
        switch spacingModel {
        case .instantPageV2:
            let g = gaps()
            var total: CGFloat = 0
            for (i, box) in boxes.enumerated() {
                total += g[i]
                total += box.measuredContentHeight(forWidth: width)
            }
            return total + g[boxes.count]
        case .containerInterior:
            var total: CGFloat = 0
            for (i, box) in boxes.enumerated() {
                // Mirror the external gap `layout` inserts between two adjacent framed atoms, so the
                // stateless measure matches the laid-out height.
                if i > 0, BlockStack.isFramedAtom(boxes[i - 1]), BlockStack.isFramedAtom(box) {
                    total += self.verticalInsetBase + BlockStack.framedNeighborMargin
                }
                total += box.measuredHeight(forWidth: width)
            }
            return total
        }
    }

    func leafRegions() -> [LeafTextRegion] { boxes.flatMap { $0.leafRegions() } }
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) { for b in boxes { b.draw(in: ctx, imageProvider: imageProvider) } }

    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        guard !boxes.isEmpty else { return baseOffset }
        let box = boxes.first(where: { point.y < $0.frame.maxY }) ?? boxes[boxes.count - 1]
        return box.closestPosition(toCanvasPoint: point)
    }
}
#endif
