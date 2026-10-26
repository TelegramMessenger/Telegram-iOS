#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

@available(iOS 13.0, *)
final class CanvasPullQuoteEditTests: XCTestCase {
    private func makeCanvas() -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        return c
    }

    private func pullQuoteCanvas(_ text: String = "hi") -> DocumentCanvasView {
        let c = makeCanvas()
        c.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: text.isEmpty ? [] : [TextRun(text: text)]))],
                    width: 320)
        c.simulateParentLayout()
        return c
    }

    func test_makePullQuote_togglesParagraphsIntoOneBlock_preservingFormatting() {
        let canvas = makeCanvas()
        var bold = CharacterAttributes(); bold.bold = true
        canvas.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), style: .body, runs: [TextRun(text: "one", attributes: bold)])),
            .paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "two")])),
        ], width: 320)
        canvas.simulateParentLayout()
        canvas.selectAll(nil)                        // span both paragraphs
        canvas.makePullQuote()
        let blocks = canvas.currentBlocks()          // currentBlocks() mirrors currentDocument().blocks
        XCTAssertEqual(blocks.count, 1)
        guard case .pullQuote(let pq) = blocks[0] else { return XCTFail("not a pull quote") }
        XCTAssertEqual(pq.text, "one\ntwo")
        XCTAssertTrue(pq.runs.contains { $0.attributes.bold })   // formatting preserved (NOT flattened)

        // Toggle back:
        canvas.selectAll(nil)
        canvas.makePullQuote()
        let back = canvas.currentBlocks()
        XCTAssertTrue(back.allSatisfy { if case .paragraph = $0 { return true } else { return false } })
        XCTAssertEqual(back.count, 2)
    }

    // MARK: - Task 13: in-block editing

    // MARK: Enter inserts an interior newline (no paragraph split)

    func test_pullQuote_enterInsertsInteriorNewline() {
        let canvas = pullQuoteCanvas("hi")
        // textStart = 1, so global 3 = after "hi"
        canvas.setCaret(global: canvas.boxes[0].textStart + 2)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1, "Enter inside a pull quote must NOT split into two blocks")
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertTrue(pq.text.contains("\n"), "the pull quote text must contain the inserted newline")
    }

    func test_pullQuote_enterAtEnd_insertsNewlineDoesNotSplit() {
        let canvas = pullQuoteCanvas("line1")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart + box.textLength)   // after "line1"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.text, "line1\n")
    }

    func test_pullQuote_enterAtStart_insertsNewlineAtFront() {
        let canvas = pullQuoteCanvas("ab")
        canvas.setCaret(global: canvas.boxes[0].textStart)   // before "ab"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.text, "\nab")
    }

    func test_pullQuote_caretAdvancesAfterNewline() {
        let canvas = pullQuoteCanvas("ab")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart + 1)   // after "a"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.head, box.textStart + 2, "caret must land after the inserted newline")
    }

    func test_pullQuote_enterReplacesSelectionWithNewline() {
        let canvas = pullQuoteCanvas("abcd")
        let box = canvas.boxes[0]
        canvas.setSelectionAnchor(global: box.textStart + 1)   // after "a"
        canvas.setSelectionHead(global: box.textStart + 3)     // before "d"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.text, "a\nd")
    }

    // MARK: Double-return exits

    func test_pullQuote_doubleReturnOnTrailingBlankLine_exitsAfter() {
        let canvas = pullQuoteCanvas("abc\n")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart + box.textLength)   // end of "abc\n"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2, "double-return on a trailing blank line exits the pull quote")
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote first") }
        XCTAssertEqual(pq.text, "abc", "the trailing blank line is removed")
        guard case .paragraph(let p) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .paragraph second") }
        XCTAssertEqual(p.style, .body, "an empty body paragraph is added after the pull quote")
        XCTAssertEqual(canvas.head, canvas.boxes[1].textStart, "caret in the new body paragraph")
    }

    func test_pullQuote_doubleReturnOnFirstBlankLine_exitsBefore() {
        let canvas = pullQuoteCanvas("\nabc")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart)   // local 0 — the empty first line
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        guard case .paragraph(let p) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .paragraph first") }
        XCTAssertEqual(p.style, .body, "an empty body paragraph is inserted before the pull quote")
        guard case .pullQuote(let pq) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .pullQuote second") }
        XCTAssertEqual(pq.text, "abc", "the empty first line is removed")
        XCTAssertEqual(canvas.head, canvas.boxes[0].textStart, "caret in the new body paragraph")
    }

    func test_pullQuote_singleReturnOnEmptyBlock_addsLine_doesNotUnmake() {
        let canvas = pullQuoteCanvas("")   // wholly-empty pull quote
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("still a pull quote after one Return") }
        XCTAssertEqual(pq.text, "\n", "the first Return adds a blank line (no un-make — the escape requires \\n\\n)")
    }

    func test_pullQuote_doubleReturnOnEmptyBlock_unmakes() {
        let canvas = pullQuoteCanvas("")   // wholly-empty pull quote
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart)
        canvas.insertText("\n")   // adds a blank line
        canvas.insertText("\n")   // \n\n → un-make
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .paragraph(let p) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .paragraph") }
        XCTAssertEqual(p.style, .body, "\\n\\n un-makes the empty pull quote to a body paragraph")
    }

    func test_pullQuote_returnOnMiddleEmptyLine_insertsNewline() {
        let canvas = pullQuoteCanvas("a\n\nb")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart + 2)   // on the middle empty line
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1, "a middle empty line stays inside the pull quote")
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.text, "a\n\n\nb", "another newline is inserted (no exit)")
    }

    // Two newlines at the beginning exits before (the first Enter lands caret after the new "\n" on the
    // content line, so the second is at local 1 — the start-of-content-after-a-leading-blank case).
    func test_pullQuote_twoNewlinesAtBeginning_exitsBefore() {
        let canvas = pullQuoteCanvas("abc")
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart)
        canvas.insertText("\n")
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2, "the second newline at the beginning exits before the pull quote")
        guard case .paragraph(let p) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .paragraph first") }
        XCTAssertEqual(p.style, .body, "an empty body paragraph before the pull quote")
        guard case .pullQuote(let pq) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .pullQuote second") }
        XCTAssertEqual(pq.text, "abc", "no stray leading blank lines remain")
    }

    // MARK: Backspace in empty pull quote → body paragraph

    func test_pullQuote_backspaceInEmptyConvertsToBody() {
        let canvas = pullQuoteCanvas("")   // wholly-empty pull quote
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart)
        canvas.deleteBackward()
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case .paragraph(let p) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .paragraph") }
        XCTAssertEqual(p.style, .body, "Backspace in an empty pull quote converts it to a body paragraph")
    }

    // MARK: - Task 5: author-region backspace

    /// Backspace with a collapsed caret at the START of a pull quote's author line relocates the caret to the
    /// pull text's end (via `prevTextPosition`) — it never merges the author into the pull text, never deletes
    /// the pull quote. (The block-quote analogue lives in `BlockQuoteEditTests`.)
    func test_backspace_atPullQuoteAuthorStart_relocatesToPullTextEnd_neverDeletesQuote() {
        let canvas = makeCanvas()
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")],
                                               author: [TextRun(text: "Ada")]))], width: 320)
        canvas.simulateParentLayout()
        let um = UndoManager()
        canvas.undoManagerOverride = um
        let box = canvas.boxes[0] as! PullQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("pq")) }) else {
            return XCTFail("no author region")
        }
        canvas.setCaret(global: authorRegion.globalStart)   // caret at author local 0
        canvas.deleteBackward()
        guard case let .pullQuote(out) = canvas.boxes[0].currentBlock() else { return XCTFail("pull quote deleted") }
        XCTAssertEqual(out.author.map(\.text).joined(), "Ada", "author preserved")
        XCTAssertEqual(out.text, "quote", "pull text preserved")
        XCTAssertEqual(canvas.head, box.textStart + box.textLength, "caret parks at the pull quote's text end")
        // It's a pure caret RELOCATION — no content edit ran, so nothing is undoable (the pre-fix path
        // routed through a spurious `applyReplaceOutcome` inside `editing { }`, which would register an undo step).
        XCTAssertFalse(um.canUndo, "stepping out of the author must not register a content edit")
    }

    // MARK: - Task 5: entering the author region (arrow + tap)

    /// Arrow-right from the end of the pull text enters a NON-empty author region (only an EMPTY author is
    /// skipped by prev/nextTextPosition; real author content stays fully navigable).
    func test_arrowRight_intoNonEmptyPullQuoteAuthor_entersAuthorRegion() {
        let canvas = makeCanvas()
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")],
                                               author: [TextRun(text: "Ada")]))], width: 320)
        canvas.simulateParentLayout()
        let box = canvas.boxes[0] as! PullQuoteBox
        let pullEnd = box.textStart + box.textLength
        let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("pq")) })!
        XCTAssertEqual(canvas.nextTextPosition(after: pullEnd), authorRegion.globalStart,
                       "arrow-right from the pull text end enters the non-empty author region")
    }

    /// A tap in the author line's area routes to the author region (so the author is directly editable),
    /// for a NON-empty author.
    func test_tapInPullQuoteAuthorArea_nonEmpty_placesCaretInAuthor() {
        let v = laidOutCanvas([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")],
                                                    author: [TextRun(text: "Ada")]))])
        let box = v.boxes[0] as! PullQuoteBox
        let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("pq")) })!
        let p = CGPoint(x: authorRegion.canvasOrigin.x + 4, y: authorRegion.canvasOrigin.y + 4)
        let resolved = v.closestGlobalPosition(to: p)
        XCTAssertTrue(resolved >= authorRegion.globalStart && resolved <= authorRegion.globalStart + authorRegion.length,
                      "a tap in the author area must resolve into the author region")
    }

    /// A tap on the empty "Add author" placeholder routes to the (empty) author region so it can be typed.
    func test_tapInPullQuoteAuthorArea_empty_placesCaretInAuthor() {
        let v = laidOutCanvas([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")], author: []))])
        let box = v.boxes[0] as! PullQuoteBox
        let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("pq")) })!
        let p = CGPoint(x: authorRegion.canvasOrigin.x + 4, y: authorRegion.canvasOrigin.y + 4)
        XCTAssertEqual(v.closestGlobalPosition(to: p), authorRegion.globalStart,
                       "tapping the empty 'Add author' placeholder places the caret at the author region start")
    }

    // MARK: - Runtime bug: typing into an empty author leaked into the NEXT paragraph

    /// The author is a SECOND leaf region on the box (outside its primary `textStart..textStart+textLength`
    /// extent and off the block-quote child stack), so the plain `applyReplaceOutcome`/`activeStack` insert path
    /// (keyed on that primary extent) used to mis-route a collapsed-caret author insert into the FOLLOWING
    /// top-level paragraph instead of the author. This is the reported bug.
    func test_insertText_atEmptyPullQuoteAuthor_landsInAuthorNotNextParagraph() {
        let canvas = makeCanvas()
        canvas.setBlocks([
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")], author: [])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "next")])),
        ], width: 320)
        canvas.simulateParentLayout()
        let box = canvas.boxes[0] as! PullQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("pq")) }) else {
            return XCTFail("no author region")
        }
        canvas.setCaret(global: authorRegion.globalStart)
        canvas.insertText("X")
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.author.map(\.text).joined(), "X", "typed char must land in the author line")
        XCTAssertEqual(pq.text, "quote", "pull text must stay unchanged")
        guard case .paragraph(let p) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .paragraph") }
        XCTAssertEqual(p.text, "next", "the following paragraph must be unaffected by the author insert")
    }

    /// The first character typed into an EMPTY pull-quote author must be caption-styled (bold caption,
    /// 15pt) — not body-styled (17pt, non-bold), which is what the empty-region typing-attributes branch
    /// fell back to before it gained a `.quoteAuthor` case.
    func test_insertText_atEmptyPullQuoteAuthor_isCaptionStyledNotBody() {
        let canvas = makeCanvas()
        canvas.setBlocks([
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")], author: [])),
        ], width: 320)
        canvas.simulateParentLayout()
        let box = canvas.boxes[0] as! PullQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("pq")) }) else {
            return XCTFail("no author region")
        }
        canvas.setCaret(global: authorRegion.globalStart)
        canvas.insertText("X")
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        guard let run = pq.author.first else { return XCTFail("no author run") }
        XCTAssertEqual(run.text, "X")
        XCTAssertFalse(run.attributes.bold, "author bold is ambient/rendered-only — stripped on read-back")
        XCTAssertEqual(run.attributes.fontSize, 15, "author must be caption-sized (15pt), not body (17pt)")
        XCTAssertNotEqual(run.attributes.fontSize, 17)
    }

    // MARK: Typing attributes are italic/centered

    func test_pullQuote_emptyTypingAttributesAreItalic() {
        // The pull-quote typing attributes must carry an italic font so the first character typed
        // into an empty pull quote is italic, not body-upright.
        let mapper = AttributedStringMapper()
        let attrs = PullQuoteBox.pullQuoteTypingAttributes(mapper)
        guard let font = attrs[.font] as? UIFont else { return XCTFail("no font in pull-quote typing attributes") }
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic),
                      "the pull-quote typing font must be italic")
    }

    func test_pullQuote_emptyTypingAttributesAreCentered() {
        let mapper = AttributedStringMapper()
        let attrs = PullQuoteBox.pullQuoteTypingAttributes(mapper)
        guard let ps = attrs[.paragraphStyle] as? NSParagraphStyle else {
            return XCTFail("no paragraphStyle in pull-quote typing attributes")
        }
        XCTAssertEqual(ps.alignment, .center, "the pull-quote typing paragraph style must be centered")
    }

    func test_pullQuote_typingAttributesAtGlobal_returnsItalicWhenEmpty() {
        let canvas = pullQuoteCanvas("")
        let box = canvas.boxes[0]
        let attrs = canvas.typingAttributesAtGlobal(box.textStart)
        guard let font = attrs[.font] as? UIFont else { return XCTFail("no font") }
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic),
                      "typing into an empty pull quote via the canvas must return an italic font")
    }

    // MARK: - Runtime bug: selection-replace / system word-replace in the author region mis-routed

    /// `replace(_:withText:)` (the path the OS drives for autocorrect / dictation) with a range that lies
    /// entirely within the author region must land the replacement in the author — not in the following
    /// top-level paragraph. Before the fix, `applySelectionReplaceOutcome` fell through to the same-stack
    /// `applyReplaceOutcome`, which mis-resolves both endpoints (the author is a second leaf region off
    /// `activeStack`'s radar) to the next box.
    func test_replace_atPullQuoteAuthor_landsInAuthorNotNextParagraph() {
        let canvas = makeCanvas()
        canvas.setBlocks([
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")], author: [TextRun(text: "Ada")])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "next")])),
        ], width: 320)
        canvas.simulateParentLayout()
        let box = canvas.boxes[0] as! PullQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("pq")) }) else {
            return XCTFail("no author region")
        }
        let range = DocumentTextRange(DocumentTextPosition(authorRegion.globalStart),
                                       DocumentTextPosition(authorRegion.globalStart + authorRegion.length))
        canvas.replace(range, withText: "Bob")
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.author.map(\.text).joined(), "Bob", "the replacement must land in the author line")
        XCTAssertEqual(pq.text, "quote", "pull text must stay unchanged")
        guard case .paragraph(let p) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .paragraph") }
        XCTAssertEqual(p.text, "next", "the following paragraph must be unaffected by the author replace")
    }

    /// A selection-replace via `insertText` (select "Ada" then type "Bob") over a range confined to the
    /// author region must also land in the author, not the following paragraph.
    func test_selectionReplace_viaInsertText_atPullQuoteAuthor_landsInAuthorNotNextParagraph() {
        let canvas = makeCanvas()
        canvas.setBlocks([
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")], author: [TextRun(text: "Ada")])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "next")])),
        ], width: 320)
        canvas.simulateParentLayout()
        let box = canvas.boxes[0] as! PullQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("pq")) }) else {
            return XCTFail("no author region")
        }
        canvas.setSelectionForTesting(anchor: authorRegion.globalStart, head: authorRegion.globalStart + authorRegion.length)
        canvas.insertText("Bob")
        guard case .pullQuote(let pq) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .pullQuote") }
        XCTAssertEqual(pq.author.map(\.text).joined(), "Bob", "the replacement must land in the author line")
        XCTAssertEqual(pq.text, "quote", "pull text must stay unchanged")
        guard case .paragraph(let p) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .paragraph") }
        XCTAssertEqual(p.text, "next", "the following paragraph must be unaffected by the author replace")
    }

    // MARK: - Task 14: editing AROUND a pull quote (framed-atom integration)

    // A canvas laid out with real frames (needed for tap-below to get a meaningful frame.maxY).
    private func laidOutCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        c.layoutIfNeeded()
        return c
    }

    // MARK: Backspace after a pull quote

    /// Backspace at the start of an EMPTY body paragraph that follows a pull quote must remove the empty
    /// paragraph and park the caret at the pull quote's text end — not delete the pull quote itself.
    /// (Mirrors `test_backspaceAtStartOfEmptyParagraphAfterCode_removesParagraph_keepsCode` in
    /// `CanvasTrailingParagraphTests`.)
    func test_backspaceAtStartOfEmptyParagraphAfterPullQuote_removesParagraph_keepsPullQuote() {
        let pq = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote text")]))
        let v = laidOutCanvas([pq, .paragraph(ParagraphBlock(id: BlockID("p"), runs: []))])
        v.setCaret(global: v.boxes[1].textStart)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1, "the empty paragraph is removed; the pull quote is kept")
        XCTAssertTrue(v.boxes[0] is PullQuoteBox)
        XCTAssertEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength,
                       "caret parks at the pull quote's text end")
    }

    /// Backspace at the start of a NON-EMPTY body paragraph after a pull quote must keep both blocks
    /// and step the caret back into the pull quote's text end (not merge or drop either block).
    func test_backspaceAtStartOfNonEmptyParagraphAfterPullQuote_keepsBoth_movesIntoQuote() {
        let pq = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote text")]))
        let v = laidOutCanvas([pq, .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "body")]))])
        v.setCaret(global: v.boxes[1].textStart)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 2, "nothing deleted — the paragraph is non-empty")
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "body")
        XCTAssertEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength,
                       "caret moved to the pull quote's text end")
    }

    // MARK: Select-all delete (cross-block endpoint)

    /// Select-All + Backspace on [pullQuote, paragraph]: the pull quote is a fully-covered cross-block
    /// endpoint and is dropped, leaving one empty body paragraph.
    /// (Mirrors `test_crossBlockDelete_fullyCoveredCodeBlockIsDropped` in `CodeBlockEditingTests`.)
    func test_selectAll_delete_pullQuoteAndParagraph_leavesEmptyDocument() {
        let pq = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote text")]))
        let v = laidOutCanvas([pq, .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "body")]))])
        v.selectAll(nil)
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is PullQuoteBox },
                       "the fully-covered pull quote is dropped by the cross-block delete")
        XCTAssertEqual(v.boxes.count, 1, "exactly one block remains (an empty body paragraph)")
    }

    /// Select-All + Backspace on a lone pull-quote-WITH-author removes the whole block INCLUDING its author
    /// (the block is dropped wholesale — its nodeSize covers the trailing author region).
    func test_selectAll_delete_pullQuoteWithAuthor_removesQuoteAndAuthor() {
        let pq = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")],
                                          author: [TextRun(text: "Ada")]))
        let v = laidOutCanvas([pq])
        v.selectAll(nil)
        v.deleteBackward()
        XCTAssertFalse(v.boxes.contains { $0 is PullQuoteBox },
                       "the pull quote (with its author) is dropped by Select-All + delete")
        XCTAssertEqual(v.boxes.count, 1, "exactly one empty body paragraph remains")
        for b in v.currentBlocks() {
            if case .paragraph(let p) = b { XCTAssertFalse(p.text.contains("Ada"), "author text must not survive") }
        }
    }

    // MARK: Framed spacing (isFramedAtom / facingInset)

    /// Body paragraphs adjacent to a pull quote must reserve the extra external margin on the
    /// pull-quote-facing side — matching the code-block / table / collapsed-quote neighbor behavior.
    /// (Mirrors `test_codeBlockNeighbors_reserveExtraExternalMargin` in `BlockStackTests`.)
    func test_pullQuoteNeighbors_reserveExtraExternalMargin() {
        let mapper = AttributedStringMapper()
        func body(_ id: String) -> BlockBox {
            BlockBox(paragraph: ParagraphBlock(id: BlockID(id), runs: [TextRun(text: "x")]),
                     mapper: mapper, width: 300)
        }
        let pq = PullQuoteBox(pullQuote: PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")]),
                              mapper: mapper, width: 300)
        let above = body("above"), below = body("below")
        BlockStack(boxes: [above, pq, below]).layout(origin: .zero, width: 300)
        // A pull quote draws its own bounded fill, so neighbors reserve the extra external margin —
        // exactly like a code block sitting the SAME distance from its neighbors as a quote.
        XCTAssertGreaterThan(above.bottomInset, BlockBox.defaultVerticalInset,
                             "block above the pull quote must reserve the extra framed-neighbor margin")
        XCTAssertGreaterThan(below.topInset, BlockBox.defaultVerticalInset,
                             "block below the pull quote must reserve the extra framed-neighbor margin")
        XCTAssertEqual(above.topInset,
                       richTextSpacingBetweenBlocks(upper: nil, lower: .paragraph, kind: .topLevel, metrics: .default),
                       accuracy: 0.01, "far side (away from the pull quote) is the document edge gap")
    }

    // MARK: - composerSelectedRange flat-axis coverage

    /// A document with [body "ab"] + [pullQuote "cd\nef"] must contribute "ab\ncd\nef" (length 8)
    /// to the composer flat axis — mirroring the code-block test in `CodeBlockEditingTests`.
    func test_composerFlatRange_countsPullQuoteInterior() {
        let canvas = makeCanvas()
        canvas.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "ab")])),
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "cd\nef")])),
        ], width: 320)
        canvas.setCaret(global: canvas.documentSize)        // caret at very end of doc
        let flatLen = ("ab\ncd\nef" as NSString).length    // 8
        XCTAssertEqual(canvas.composerSelectedRange.location, flatLen,
                       "pull quote interior must contribute to the flat composer offset")
    }

    /// A document with ONLY a pull quote must NOT return {0,0} for composerSelectedRange:
    /// a caret at the pull quote's text end should map to the pull quote's text length.
    func test_composerFlatRange_lonePullQuote_notStuckAtZero() {
        let canvas = makeCanvas()
        canvas.setBlocks([
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "hello")])),
        ], width: 320)
        let box = canvas.boxes[0]
        canvas.setCaret(global: box.textStart + box.textLength)   // end of "hello"
        let range = canvas.composerSelectedRange
        XCTAssertEqual(range.location, 5,
                       "a lone pull quote's end-caret must map to flat offset 5, not 0")
        XCTAssertEqual(range.length, 0)
    }

    /// A caret placed INSIDE a pull quote (at some mid-text offset) round-trips through
    /// composerSelectedRange get → set → get without losing its position.
    func test_composerSelectedRange_caretInsidePullQuote_roundTrips() {
        let canvas = makeCanvas()
        canvas.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "AB")])),
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "CD")])),
        ], width: 320)
        // "AB\nCD" — caret after 'C' in the pull quote: flat offset 4 (A,B,\n,C)
        let pqBox = canvas.boxes[1]
        canvas.setCaret(global: pqBox.textStart + 1)   // after 'C' in "CD"
        let got = canvas.composerSelectedRange
        XCTAssertEqual(got, NSRange(location: 4, length: 0),
                       "caret after first char of pull quote is flat offset 4")
        // Set back and verify the global position agrees.
        canvas.composerSelectedRange = got
        XCTAssertEqual(canvas.head, pqBox.textStart + 1,
                       "setting flat offset 4 back must land at the same global position")
    }

    // MARK: - Conditional author (hidden unless the quote has content)

    func test_pullQuote_authorAppearsWhenBodyTyped_thenDisappears_caretUnmoved() {
        let canvas = makeCanvas()
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [], author: []))], width: 320)
        canvas.simulateParentLayout()
        let box = canvas.boxes[0] as! PullQuoteBox
        XCTAssertFalse(box.shouldShowAuthor)                 // fresh empty pull quote: no author
        canvas.setCaret(global: box.leafRegions()[0].globalStart)   // caret in the (empty) pull text
        canvas.insertText("x")
        XCTAssertTrue(box.shouldShowAuthor)                  // body has text → author appears
        XCTAssertEqual(box.leafRegions().count, 2)
        let caretAfterType = canvas.head
        canvas.deleteBackward()                              // remove the only body char
        XCTAssertFalse(box.shouldShowAuthor)                 // body empty again → author disappears
        XCTAssertEqual(box.leafRegions().count, 1)
        XCTAssertEqual(canvas.head, caretAfterType - 1, "caret stays in the body, unmoved by the author toggle")
    }

    // MARK: Tap-below affordance

    /// A tap below a trailing pull quote appends a new empty body paragraph.
    /// (Mirrors `test_tapBelowTrailingCodeBlock_addsBodyParagraph` in `CodeBlockEditingTests`.)
    func test_tapBelowTrailingPullQuote_addsBodyParagraph() {
        let pq = Block.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quote")]))
        let v = laidOutCanvas([pq])
        let lastMaxY = v.boxes[0].frame.maxY
        XCTAssertGreaterThan(lastMaxY, 0, "precondition: the pull quote box is laid out")
        v.performSingleTap(at: CGPoint(x: 20, y: lastMaxY + 40))
        XCTAssertEqual(v.boxes.count, 2)
        guard case let .paragraph(p) = v.boxes[1].currentBlock() else {
            return XCTFail("expected a .paragraph block after the pull quote")
        }
        XCTAssertEqual(p.style, .body,
                       "tapping below the trailing pull quote starts a body paragraph after it")
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret moves into the new paragraph")
    }
}
#endif
