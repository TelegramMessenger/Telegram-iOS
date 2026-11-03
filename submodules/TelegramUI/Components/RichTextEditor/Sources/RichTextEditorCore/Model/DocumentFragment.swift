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

/// A fresh identity for every per-occurrence reference INSIDE a run — today exactly one,
/// `EmojiRef.instanceID`.
///
/// It is the same rule as the block ids below, one level down, and it was missed there for the same
/// reason the comment on `.media` gives: a caption "has no nested BlockID", which is true and not the
/// whole question. `instanceID` is documented as *unique per occurrence* and IS the hosted-view
/// pooling key (`syncCustomEmojiViews` keys on it deliberately, so the same sticker twice is two
/// views). A pasted emoji that reuses one therefore shares the original's view and only one of the
/// two draws — reported after a paste as "the custom emoji is only displayed in the pasted one", and
/// caught by the editor's own `derivedViewPlacementDrift` check, which traps on the shared view being
/// at one occurrence's rect while the other wants it at its own.
///
/// `EmojiRef` is the ONLY run-level identity: a formula and an inline button are identified
/// positionally and carry none.
private func regeneratingRunIdentities(_ runs: [TextRun]) -> [TextRun] {
    runs.map { run in
        guard let emoji = run.attributes.emoji else { return run }
        var fresh = run
        fresh.attributes.emoji = EmojiRef(id: emoji.id, instanceID: BlockID.generate().rawValue,
                                          altText: emoji.altText)
        return fresh
    }
}

