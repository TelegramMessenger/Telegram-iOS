import Foundation

// MARK: - Task 3: insertingFragment helpers

/// True for a fragment block that pastes by folding its runs INLINE into the host paragraph, which
/// keeps the HOST's paragraph style. Quotes, list items, and code blocks always paste as their own
/// block.
///
/// **The two directions are not symmetric, and treating them as one destroys headings.** Folding
/// discards the fragment paragraph's own style, so it is lossless only when the fragment has no style
/// to lose:
///   - a plain BODY paragraph carries no block structure → always folds. This is the case that MUST
///     keep folding: pasting text into a heading has to stay in the heading.
///   - a HEADING paragraph loses its level when folded → folds only into a host that is already that
///     same style (`# X` pasted inside an H1 should not shatter it into three blocks). Anywhere else
///     it stands as its own block, and the caller's split-and-assemble path places it.
///
/// This used to accept every heading level unconditionally, so a fragment beginning (or ending) with a
/// heading folded into the body paragraph it was pasted into — the reported "pasting a copied rich
/// message loses its headings", since the chat composer's host paragraph is always body.
public func isInlineMergeable(_ block: Block, intoHostStyle hostStyle: ParagraphStyleName) -> Bool {
    guard case .paragraph(let p) = block, p.list == nil else { return false }
    switch p.style {
    case .body: return true
    case .heading1, .heading2, .heading3, .heading4, .heading5, .heading6: return p.style == hostStyle
    case .caption, .pullQuote: return false
    }
}

/// Recursively regenerates fresh `BlockID`s for a list of blocks (for paste collision avoidance). Block views
/// are keyed by `BlockID`, so a paste that reuses an existing block's id steals its view and the original block
/// disappears. The switch is EXHAUSTIVE (no `default`) on purpose: a new `Block` case must decide how its ids
/// regenerate rather than silently falling through and reintroducing that bug.
private func regeneratingIDs(_ blocks: [Block]) -> [Block] {
    blocks.map { block in
        switch block {
        case .paragraph(let p):
            return .paragraph(ParagraphBlock(id: .generate(), style: p.style,
                                             paragraph: p.paragraph, list: p.list, runs: p.runs))
        case .code(let c):
            return .code(CodeBlock(id: .generate(), language: c.language, runs: c.runs))
        case .pullQuote(let pq):
            return .pullQuote(PullQuote(id: .generate(), runs: pq.runs, author: pq.author))
        case .blockQuote(let bq):
            return .blockQuote(BlockQuote(id: .generate(), children: regeneratingIDs(bq.children), collapsed: bq.collapsed, author: bq.author))
        case .details(let d):
            return .details(DetailsBlock(id: .generate(), title: d.title,
                                         children: regeneratingIDs(d.children), expanded: d.expanded))
        case .table(let t):
            // Regenerate the table AND its nested row/cell/inner-block IDs — a pasted "Copy Table" carries the
            // source table's IDs verbatim, and block views are keyed by BlockID, so a duplicate-ID paste would
            // steal the original table's view and make the original disappear.
            // Only the IDENTITIES are regenerated — every table/cell ATTRIBUTE is forwarded. Omitting one
            // silently changes the pasted table: `compact`/`bordered` reset to their defaults (a copied
            // unbordered table pastes back bordered) and `colspan`/`rowspan` reset to 1, splitting merged
            // cells apart.
            return .table(TableBlock(id: .generate(), columns: t.columns, rows: t.rows.map { row in
                Row(id: .generate(), height: row.height, cells: row.cells.map { cell in
                    Cell(id: .generate(), blocks: regeneratingIDs(cell.blocks), background: cell.background,
                         horizontalAlignment: cell.horizontalAlignment, verticalAlignment: cell.verticalAlignment,
                         isHeader: cell.isHeader, colspan: cell.colspan, rowspan: cell.rowspan)
                })
            }, compact: t.compact, bordered: t.bordered))
        case .media(let m):
            // Regenerate the block id only; `mediaID` is the host's content key (may legitimately repeat across
            // blocks), and the caption is inline `[TextRun]` with no nested BlockID. Use the container init and
            // pass `items` through wholesale — a multi-media container's items carry no BlockID of their own, so
            // regeneration is a pure passthrough — else this drops every item past the first (mirrors the Task-7
            // fix in DocumentCanvasView+Editing.swift, which hit the same legacy-single-item-init trap).
            return .media(MediaBlock(id: .generate(), items: m.items,
                                     displayWidth: m.displayWidth, alignment: m.alignment, caption: m.caption))
        case .buttonRow(let r):
            // Regenerate the row id only. A `ButtonRef` carries no `BlockID` of its own (a pill is
            // identified positionally, by its index in the row), so the buttons pass through wholesale.
            return .buttonRow(ButtonRowBlock(id: .generate(), buttons: r.buttons, alignment: r.alignment))
        }
    }
}

