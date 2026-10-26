import XCTest
@testable import RichTextEditorCore

/// **Deleting a block's TEXT empties the block; it does not delete the block.**
///
/// Selecting everything on a line and pressing delete leaves a blank line — in any editor — and
/// `replacingRange` removed the line instead. `extractFragment` keeps a block only when the range
/// covers some of its TEXT, and the deletion is computed as the complement (`prefix = [0, lo)`,
/// `suffix = [hi, size)`), so a block whose text is exactly the deleted range appears in NEITHER
/// half and vanishes. Its heading level, list membership or code language went with it.
///
/// The rule this pins: **a range lying inside ONE block's span deletes text, never the block.** The
/// complement is the right model for everything else — a fully covered table or media block really
/// is dropped, and that is what the range covering the block's whole SPAN means.
final class DocumentEmptiedBlockTests: XCTestCase {
    private func doc(_ blocks: Block...) -> Document { Document(blocks: blocks) }
    private func para(_ id: String, _ text: String, style: ParagraphStyleName = .body,
                      list: ListMembership? = nil) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: style, list: list,
                                  runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func kinds(_ d: Document) -> [String] {
        d.blocks.map { block in
            switch block {
            case .paragraph: return "paragraph"
            case .code: return "code"
            case .pullQuote: return "pullQuote"
            case .blockQuote: return "blockQuote"
            case .details: return "details"
            case .table: return "table"
            case .media: return "media"
            case .buttonRow: return "buttonRow"
            }
        }
    }
    private func texts(_ d: Document) -> [String] {
        d.blocks.compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
    }
    /// The whole text range of the block at `index`.
    private func textRange(_ d: Document, _ index: Int) -> (Int, Int) {
        let start = d.globalTextStart(ofBlockAt: index)
        switch d.blocks[index] {
        case .paragraph(let p): return (start, start + p.utf16Count)
        case .code(let c): return (start, start + c.utf16Count)
        case .pullQuote(let pq): return (start, start + pq.utf16Count)
        default: return (start, start)
        }
    }

    // MARK: - The line survives

    func test_deletingASecondParagraphsWholeTextLeavesABlankLine() {
        let d = doc(para("a", "A"), para("b", "Hello"))
        let (lo, hi) = textRange(d, 1)
        let (out, caret) = d.replacingRange(globalFrom: lo, globalTo: hi, with: Document(blocks: []))

        XCTAssertEqual(texts(out), ["A", ""], "the line stays, emptied")
        XCTAssertEqual(caret, out.globalTextStart(ofBlockAt: 1), "the caret is on the now-blank line")
    }

    func test_deletingTheFirstParagraphsWholeTextLeavesABlankLine() {
        let d = doc(para("a", "Hello"), para("b", "B"))
        let (lo, hi) = textRange(d, 0)
        let (out, _) = d.replacingRange(globalFrom: lo, globalTo: hi, with: Document(blocks: []))

        XCTAssertEqual(texts(out), ["", "B"])
    }

    func test_deletingTheOnlyParagraphsTextLeavesAnEmptyDocumentWithOneLine() {
        let d = doc(para("a", "Hello"))
        let (lo, hi) = textRange(d, 0)
        let (out, _) = d.replacingRange(globalFrom: lo, globalTo: hi, with: Document(blocks: []))

        XCTAssertEqual(texts(out), [""], "a document always keeps a line to type on")
    }

    // MARK: - The block's SHAPE survives with it

    func test_anEmptiedHeadingIsStillAHeading() {
        let d = doc(para("a", "A"), para("h", "Title", style: .heading2))
        let (lo, hi) = textRange(d, 1)
        let (out, _) = d.replacingRange(globalFrom: lo, globalTo: hi, with: Document(blocks: []))

        guard out.blocks.count == 2, case let .paragraph(p) = out.blocks[1] else {
            return XCTFail("expected the heading to survive, got \(kinds(out))")
        }
        XCTAssertEqual(p.style, .heading2, "emptying the text must not silently demote it to body")
    }

    func test_anEmptiedListItemIsStillAListItem() {
        let d = doc(para("a", "A"), para("l", "item", list: ListMembership(marker: .bullet, level: 0)))
        let (lo, hi) = textRange(d, 1)
        let (out, _) = d.replacingRange(globalFrom: lo, globalTo: hi, with: Document(blocks: []))

        guard out.blocks.count == 2, case let .paragraph(p) = out.blocks[1] else {
            return XCTFail("expected the item to survive, got \(kinds(out))")
        }
        XCTAssertEqual(p.list?.marker, .bullet, "the bullet stays; the user emptied its text, not the list")
    }

    func test_anEmptiedCodeBlockKeepsItsLanguage() {
        let d = doc(para("a", "A"), .code(CodeBlock(id: BlockID("c"), language: "swift",
                                                    runs: [TextRun(text: "let x = 1")])))
        let (lo, hi) = textRange(d, 1)
        let (out, _) = d.replacingRange(globalFrom: lo, globalTo: hi, with: Document(blocks: []))

        guard out.blocks.count == 2, case let .code(c) = out.blocks[1] else {
            return XCTFail("expected the code block to survive, got \(kinds(out))")
        }
        XCTAssertEqual(c.language, "swift")
        XCTAssertEqual(c.utf16Count, 0)
    }

    // MARK: - Controls: what a range covering the whole SPAN still does

