#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Paragraph-level formatting commands. They apply to every top-level `BlockBox` the selection
/// touches (a collapsed caret = its one paragraph), mutate the box's `style` / `paragraphAttributes`,
/// and run inside `editing { }` for undo. Top-level only in 5a — paragraph styles inside table cells
/// (headings in cells aren't meaningful GFM) are out of scope.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Assigns a named paragraph style (Title/H1–H3/Body/Quote) to the touched paragraphs and rebuilds
    /// their run layout so the style's font (size/weight) actually applies. Run size/family pins are
    /// cleared so the style decides them; user bold/italic/strike/code and links are preserved.
    /// Title/headings are regular-weight by default (StyleSheet.font no longer forces bold), so bold is a
    /// pure user toggle that round-trips uniformly — a heading→body down-convert carries no residual bold.
    func setParagraphStyle(_ name: ParagraphStyleName) {
        guard !boxes.isEmpty else { return }
        editing {
            for p in selectedBlockBoxes() {   // top level AND inside a detail block's body
                p.style = name
                var para = p.currentParagraph()
                para.runs = para.runs.map { run in
                    var a = run.attributes
                    a.fontSize = nil
                    a.fontFamily = nil
                    return TextRun(text: run.text, attributes: a)
                }
                p.layout.attributedString = mapper.attributedString(for: para)
            }
            recomputeSpans()
            return .unchanged
        }
    }

    /// Toggle the touched top-level paragraphs into a single code block, or (if the selection is already a
    /// single code block) toggle it back into body paragraphs split on "\n". Top-level only. Runs in
    /// `editing { }`.
    func makeCodeBlock() {
        guard !boxes.isEmpty else { return }
        // Operate on the caret's OWN stack (top level OR a detail block's body), so Code toggles work inside a
        // details body too. A cross-stack selection is not toggled.
        let selLo = min(selFrom, selTo), selHi = max(selFrom, selTo)
        guard sameOwningStack(selLo, selHi), let owning = activeStack(at: selLo)?.stack else { return }
        let stackBoxes = owning.boxes
        let touched = stackBoxes.indices.filter { i in
            let b = stackBoxes[i]
            let lo = b.textStart, hi = b.textStart + b.textLength
            return selLo <= hi && selHi >= lo
        }
        guard let first = touched.first, let last = touched.last else { return }
        // Gathers flat text from a paragraph or code block; nil for non-text blocks (image/table).
        func boxText(_ box: CanvasBlock) -> String? {
            if let p = box as? BlockBox { return p.currentParagraph().text }
            if let c = box as? CodeBlockBox { return c.currentCode().text }
            return nil   // media/table: no flat-text representation
        }
        let isToggleOff = touched.count == 1 && stackBoxes[first] is CodeBlockBox
        // Refuse a toggle-ON that spans a non-text block (image/table) — replaceSubrange would
        // otherwise silently delete it. Must run BEFORE `editing { }` to avoid a no-op undo entry.
        if !isToggleOff, (first...last).contains(where: { boxText(stackBoxes[$0]) == nil }) { return }
        editing {
            if isToggleOff, let codeBox = stackBoxes[first] as? CodeBlockBox {
                // Toggle OFF: split the code text on "\n" into body paragraphs.
                let lines = codeBox.currentCode().text.components(separatedBy: "\n")
                let paras: [CanvasBlock] = lines.map { line in
                    BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body,
                                                       runs: line.isEmpty ? [] : [TextRun(text: line)]),
                             mapper: mapper, width: effectiveWidth)
                }
                var newBoxes = owning.boxes
                newBoxes.replaceSubrange(first...first, with: paras)
                owning.boxes = newBoxes
                recomputeSpans()
                return .caret(at: paras[0].textStart)
            }
            // Toggle ON: join the touched blocks' text with "\n" into one code block. Existing code
            // block text is preserved (not dropped); the guard above already ensured every block
            // in range has a flat-text representation.
            let text = (first...last).compactMap { boxText(stackBoxes[$0]) }.joined(separator: "\n")
            let codeBox = CodeBlockBox(code: CodeBlock(id: BlockID.generate(), language: nil,
                                                       runs: [TextRun(text: text)]),
                                       mapper: mapper, width: effectiveWidth)
            var newBoxes = owning.boxes
            newBoxes.replaceSubrange(first...last, with: [codeBox])
            owning.boxes = newBoxes
            recomputeSpans()
            return .caret(at: codeBox.textStart + codeBox.textLength)   // caret at END of new code block
        }
    }

    /// Toggle the touched top-level paragraphs into a single pull-quote block, or (if the selection
    /// is already a single pull-quote block) toggle it back into body paragraphs split on "\n".
    /// Top-level only. Runs in `editing { }`. Unlike `makeCodeBlock`, a pull quote PRESERVES inline
    /// formatting (bold/italic/link/…): runs are gathered/emitted, not flattened to plain text.
    func makePullQuote() {
        guard !boxes.isEmpty else { return }
        // Operate on the caret's OWN stack (top level OR a detail block's body). A cross-stack selection is
        // not toggled.
        let selLo = min(selFrom, selTo), selHi = max(selFrom, selTo)
        guard sameOwningStack(selLo, selHi), let owning = activeStack(at: selLo)?.stack else { return }
        let stackBoxes = owning.boxes
        let touched = stackBoxes.indices.filter { i in
            let b = stackBoxes[i]
            let lo = b.textStart, hi = b.textStart + b.textLength
            return selLo <= hi && selHi >= lo
        }
        guard let first = touched.first, let last = touched.last else { return }
        // Gathers runs from a paragraph or pull-quote block; nil for non-text blocks (image/table/code).
        func boxRuns(_ box: CanvasBlock) -> [TextRun]? {
            if let p = box as? BlockBox { return p.currentParagraph().runs }
            if let pq = box as? PullQuoteBox, case .pullQuote(let q) = pq.currentBlock() { return q.runs }
            return nil   // media/table/code/collapsedQuote: refuse
        }
        let isToggleOff = touched.count == 1 && stackBoxes[first] is PullQuoteBox
        // Refuse a toggle-ON that spans a non-text block (image/table/code) — replaceSubrange would
        // otherwise silently delete it. Must run BEFORE `editing { }` to avoid a no-op undo entry.
        if !isToggleOff, (first...last).contains(where: { boxRuns(stackBoxes[$0]) == nil }) { return }
        editing {
            if isToggleOff, let pqBox = stackBoxes[first] as? PullQuoteBox,
               case .pullQuote(let q) = pqBox.currentBlock() {
                // Toggle OFF: split the pull-quote runs on "\n" into body paragraphs, preserving attributes.
                let paras: [CanvasBlock] = paragraphRunsSplitByNewline(q.runs).map { runs in
                    BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: runs),
                             mapper: mapper, width: effectiveWidth)
                }
                var newBoxes = owning.boxes
                newBoxes.replaceSubrange(first...first, with: paras)
                owning.boxes = newBoxes
                recomputeSpans()
                return .caret(at: paras[0].textStart)
            }
            // Toggle ON: join the touched blocks' runs with a "\n" separator between blocks into one
            // pull-quote. The guard above already ensured every block in range has a run representation.
            var joined: [TextRun] = []
            for (n, i) in (first...last).enumerated() {
                if n > 0 { joined.append(TextRun(text: "\n")) }
                joined.append(contentsOf: boxRuns(stackBoxes[i]) ?? [])
            }
            let pqBox = PullQuoteBox(pullQuote: PullQuote(id: BlockID.generate(), runs: joined),
                                     mapper: mapper, pullQuoteStyle: pullQuoteStyle, width: effectiveWidth)
            var newBoxes = owning.boxes
            newBoxes.replaceSubrange(first...last, with: [pqBox])
            owning.boxes = newBoxes
            recomputeSpans()
            return .caret(at: pqBox.textStart + pqBox.textLength)   // caret at END of new pull-quote block
        }
    }

    /// Split a run array at "\n" characters into separate per-paragraph run arrays, preserving per-run
    /// attributes. Used by `makePullQuote` to toggle a pull-quote back into body paragraphs.
    private func paragraphRunsSplitByNewline(_ runs: [TextRun]) -> [[TextRun]] {
        var paras: [[TextRun]] = [[]]
        for run in runs {
            let segs = run.text.components(separatedBy: "\n")
            for (i, seg) in segs.enumerated() {
                if i > 0 { paras.append([]) }
                if !seg.isEmpty { paras[paras.count - 1].append(TextRun(text: seg, attributes: run.attributes)) }
            }
        }
        return paras
    }

    /// Wraps the touched block(s) of the active stack into one `Block.blockQuote`, preserving them as
    /// children (no flattening). When the caret is already inside a block quote, the active stack is that
    /// quote's child stack, so re-applying Quote nests one level deeper. Runs in `editing { }`. Expanded
    /// quotes only (collapse is a later task).
    ///
    /// No-ops when the caret (or either selection endpoint) is inside a table cell — wrapping a cell's
    /// content into a block quote is not supported (a `TableBlockBox.cellStack` does not recurse into
    /// block quotes; the result would be a half-broken state where Enter is silently dropped).
    func wrapInBlockQuote() {
        let lo = min(selFrom, selTo), hi = max(selFrom, selTo)
        // Refuse if either endpoint is inside a table cell.
        guard !isInsideTable(lo), !isInsideTable(hi) else { return }
        // Require both endpoints share the same owning stack (root, or a quote's child stack).
        // Fall back to the top-level stack for cross-stack selections.
        guard sameOwningStack(lo, hi), let owning = activeStack(at: lo)?.stack else {
            wrapTopLevelInBlockQuote(); return
        }
        let stackBoxes = owning.boxes
        let touched = stackBoxes.indices.filter { i in
            let b = stackBoxes[i]; return lo <= b.textStart + b.textLength && hi >= b.textStart
        }
        guard let first = touched.first, let last = touched.last else { return }
        let children = (first...last).map { stackBoxes[$0].currentBlock() }
        let bqBox = BlockQuoteBox(blockQuote: BlockQuote(id: .generate(), children: children, collapsed: false),
                                  mapper: mapper, quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle,
                                  expandImage: quoteCollapseIcons?.expand,
                                  collapseImage: quoteCollapseIcons?.collapse, width: effectiveWidth)
        editing {
            owning.boxes.replaceSubrange(first...last, with: [bqBox])
            recomputeSpans()
            // Land the caret at the start of the first child in the new block quote.
            let caret = bqBox.children.boxes.first?.leafRegions().first?.globalStart ?? (bqBox.nodeStart + 1)
            return .caret(at: caret)
        }
    }

    /// Fallback for cross-stack selections: wraps the touched TOP-LEVEL boxes (root stack) into one
    /// `Block.blockQuote`. Called when the selection endpoints don't share a single owning stack.
    private func wrapTopLevelInBlockQuote() {
        let lo = min(selFrom, selTo), hi = max(selFrom, selTo)
        let touched = boxes.indices.filter { i in
            let b = boxes[i]; return lo <= b.textStart + b.textLength && hi >= b.textStart
        }
        guard let first = touched.first, let last = touched.last else { return }
        let children = (first...last).map { boxes[$0].currentBlock() }
        let bqBox = BlockQuoteBox(blockQuote: BlockQuote(id: .generate(), children: children, collapsed: false),
                                  mapper: mapper, quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle,
                                  expandImage: quoteCollapseIcons?.expand,
                                  collapseImage: quoteCollapseIcons?.collapse, width: effectiveWidth)
        editing {
            var newBoxes = boxes
            newBoxes.replaceSubrange(first...last, with: [bqBox])
            boxes = newBoxes
            recomputeSpans()
            let caret = bqBox.children.boxes.first?.leafRegions().first?.globalStart ?? (bqBox.nodeStart + 1)
            return .caret(at: caret)
        }
    }

    /// The DEEPEST BlockQuoteBox whose token span contains `pos`, plus the stack it lives in and its index there.
    private func enclosingBlockQuote(at pos: Int) -> (box: BlockQuoteBox, parentStack: BlockStack, index: Int)? {
        var result: (BlockQuoteBox, BlockStack, Int)? = nil
        func descend(_ stack: BlockStack) {
            for (i, b) in stack.boxes.enumerated() {
                if let bq = b as? BlockQuoteBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    result = (bq, stack, i)          // record; a deeper quote inside overwrites it
                    descend(bq.children)
                } else if let t = b as? TableBlockBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    for row in t.cells { for cell in row { descend(cell) } }
                }
            }
        }
        descend(root)
        return result
    }

    /// The DEEPEST block-quote-OR-pull-quote box whose token span contains `pos`, plus the stack it lives
    /// in and its index there. Generalizes `enclosingBlockQuote` to also match `PullQuoteBox` — used by the
    /// Return-in-author-line split, which needs to rebuild either quote kind uniformly. Still descends into
    /// `BlockQuoteBox.children` (so a caret in a NESTED quote's author resolves to that inner quote, not the
    /// outer one) and into table cells.
    func enclosingQuote(at pos: Int) -> (box: CanvasBlock, parentStack: BlockStack, index: Int)? {
        var result: (CanvasBlock, BlockStack, Int)? = nil
        func descend(_ stack: BlockStack) {
            for (i, b) in stack.boxes.enumerated() {
                if let bq = b as? BlockQuoteBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    result = (bq, stack, i)          // record; a deeper quote inside overwrites it
                    descend(bq.children)
                } else if b is PullQuoteBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    result = (b, stack, i)
                } else if let t = b as? TableBlockBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    for row in t.cells { for cell in row { descend(cell) } }
                }
            }
        }
        descend(root)
        return result
    }

    /// "None": removes exactly one block-quote level around the caret — the deepest enclosing quote's children are
    /// spliced back into its parent stack in place. At level 1 they become top-level blocks. Runs in `editing { }`.
    func unwrapBlockQuoteLevel() {
        guard let (bqBox, parentStack, index) = enclosingBlockQuote(at: min(anchor, head)) else { return }
        guard case .blockQuote(let model) = bqBox.currentBlock() else { return }
        let childBoxes = model.children.compactMap {
            makeBox(for: $0, mapper: mapper, quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle,
                    expandImage: quoteCollapseIcons?.expand, collapseImage: quoteCollapseIcons?.collapse,
                    horizontalBleed: 0, width: effectiveWidth) }
        editing {
            parentStack.boxes.replaceSubrange(index...index, with: childBoxes)
            recomputeSpans()
            let caret = childBoxes.first?.leafRegions().first?.globalStart ?? bqBox.nodeStart
            return .caret(at: caret)
        }
    }

    /// If the caret sits on an EMPTY child that is the LAST child of its enclosing block quote, exit: remove that
    /// empty child and drop a body paragraph AFTER the quote (or, if it was the quote's only child, REPLACE the quote
    /// with that body paragraph). Returns true when it handled the exit. Runs in `editing { }`.
    func blockQuoteEmptyTrailingChildExit() -> Bool {
        guard let active = activeStack(at: head), let child = active.box as? BlockBox, child.textLength == 0,
              let (bqBox, parentStack, index) = enclosingBlockQuote(at: head),
              bqBox.children.boxes.last === child else { return false }
        // A WHOLLY-EMPTY quote (this empty line is its ONLY child) must NOT escape on a single Return — the
        // quote-escape requires a double Return (\n\n). The first Return falls through to insertParagraphBreak
        // (adds a second empty line inside the quote); the second Return lands here with ≥2 children and escapes.
        guard bqBox.children.boxes.count > 1 else { return false }
        editing {
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            let allEmpty = bqBox.children.boxes.allSatisfy { ($0 as? BlockBox)?.textLength == 0 }
            if allEmpty {
                // \n\n in a wholly-empty quote → un-quote the whole (empty) quote to a single body paragraph.
                parentStack.boxes.replaceSubrange(index...index, with: [body])
            } else {
                bqBox.children.boxes.removeLast()                                // drop the empty trailing child
                parentStack.boxes.insert(body, at: index + 1)                   // body after the quote
            }
            recomputeSpans()
            let caret = body.leafRegions().first?.globalStart ?? body.nodeStart
            return .caret(at: caret)
        }
        return true
    }

    /// Double-return at the BEGINNING of a block quote (\n\n): a caret at the start (local 0) of the quote's
    /// first content line, with an empty line directly above it — the caret is ON that leading blank line
    /// (`active.index == 0`) OR at the start of the content right after it (`active.index == 1`), mirroring the
    /// code/pull `.before` case — exits the quote with an empty body paragraph placed BEFORE it (the leading
    /// blank line is dropped). Only fires when the quote still has content; a WHOLLY-empty quote is handled by
    /// `blockQuoteEmptyTrailingChildExit` above (which un-quotes the whole thing), so this never strands an
    /// empty quote. Checked AFTER the trailing exit so the wholly-empty case takes the un-quote path.
    func blockQuoteEmptyLeadingChildExit() -> Bool {
        guard let active = activeStack(at: head), active.local == 0,
              let (bqBox, parentStack, index) = enclosingBlockQuote(at: head),
              bqBox.children.boxes.count > 1, active.index <= 1,
              let first = bqBox.children.boxes.first as? BlockBox, first.textLength == 0,
              !bqBox.children.boxes.allSatisfy({ ($0 as? BlockBox)?.textLength == 0 }) else { return false }
        editing {
            let body = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                mapper: mapper, width: effectiveWidth)
            bqBox.children.boxes.removeFirst()             // drop the leading blank line
            parentStack.boxes.insert(body, at: index)      // body paragraph BEFORE the quote
            recomputeSpans()
            let caret = body.leafRegions().first?.globalStart ?? body.nodeStart
            return .caret(at: caret)
        }
        return true
    }

    /// Sets paragraph alignment on the touched paragraphs. Alignment is a pure paragraph-style
    /// property, so `restyle` (which re-applies `.paragraphStyle`) suffices — no font rebuild.
    func setAlignment(_ alignment: TextAlignment) {
        guard !boxes.isEmpty else { return }
        editing {
            for box in boxes {
                guard let p = box as? BlockBox else { continue }
                let lo = p.textStart, hi = p.textStart + p.textLength
                guard selFrom <= hi && selTo >= lo else { continue }
                p.paragraphAttributes.alignment = alignment
                restyle(p)
            }
            recomputeSpans()
            return .unchanged
        }
    }

    /// Number of block quotes enclosing `pos` (0 = not in a quote; N = nested N levels deep).
    func blockQuoteDepth(at pos: Int) -> Int {
        var depth = 0
        func descend(_ stack: BlockStack) {
            for b in stack.boxes {
                if let bq = b as? BlockQuoteBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    depth += 1; descend(bq.children)
                } else if let t = b as? TableBlockBox, pos > b.nodeStart, pos < b.nodeStart + b.nodeSize {
                    for row in t.cells { for cell in row { descend(cell) } }
                }
            }
        }
        descend(root)
        return depth
    }
}
#endif