extension Document {
    /// Returns a copy with every top-level block given a fresh `BlockID`, recursing into block quotes.
    public func regeneratingTopLevelIDs() -> Document {
        Document(schemaVersion: schemaVersion, blocks: regeneratingIDs(blocks))
    }

    /// Splices `fragment` into this document at the global caret. Returns the new document and the
    /// caret position at the end of the pasted content, or nil if `caret` is not in a top-level
    /// paragraph/code text region (caller falls back to a plain insert).
    public func insertingFragment(_ fragment: Document, atGlobal caret: Int) -> (document: Document, caret: Int)? {
        let frag = fragment.regeneratingTopLevelIDs().blocks
        guard let locus = topLevelTextLocus(globalCaret: caret) else { return nil }
        guard !frag.isEmpty else { return (self, caret) }
        var newBlocks = blocks

        // Destination is a code block → flatten the fragment to text and insert inline.
        if case .code(let host) = blocks[locus.index] {
            let inserted = frag.map(blockPlainText).joined(separator: "\n")
            let runs = insertingText(inserted, into: host.runs, atUTF16: locus.local)
            newBlocks[locus.index] = .code(CodeBlock(id: host.id, language: host.language, runs: runs))
            return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                    caret + (inserted as NSString).length)
        }

        guard case .paragraph(let host) = blocks[locus.index] else { return nil }
        let (headHalf, tailHalf) = host.split(at: locus.local, newID: .generate())

        // Single inline-mergeable paragraph → fold its runs into the host paragraph.
        if frag.count == 1, isInlineMergeable(frag[0], intoHostStyle: host.style), case .paragraph(let only) = frag[0] {
            let merged = ParagraphBlock(id: host.id, style: host.style, paragraph: host.paragraph,
                                        list: host.list, runs: headHalf.runs + only.runs + tailHalf.runs)
            newBlocks[locus.index] = .paragraph(merged)
            return (Document(schemaVersion: schemaVersion, blocks: newBlocks), caret + only.utf16Count)
        }

        // Multi-block (or a single non-inline block): split host, merge inline-compatible ends.
        var middle = frag
        var headBlock = Block.paragraph(headHalf)
        var tailPara = ParagraphBlock(id: .generate(), style: host.style, paragraph: host.paragraph,
                                      list: host.list, runs: tailHalf.runs)
        var caretInTail = 0

        // Both split halves carry the host's style, so both ends test against it.
        if let first = middle.first, isInlineMergeable(first, intoHostStyle: host.style), case .paragraph(let fp) = first {
            headBlock = .paragraph(headHalf.merging(fp))
            middle.removeFirst()
        }
        if let last = middle.last, isInlineMergeable(last, intoHostStyle: host.style), case .paragraph(let lp) = last {
            tailPara = ParagraphBlock(id: tailPara.id, style: tailPara.style, paragraph: tailPara.paragraph,
                                      list: tailPara.list, runs: lp.runs + tailPara.runs)
            caretInTail = lp.utf16Count
            middle.removeLast()
        }