    /// The complement model is right for a block the range really does cover whole — this is the
    /// behaviour the fix must not disturb.
    func test_aRangeOverATablesWholeSpanStillDropsIt() {
        let table = Block.table(TableBlock.empty(rows: 1, columns: 1))
        let d = doc(para("a", "A"), table, para("b", "B"))
        let aSize = DocumentTree.documentSize(doc(para("a", "A")))
        let tSize = DocumentTree.documentSize(Document(blocks: [table]))
        let (out, _) = d.replacingRange(globalFrom: aSize, globalTo: aSize + tSize, with: Document(blocks: []))

        XCTAssertEqual(kinds(out), ["paragraph", "paragraph"], "a wholly covered table is still dropped")
    }

    /// A range crossing a paragraph break still JOINS the two paragraphs — it lies in no single
    /// block's span, so the new rule must not fire.
    func test_aRangeAcrossABreakStillJoins() {
        let d = doc(para("a", "AB"), para("b", "CD"))
        let (out, _) = d.replacingRange(globalFrom: 2, globalTo: 6, with: Document(blocks: []))

        XCTAssertEqual(texts(out), ["AD"], "the join is unchanged")
    }

    /// Replacing a whole paragraph's text with a fragment still yields one block — and now keeps the
    /// style it was rewriting, because the fragment folds into the surviving emptied block.
    func test_rewritingAWholeParagraphKeepsItsStyle() {
        let d = doc(para("a", "A"), para("h", "Title", style: .heading2))
        let (lo, hi) = textRange(d, 1)
        let (out, _) = d.replacingRange(globalFrom: lo, globalTo: hi, with: doc(para("n", "New")))

        XCTAssertEqual(texts(out), ["A", "New"])
        guard case let .paragraph(p) = out.blocks[1] else { return XCTFail("expected a paragraph") }
        XCTAssertEqual(p.style, .heading2, "an AI rewrite of a heading stays a heading")
    }

    /// A collapsed range IN an empty paragraph (a paste at the caret there) is also "one block's whole
    /// text", and the paragraph must come out once: the complement's suffix from `hi` kept it too,
    /// so the result had it twice and the paste left a blank line after the pasted text.
    func test_pastingAtACaretInAnEmptyParagraphAddsNoBlankLine() {
        let fragment = Document(blocks: [para("f", "Pasted")])
        let alone = doc(para("a", ""))
        let (lo, _) = textRange(alone, 0)
        let (out, _) = alone.replacingRange(globalFrom: lo, globalTo: lo, with: fragment)
        XCTAssertEqual(texts(out), ["Pasted"])

        let between = doc(para("a", ""), para("b", "B"))
        let (at, _) = textRange(between, 0)
        let (joined, _) = between.replacingRange(globalFrom: at, globalTo: at, with: fragment)
        XCTAssertEqual(texts(joined), ["Pasted", "B"])

        let deleted = between.replacingRange(globalFrom: at, globalTo: at, with: Document(blocks: []))
        XCTAssertEqual(texts(deleted.document), ["", "B"], "an empty delete in an empty line changes nothing")
    }

    // MARK: - A MULTI-block rewrite keeps the fragment's own styles

    private func styles(_ d: Document) -> [ParagraphStyleName?] {
        d.blocks.map { if case .paragraph(let p) = $0 { return p.style } else { return nil } }
    }
    private func lists(_ d: Document) -> [ListMarker?] {
        d.blocks.map { if case .paragraph(let p) = $0 { return p.list?.marker } else { return nil } }
    }

    /// The AI rewrite of a heading that answers with a heading AND a body paragraph. Folding that
    /// into the emptied heading imposed its style on BOTH ends of the fragment — two H1s — because
    /// the split of an emptied block has a tail half that only exists as a copy of its style.
    func test_rewritingAWholeHeadingWithSeveralBlocksKeepsTheirOwnStyles() {
        let d = doc(para("a", "A"), para("h", "Title", style: .heading1))
        let (lo, hi) = textRange(d, 1)
        let fragment = doc(para("n", "New title", style: .heading1), para("b", "Body text"))
        let (out, caret) = d.replacingRange(globalFrom: lo, globalTo: hi, with: fragment)

        XCTAssertEqual(texts(out), ["A", "New title", "Body text"])
        XCTAssertEqual(styles(out), [.body, .heading1, .body], "the body paragraph was retyped as the heading")
        XCTAssertEqual(caret, out.globalTextStart(ofBlockAt: 2) + 9, "the caret follows the inserted content")
    }

    func test_rewritingAWholeListItemWithSeveralBlocksAddsNoListMembership() {
        let d = doc(para("a", "a"), para("l", "item", list: ListMembership(marker: .bullet, level: 0)), para("b", "b"))
        let (lo, hi) = textRange(d, 1)
        let fragment = doc(para("x", "A"), .table(TableBlock.empty(rows: 1, columns: 1)), para("y", "B"))
        let (out, _) = d.replacingRange(globalFrom: lo, globalTo: hi, with: fragment)

        XCTAssertEqual(kinds(out), ["paragraph", "paragraph", "table", "paragraph", "paragraph"])
        XCTAssertEqual(texts(out), ["a", "A", "B", "b"])
        XCTAssertEqual(lists(out), [nil, nil, nil, nil, nil], "the fragment's paragraphs were turned into list items")
    }

    /// Control: a caret in an EMPTY paragraph is a paste, not a rewrite, and keeps the splice — the
    /// pasted ends fold into the line (no blank line is left after them), as a paste at that caret
    /// on the legacy canvas does.
    func test_controlAMultiBlockPasteAtACaretInAnEmptyLineStillConsumesTheLine() {
        let d = doc(para("a", ""), para("b", "B"))
        let (at, _) = textRange(d, 0)
        let (out, _) = d.replacingRange(globalFrom: at, globalTo: at, with: doc(para("x", "X"), para("y", "Y")))
        XCTAssertEqual(texts(out), ["X", "Y", "B"])
    }
}