/// Recursively regenerates fresh `BlockID`s for a list of blocks — and fresh run-level identities
/// with them (`regeneratingRunIdentities`) — for paste collision avoidance. Block views are keyed by
/// `BlockID` and hosted emoji views by `EmojiRef.instanceID`, so a paste that reuses either steals
/// the original's view and the original stops drawing. The switch is EXHAUSTIVE (no `default`) on
/// purpose: a new `Block` case must decide how its ids regenerate rather than silently falling
/// through and reintroducing that bug — and a case that carries `[TextRun]` must pass them through
/// `regeneratingRunIdentities`, which is the half this function was missing.
private func regeneratingIDs(_ blocks: [Block]) -> [Block] {
    blocks.map { block in
        switch block {
        case .paragraph(let p):
            return .paragraph(ParagraphBlock(id: .generate(), style: p.style,
                                             paragraph: p.paragraph, list: p.list,
                                             runs: regeneratingRunIdentities(p.runs)))
        case .code(let c):
            return .code(CodeBlock(id: .generate(), language: c.language,
                                   runs: regeneratingRunIdentities(c.runs)))
        case .pullQuote(let pq):
            return .pullQuote(PullQuote(id: .generate(), runs: regeneratingRunIdentities(pq.runs),
                                        author: regeneratingRunIdentities(pq.author)))
        case .blockQuote(let bq):
            return .blockQuote(BlockQuote(id: .generate(), children: regeneratingIDs(bq.children),
                                          collapsed: bq.collapsed,
                                          author: regeneratingRunIdentities(bq.author)))
        case .details(let d):
            return .details(DetailsBlock(id: .generate(), title: regeneratingRunIdentities(d.title),
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
            // blocks), and the caption is inline `[TextRun]` with no nested BlockID — but its RUNS carry
            // per-occurrence identity, so they go through `regeneratingRunIdentities` like any other. Use the container init and
            // pass `items` through wholesale — a multi-media container's items carry no BlockID of their own, so
            // regeneration is a pure passthrough — else this drops every item past the first (mirrors the Task-7
            // fix in DocumentCanvasView+Editing.swift, which hit the same legacy-single-item-init trap).
            return .media(MediaBlock(id: .generate(), items: m.items,
                                     displayWidth: m.displayWidth, alignment: m.alignment,
                                     caption: regeneratingRunIdentities(m.caption)))
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
        guard let result = insertingFragmentReportingInsertion(fragment, atGlobal: caret) else { return nil }
        return (result.document, result.caret)
    }

    /// As `insertingFragment`, and additionally **which block the inserted content ENDS IN**.
    ///
    /// Only this function knows: the answer depends on whether the fragment's ends inline-merged into
    /// the split host and on whether the empty host tail was dropped, all of which are decided here.
    /// A caller that re-derived it would be the "second derivation" this file's own comments keep
    /// warning about — and it cannot be derived from the returned caret, because for a block with no
    /// trailing text (a table, a medium, a button row) that caret is a STRUCTURAL position inside the
    /// block rather than after it.
    ///
    /// `lastInsertedBlockIndex` is nil when the fragment did not land as blocks at all — it folded
    /// wholly into existing text (a code-block destination, or a single inline-mergeable paragraph).
    /// The caret is then already mid-text and needs no policy.
    public func insertingFragmentReportingInsertion(_ fragment: Document, atGlobal caret: Int)
        -> (document: Document, caret: Int, lastInsertedBlockIndex: Int?)? {
        let frag = fragment.regeneratingTopLevelIDs().blocks
        guard let locus = topLevelTextLocus(globalCaret: caret) else { return nil }
        guard !frag.isEmpty else { return (self, caret, nil) }
        var newBlocks = blocks

        // Destination is a code block → flatten the fragment to text and insert inline.
        if case .code(let host) = blocks[locus.index] {
            let inserted = frag.map(blockPlainText).joined(separator: "\n")
            let runs = insertingText(inserted, into: host.runs, atUTF16: locus.local)
            newBlocks[locus.index] = .code(CodeBlock(id: host.id, language: host.language, runs: runs))
            // Flattened into the host's code text: no block landed, so there is nothing to place a
            // caret after.
            return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                    caret + (inserted as NSString).length, nil)
        }

        guard case .paragraph(let host) = blocks[locus.index] else { return nil }
        let (headHalf, tailHalf) = host.split(at: locus.local, newID: .generate())

        // Single inline-mergeable paragraph → fold its runs into the host paragraph.
        if frag.count == 1, isInlineMergeable(frag[0], intoHostStyle: host.style), case .paragraph(let only) = frag[0] {
            let merged = ParagraphBlock(id: host.id, style: host.style, paragraph: host.paragraph,
                                        list: host.list, runs: headHalf.runs + only.runs + tailHalf.runs)
            newBlocks[locus.index] = .paragraph(merged)
            // Folded into the host paragraph's runs — again no block of its own.
            return (Document(schemaVersion: schemaVersion, blocks: newBlocks), caret + only.utf16Count, nil)
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
        var tailAbsorbedFragment = false
        if let last = middle.last, isInlineMergeable(last, intoHostStyle: host.style), case .paragraph(let lp) = last {
            tailAbsorbedFragment = true
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
        // WHERE THE INSERTED CONTENT ENDS, which is not always `lastIndex`: when the host's tail
        // survived (a mid-paragraph paste) the last assembled block is EXISTING content, and the
        // inserted run ends one earlier — unless the fragment's own last block was absorbed INTO that
        // tail, in which case the tail is partly inserted and is the right answer.
        let lastInserted: Int
        if tailAbsorbedFragment || tailDropped {
            lastInserted = lastIndex
        } else {
            lastInserted = max(locus.index, lastIndex - 1)
        }
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
        return (newDoc, caretPos, lastInserted)
    }
}

/// The global offset from a top-level block's own start to its editable CODE text. A code block is a
/// container of [languagePara, codePara] (see `DocumentTree.node(for:)`), so its code text sits three
/// tokens past where a bare paragraph's would: language open + language text + language close + code open.
func codeTextStartOffset(_ code: CodeBlock) -> Int { 4 + code.languageUTF16Count }

/// Plain text of a paragraph/code/blockQuote block (empty for media). Used for the code-destination flatten
/// and, through `externalChecklistPlainText`, for the plain-text pasteboard rep of every copy.
///
/// A TABLE is its `tableFlattenedText` rows, one line per row. It used to fall to `""`, so copying a
/// table wrote a plain text without any of its cells (`"para before\n\npara after"`) and any plain-text
/// destination lost the table (composer harness, 2026-09-23, `HarnessTableCopyPlainTextTests`).
public func blockPlainText(_ block: Block) -> String {
    switch block {
    case .paragraph(let p): return runsPlainText(p.runs)
    case .code(let c): return c.text
    case .pullQuote(let pq): return runsPlainText(pq.runs)
    case .blockQuote(let bq): return bq.children.map(blockPlainText).joined(separator: "\n")
    case .details(let d):
        let titleText = runsPlainText(d.title)
        let body = d.children.map(blockPlainText).joined(separator: "\n")
        return body.isEmpty ? titleText : titleText + "\n" + body
    case .table(let table): return tableFlattenedText(table).joined(separator: "\n")
    default: return ""
    }
}

/// `runs` as plain text, an inline atom as its TEXT rather than its attachment character: a custom
/// emoji its `altText` (nothing when it has none), an inline button its label, a formula its LaTeX
/// (already the run's model text). Every consumer of plain text puts it somewhere that holds text
/// only — a code block, a one-line field, the plain-text pasteboard, a table converted to text — and
/// there an atom's `U+FFFC` is a bare character with no entity, which a message sends literally
/// (composer harness p16, `HarnessAtomFlatteningTests`: Format ▸ Code over a custom emoji, a paste
/// into code or into an author line, Convert to Text). The engine's own insert of an emoji into code
/// already took its `altText` (`insertEmojiAltTextIntoCode`); this is that rule for every other way.
public func runsPlainText(_ runs: [TextRun]) -> String {
    runs.map { run -> String in
        if let emoji = run.attributes.emoji { return emoji.altText ?? "" }
        if let button = run.attributes.button { return button.labelText }
        if let formula = run.attributes.formula, !formula.isEmpty { return formula }
        return run.text
    }.joined()
}

/// The paragraph breaks this editor does not hold, and the one it does. CRLF (one break), a lone CR,
/// `U+2029` PARAGRAPH SEPARATOR and NEL (`U+0085`) all become `"\n"` — the model's only paragraph break,
/// which a body renders as the engine's in-block line separator — as a stock text view makes of them.
/// `U+2028` LINE SEPARATOR is NOT touched: it already IS the engine's in-block break.
///
/// THE one normaliser for text entering the editor: the content set (the engine bridge's render, so a draft
/// or an edit load with CR endings is held as typed text would be), the engine's own paste (its host view's
/// combine step mirrors this list in Objective-C), every host paste and drop (`EnginePasteSource`). Kept in
/// one place because each door got its own subset before: the paste mapped CR / CRLF (composer harness p20)
/// and the set nothing, so a set CR stayed in the model as `U+000D` and was sent, and a `U+2029` reached the
/// model by a plain paste; with either inside a block the tokenizer's paragraph boundaries disagreed with
/// the rest of `UITextInput` (p24, `HarnessSetCarriageReturnTests`). Literal: Foundation's default search
/// matches whole composed character sequences, so a break followed by a mark was not found.
public func normalisedLineBreaks(_ text: String) -> String {
    guard text.unicodeScalars.contains(where: { $0 == "\r" || $0 == "\u{2029}" || $0 == "\u{0085}" }) else {
        return text
    }
    return text.replacingOccurrences(of: "\r\n", with: "\n", options: .literal)
        .replacingOccurrences(of: "\r", with: "\n", options: .literal)
        .replacingOccurrences(of: "\u{2029}", with: "\n", options: .literal)
        .replacingOccurrences(of: "\u{0085}", with: "\n", options: .literal)
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
            case .blockQuote(let bq) where !bq.collapsed:
                // A medium or table INSIDE a container snaps too, on the same axis one level down —
                // the layout `extractFragment` recurses with (children one token past the quote's
                // open). Only the top level was walked, so a copy ending in a QUOTED medium's caption
                // left it covered in part, the fragment carried the quote's text and no photo, and a
                // Cut + Paste lost the photo for good (composer harness p13,
                // `HarnessQuotedMediaCopyTests`).
                (lo, hi) = Self.expanding(lo, hi, overNonTextBlocksOf: bq.children, at: start + 1)
            case .details(let d) where d.expanded:
                // The body one token past the title's close (`extractFragment`'s `childrenStart`).
                (lo, hi) = Self.expanding(lo, hi, overNonTextBlocksOf: d.children, at: start + 2 + d.titleUTF16Count + 1)
            default:
                break
            }
            cursor = end
        }
        return (min(lo, hi), max(lo, hi))
    }

    /// The fragment a range lying wholly inside ONE medium's CAPTION copies: the covered caption
    /// text as a body paragraph, formatting kept. nil for any other range (an empty one included).
    ///
    /// A caption is a text region, but it lies inside the media block's span, so
    /// `expandingRangeOverNonTextBlocks` snaps a range there to the WHOLE unit and a word copied from
    /// a caption copied the photo instead — pasted back into the caption it then added nothing
    /// (composer harness p13, `HarnessCaptionFragmentPasteTests`). Asked before that expansion; a
    /// range reaching out of the caption keeps the whole-unit rule. Walks expanded quotes and details
    /// bodies on the same axis `extractFragment` recurses with.
    public func captionTextFragment(globalFrom lo: Int, globalTo hi: Int) -> Document? {
        guard lo < hi else { return nil }
        var cursor = 0
        for block in blocks {
            let size = DocumentTree.documentSize(Document(blocks: [block]))
            defer { cursor += size }
            guard lo >= cursor, hi <= cursor + size else { continue }
            switch block {
            case .media(let media) where !media.isCaptionless:
                let captionStart = cursor + 3
                guard lo >= captionStart, hi <= captionStart + media.captionUTF16Count else { return nil }
                let runs = regeneratingRunIdentities(sliceRuns(media.caption, fromUTF16: lo - captionStart,
                                                               toUTF16: hi - captionStart))
                return Document(blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: runs))])
            case .blockQuote(let quote) where !quote.collapsed:
                return Document(blocks: quote.children)
                    .captionTextFragment(globalFrom: lo - (cursor + 1), globalTo: hi - (cursor + 1))
            case .details(let details) where details.expanded:
                let origin = cursor + 2 + details.titleUTF16Count + 1
                return Document(blocks: details.children)
                    .captionTextFragment(globalFrom: lo - origin, globalTo: hi - origin)
            default:
                return nil
            }
        }
        return nil
    }

    /// The fragment a range lying wholly inside ONE table cell copies: what that range covers of the
    /// cell's own blocks (a word copies as that word), never the whole table. nil for any other range,
    /// an empty one included.
    ///
    /// A cell is a text region like a caption: `expandingRangeOverNonTextBlocks` snaps an endpoint
    /// inside a table to the WHOLE table, so a word copied from a cell copied the table, and pasted into
    /// another table's cell it replaced that table with a copy of the first (composer harness p19,
    /// `HarnessFragmentPasteIntoTableCellTests`). Asked before that expansion, beside
    /// `captionTextFragment`; a range reaching out of the cell keeps the whole-table rule. Walks expanded
    /// quotes and details bodies on the axis `extractFragment` recurses with.
    public func tableCellFragment(globalFrom lo: Int, globalTo hi: Int) -> Document? {
        guard lo < hi, let cell = Self.cellContaining(lo, hi, in: blocks, origin: 0) else { return nil }
        let children = Document(blocks: cell.blocks)
        let (innerLo, innerHi) = children.expandingRangeOverNonTextBlocks(globalFrom: lo - cell.childrenStart,
                                                                          globalTo: hi - cell.childrenStart)
        let fragment = children.extractFragment(globalFrom: innerLo, globalTo: innerHi, carryingNonTextBlocks: true)
        return fragment.blocks.isEmpty ? nil : fragment
    }

    /// The table cell whose children hold `[lo, hi]` — its blocks and the global position its children
    /// start at (one token past the cell's open) — searching `blocks` laid out from `origin`, into
    /// expanded quotes and details bodies. nil when the range is not inside one cell's children.
    internal static func cellContaining(_ lo: Int, _ hi: Int, in blocks: [Block], origin: Int)
        -> (blocks: [Block], childrenStart: Int)? {
        var cursor = origin
        for block in blocks {
            let size = DocumentTree.documentSize(Document(blocks: [block]))
            defer { cursor += size }
            guard lo >= cursor, hi <= cursor + size else { continue }
            switch block {
            case .table(let table):
                var rowStart = cursor + 1
                for row in table.rows {
                    var cellStart = rowStart + 1
                    for cell in row.cells {
                        let childrenSize = DocumentTree.documentSize(Document(blocks: cell.blocks))
                        let childrenStart = cellStart + 1
                        if lo >= childrenStart, hi <= childrenStart + childrenSize {
                            return (cell.blocks, childrenStart)
                        }
                        cellStart += childrenSize + 2
                    }
                    rowStart = cellStart + 1
                }
                return nil
            case .blockQuote(let quote) where !quote.collapsed:
                guard let inner = cellContaining(lo, hi, in: quote.children, origin: cursor + 1) else { return nil }
                return inner
            case .details(let details) where details.expanded:
                guard let inner = cellContaining(lo, hi, in: details.children,
                                                 origin: cursor + 2 + details.titleUTF16Count + 1) else { return nil }
                return inner
            default:
                return nil
            }
        }
        return nil
    }

    /// `expandingRangeOverNonTextBlocks` over `children` laid out from global offset `origin`.
    private static func expanding(_ lo: Int, _ hi: Int, overNonTextBlocksOf children: [Block], at origin: Int) -> (Int, Int) {
        let (innerLo, innerHi) = Document(blocks: children)
            .expandingRangeOverNonTextBlocks(globalFrom: lo - origin, globalTo: hi - origin)
        return (innerLo + origin, innerHi + origin)
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
    /// The same block with its TEXT emptied and everything else kept — style, list, language,
    /// author, identity. `nil` for a block with no single text region of its own (a table, a medium,
    /// a button row, a container), where "emptying its text" is not a thing that can happen to it.
    /// Exhaustive with no `default`, so a new `Block` case has to decide.
    private func emptiedKeepingShape(_ block: Block) -> Block? {
        switch block {
        case .paragraph(let p):
            return .paragraph(ParagraphBlock(id: p.id, style: p.style, paragraph: p.paragraph,
                                             list: p.list, runs: []))
        case .code(let c):
            return .code(CodeBlock(id: c.id, language: c.language, runs: []))
        case .pullQuote(let pq):
            return .pullQuote(PullQuote(id: pq.id, runs: [], author: pq.author))
        case .media, .table, .blockQuote, .details, .buttonRow:
            return nil
        }
    }

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
        let result = replacingRangeReportingInsertion(globalFrom: lo, globalTo: hi, with: fragment)
        return (result.document, result.caret)
    }

    /// As `replacingRange`, and additionally which block the inserted content ENDS IN — see
    /// `insertingFragmentReportingInsertion` for why only this layer can answer it.
    public func replacingRangeReportingInsertion(globalFrom lo: Int, globalTo hi: Int,
                                                 with fragment: Document)
        -> (document: Document, caret: Int, lastInsertedBlockIndex: Int?) {
        return self.replacingRangeReportingInsertion(globalFrom: lo, globalTo: hi, with: fragment,
                                                     endsTheCopiedDocument: true, nested: false)
    }

    /// `endsTheCopiedDocument` / `nested`: `extractFragment`'s own flags, for the same document —
    /// whether this document's end is the end of the one the range was taken in, and whether these
    /// are a container's children. The range is measured with the SAME coverage rule the copy uses
    /// (`carriedEmptyEndRegionStart`).
    private func replacingRangeReportingInsertion(globalFrom lo: Int, globalTo hi: Int,
                                                  with fragment: Document,
                                                  endsTheCopiedDocument: Bool, nested: Bool)
        -> (document: Document, caret: Int, lastInsertedBlockIndex: Int?) {
        let size = DocumentTree.documentSize(self)
        let clampedLo = max(0, min(lo, size))
        var clampedHi = max(clampedLo, min(hi, size))

        // **A range ending at an empty region the copy carries covers the rest of the document.**
        // `extractFragment` admits an EMPTY text region at the document's end when the range reaches
        // it — an empty code block or pull quote, an empty last line of an expanded details that ends
        // the document — because that is where Select All ends, and its end IS the region's start.
        // The complement below takes the suffix from that same position, where the region is
        // covered again, so it was in BOTH halves: Select All → Copy → Paste over `[p ""] [pull ""]`
        // gave `[p ""] [pull] [pull]`, and every paste-back added one more (composer harness p18,
        // fuzz seed 6, `HarnessEmptyPullQuoteAtEndPasteTests`). Past that region there are only
        // closing tokens, so taking the range to the document's end drops nothing the copy did not
        // take. Only where the copy's own rule admits it: a top-level empty last PARAGRAPH is the
        // document's trailing line and stays in the suffix, and a block quote's children never end
        // the document (its author line follows them).
        if endsTheCopiedDocument, clampedLo < clampedHi,
           let carried = self.carriedEmptyEndRegionStart(origin: 0, nested: nested), clampedHi == carried {
            clampedHi = size
        }

        if let contained = replacingRangeInsideOneContainer(globalFrom: clampedLo, globalTo: clampedHi,
                                                            with: fragment,
                                                            endsTheCopiedDocument: endsTheCopiedDocument) {
            return contained
        }

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
        // The complement is taken AROUND the replaced range (`complementOf`): a second line the
        // range's own copy carries as metadata is not left in it as body text.
        let removed = (lo: clampedLo, hi: clampedHi)
        let prefix = extractFragment(globalFrom: 0, globalTo: clampedLo, carryingNonTextBlocks: true,
                                     endsTheCopiedDocument: true, nested: false, languagesAsText: false,
                                     complementOf: removed).blocks
        let suffix = extractFragment(globalFrom: clampedHi, globalTo: size, carryingNonTextBlocks: true,
                                     endsTheCopiedDocument: true, nested: false, languagesAsText: false,
                                     complementOf: removed).blocks

        // Build the DELETE result + the deletion caret. Join the boundary paragraphs whenever BOTH boundaries are
        // mid-text (so `prefix.last` is the lo-paragraph's head and `suffix.first` is the hi-paragraph's tail) —
        // standard multi-paragraph-delete semantics: everything between them (paragraph breaks AND any fully-
        // covered blocks such as tables/media) is inside `[lo, hi)` and dropped, so the head and tail become
        // adjacent and merge into ONE paragraph. For a pure delete this is the merge; for a replace the fragment
        // is then spliced INTO the joined paragraph at the join offset (head + fragment + tail in one paragraph).
        // **A range covering exactly ONE block's whole TEXT deletes the text, never the block.**
        // The delete is computed as the COMPLEMENT, and `extractFragment` keeps a block only where it
        // covers some of that block's text — so a block whose text IS the range appears in NEITHER
        // half and simply vanished, taking its heading level, list membership or code language with
        // it. Selecting everything on a line and deleting leaves a blank line, in this editor as in
        // any other.
        //
        // The complement model stays right for everything else, which is what the two equalities
        // below protect: a range over a block's whole SPAN still drops it (a fully covered table),
        // and a range crossing a paragraph break still joins the two halves, because neither lies on
        // one block's own text boundaries.
        let emptiedInPlace: Block? = {
            guard let lo = loBlock, let hi = hiBlock, lo.index == hi.index else { return nil }
            let textStart = globalTextStart(ofBlockAt: lo.index)
            guard clampedLo == textStart,
                  clampedHi == textStart + blockContentLength(blocks[lo.index]) else { return nil }
            return emptiedKeepingShape(blocks[lo.index])
        }()

        var delBlocks: [Block]
        var delCaret: Int
        if let emptied = emptiedInPlace, let block = loBlock {
            // The blocks after it are taken from the block's END, not from `hi`. For an EMPTY block
            // the range is empty (`[textStart, textStart)`), and the complement's suffix from `hi`
            // keeps an empty paragraph its range merely touches — the block itself, so it came out
            // TWICE. Measured (composer harness, 2026-09-23): pasting the editor's own fragment at a
            // caret in an empty paragraph left an empty paragraph after the pasted text, so cut +
            // paste of a whole line was not a round trip. For a non-empty block nothing of it lies
            // past its text end, so this is the same suffix.
            let tail = extractFragment(globalFrom: block.start + block.size, globalTo: size,
                                       carryingNonTextBlocks: true).blocks
            // **A MULTI-block fragment rewriting a block's whole text keeps its own styles.** The
            // emptied block is kept so that what replaces its text FOLDS into it — a pure delete
            // leaves the line, a one-block rewrite keeps the heading or the list item. A fragment of
            // several blocks folds into BOTH halves of the split, and the tail half of an emptied
            // block is nothing but a copy of its style: an AI rewrite of `H1 "Title"` answering
            // `[H1, p]` gave two H1s, and a list item answering `[p, table, p]` turned both
            // paragraphs into items. Such a fragment replaces the block, as before the emptied
            // block existed. A caret in an EMPTY line (`clampedLo == clampedHi`) is a paste, not a
            // rewrite, and keeps the splice the legacy canvas's paste at that caret makes.
            if clampedLo < clampedHi, fragment.blocks.count > 1 {
                let frag = fragment.regeneratingTopLevelIDs().blocks
                let assembled = prefix + frag + tail
                let doc = Document(blocks: assembled)
                let lastFragIndex = prefix.count + frag.count - 1
                let caret = doc.globalTextStart(ofBlockAt: lastFragIndex) + blockContentLength(assembled[lastFragIndex])
                return (doc, max(0, min(caret, DocumentTree.documentSize(doc))), lastFragIndex)
            }
            delBlocks = prefix + [emptied] + tail
            delCaret = Document(blocks: delBlocks).globalTextStart(ofBlockAt: prefix.count)
        } else if headMidPara, tailMidPara,
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
            // A pure delete inserts nothing.
            return (deletedDoc, max(0, min(delCaret, DocumentTree.documentSize(deletedDoc))), nil)
        }

        // Insert the fragment at the deletion caret; the tested splice handles the in-text case (merging the
        // fragment's inline ends into the surrounding paragraph text).
        if let spliced = deletedDoc.insertingFragmentReportingInsertion(fragment, atGlobal: delCaret) {
            return spliced
        }
        // Fallback: the deletion caret is at a boundary gap (a whole covered block bordered the range), so the
        // fragment cannot fold into text — splice its blocks in as standalone blocks at that gap.
        let frag = fragment.regeneratingTopLevelIDs().blocks
        let assembled = prefix + frag + suffix
        let doc = Document(blocks: assembled)
        let lastFragIndex = prefix.count + frag.count - 1
        let caret = doc.globalTextStart(ofBlockAt: lastFragIndex) + blockContentLength(assembled[lastFragIndex])
        // Here the fragment's blocks went in standalone, so its last block IS the last inserted one.
        return (doc, max(0, min(caret, DocumentTree.documentSize(doc))), lastFragIndex)
    }

    /// The global start of the EMPTY text region at this document's end that `extractFragment`
    /// covers when a range ends exactly there (its `coversEmptyRegion` admission, with
    /// `endsTheCopiedDocument` true), or nil. Mirrors that rule case by case: the last block is an
    /// empty code block or an empty pull quote (author or not), or — `nested`, a container's
    /// children — an empty paragraph; an EXPANDED details recurses into its body, which then ends
    /// the document too. A top-level paragraph keeps the bare rule and is never admitted.
    private func carriedEmptyEndRegionStart(origin: Int, nested: Bool) -> Int? {
        guard let last = blocks.last else { return nil }
        let cursor = origin + DocumentTree.documentSize(Document(blocks: Array(blocks.dropLast())))
        switch last {
        case .code(let code) where code.utf16Count == 0:
            return cursor + codeTextStartOffset(code)
        case .pullQuote(let quote) where quote.utf16Count == 0:
            return cursor + 2
        case .paragraph(let paragraph) where nested && paragraph.utf16Count == 0:
            return cursor + 1
        case .details(let details) where details.expanded && !details.children.isEmpty:
            return Document(blocks: details.children)
                .carriedEmptyEndRegionStart(origin: cursor + 2 + details.titleUTF16Count + 1, nested: true)
        case .details(let details) where !details.expanded && details.titleUTF16Count == 0:
            // A folded details' empty title is its only text position (`extractFragment`'s
            // `titleTouched`): a range ending there carries it, folded body and all.
            return cursor + 2
        default:
            return nil
        }
    }

    /// The fragment as the text of a ONE-LINE PLAIN field — a quote's or pull quote's author, a code
    /// block's language, a details title: `oneLineRuns(of:)` — every line of every block, joined by one
    /// space — with each code block's LANGUAGE as a line before its code, as plain text (an atom as its
    /// text, `runsPlainText`). The pasteboard's plain string is not this: `blockPlainText` leaves authors
    /// and languages out (composer harness p22, `HarnessFragmentIntoOneLineFieldTests`).
    ///
    /// For a fragment that came with no range — a host's copy of a whole message — where every language
    /// is content. The editor's OWN copy carries the exact text of what it deleted instead (the engine's
    /// one-line representation): a partial copy of a code body carries the language as METADATA (a paste
    /// of it makes a code block in that language), which a field must not receive as text.
    public var oneLineFieldText: String {
        func withLanguageLines(_ blocks: [Block]) -> [Block] {
            return blocks.flatMap { block -> [Block] in
                switch block {
                case .code(let code):
                    guard let language = code.language, !language.isEmpty else { return [block] }
                    return [.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: language)])), block]
                case .blockQuote(var quote):
                    quote.children = withLanguageLines(quote.children)
                    return [.blockQuote(quote)]
                case .details(var details):
                    details.children = withLanguageLines(details.children)
                    return [.details(details)]
                default:
                    return [block]
                }
            }
        }
        return runsPlainText(oneLineRuns(of: Document(schemaVersion: schemaVersion, blocks: withLanguageLines(blocks))))
    }

    /// A fragment as the runs of a ONE-LINE text region (a details title, a media caption): each
    /// paragraph's runs, formatting kept, every other block as its plain text, blocks joined by one
    /// space.
    private func oneLineRuns(of fragment: Document) -> [TextRun] {
        var inserted: [TextRun] = []
        for (offset, block) in fragment.blocks.enumerated() {
            let text = blockPlainText(block)
            if offset > 0, !text.isEmpty || !inserted.isEmpty { inserted.append(TextRun(text: " ")) }
            // Every block as its RUNS (`blockInlineRuns`), a line break inside one as a space: a pull
            // quote's or a quote's text flattened to plain text left its custom emoji as a bare
            // `U+FFFC` (composer harness p16).
            inserted.append(contentsOf: blockInlineRuns(block).map { run in
                var run = run
                run.text = run.text.replacingOccurrences(of: "\n", with: " ")
                return run
            })
        }
        inserted.removeAll { $0.text.isEmpty }
        return inserted
    }

    /// A fragment block as the RUNS of a text region, formatting and inline atoms kept: a paragraph's
    /// or a pull quote's runs, a code block's text, a quote's or a details' blocks one line each (a
    /// details' title first), a table one line per row with its cells separated by a space. A medium
    /// or a button row has no text and gives nothing.
    ///
    /// Plain text (`blockPlainText`) is not enough for a region that holds runs: an atom's plain text
    /// is its attachment character, so a custom emoji copied inside a pull quote and pasted inside a
    /// pull quote came back as a bare `U+FFFC` with no entity, sent as a literal character (composer
    /// harness p16, fuzz seed 83, `HarnessPullQuoteFragmentAtomPasteTests`).
    private func blockInlineRuns(_ block: Block) -> [TextRun] {
        func lines(_ parts: [[TextRun]], separator: String) -> [TextRun] {
            var result: [TextRun] = []
            for (offset, part) in parts.enumerated() {
                if offset > 0 { result.append(TextRun(text: separator)) }
                result.append(contentsOf: part)
            }
            return result
        }
        switch block {
        case .paragraph(let paragraph): return regeneratingRunIdentities(paragraph.runs)
        // A quote's AUTHOR is text the fragment carries: a copy that reached into it and pasted where
        // only runs go lost it (composer harness p19 fix wave, `HarnessQuoteAuthorCutMoveTests`). It
        // goes on a line of its own after the body, as it is drawn.
        case .pullQuote(let quote):
            let body = regeneratingRunIdentities(quote.runs)
            guard !quote.author.isEmpty else { return body }
            return lines([body, regeneratingRunIdentities(quote.author)].filter { !$0.isEmpty }, separator: "\n")
        case .code(let code): return code.text.isEmpty ? [] : [TextRun(text: code.text)]
        case .blockQuote(let quote):
            var parts = quote.children.map(blockInlineRuns)
            if !quote.author.isEmpty { parts.append(regeneratingRunIdentities(quote.author)) }
            return lines(parts, separator: "\n")
        case .details(let details):
            // A body holding no text adds nothing, as in `blockPlainText`: the empty body line a copy of
            // part of a title carries (an expanded details always has one) went into the title it was
            // pasted back into as a space — replacing "T" in the title "Tit" with its own copy gave "T it".
            // Text means a character that is not a line break: the breaks between several empty lines
            // are characters too, joined here or inside a nested container's own line (a quote of empty
            // paragraphs), and read as text they pasted spaces.
            let title = regeneratingRunIdentities(details.title)
            let body = lines(details.children.map(blockInlineRuns), separator: "\n")
            guard body.contains(where: { $0.text.contains { $0 != "\n" } }) else { return title }
            return lines([title, body], separator: "\n")
        case .table(let table):
            return lines(table.rows.map { row in
                lines(row.cells.map { cell in lines(cell.blocks.map(blockInlineRuns), separator: " ") }, separator: " ")
            }, separator: "\n")
        case .media, .buttonRow:
            return []
        }
    }

    /// **A range that lies wholly inside ONE container's own text is replaced inside it.**
    ///
    /// The complement model below splits every block the range touches into a prefix half and a
    /// suffix half, and only a top-level PARAGRAPH is ever joined back. For a range inside a code
    /// block or an open block quote that meant the container came out in two with the fragment
    /// between the halves as top-level blocks: the editor's own copy of one word, pasted after
    /// "Second " in `[quote "Second paragraph."]`, gave `[quote "Second "] [p "First"] [quote
    /// "paragraph."]` (composer harness, 2026-09-23, `HarnessFragmentPasteIntoContainerTests`).
    ///
    /// - A CODE block takes the fragment as text, each block's plain text on its own line — the
    ///   rule `insertingFragmentReportingInsertion` already applies to a caret in code.
    /// - An open BLOCK QUOTE takes the replacement in its children: the same function applied to
    ///   the document of its children, which sit one token past the quote's open laid out exactly
    ///   as that document. So a single paragraph folds into the child it lands in, and a
    ///   multi-block fragment lands as blocks INSIDE the quote (a quote holds any block), with the
    ///   usual split of the host child. Nested quotes recurse.
    ///
    /// nil — the range crosses a container's edge, touches a folded quote or a language/author
    /// line, or is not in a container — leaves the general path to decide.
    private func replacingRangeInsideOneContainer(globalFrom lo: Int, globalTo hi: Int, with fragment: Document,
                                                  endsTheCopiedDocument: Bool)
        -> (document: Document, caret: Int, lastInsertedBlockIndex: Int?)? {
        var cursor = 0
        for index in blocks.indices {
            let block = blocks[index]
            let blockSize = DocumentTree.documentSize(Document(blocks: [block]))
            defer { cursor += blockSize }
            guard lo >= cursor, hi <= cursor + blockSize else { continue }
            switch block {
            case .code(let code):
                // A range inside the LANGUAGE line edits the language: the fragment as one line of
                // plain text, a details title's rule, and an emptied line is no language. Left to the
                // complement model, the covered part was dropped from nowhere and the uncovered head
                // came back as a body paragraph: deleting "yt" in "python" gave `[p "p"] [code python]`
                // (the language line is on the axis since 0e12da1b82's copy rule). Always on the axis
                // (`DocumentTree`), two tokens in: the container's open and the line's own.
                let languageStart = cursor + 2
                if lo >= languageStart, hi <= languageStart + code.languageUTF16Count {
                    let inserted = runsPlainText(oneLineRuns(of: fragment))
                    let language = ((code.language ?? "") as NSString)
                        .replacingCharacters(in: NSRange(location: lo - languageStart, length: hi - lo), with: inserted)
                    var newBlocks = blocks
                    newBlocks[index] = .code(CodeBlock(id: code.id, language: language.isEmpty ? nil : language,
                                                       runs: code.runs))
                    return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                            lo + (inserted as NSString).length, nil)
                }
                let codeStart = cursor + codeTextStartOffset(code)
                guard lo >= codeStart, hi <= codeStart + code.utf16Count else { return nil }
                let inserted = fragment.blocks.map(blockPlainText).joined(separator: "\n")
                let a = lo - codeStart, b = hi - codeStart
                let kept = sliceRuns(code.runs, fromUTF16: 0, toUTF16: a)
                    + sliceRuns(code.runs, fromUTF16: b, toUTF16: code.utf16Count)
                let runs = inserted.isEmpty ? kept : insertingText(inserted, into: kept, atUTF16: a)
                var newBlocks = blocks
                newBlocks[index] = .code(CodeBlock(id: code.id, language: code.language, runs: runs))
                // Folded into the code text: no block landed, the caret is already mid-text.
                return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                        lo + (inserted as NSString).length, nil)
            case .pullQuote(let quote):
                // A pull quote holds TEXT, not blocks (it is one body with an author line), so the
                // fragment is spliced into its runs: each paragraph's runs, formatting kept, and every
                // other block as its plain text, one line each. Left to the general path, the editor's
                // own copy of one word pasted mid-pull-quote came out as
                // `[pull "Second "] [p "First"] [pull "paragraph."]` (composer harness, 2026-09-23,
                // `HarnessFragmentPasteIntoPullQuoteTests`). The text starts two tokens in: the
                // container's open and the body paragraph's.
                let textStart = cursor + 2
                // A range inside the AUTHOR line edits the author, one line of runs (the details
                // title's rule): left to the complement model, the author stayed whole and its
                // uncovered tail came back as a body paragraph — deleting "ut" in "Author" gave
                // `[pull "body" by "Author"] [p "hor"]`. The line is on the axis only while the quote
                // has content (`DocumentTree`), so it is asked of the block's own size: absent, its
                // start would be the boundary with the next block.
                let authorStart = textStart + quote.utf16Count + 2
                if blockSize == quote.utf16Count + quote.authorUTF16Count + 6,
                   lo >= authorStart, hi <= authorStart + quote.authorUTF16Count {
                    let inserted = oneLineRuns(of: fragment)
                    let author = sliceRuns(quote.author, fromUTF16: 0, toUTF16: lo - authorStart) + inserted
                        + sliceRuns(quote.author, fromUTF16: hi - authorStart, toUTF16: quote.authorUTF16Count)
                    var newBlocks = blocks
                    newBlocks[index] = .pullQuote(PullQuote(id: quote.id, runs: quote.runs, author: author))
                    return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                            lo + inserted.reduce(0) { $0 + $1.utf16Count }, nil)
                }
                guard lo >= textStart, hi <= textStart + quote.utf16Count else { return nil }
                // **A range covering exactly the whole body is the pull quote**: its copy carries the
                // whole author (`extractFragment`), so a PULL QUOTE replacing it replaces the author as
                // well — spliced as runs below, the author line went into the body beside the author
                // still there, and the AI edit handing back `[pull "pulled" by "Auth"]` unchanged gave
                // `pull "pulled\nAuth" by "Auth"`. A replacement with no author keeps the one there.
                if quote.utf16Count > 0, lo == textStart, hi == textStart + quote.utf16Count,
                   fragment.blocks.count == 1, case .pullQuote(let replacement) = fragment.blocks[0] {
                    let runs = regeneratingRunIdentities(replacement.runs)
                    let author = replacement.author.isEmpty ? quote.author : regeneratingRunIdentities(replacement.author)
                    var newBlocks = blocks
                    newBlocks[index] = .pullQuote(PullQuote(id: quote.id, runs: runs, author: author))
                    return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                            textStart + runs.reduce(0) { $0 + $1.utf16Count }, nil)
                }
                // Every block as its runs (`blockInlineRuns`): a PULL-QUOTE fragment — what a copy made
                // inside a pull quote is — took the plain-text branch here, and its custom emoji came
                // back as a bare `U+FFFC` (composer harness p16, `HarnessPullQuoteFragmentAtomPasteTests`).
                var inserted: [TextRun] = []
                for (offset, block) in fragment.blocks.enumerated() {
                    if offset > 0 { inserted.append(TextRun(text: "\n")) }
                    inserted.append(contentsOf: blockInlineRuns(block))
                }
                inserted.removeAll { $0.text.isEmpty }
                let a = lo - textStart, b = hi - textStart
                let runs = sliceRuns(quote.runs, fromUTF16: 0, toUTF16: a) + inserted
                    + sliceRuns(quote.runs, fromUTF16: b, toUTF16: quote.utf16Count)
                var newBlocks = blocks
                newBlocks[index] = .pullQuote(PullQuote(id: quote.id, runs: runs, author: quote.author))
                // Folded into the pull quote's text: no block landed, the caret is already mid-text.
                return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                        lo + inserted.reduce(0) { $0 + $1.utf16Count }, nil)
            case .details(let details):
                // A range inside ONE details stays inside it: in its TITLE the fragment is spliced as
                // text (a title holds runs, like a pull quote's body); in its expanded BODY the same
                // function runs on the children, as for a block quote. Left to the complement model, the
                // details came out split, or — before `extractFragment` learned to enter a details —
                // dropped from both halves.
                let titleStart = cursor + 2
                let titleEnd = titleStart + details.titleUTF16Count
                if lo >= titleStart, hi <= titleEnd {
                    let inserted = oneLineRuns(of: fragment)
                    let a = lo - titleStart, b = hi - titleStart
                    let title = sliceRuns(details.title, fromUTF16: 0, toUTF16: a) + inserted
                        + sliceRuns(details.title, fromUTF16: b, toUTF16: details.titleUTF16Count)
                    var newBlocks = blocks
                    newBlocks[index] = .details(DetailsBlock(id: details.id, title: title,
                                                             children: details.children, expanded: details.expanded))
                    return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                            lo + inserted.reduce(0) { $0 + $1.utf16Count }, nil)
                }
                let childrenStart = titleEnd + 1
                let children = Document(blocks: details.children)
                let childrenSize = DocumentTree.documentSize(children)
                guard details.expanded, !details.children.isEmpty,
                      lo >= childrenStart, hi <= childrenStart + childrenSize else { return nil }
                // The body ends the copied document when this details does (`extractFragment`'s rule).
                let inner = children.replacingRangeReportingInsertion(globalFrom: lo - childrenStart,
                                                                      globalTo: hi - childrenStart,
                                                                      with: fragment,
                                                                      endsTheCopiedDocument: endsTheCopiedDocument
                                                                          && index == blocks.count - 1,
                                                                      nested: true)
                var newBlocks = blocks
                newBlocks[index] = .details(DetailsBlock(id: details.id, title: details.title,
                                                         children: inner.document.blocks, expanded: true))
                let lastInserted: Int? = inner.lastInsertedBlockIndex.flatMap { innerIndex in
                    guard innerIndex < inner.document.blocks.count else { return index }
                    if case .paragraph(let p) = inner.document.blocks[innerIndex] {
                        switch p.style {
                        case .body, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6: return nil
                        case .caption, .pullQuote: return index
                        }
                    }
                    return index
                }
                return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                        childrenStart + inner.caret, lastInserted)
            case .media(let media) where !media.isCaptionless:
                // A range inside a medium's CAPTION is the caption's text input: the fragment is
                // spliced into its runs, one line, formatting kept — a details title's rule. Left to
                // the complement model, the caption position lies inside the media block's span, so
                // the medium appeared in neither half: the editor's own copy of one word pasted into a
                // caption DELETED the photo and its caption, and a copy taken from the caption itself
                // pasted as nothing (composer harness p13, `HarnessCaptionFragmentPasteTests`). The
                // caption text sits three tokens in: the block's open, the atom, the caption's open.
                let captionStart = cursor + 3
                guard lo >= captionStart, hi <= captionStart + media.captionUTF16Count else { return nil }
                let inserted = oneLineRuns(of: fragment)
                let a = lo - captionStart, b = hi - captionStart
                var updated = media
                updated.caption = sliceRuns(media.caption, fromUTF16: 0, toUTF16: a) + inserted
                    + sliceRuns(media.caption, fromUTF16: b, toUTF16: media.captionUTF16Count)
                var newBlocks = blocks
                newBlocks[index] = .media(updated)
                return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                        lo + inserted.reduce(0) { $0 + $1.utf16Count }, nil)
            case .table(var table):
                // A range inside ONE cell is the cell's text input: a cell holds a line of runs, so
                // the fragment is degraded to inline content — each block's runs, formatting and
                // inline atoms kept, one line each (the pull quote's rule) — and spliced into the
                // cell's own blocks. A medium, a table or a row in the fragment has no inline form
                // and adds nothing. Left to the complement model, the collapsed range lay inside the
                // table's span, so the table appeared in neither half: pasting the editor's own copy
                // at a caret in a cell DELETED the whole table (composer harness p19,
                // `HarnessFragmentPasteIntoTableCellTests`). A range crossing cells is the general
                // path's.
                var rowStart = cursor + 1
                for rowIndex in table.rows.indices {
                    var cellStart = rowStart + 1
                    for columnIndex in table.rows[rowIndex].cells.indices {
                        let cell = table.rows[rowIndex].cells[columnIndex]
                        let children = Document(blocks: cell.blocks)
                        let childrenSize = DocumentTree.documentSize(children)
                        let childrenStart = cellStart + 1
                        if lo >= childrenStart, hi <= childrenStart + childrenSize, !cell.blocks.isEmpty {
                            var runs: [TextRun] = []
                            for (offset, block) in fragment.blocks.enumerated() {
                                let blockRuns = blockInlineRuns(block)
                                if offset > 0, !runs.isEmpty, !blockRuns.isEmpty { runs.append(TextRun(text: "\n")) }
                                runs.append(contentsOf: blockRuns)
                            }
                            runs.removeAll { $0.text.isEmpty }
                            let inline = runs.isEmpty ? Document(blocks: [])
                                : Document(blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: runs))])
                            let inner = children.replacingRangeReportingInsertion(globalFrom: lo - childrenStart,
                                                                                  globalTo: hi - childrenStart,
                                                                                  with: inline,
                                                                                  endsTheCopiedDocument: false,
                                                                                  nested: true)
                            table.rows[rowIndex].cells[columnIndex].blocks = inner.document.blocks
                            var newBlocks = blocks
                            newBlocks[index] = .table(table)
                            // Folded into the cell's text: the caret stays in the cell.
                            return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                                    childrenStart + inner.caret, nil)
                        }
                        cellStart += childrenSize + 2
                    }
                    rowStart = cellStart + 1
                }
                return nil
            case .blockQuote(let quote) where !quote.collapsed:
                let childrenStart = cursor + 1
                let children = Document(blocks: quote.children)
                let childrenSize = DocumentTree.documentSize(children)
                // A range inside the AUTHOR line edits the author — the pull quote's rule above. On the
                // axis only while the quote has content, so asked of the block's own size.
                let authorStart = childrenStart + childrenSize + 1
                if blockSize == childrenSize + quote.authorUTF16Count + 4,
                   lo >= authorStart, hi <= authorStart + quote.authorUTF16Count {
                    let inserted = oneLineRuns(of: fragment)
                    let author = sliceRuns(quote.author, fromUTF16: 0, toUTF16: lo - authorStart) + inserted
                        + sliceRuns(quote.author, fromUTF16: hi - authorStart, toUTF16: quote.authorUTF16Count)
                    var newBlocks = blocks
                    newBlocks[index] = .blockQuote(BlockQuote(id: quote.id, children: quote.children,
                                                              collapsed: false, author: author))
                    return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                            lo + inserted.reduce(0) { $0 + $1.utf16Count }, nil)
                }
                guard !quote.children.isEmpty, lo >= childrenStart, hi <= childrenStart + childrenSize else {
                    return nil
                }
                // **A quote pasted into a quote brings its children, not a second quote.** A part of a
                // quote copies AS a quote (`extractFragment`, the code block's precedent), and the code
                // block's other half is that a code fragment pasted into code lands as its text; landed
                // as a block here, a word copied inside a quote and pasted back into it nested a quote
                // (`[quote [p "Second paragraph."] [quote [p "Second"]]]`), and the AI edit of a word
                // in a quote, handed back unchanged, split the child around a nested quote. One level
                // per quote: a copy from deeper keeps the levels this quote does not account for. A
                // quote carrying AUTHOR text keeps its own level — its children alone would drop it.
                var inserted = fragment
                if fragment.blocks.count == 1, case .blockQuote(let wrapped) = fragment.blocks[0],
                   !wrapped.collapsed, wrapped.author.allSatisfy({ $0.text.isEmpty }) {
                    inserted = Document(schemaVersion: fragment.schemaVersion, blocks: wrapped.children)
                }
                // A quote's children never end the copied document: its author line follows them.
                let inner = children.replacingRangeReportingInsertion(globalFrom: lo - childrenStart,
                                                                      globalTo: hi - childrenStart,
                                                                      with: inserted,
                                                                      endsTheCopiedDocument: false,
                                                                      nested: true)
                var newBlocks = blocks
                newBlocks[index] = .blockQuote(BlockQuote(id: quote.id, children: inner.document.blocks,
                                                          collapsed: false, author: quote.author))
                // The caller's caret policy works on TOP-LEVEL blocks. Content ending in text the
                // user can carry on typing in needs none (nil); anything else — a table, a medium,
                // a nested quote — is placed after by the caller, which can only mean after this
                // quote.
                let lastInserted: Int? = inner.lastInsertedBlockIndex.flatMap { innerIndex in
                    guard innerIndex < inner.document.blocks.count else { return index }
                    if case .paragraph(let p) = inner.document.blocks[innerIndex] {
                        switch p.style {
                        case .body, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6: return nil
                        case .caption, .pullQuote: return index
                        }
                    }
                    return index
                }
                return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                        childrenStart + inner.caret, lastInserted)
            default:
                return nil
            }
        }
        return nil
    }

    /// A sub-`Document` of the selection `[lo, hi)`. Paragraph and code blocks are copied (boundary
    /// blocks truncated to the covered runs). By default **media and table blocks are skipped** (Phase 5d
    /// copy/paste scope); pass `carryingNonTextBlocks: true` (the AI-edit-on-selection path) to also carry a
    /// **fully-covered** media/table block (fresh IDs via `regeneratingIDs`). All block IDs are freshly generated.
    public func extractFragment(globalFrom lo: Int, globalTo hi: Int,
                                carryingNonTextBlocks: Bool = false) -> Document {
        return self.extractFragment(globalFrom: lo, globalTo: hi, carryingNonTextBlocks: carryingNonTextBlocks,
                                    endsTheCopiedDocument: true, nested: false, languagesAsText: false,
                                    complementOf: nil)
    }

    /// `extractFragment` with every code block's LANGUAGE as the text the range covered: the covered part
    /// of the language line as a body line before its code, and a code block with no language. The
    /// fragment `extractFragment` gives carries a code block's language as METADATA whether or not the
    /// range held its language line (a pasted body slice is a code block in that language, which
    /// `CodeBlockPositionTests` pins), so a destination that holds only RUNS — a table cell, a media
    /// caption, a pull quote's body — could not tell the language the copy took from one it did not, and
    /// degraded every code block to its body: Cut + Paste of a code block into a cell deleted its language
    /// (composer harness p23, `HarnessCodeLanguageIntoRunsRegionTests`). This is the copy's covered TEXT,
    /// which the editor's own copy writes beside the fragment for such a destination.
    public func extractFragmentAsCoveredText(globalFrom lo: Int, globalTo hi: Int,
                                             carryingNonTextBlocks: Bool = false) -> Document {
        return self.extractFragment(globalFrom: lo, globalTo: hi, carryingNonTextBlocks: carryingNonTextBlocks,
                                    endsTheCopiedDocument: true, nested: false, languagesAsText: true,
                                    complementOf: nil)
    }

    /// Every code block's language as a body line before its code (the code then languageless): a fragment
    /// that came with no range — a host's copy of a whole message — holds every language as content, which
    /// is `oneLineFieldText`'s rule too. What a runs-only destination takes from a fragment that has no
    /// covered-text twin (`extractFragmentAsCoveredText`).
    public var withCodeLanguagesAsText: Document {
        func lines(_ blocks: [Block]) -> [Block] {
            return blocks.flatMap { block -> [Block] in
                switch block {
                case .code(let code):
                    guard let language = code.language, !language.isEmpty else { return [block] }
                    return [.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: language)])),
                            .code(CodeBlock(id: code.id, language: nil, runs: code.runs))]
                case .blockQuote(var quote):
                    quote.children = lines(quote.children)
                    return [.blockQuote(quote)]
                case .details(var details):
                    details.children = lines(details.children)
                    return [.details(details)]
                default:
                    return [block]
                }
            }
        }
        return Document(schemaVersion: schemaVersion, blocks: lines(blocks), layoutDirection: layoutDirection)
    }

    /// `endsTheCopiedDocument`: this document's end is the end of the document the range was taken in
    /// (true at the top; for a container's children, true only when nothing with a text position
    /// follows them there — an EXPANDED details that ends its document; never a block quote's, whose
    /// author line follows them). `nested`: these are a container's children.
    ///
    /// `complementOf`: nil for a copy. For one half of `replacingRange`'s complement it is the range
    /// being replaced, in this document's coordinates: a second line that range's own copy carries
    /// as METADATA — a code block's language once it covers some of the code text, a pull quote's
    /// whole author once it covers the whole body — is that range's, and is not kept here as a body
    /// paragraph (the language-only and author-only branches below). Kept, the replacement had it
    /// twice: `[p "intro"] [pull "pulled" by "Auth"]`, replace `"intro…pulled"` with its own copy →
    /// a stray `p "Auth"` after the pull quote; from a code block's text into the next paragraph → a
    /// `p "swift"` before a code block still in swift.
    private func extractFragment(globalFrom lo: Int, globalTo hi: Int, carryingNonTextBlocks: Bool,
                                 endsTheCopiedDocument: Bool, nested: Bool, languagesAsText: Bool,
                                 complementOf removed: (lo: Int, hi: Int)?) -> Document {
        guard lo < hi else { return Document(blocks: []) }
        var out: [Block] = []
        var cursor = 0
        // An EMPTY text region covers no character, so "some of its text is covered" can never hold
        // for it. It is covered when the range starts at or before it and reaches it — past it, or AT
        // it when it is the last text position of this document (a Select All ends there). That is
        // the empty paragraph's rule (`lo <= textStart && hi > textStart`) with the document's end
        // admitted, so a container whose only text is empty — an empty code block, an empty pull
        // quote with or without an author — is carried like the blank line it is. Collected by
        // covered text alone, Select All → Copy → Paste dropped both, the pull quote's author with
        // it (composer harness, 2026-09-23, fuzz seed 83, `HarnessEmptyContainerCopyPasteTests`).
        //
        // "The document" is the one the range was taken in, not a container's children: a range ending
        // at the start of an empty line that is the last of a details' or a quote's children, with more
        // text after the container, ends BEFORE that line (a range's end is exclusive), and was admitted
        // because it was the last position of the CHILDREN. Conversely an empty paragraph that is the
        // last line of an expanded details ending the document is where Select All ends, so it is
        // covered like an empty code block there; before, the paragraph kept the bare `hi > start` rule
        // and Select All → Copy of `[details "T" [p "body"] [p ""]]` at the document end dropped the
        // empty line from the body (composer harness p17, fuzz seed 69,
        // `HarnessDetailsTrailingEmptyLineCopyTests`). A TOP-LEVEL empty last paragraph keeps the bare
        // rule: it is the document's trailing line, which a paste supplies itself.
        let documentEnd = DocumentTree.documentSize(self)
        func covers(_ range: (lo: Int, hi: Int), emptyRegionAt start: Int, blockEnd: Int) -> Bool {
            range.lo <= start
                && (range.hi > start || (range.hi == start && endsTheCopiedDocument && blockEnd == documentEnd))
        }
        func coversEmptyRegion(at start: Int, blockEnd: Int) -> Bool {
            covers((lo, hi), emptyRegionAt: start, blockEnd: blockEnd)
        }
        // `complementOf`, for a container's children laid out from `origin`.
        func removedInChildren(at origin: Int) -> (lo: Int, hi: Int)? {
            removed.map { (lo: $0.lo - origin, hi: $0.hi - origin) }
        }
        // A container's children copied WHOLE: every language they hold was covered.
        func wholly(_ children: [Block]) -> [Block] {
            let regenerated = regeneratingIDs(children)
            return languagesAsText ? Document(blocks: regenerated).withCodeLanguagesAsText.blocks : regenerated
        }
        for block in blocks {
            let size = DocumentTree.documentSize(Document(blocks: [block]))
            let textStart = cursor + 1
            switch block {
            case .paragraph(let p):
                let a = max(lo, textStart), b = min(hi, textStart + p.utf16Count)
                let emptyCovered = nested
                    ? coversEmptyRegion(at: textStart, blockEnd: cursor + size)
                    : (lo <= textStart && hi > textStart)
                if a < b || (p.utf16Count == 0 && emptyCovered) {
                    let r = sliceRuns(p.runs, fromUTF16: max(0, a - textStart), toUTF16: max(0, b - textStart))
                    // A range PART of one list item's text — no paragraph break, not all of its text —
                    // is text, not an item: it leaves the membership behind, so a paste folds it inline
                    // (`isInlineMergeable`) as a stock text view does. Carrying the `list`, a word
                    // copied from an item pasted as an item of its own and split the line it landed in
                    // (a checked one's check came too; composer harness p16,
                    // `HarnessPartialFragmentPasteTests`). All of an item's text, or anything reaching
                    // past it, still copies as the item. A heading keeps its style either way
                    // (`isInlineMergeable`'s decision).
                    let insideOneItem = lo >= textStart && hi <= textStart + p.utf16Count
                        && hi - lo < p.utf16Count
                    out.append(.paragraph(ParagraphBlock(id: .generate(), style: p.style,
                                                          paragraph: p.paragraph,
                                                          list: insideOneItem ? nil : p.list, runs: r)))
                }
            case .code(let c):
                // Container now, like a pull quote: the code text starts past the language line, NOT at
                // the shared `textStart`. A partial copy carries the language, which is block metadata
                // rather than flat text — the same rule the pull quote applies to its author.
                let codeStart = cursor + codeTextStartOffset(c)
                let a = max(lo, codeStart), b = min(hi, codeStart + c.utf16Count)
                // `languagesAsText` (`extractFragmentAsCoveredText`): the language line's COVERED text as a
                // line of its own before the code, and the code languageless.
                func code(_ runs: [TextRun]) {
                    guard languagesAsText else {
                        out.append(.code(CodeBlock(id: .generate(), language: c.language, runs: runs)))
                        return
                    }
                    let la = max(lo, cursor + 2), lb = min(hi, cursor + 2 + c.languageUTF16Count)
                    if let language = c.language, la < lb {
                        let slice = (language as NSString).substring(with: NSRange(location: la - (cursor + 2), length: lb - la))
                        out.append(.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: slice)])))
                    }
                    out.append(.code(CodeBlock(id: .generate(), language: nil, runs: runs)))
                }
                // The replaced range's copy is this code block, in its language (`complementOf`).
                let languageIsRemoved = removed.map { r in
                    max(r.lo, codeStart) < min(r.hi, codeStart + c.utf16Count)
                        || (c.utf16Count == 0 && covers(r, emptyRegionAt: codeStart, blockEnd: cursor + size))
                } ?? false
                if a < b {
                    code(sliceRuns(c.runs, fromUTF16: a - codeStart, toUTF16: b - codeStart))
                } else if c.utf16Count == 0, coversEmptyRegion(at: codeStart, blockEnd: cursor + size) {
                    // An EMPTY code block is carried like an empty paragraph (see `coversEmptyRegion`).
                    code([])
                } else if let language = c.language, c.languageUTF16Count > 0, !languageIsRemoved,
                          max(lo, cursor + 2) < min(hi, cursor + 2 + c.languageUTF16Count) {
                    // Only the LANGUAGE line's text is covered (a range ending at the code text's start):
                    // it copies as text. The language is on the editor's axis, and a Cut or a move deleted
                    // it while the copy carried nothing (composer harness p19 fix wave,
                    // `HarnessQuoteAuthorCutMoveTests`).
                    let from = max(lo, cursor + 2) - (cursor + 2), to = min(hi, cursor + 2 + c.languageUTF16Count) - (cursor + 2)
                    let slice = (language as NSString).substring(with: NSRange(location: from, length: to - from))
                    out.append(.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: slice)])))
                }
            case .pullQuote(let pq):
                // A pull quote is now a `.blockQuote` container [pullPara, authorPara] (Task 2), so the pull
                // text starts at cursor + 2 (container open + pullPara open), NOT the shared `textStart`
                // (cursor + 1, correct for paragraph/code). Using `textStart` here slices the wrong UTF-16
                // range and computes the author-carry condition against the wrong base.
                let ptStart = cursor + 2
                let a = max(lo, ptStart), b = min(hi, ptStart + pq.utf16Count)
                // The author's COVERED text: the author line is on the editor's axis (after the pull
                // text's close and its own open), and a copy that reached into it and carried nothing of
                // it lost that text when a Cut or a move deleted it (composer harness p19 fix wave,
                // `HarnessQuoteAuthorCutMoveTests`). The whole pull text still carries the whole author.
                let authorStart = ptStart + pq.utf16Count + 2
                let authorA = max(lo, authorStart), authorB = min(hi, authorStart + pq.authorUTF16Count)
                let authorSlice = authorA < authorB
                    ? sliceRuns(pq.author, fromUTF16: authorA - authorStart, toUTF16: authorB - authorStart) : []
                // The replaced range's copy is this pull quote, author and all (`complementOf`).
                let authorIsRemoved = removed.map { r in
                    pq.utf16Count > 0
                        ? r.lo <= ptStart && r.hi >= ptStart + pq.utf16Count
                        : covers(r, emptyRegionAt: ptStart, blockEnd: cursor + size)
                } ?? false
                if a < b {
                    let r = sliceRuns(pq.runs, fromUTF16: a - ptStart, toUTF16: b - ptStart)
                    let author = (a == ptStart && b == ptStart + pq.utf16Count) ? pq.author : authorSlice
                    out.append(.pullQuote(PullQuote(id: .generate(), runs: r, author: author)))
                } else if pq.utf16Count == 0, coversEmptyRegion(at: ptStart, blockEnd: cursor + size) {
                    // An EMPTY pull text is wholly covered once covered at all, so the author comes too.
                    out.append(.pullQuote(PullQuote(id: .generate(), runs: [], author: pq.author)))
                } else if !authorSlice.isEmpty, !authorIsRemoved {
                    // Only the author's text of a pull quote with text: it copies as text.
                    out.append(.paragraph(ParagraphBlock(id: .generate(), runs: regeneratingRunIdentities(authorSlice))))
                }
            case .blockQuote(let bq):
                if lo <= cursor && hi >= cursor + size {
                    out.append(.blockQuote(BlockQuote(id: .generate(),
                                                      children: wholly(bq.children),
                                                      collapsed: bq.collapsed,
                                                      author: bq.author)))
                } else if !bq.collapsed {
                    // A selection that ENTERS the quote takes the part of its children it covers, as a
                    // quote — the same rule code and pull quotes follow (their partial copies stay code
                    // and pull quotes). It used to be dropped whole, and a text-position selection
                    // never covers a quote's closing tokens: Select All ends in the author line's
                    // text, so the engine's Select All + Copy of `[p] [quote]` put only the paragraph
                    // on the pasteboard, and Cut deleted the quote with no copy of it (composer
                    // harness, 2026-09-22). The children sit one token past the quote's open, laid
                    // out exactly as a document of them would be; the author line follows them and,
                    // like a pull quote's, is carried only when its whole text is covered.
                    let childrenStart = cursor + 1
                    // The author line follows the children, so their end is never the document's.
                    let inner = Document(blocks: bq.children)
                        .extractFragment(globalFrom: lo - childrenStart, globalTo: hi - childrenStart,
                                         carryingNonTextBlocks: carryingNonTextBlocks,
                                         endsTheCopiedDocument: false, nested: true,
                                         languagesAsText: languagesAsText,
                                         complementOf: removedInChildren(at: childrenStart))
                    // The author's covered text comes too (the pull quote's rule above, p19 fix wave).
                    let authorStart = childrenStart + DocumentTree.documentSize(Document(blocks: bq.children)) + 1
                    let authorA = max(lo, authorStart), authorB = min(hi, authorStart + bq.authorUTF16Count)
                    let authorSlice = authorA < authorB
                        ? sliceRuns(bq.author, fromUTF16: authorA - authorStart, toUTF16: authorB - authorStart) : []
                    // A range covering ALL of the children's text takes the whole author, as the whole pull
                    // text does: the engine's gate drops such a quote whole, author included
                    // (`containerIsCovered`), and its Copy is widened to match. The replaced range's copy
                    // then carries the author (`complementOf`), so the complement must not keep it as a
                    // body paragraph: an AI edit handed back unchanged turned `[quote … by "Auth"]` into
                    // `[quote … by ""] [p "Auth"]` (review of the fix wave, 2026-10-12,
                    // `DocumentSecondaryLineReplaceTests`).
                    let childrenText = primaryTextExtent(of: Document(blocks: bq.children))
                    func coversAllChildren(_ r: (lo: Int, hi: Int)) -> Bool {
                        guard let e = childrenText else { return false }
                        let last = childrenStart + e.last
                        // An empty last region is covered by the nested rule: the range must go past it.
                        return r.lo <= childrenStart + e.first && (r.hi > last || (r.hi == last && !e.lastIsEmpty))
                    }
                    let authorIsRemoved = removed.map(coversAllChildren) ?? false
                    let author = authorIsRemoved ? [] : (coversAllChildren((lo, hi)) ? bq.author : authorSlice)
                    if !inner.blocks.isEmpty {
                        out.append(.blockQuote(BlockQuote(id: .generate(), children: inner.blocks,
                                                          collapsed: false,
                                                          author: author)))
                    } else if !authorSlice.isEmpty, !authorIsRemoved {
                        out.append(.paragraph(ParagraphBlock(id: .generate(), runs: regeneratingRunIdentities(authorSlice))))
                    }
                }
            case .details(let d):
                if lo <= cursor && hi >= cursor + size {
                    out.append(.details(DetailsBlock(id: .generate(), title: d.title,
                                                     children: wholly(d.children), expanded: d.expanded)))
                } else if lo < cursor + size && hi > cursor {
                    // A range that ENTERS the details — the twin of the block quote's rule above. A text
                    // selection never covers the closing tokens, so a details ending the document was
                    // dropped by Select All → Copy, and a selection entering only its title kept nothing
                    // of it (composer harness, 2026-09-23, fuzz seed 215, `HarnessDetailsCopyPasteTests`).
                    // The title sits two tokens in (container open, title open), the body one token after
                    // the title's close, laid out exactly as a document of the children (expanded only —
                    // a folded body is off the axis).
                    let titleStart = cursor + 2
                    let titleEnd = titleStart + d.titleUTF16Count
                    let ta = max(lo, titleStart), tb = min(hi, titleEnd)
                    // An EMPTY title is covered by the empty region's rule: the bare one for an expanded
                    // details (its body follows), the document-end admission for a folded one, whose
                    // title is its only text position — where Select All ends when it ends the document
                    // (mirrored by `carriedEmptyEndRegionStart`).
                    let titleTouched = ta < tb || (d.titleUTF16Count == 0
                        && (d.expanded ? lo <= titleStart && hi > titleStart
                                       : coversEmptyRegion(at: titleStart, blockEnd: cursor + size)))
                    let childrenStart = titleEnd + 1
                    // The body's end is the document's when this details ends it (its close is no text
                    // position). Empty when the range covers none of the body.
                    let coveredChildren: [Block] = d.expanded
                        ? Document(blocks: d.children)
                            .extractFragment(globalFrom: lo - childrenStart, globalTo: hi - childrenStart,
                                             carryingNonTextBlocks: carryingNonTextBlocks,
                                             endsTheCopiedDocument: endsTheCopiedDocument && cursor + size == documentEnd,
                                             nested: true, languagesAsText: languagesAsText,
                                             complementOf: removedInChildren(at: childrenStart)).blocks
                        : []
                    // **The range carries a details only when it covers some of its title.** It used to
                    // be enough to START at or before the title, so a range ENDING at the title's start —
                    // covering no title text and, the body following the title, no body either — copied
                    // `[details "" [p ""]]` out of nothing: from "fore" in `[p "before"] [details "Title"
                    // …]` to the title's start gave `[p "fore"] [details "" [p ""]]` (before 0e12da1b82,
                    // `[p "fore"]`), and replacing that range with its own copy added a details.
                    if titleTouched {
                        var children: [Block]
                        if d.expanded {
                            children = coveredChildren
                            // An expanded details always has a body line: the engine bridge mints an empty
                            // paragraph for a childless one, so a fragment without it would put a line on
                            // screen that the model does not have, and every position after it would be one
                            // short (the caret after pasting `[details "T" [p ""]]` landed in its body).
                            if children.isEmpty {
                                children = [.paragraph(ParagraphBlock(id: .generate()))]
                            }
                        } else {
                            // Folded: the body travels with a WHOLLY covered title, never with a partial one.
                            children = (lo <= titleStart && hi >= titleEnd) ? wholly(d.children) : []
                        }
                        // The covered part of the title as its title, the covered children as its body.
                        let title = ta < tb ? sliceRuns(d.title, fromUTF16: ta - titleStart, toUTF16: tb - titleStart) : []
                        out.append(.details(DetailsBlock(id: .generate(), title: title,
                                                         children: children, expanded: d.expanded)))
                    } else {
                        // Wholly inside the body: the text itself, not a details around it — and nothing
                        // when it covers none of it. The body line minted above is only for a details
                        // the range carries: minted here, a range from the end of the last body line
                        // left a stray empty top-level paragraph in `replacingRange`'s complement.
                        out.append(contentsOf: coveredChildren)
                    }
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

/// The first and last positions of a document's PRIMARY text, relative to its own origin: the span a
/// range must cover for every child of a container holding the document to be covered. A code
/// block's language line and a quote's author are second lines and do not count — a range covering a
/// container's primary text carries them (the engine's `containerIsCovered`). Nil for a document
/// with no text at all (a lone caption-less atom).
private func primaryTextExtent(of document: Document) -> (first: Int, last: Int, lastIsEmpty: Bool)? {
    var first: Int?
    var last: (end: Int, isEmpty: Bool)?
    func walk(_ node: DocNode, _ contentStart: Int) {
        var acc = 0
        for child in node.children {
            let childStart = contentStart + acc
            switch child {
            case .text(let length, let ref):
                switch ref {
                case .codeLanguage, .quoteAuthor:
                    break
                case .paragraph, .caption, .code, .pullQuote, .detailsTitle:
                    if first == nil { first = childStart }
                    last = (childStart + length, length == 0)
                }
            case .mediaAtom:
                break
            default:
                walk(child, childStart + 1)
            }
            acc += child.nodeSize
        }
    }
    walk(DocumentTree.build(from: document), 0)
    guard let first, let last else { return nil }
    return (first, last.end, last.isEmpty)
}