        var assembled = [headBlock] + middle + [Block.paragraph(tailPara)]
        // The empty halves of the split host that no pasted block merged into would be spurious blank lines
        // around the paste (most visible: pasting a list / quote / code — non-inline-mergeable — at a
        // paragraph end leaves a trailing empty paragraph; at a paragraph start, a leading one). These are
        // EXACTLY `headBlock`/`tailPara` — the split halves — so dropping is keyed on emptiness of the
        // OUTERMOST block only, never a pasted fragment block (those sit in `middle`, and even when a single
        // fragment block inline-merges into a split half it folds INTO `headBlock`/`tailPara`, so the merged
        // result is what's tested). Drop a trailing and/or leading empty paragraph as long as content remains.
        // "Empty" is text-emptiness (`text.isEmpty`) — a paragraph may carry either no runs or one zero-length
        // run; both must be treated as a blank line. A non-empty tail (mid-paragraph paste) and interior empty
        // paragraphs within the fragment (which live in `middle`, not at an end) are untouched.
        let tailDropped = { () -> Bool in
            if case .paragraph(let t) = assembled.last, t.text.isEmpty, assembled.count > 1 {
                assembled.removeLast(); return true
            }
            return false
        }()
        if case .paragraph(let h) = assembled.first, h.text.isEmpty, assembled.count > 1 {
            assembled.removeFirst()
        }
        newBlocks.replaceSubrange(locus.index...locus.index, with: assembled)
        let newDoc = Document(schemaVersion: schemaVersion, blocks: newBlocks)
        // `lastIndex` is computed AFTER both removals so a leading drop doesn't skew it.
        let lastIndex = locus.index + assembled.count - 1
        let caretPos: Int
        if tailDropped {
            // The empty host-tail was dropped → the caret goes to the END of the new last block (the last
            // pasted block); `caretInTail` (0 here, since the tail wasn't inline-merged) no longer applies.
            let lastLen: Int
            switch assembled.last! {
            case .paragraph(let p): lastLen = p.utf16Count
            case .code(let c): lastLen = c.utf16Count
            case .pullQuote(let pq): lastLen = pq.utf16Count
            default: lastLen = 0
            }
            caretPos = newDoc.globalTextStart(ofBlockAt: lastIndex) + lastLen
        } else {
            // The tail survived (real content after the caret, or an inline-merged tail) → keep the original target.
            caretPos = newDoc.globalTextStart(ofBlockAt: lastIndex) + caretInTail
        }
        return (newDoc, caretPos)
    }
}

/// The global offset from a top-level block's own start to its editable CODE text. A code block is a
/// container of [languagePara, codePara] (see `DocumentTree.node(for:)`), so its code text sits three
/// tokens past where a bare paragraph's would: language open + language text + language close + code open.
func codeTextStartOffset(_ code: CodeBlock) -> Int { 4 + code.languageUTF16Count }

/// Plain text of a paragraph/code/blockQuote block (empty for media/table). Used for the code-destination flatten.
public func blockPlainText(_ block: Block) -> String {
    switch block {
    case .paragraph(let p): return p.text
    case .code(let c): return c.text
    case .pullQuote(let pq): return pq.text
    case .blockQuote(let bq): return bq.children.map(blockPlainText).joined(separator: "\n")
    case .details(let d):
        let titleText = d.title.map(\.text).joined()
        let body = d.children.map(blockPlainText).joined(separator: "\n")
        return body.isEmpty ? titleText : titleText + "\n" + body
    default: return ""
    }
}

/// Flattens a table to plain-text lines — ONE line per row, the row's cells joined by " " (each cell's blocks
/// also joined by " "). Used by "Copy Table" (the plain-text rep) and "Convert to Text" (each row → a body
/// paragraph).
public func tableFlattenedText(_ table: TableBlock) -> [String] {
    return table.rows.map { row in
        row.cells.map { cell in cell.blocks.map(blockPlainText).joined(separator: " ") }.joined(separator: " ")
    }
}

extension Document {
    /// The (top-level block index, local UTF-16 offset) for a global caret landing in a top-level
    /// paragraph or code block. nil when the caret is inside a table cell / media caption / non-text slot.
    public func topLevelTextLocus(globalCaret caret: Int) -> (index: Int, local: Int)? {
        var cursor = 0
        for i in blocks.indices {
            let size = DocumentTree.documentSize(Document(blocks: [blocks[i]]))
            let textStart = cursor + 1
            switch blocks[i] {
            case .paragraph(let p):
                if caret >= textStart && caret <= textStart + p.utf16Count { return (i, caret - textStart) }
            case .code(let c):
                // The LANGUAGE line is deliberately not a locus here: a fragment paste into it falls
                // through to the caller's plain-text flatten, which is what the language line accepts.
                let codeStart = cursor + codeTextStartOffset(c)
                if caret >= codeStart && caret <= codeStart + c.utf16Count { return (i, caret - codeStart) }
            default: break
            }
            cursor += size
        }
        return nil
    }

