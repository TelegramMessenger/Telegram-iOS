#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    // MARK: - Per-box collapse toggle (BlockQuoteBox, Task 12)

    /// Flips the `collapsed` flag on `box` (rebuild the box, relocate the caret, recompute). Mirrors the
    /// caret-relocation logic of `collapseQuoteRun`/`expandCollapsedQuote` for a single box.
    func toggleCollapsed(box: BlockQuoteBox) {
        guard let (parentStack, index) = parentStackAndIndex(of: box),
              case .blockQuote(var bq) = box.currentBlock() else { return }
        let wasCollapsed = bq.collapsed
        bq.collapsed.toggle()
        let oldStart = box.nodeStart, oldSize = box.nodeSize
        let beforeAnchor = anchor, beforeHead = head
        let caretTouched = (beforeHead >= oldStart && beforeHead < oldStart + oldSize)
            || (beforeAnchor >= oldStart && beforeAnchor < oldStart + oldSize)
        editing {
            let newBox = BlockQuoteBox(blockQuote: bq, mapper: mapper, quoteStyle: quoteStyle,
                                       pullQuoteStyle: pullQuoteStyle,
                                       expandImage: quoteCollapseIcons?.expand,
                                       collapseImage: quoteCollapseIcons?.collapse,
                                       width: effectiveWidth)
            parentStack.boxes.replaceSubrange(index...index, with: [newBox])
            recomputeSpans()
            if caretTouched {
                if wasCollapsed {   // EXPANDING: caret into the first child leaf
                    let caret = newBox.children.boxes.first?.leafRegions().first?.globalStart
                        ?? (newBox.nodeStart + 1)
                    return .caret(at: caret)
                } else {            // COLLAPSING: focus the caret on the collapsed quote's own leading gap —
                    // the atom's cursor slot (where a tap on the folded quote lands via `closestPosition`),
                    // NOT a trailing body paragraph. The folded quote is a block and owns this position.
                    return .caret(at: newBox.nodeStart)
                }
            } else {                // caret outside — preserve, shifted by the size delta
                let delta = newBox.nodeSize - oldSize
                func remap(_ p: Int) -> Int { p < oldStart ? p : p + delta }
                // A RANGE, not a caret: this arm PRESERVES the pre-fold selection, which need not be
                // collapsed. `.range` does not normalize its arguments, so a reversed selection stays
                // reversed — the same pair of writes, in the same order. **Collapsing it to `.caret(at:)`
                // is a live behaviour change that the whole suite passes** — measured; the numbers are on
                // the twin arm in `+Details.swift`'s `toggleDetailsExpanded`, not restated here.
                // **TASK 39 STEP 0a pinned this arm**:
                // `BlockQuoteBoxTests.test_toggleCollapsed_withARangeSelectionOutsideTheQuote_preservesBOTHEndpoints`
                // and its reversed twin, both proven red against the `.caret` spelling with the mutation
                // confirmed present first. The arming record is on the `+Details.swift` arm.
                return .range(remap(beforeAnchor), remap(beforeHead))
            }
        }
    }

    /// The owning `BlockStack` + index for `box` — a recursive descent matching by identity (`===`).
    /// Returns nil when the box is not in the tree.
    func parentStackAndIndex(of box: CanvasBlock) -> (BlockStack, Int)? {
        func descend(_ stack: BlockStack) -> (BlockStack, Int)? {
            for (i, b) in stack.boxes.enumerated() {
                if b === box { return (stack, i) }
                if let bq = b as? BlockQuoteBox, let found = descend(bq.children) { return found }
                if let d = b as? DetailsBox, let found = descend(d.children) { return found }
                if let t = b as? TableBlockBox {
                    for row in t.cells { for cell in row { if let found = descend(cell) { return found } } }
                }
            }
            return nil
        }
        return descend(root)
    }

    /// Walks the full box tree and returns the first `BlockQuoteBox` whose ACTIVE glyph rect (expanded →
    /// collapse glyph, collapsed → expand glyph) contains `point` (with a ±12pt touch inset). Used by
    /// `handleTap` to route glyph taps before normal caret placement.
    ///
    /// The walk mirrors `parentStackAndIndex(of:)`: it descends `BlockQuoteBox.children` AND sweeps every
    /// `TableBlockBox` cell, so a `BlockQuoteBox` nested inside a table cell is reachable.
    func firstBlockQuoteGlyphHit(at point: CGPoint) -> BlockQuoteBox? {
        func check(_ bq: BlockQuoteBox) -> BlockQuoteBox? {
            // Recurse into children FIRST (deepest-match wins): a tap on a nested quote's collapse
            // glyph must return the inner quote even when the outer quote's glyph rect (same x,
            // slightly different y) also contains the touch after the ±12pt inset expansion.
            if !bq.collapsed {
                for child in bq.children.boxes {
                    if let found = searchStack(child) { return found }
                }
            }
            // Then check this box's own glyph.
            let activeRect: CGRect? = {
                if bq.collapsed {
                    return bq.expandGlyphRect()
                } else {
                    // A short quote (≤ maxPreviewLines) shows no collapse control — nothing to fold.
                    return bq.isCollapsible ? bq.collapseGlyphRect() : nil
                }
            }()
            if let r = activeRect, r.insetBy(dx: -12, dy: -12).contains(point) { return bq }
            return nil
        }
        func searchStack(_ b: CanvasBlock) -> BlockQuoteBox? {
            if let bq = b as? BlockQuoteBox { return check(bq) }
            if let t = b as? TableBlockBox {
                for row in t.cells { for cell in row { for cellBox in cell.boxes { if let found = searchStack(cellBox) { return found } } } }
            }
            return nil
        }
        for b in boxes {
            if let found = searchStack(b) { return found }
        }
        return nil
    }
}
#endif