    /// The nearest top-level paragraph/code text position for a caret that falls OUTSIDE the document's
    /// editable text range — below the first text block's start, or above the last text block's end. Returns
    /// nil for a caret INSIDE the range that simply isn't a top-level text locus (e.g. a table cell / media
    /// caption), so callers keep their in-cell behavior. Recovers a paste whose caret was reported as 0 — a
    /// freshly-latched chat composer sets its selection before its layout boxes exist, so the flat→global map
    /// yields 0 (below the first text start), which `insertingFragment` cannot resolve.
    public func nearestTopLevelTextPosition(to caret: Int) -> Int? {
        var cursor = 0
        var firstStart: Int? = nil
        var lastTextEnd: Int? = nil
        for i in blocks.indices {
            let size = DocumentTree.documentSize(Document(blocks: [blocks[i]]))
            let textStart = cursor + 1
            switch blocks[i] {
            case .paragraph(let p):
                if firstStart == nil { firstStart = textStart }
                lastTextEnd = textStart + p.utf16Count
            case .code(let c):
                let codeStart = cursor + codeTextStartOffset(c)
                if firstStart == nil { firstStart = codeStart }
                lastTextEnd = codeStart + c.utf16Count
            default: break
            }
            cursor += size
        }
        let documentSize = cursor
        guard let firstStart, let lastTextEnd else { return nil }   // no top-level text block to land in
        if caret < firstStart { return firstStart }        // e.g. the freshly-latched composer caret == 0
        if caret > documentSize { return lastTextEnd }      // beyond the whole document
        // Inside the document but not a top-level text locus — e.g. a caret in a table cell / media caption,
        // INCLUDING one that sits past the last text paragraph. Return nil so the caller keeps its in-cell
        // (flatten) behavior rather than redirecting the paste to a paragraph.
        return nil
    }

    /// The global position of the first editable text offset of the top-level block at `index`.
    /// A paragraph's text sits one token in (the block's own container-open token) — `cursor + 1`. A pull
    /// quote is a `.blockQuote(children: [pullTextPara, authorPara])` container (see
    /// `DocumentTree.node(for:)`), so its pull text is nested one level deeper — `cursor + 2` (the
    /// pull-quote container's open token, THEN the pull-text paragraph's own). A CODE block is likewise a
    /// container, `[languagePara, codePara]`, and its editable code text sits past the whole language
    /// child — `cursor + 4 + languageUTF16Count`.
    public func globalTextStart(ofBlockAt index: Int) -> Int {
        let cursor = DocumentTree.documentSize(Document(blocks: Array(blocks[..<index])))
        if case .pullQuote = blocks[index] {
            return cursor + 2
        }
        if case .code(let c) = blocks[index] {
            return cursor + codeTextStartOffset(c)
        }
        return cursor + 1
    }

    /// Expands `[lo, hi)` so that an endpoint landing anywhere INSIDE a `.media` or `.table` block is snapped
    /// to that block's whole span — `lo` down to the block's start, `hi` up to the block's end. Endpoints in
    /// paragraph / code / quote text are left untouched. Realizes "treat a partial table/image selection as a
    /// whole-block selection, in both directions" (AI-edit-on-selection). Walks the SAME block-span axis as
    /// `extractFragment` (`cursor` / `DocumentTree.documentSize`).
    public func expandingRangeOverNonTextBlocks(globalFrom lo: Int, globalTo hi: Int) -> (Int, Int) {
        let orderedLo = Swift.min(lo, hi), orderedHi = Swift.max(lo, hi)   // normalize at entry
        var lo = orderedLo
        var hi = orderedHi
        var cursor = 0
        for block in blocks {
            let size = DocumentTree.documentSize(Document(blocks: [block]))
            let start = cursor, end = cursor + size
            switch block {
            case .media, .table:
                if lo > start && lo < end { lo = start }   // lo strictly inside → snap to block start
                if hi > start && hi < end { hi = end }      // hi strictly inside → snap to block end
            default:
                break
            }
            cursor = end
        }
        return (min(lo, hi), max(lo, hi))
    }

    /// The top-level block whose global span `[start, start+size)` contains `pos` (`start <= pos < start+size`),
    /// with its span start and size. Returns the LAST block for `pos == documentSize`; nil for an empty document.
    /// Same block-span axis as `extractFragment` / `expandingRangeOverNonTextBlocks`.
    private func topLevelBlock(containingGlobal pos: Int) -> (index: Int, start: Int, size: Int)? {
        guard !blocks.isEmpty else { return nil }
        var cursor = 0
        for i in blocks.indices {
            let size = DocumentTree.documentSize(Document(blocks: [blocks[i]]))
            if pos < cursor + size { return (i, cursor, size) }
            cursor += size
        }
        let last = blocks.count - 1
        let lastSize = DocumentTree.documentSize(Document(blocks: [blocks[last]]))
        return (last, cursor - lastSize, lastSize)
    }

    /// UTF-16 length of a paragraph/code/pull-quote block's editable text; 0 for atoms (media/table/blockQuote).
    private func blockContentLength(_ block: Block) -> Int {
        switch block {
        case .paragraph(let p): return p.utf16Count
        case .code(let c): return c.utf16Count
        case .pullQuote(let pq): return pq.utf16Count
        default: return 0
        }
    }

    /// Replaces the global range `[lo, hi)` with `fragment`'s blocks, returning the new document and a collapsed
    /// caret at the END of the inserted content (or the deletion point when `fragment` is empty). Fully-covered
    /// media/table/quote blocks in the range are dropped — at EITHER end of a mixed range — because the delete is
    /// computed structurally (`extractFragment` of the complement) rather than via a caret-based cross-block
    /// walk, so it does not depend on the canvas's boundary resolution (the `resolveBox` degenerate-container
    /// tech debt). The insertion reuses the tested `insertingFragment` splice when the deletion caret lands in a
    /// top-level text region, and otherwise splices the fragment's blocks at the boundary gap. All block IDs are
    /// freshly generated.
    public func replacingRange(globalFrom lo: Int, globalTo hi: Int,
                               with fragment: Document) -> (document: Document, caret: Int) {
        let size = DocumentTree.documentSize(self)
        let clampedLo = max(0, min(lo, size))
        let clampedHi = max(clampedLo, min(hi, size))

        // Classify each boundary against the ORIGINAL structure: is it inside a paragraph's text (its split
        // half is a partial paragraph the fragment folds into / the two halves join on a pure delete), or at a
        // block boundary (a complete neighbouring block — never merge a whole table/media into the fragment).
        let loBlock = topLevelBlock(containingGlobal: min(clampedLo, max(0, size - 1)))
        let hiBlock = topLevelBlock(containingGlobal: min(clampedHi, max(0, size - 1)))
        let headMidPara: Bool = {
            guard let b = loBlock, case .paragraph = blocks[b.index] else { return false }
            // Strictly PAST the text start (`b.start` is the open token, textStart is `b.start + 1`), so the
            // head half `[textStart, lo)` is non-empty and IS `prefix.last`. `lo == textStart` leaves an empty
            // head, so `prefix.last` is the PREVIOUS block — merging into it would destroy the paragraph break
            // (symmetric with `tailMidPara`, which likewise excludes the leading boundary).
            return clampedLo > b.start + 1
        }()
        let tailMidPara: Bool = {
            guard let b = hiBlock, case .paragraph = blocks[b.index] else { return false }
            // Strictly inside the text on BOTH sides: past the open token AND before the close token
            // (`b.start + b.size - 1` is the close-token / text-end position). Excluding the text end is
            // symmetric with `headMidPara`'s `> b.start + 1`: at `hi == textEnd` the tail half is empty, so
            // `suffix.first` is the NEXT block — folding the fragment into it would destroy the break.
            return clampedHi > b.start && clampedHi < b.start + b.size - 1
        }()
        let prefix = extractFragment(globalFrom: 0, globalTo: clampedLo, carryingNonTextBlocks: true).blocks
        let suffix = extractFragment(globalFrom: clampedHi, globalTo: size, carryingNonTextBlocks: true).blocks

        // Build the DELETE result + the deletion caret. Join the boundary paragraphs whenever BOTH boundaries are
        // mid-text (so `prefix.last` is the lo-paragraph's head and `suffix.first` is the hi-paragraph's tail) —
        // standard multi-paragraph-delete semantics: everything between them (paragraph breaks AND any fully-
        // covered blocks such as tables/media) is inside `[lo, hi)` and dropped, so the head and tail become
        // adjacent and merge into ONE paragraph. For a pure delete this is the merge; for a replace the fragment
        // is then spliced INTO the joined paragraph at the join offset (head + fragment + tail in one paragraph).
        var delBlocks: [Block]
        var delCaret: Int
        if headMidPara, tailMidPara,
           let last = prefix.last, case .paragraph(let lp) = last,
           let first = suffix.first, case .paragraph(let sp) = first {
            var joined = prefix
            joined[joined.count - 1] = .paragraph(lp.merging(sp))
            delBlocks = joined + Array(suffix.dropFirst())
            delCaret = Document(blocks: delBlocks).globalTextStart(ofBlockAt: joined.count - 1) + lp.utf16Count
        } else {
            delBlocks = prefix + suffix
            if headMidPara, let last = prefix.last {
                // A surviving head half: caret at the end of prefix.last's text so a fragment folds into it.
                delCaret = Document(blocks: delBlocks).globalTextStart(ofBlockAt: prefix.count - 1) + blockContentLength(last)
            } else if tailMidPara, case .paragraph = suffix.first {
                // No surviving head, but the hi-paragraph's TAIL survives as `suffix.first`: caret at the START
                // of that tail's text (one past the prefix content) so a fragment folds into the tail (e.g.
                // rewriting a non-first paragraph, or a range starting at a table then into the next paragraph).
                delCaret = DocumentTree.documentSize(Document(blocks: prefix)) + 1
            } else {
                delCaret = DocumentTree.documentSize(Document(blocks: prefix))   // gap after the complete prefix (0 if empty)
            }
        }
        if delBlocks.isEmpty {
            delBlocks = [.paragraph(ParagraphBlock(id: .generate(), style: .body, runs: []))]
        }
        let deletedDoc = Document(blocks: delBlocks)

        guard !fragment.blocks.isEmpty else {
            return (deletedDoc, max(0, min(delCaret, DocumentTree.documentSize(deletedDoc))))
        }

        // Insert the fragment at the deletion caret; the tested splice handles the in-text case (merging the
        // fragment's inline ends into the surrounding paragraph text).
        if let (spliced, caret) = deletedDoc.insertingFragment(fragment, atGlobal: delCaret) {
            return (spliced, caret)
        }
        // Fallback: the deletion caret is at a boundary gap (a whole covered block bordered the range), so the
        // fragment cannot fold into text — splice its blocks in as standalone blocks at that gap.
        let frag = fragment.regeneratingTopLevelIDs().blocks
        let assembled = prefix + frag + suffix
        let doc = Document(blocks: assembled)
        let lastFragIndex = prefix.count + frag.count - 1
        let caret = doc.globalTextStart(ofBlockAt: lastFragIndex) + blockContentLength(assembled[lastFragIndex])
        return (doc, max(0, min(caret, DocumentTree.documentSize(doc))))
    }

    /// A sub-`Document` of the selection `[lo, hi)`. Paragraph and code blocks are copied (boundary
    /// blocks truncated to the covered runs). By default **media and table blocks are skipped** (Phase 5d
    /// copy/paste scope); pass `carryingNonTextBlocks: true` (the AI-edit-on-selection path) to also carry a
    /// **fully-covered** media/table block (fresh IDs via `regeneratingIDs`). All block IDs are freshly generated.
    public func extractFragment(globalFrom lo: Int, globalTo hi: Int,
                                carryingNonTextBlocks: Bool = false) -> Document {
        guard lo < hi else { return Document(blocks: []) }
        var out: [Block] = []
        var cursor = 0
        for block in blocks {
            let size = DocumentTree.documentSize(Document(blocks: [block]))
            let textStart = cursor + 1
            switch block {
            case .paragraph(let p):
                let a = max(lo, textStart), b = min(hi, textStart + p.utf16Count)
                if a < b || (p.utf16Count == 0 && lo <= textStart && hi > textStart) {
                    let r = sliceRuns(p.runs, fromUTF16: max(0, a - textStart), toUTF16: max(0, b - textStart))
                    out.append(.paragraph(ParagraphBlock(id: .generate(), style: p.style,
                                                          paragraph: p.paragraph, list: p.list, runs: r)))
                }
            case .code(let c):
                // Container now, like a pull quote: the code text starts past the language line, NOT at
                // the shared `textStart`. A partial copy carries the language, which is block metadata
                // rather than flat text — the same rule the pull quote applies to its author.
                let codeStart = cursor + codeTextStartOffset(c)
                let a = max(lo, codeStart), b = min(hi, codeStart + c.utf16Count)
                if a < b {
                    let r = sliceRuns(c.runs, fromUTF16: a - codeStart, toUTF16: b - codeStart)
                    out.append(.code(CodeBlock(id: .generate(), language: c.language, runs: r)))
                }
                // Note: empty code blocks (utf16Count == 0) are intentionally not captured — they
                // carry no content and are meaningless to paste (asymmetric with empty paragraphs,
                // which preserve the blank line's structure on intra-document paste).
            case .pullQuote(let pq):
                // A pull quote is now a `.blockQuote` container [pullPara, authorPara] (Task 2), so the pull
                // text starts at cursor + 2 (container open + pullPara open), NOT the shared `textStart`
                // (cursor + 1, correct for paragraph/code). Using `textStart` here slices the wrong UTF-16
                // range and computes the author-carry condition against the wrong base.
                let ptStart = cursor + 2
                let a = max(lo, ptStart), b = min(hi, ptStart + pq.utf16Count)
                if a < b {
                    let r = sliceRuns(pq.runs, fromUTF16: a - ptStart, toUTF16: b - ptStart)
                    // A partial pull-text copy carries no author — the author is off the flat text axis,
                    // so it only survives when the WHOLE pull text is captured.
                    let author = (a == ptStart && b == ptStart + pq.utf16Count) ? pq.author : []
                    out.append(.pullQuote(PullQuote(id: .generate(), runs: r, author: author)))
                }
            case .blockQuote(let bq):
                // Capture the whole block quote only when the selection fully covers its span
                // [cursor, cursor+size). Partial coverage stays dropped (like media/table) — a
                // partial block quote is structurally incomplete and not meaningful to paste.
                if lo <= cursor && hi >= cursor + size {
                    out.append(.blockQuote(BlockQuote(id: .generate(),
                                                      children: regeneratingIDs(bq.children),
                                                      collapsed: bq.collapsed,
                                                      author: bq.author)))
                }
            case .details(let d):
                // Capture the whole detail block only on full coverage (mirrors `.blockQuote`). Interactive
                // copy/paste of details is deferred (v1); this arm keeps the AI-edit full-range path lossless.
                if lo <= cursor && hi >= cursor + size {
                    out.append(.details(DetailsBlock(id: .generate(), title: d.title,
                                                     children: regeneratingIDs(d.children), expanded: d.expanded)))
                }
            case .media, .table, .buttonRow:
                // Carried only for the AI-edit path, and only when the selection FULLY covers the block's
                // span [cursor, cursor+size) — mirrors the `.blockQuote` full-coverage rule above. After the
                // caller's range expansion these are always fully covered. `regeneratingIDs` gives fresh IDs.
                if carryingNonTextBlocks, lo <= cursor && hi >= cursor + size {
                    out.append(contentsOf: regeneratingIDs([block]))
                }
            }
            cursor += size
        }
        return Document(blocks: out)
    }
}
