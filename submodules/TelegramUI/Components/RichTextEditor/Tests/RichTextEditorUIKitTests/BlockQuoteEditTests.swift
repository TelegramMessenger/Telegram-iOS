#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit
final class BlockQuoteEditTests: XCTestCase {
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView(); c.frame = CGRect(x:0,y:0,width:320,height:400)
        c.setBlocks(blocks, width: 320); c.simulateParentLayout(); return c
    }

    /// A canvas laid out with real frames (needed for tap-point → position routing).
    private func laidOutCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        c.layoutIfNeeded()
        return c
    }

    func test_wrapInBlockQuote_wrapsTwoParagraphs() {
        let c = canvas([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "aa")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "bb")]))])
        // Select across both paragraphs using anchor/head seam (same idiom as other UIKit tests)
        c.setSelectionForTesting(anchor: 0, head: c.documentSizeValue)
        c.wrapInBlockQuote()
        let blocks = c.currentBlocks()
        XCTAssertEqual(blocks.count, 1, "both paragraphs should be wrapped into one block quote")
        guard case .blockQuote(let q) = blocks[0] else { return XCTFail("not wrapped in a block quote") }
        XCTAssertEqual(q.children.count, 2, "both paragraphs preserved as children")
        XCTAssertFalse(q.collapsed, "new block quote is expanded")
    }

    func test_wrapInBlockQuote_nestsWhenAlreadyInsideQuote() {
        let inner = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let c = canvas([.blockQuote(inner)])
        // Place caret inside the quote's child paragraph using the anchor/head seam
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart + 1
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.wrapInBlockQuote()
        let blocks = c.currentBlocks()
        guard case .blockQuote(let outer) = blocks[0] else { return XCTFail("outer block quote missing") }
        guard case .blockQuote = outer.children.first else {
            return XCTFail("did not nest — expected a block quote inside the block quote")
        }
    }

    func test_unwrapBlockQuoteLevel_level1_childrenBecomeTopLevel() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "aa")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "bb")]))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart + 1
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.unwrapBlockQuoteLevel()
        let blocks = c.currentBlocks()
        XCTAssertEqual(blocks.count, 2)                                  // children spliced to top level
        for b in blocks { if case .blockQuote = b { XCTFail("still wrapped") } }
    }

    func test_unwrapBlockQuoteLevel_nested_removesOneLevel() {
        let inner = BlockQuote(id: BlockID("in"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let outer = BlockQuote(id: BlockID("out"), children: [.blockQuote(inner)], collapsed: false)
        let c = canvas([.blockQuote(outer)])
        let outerBox = c.boxes.first as! BlockQuoteBox
        let innerBox = outerBox.children.boxes.compactMap { $0 as? BlockQuoteBox }.first!
        let pos = innerBox.children.boxes[0].leafRegions().first!.globalStart + 1
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.unwrapBlockQuoteLevel()                                           // removes the INNER level only
        let blocks = c.currentBlocks()
        guard case .blockQuote(let stillOuter) = blocks[0] else { return XCTFail("outer quote gone") }
        // inner removed → outer now directly holds the paragraph
        guard case .paragraph = stillOuter.children.first else { return XCTFail("inner level not removed") }
    }

    func test_enter_insideQuote_addsChildParagraph() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        let endOfChild = box.children.boxes[0].leafRegions().first!.globalStart + 2   // after "hi"
        c.setSelectionForTesting(anchor: endOfChild, head: endOfChild)
        c.insertText("\n")                                   // Enter (use the same seam the other Enter tests use)
        guard case .blockQuote(let q) = c.currentBlocks()[0] else { return XCTFail() }
        XCTAssertEqual(q.children.count, 2)                         // Enter added a child paragraph (still inside the quote)
    }

    /// Reported bug: in a block quote with ONE paragraph, pressing Return at the END of that paragraph
    /// (which adds an empty second line inside the quote), then Backspace, must merge the empty second
    /// line back into the first — not mis-route into the block AFTER the quote.
    func test_return_thenBackspace_loneQuoteChild_mergesEmptySecondLine_notFollowingBlock() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "text")]))
            ], collapsed: false, author: [])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart + 4   // end of "text"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.insertText("\n")                                    // Return: splits the child into ["text", ""]

        // Intermediate state: the quote now has 2 children, caret at the empty second child's start.
        XCTAssertEqual(box.children.boxes.count, 2, "Return should split the lone child into two")
        let secondRegion = box.children.boxes[1].leafRegions().first!
        XCTAssertEqual(secondRegion.length, 0, "the new second child is empty")
        XCTAssertEqual(c.head, secondRegion.globalStart, "caret at the start of the empty second child")

        c.deleteBackward()
        let doc = c.currentBlocks()
        guard case .blockQuote(let q) = doc[0] else { return XCTFail("quote gone") }
        XCTAssertEqual(q.children.count, 1, "the empty second line should have merged back into the first")
        guard case .paragraph(let onlyChild) = q.children.first else { return XCTFail("expected a paragraph child") }
        XCTAssertEqual(onlyChild.text, "text", "content preserved")
        XCTAssertEqual(c.head, box.children.boxes[0].leafRegions().first!.globalStart + 4,
                       "caret at the end of \"text\" (offset 4)")
        guard doc.count > 1, case .paragraph(let afterPara) = doc[1] else { return XCTFail("expected the following paragraph") }
        XCTAssertEqual(afterPara.text, "after", "the following paragraph must be UNCHANGED")
    }

    func test_backspace_objectReplacementRange_atNonFirstQuoteChild_mergesIntoSibling_notFollowingBlock() {
        // iOS delivers Backspace at the START of a non-first quote child NOT as a collapsed caret but as an
        // object-replacement RANGE spanning the paragraph break (previous child's end .. this child's start) —
        // observed at runtime as `sel=3..5`. It must merge into the previous sibling, NOT fall to
        // applySelectionReplaceOutcome (which mis-resolves inside the degenerate container and edited the block AFTER
        // the quote — the reported "Return then Backspace deletes from the following paragraph" bug).
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "text")])),
                .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [])),   // empty second line, as left by a Return
            ], collapsed: false, author: [])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let child1End = box.children.boxes[0].leafRegions().first!.globalStart + 4   // end of "text"
        let child2Start = box.children.boxes[1].leafRegions().first!.globalStart     // start of the empty 2nd child
        c.setSelectionForTesting(anchor: child1End, head: child2Start)   // the object-replacement range
        c.deleteBackward()

        let doc = c.currentBlocks()
        guard case .blockQuote(let q) = doc[0] else { return XCTFail("quote gone") }
        XCTAssertEqual(q.children.count, 1, "the empty second line should have merged back into the first")
        guard case .paragraph(let onlyChild) = q.children.first else { return XCTFail("expected a paragraph child") }
        XCTAssertEqual(onlyChild.text, "text", "content preserved")
        guard doc.count > 1, case .paragraph(let afterPara) = doc[1] else { return XCTFail("expected the following paragraph") }
        XCTAssertEqual(afterPara.text, "after", "the following paragraph must be UNCHANGED (was the bug)")
    }

    func test_backspace_midTextInQuoteChild_deletesInQuote_notFollowingBlock() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))
            ], collapsed: false, author: [])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let mid = box.children.boxes[0].leafRegions().first!.globalStart + 3   // caret after "hel"
        c.setSelectionForTesting(anchor: mid, head: mid)
        c.deleteBackward()   // delete the 'l' before the caret
        let doc = c.currentBlocks()
        guard case .blockQuote(let q) = doc[0], case .paragraph(let child) = q.children.first else { return XCTFail("quote gone") }
        XCTAssertEqual(child.text, "helo", "a mid-text char is deleted inside the quote")
        guard doc.count > 1, case .paragraph(let after) = doc[1] else { return XCTFail("following block gone") }
        XCTAssertEqual(after.text, "after", "the following block is UNCHANGED")
    }

    func test_selectionDelete_midTextInQuoteChild_deletesInQuote_notFollowingBlock() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello world")]))
            ], collapsed: false, author: [])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let start = box.children.boxes[0].leafRegions().first!.globalStart
        c.setSelectionForTesting(anchor: start + 5, head: start + 11)   // select " world"
        c.deleteBackward()
        let doc = c.currentBlocks()
        guard case .blockQuote(let q) = doc[0], case .paragraph(let child) = q.children.first else { return XCTFail("quote gone") }
        XCTAssertEqual(child.text, "hello", "the mid-text selection is deleted inside the quote")
        guard doc.count > 1, case .paragraph(let after) = doc[1] else { return XCTFail("following block gone") }
        XCTAssertEqual(after.text, "after", "the following block is UNCHANGED")
    }

    // MARK: - vertical arrow nav must visit every quote line + the author (no skipping)

    private func vnavLabel(_ c: DocumentCanvasView, _ pos: Int, _ box: BlockQuoteBox) -> String {
        guard let (r, _) = c.leafRegion(containingGlobal: pos) else { return "none" }
        if case .quoteAuthor = r.ref { return "author" }
        for (i, child) in box.children.boxes.enumerated() {
            if let cr = child.leafRegions().first, cr.globalStart == r.globalStart { return "l\(i + 1)" }
        }
        return "after"
    }

    private func largeAuthorSpacingCanvas() -> DocumentCanvasView {
        // A LARGE author spacing (40pt) creates a gap > step/2 between the last quote line and the author —
        // which used to stall the geometric step and escape the whole quote, skipping the author.
        let c = DocumentCanvasView()
        var qs = QuoteStyle.default; qs.authorSpacing = 40
        c.applyQuoteStyle(qs)
        c.setBlocks([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("l1"), runs: [TextRun(text: "one")])),
                .paragraph(ParagraphBlock(id: BlockID("l2"), runs: [TextRun(text: "two")])),
            ], collapsed: false, author: [TextRun(text: "the author")])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        c.layoutIfNeeded()
        return c
    }

    func test_verticalNav_largeAuthorSpacing_downVisitsAuthor_noSkip() {
        let c = largeAuthorSpacingCanvas()
        let box = c.boxes.first as! BlockQuoteBox
        var pos = box.children.boxes[0].leafRegions().first!.globalStart
        var seq: [String] = []
        for _ in 0..<4 { pos = c.verticalPosition(from: pos, down: true); seq.append(vnavLabel(c, pos, box)); if seq.last == "after" { break } }
        XCTAssertEqual(seq, ["l2", "author", "after"], "Down must visit the author even across a large author-spacing gap")
    }

    func test_verticalNav_largeAuthorSpacing_upVisitsAuthor_noSkip() {
        let c = largeAuthorSpacingCanvas()
        let box = c.boxes.first as! BlockQuoteBox
        var pos = c.boxes[1].leafRegions().first!.globalStart   // "after"
        var seq: [String] = []
        for _ in 0..<4 { pos = c.verticalPosition(from: pos, down: false); seq.append(vnavLabel(c, pos, box)); if seq.last == "l1" { break } }
        XCTAssertEqual(seq, ["author", "l2", "l1"], "Up must visit the author even across a large author-spacing gap")
    }

    func test_verticalNav_downAndUp_visitEveryQuoteLineAndAuthor_noSkips() {
        let c = laidOutCanvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("l1"), runs: [TextRun(text: "one")])),
                .paragraph(ParagraphBlock(id: BlockID("l2"), runs: [TextRun(text: "two")])),
                .paragraph(ParagraphBlock(id: BlockID("l3"), runs: [TextRun(text: "three")])),
            ], collapsed: false, author: [TextRun(text: "author")])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let l1 = box.children.boxes[0].leafRegions().first!.globalStart

        // Walk DOWN from line 1; must visit l2, l3, author, after — every line, in order.
        var pos = l1
        var down: [String] = []
        for _ in 0..<4 { pos = c.verticalPosition(from: pos, down: true); down.append(vnavLabel(c, pos, box)) }
        XCTAssertEqual(down, ["l2", "l3", "author", "after"], "Down must step through every line + author")

        // Walk UP from the following block; must visit author, l3, l2, l1 — no skips.
        let after = c.boxes[1].leafRegions().first!.globalStart
        pos = after
        var up: [String] = []
        for _ in 0..<4 { pos = c.verticalPosition(from: pos, down: false); up.append(vnavLabel(c, pos, box)) }
        XCTAssertEqual(up, ["author", "l3", "l2", "l1"], "Up must step through the author + every line")
    }

    // MARK: - Select-All → Backspace resets to a plain body paragraph

    func test_selectAll_backspace_headingFirst_resetsToBodyParagraph() {
        let c = canvas([
            .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Title")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "body")])),
        ])
        c.setSelectionForTesting(anchor: 0, head: c.documentSizeValue)
        c.deleteBackward()
        let doc = c.currentBlocks()
        XCTAssertEqual(doc.count, 1, "one block remains")
        guard case .paragraph(let p) = doc[0] else { return XCTFail("expected a paragraph") }
        XCTAssertEqual(p.style, .body, "the remaining empty block must be a BODY paragraph, not a heading")
        XCTAssertEqual(p.text, "")
    }

    func test_selectAll_backspace_quoteFirst_resetsToBodyParagraph() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "quoted")]))
            ], collapsed: false, author: [])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "body")])),
        ])
        c.setSelectionForTesting(anchor: 0, head: c.documentSizeValue)
        c.deleteBackward()
        let doc = c.currentBlocks()
        XCTAssertEqual(doc.count, 1, "one block remains")
        guard case .paragraph(let p) = doc[0] else { return XCTFail("expected a plain paragraph, not a quote") }
        XCTAssertEqual(p.style, .body)
        XCTAssertEqual(p.text, "")
    }

    // MARK: - Tab affordance for quotes (body → author end; author → out)

    private func authorRegion(_ box: BlockQuoteBox) -> LeafTextRegion {
        box.leafRegions().first { if case .quoteAuthor = $0.ref { return true } else { return false } }!
    }

    func test_tab_inQuoteBody_movesToEndOfAuthor() {
        let c = laidOutCanvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))
            ], collapsed: false, author: [TextRun(text: "Ada")])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        c.setCaret(global: box.children.boxes[0].leafRegions().first!.globalStart + 2)   // mid "hello"
        XCTAssertTrue(c.handleQuoteTabForward())
        let author = authorRegion(box)
        XCTAssertEqual(c.head, author.globalStart + author.length, "caret at the END of the author string")
    }

    func test_tab_inAuthor_movesOutToFollowingBlock() {
        let c = laidOutCanvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))
            ], collapsed: false, author: [TextRun(text: "Ada")])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        c.setCaret(global: authorRegion(box).globalStart + 1)   // mid author
        XCTAssertTrue(c.handleQuoteTabForward())
        XCTAssertEqual(c.head, c.boxes[1].leafRegions().first!.globalStart, "caret moved OUT to the following block")
    }

    func test_tab_inAuthor_noFollowingBlock_staysPut() {
        let c = laidOutCanvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))
            ], collapsed: false, author: [TextRun(text: "Ada")])),
        ])   // no block after the quote
        let box = c.boxes.first as! BlockQuoteBox
        let authorMid = authorRegion(box).globalStart + 1
        c.setCaret(global: authorMid)
        XCTAssertTrue(c.handleQuoteTabForward(), "Tab is consumed by the quote")
        XCTAssertEqual(c.head, authorMid, "no following place → caret stays in the author")
    }

    func test_tab_inTopLevelParagraph_isNotHandledByQuoteTab() {
        let c = laidOutCanvas([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "plain")]))])
        c.setCaret(global: c.boxes[0].leafRegions().first!.globalStart + 2)
        XCTAssertFalse(c.handleQuoteTabForward(), "outside a quote, quote-Tab does not consume the key")
    }

    // MARK: - resolveBox-misroute audit fixes (caret in a quote must not act on the following block)

    private func quoteThenAfter(_ afterStyle: ParagraphStyleName = .body) -> DocumentCanvasView {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hi")]))
            ], collapsed: false, author: [])),
            .paragraph(ParagraphBlock(id: BlockID("after"), style: afterStyle, runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let mid = box.children.boxes[0].leafRegions().first!.globalStart + 1   // caret inside the quote line
        c.setSelectionForTesting(anchor: mid, head: mid)
        return c
    }

    func test_insertTable_caretInQuote_isNoOp_followingBlockUntouched() {
        let c = quoteThenAfter()
        let before = c.currentBlocks().count
        c.insertTable(rows: 2, columns: 2)
        XCTAssertEqual(c.currentBlocks().count, before, "insertTable is a no-op when the caret is in a quote")
        guard case .paragraph(let after) = c.currentBlocks().last else { return XCTFail("following block changed") }
        XCTAssertEqual(after.text, "after", "the following block is untouched")
    }

    func test_insertMedia_caretInQuote_isNoOp_followingBlockUntouched() {
        let c = quoteThenAfter()
        let before = c.currentBlocks().count
        c.insertMedia(mediaID: "m", naturalSize: CGSize(width: 100, height: 100), kind: .image)
        XCTAssertEqual(c.currentBlocks().count, before, "insertMedia is a no-op when the caret is in a quote")
        guard case .paragraph(let after) = c.currentBlocks().last else { return XCTFail("following block changed") }
        XCTAssertEqual(after.text, "after", "the following block is untouched")
    }

    func test_currentState_caretInQuote_paragraphStyleReflectsQuoteChild_notFollowingBlock() {
        let c = quoteThenAfter(.heading1)   // following block is a heading; the quote line is body
        XCTAssertEqual(c.currentState().paragraphStyle, .body, "toolbar reflects the quote line's style, not the following heading")
    }

    func test_backspace_midTextRange_inQuoteChild_emptyFollowingBlock_deletesChar_notFollowingBlock() {
        // The device repro: a mid-text Backspace inside a quote line arrives as the RANGE [local0, local1]
        // (iOS delivers even a single-char backspace as a range). With an EMPTY block after the quote,
        // resolveBox(selTo) mis-resolves the in-quote position to that empty block and the atom-after handler
        // REMOVES it. It must instead delete the char inside the quote and leave the following block alone.
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "a")])),
                .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "bc")])),
                .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [TextRun(text: "d")])),
            ], collapsed: false, author: [])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [])),   // EMPTY following block
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let child1Start = box.children.boxes[1].leafRegions().first!.globalStart
        c.setSelectionForTesting(anchor: child1Start, head: child1Start + 1)   // the mid-text backspace range [local0, local1]
        c.deleteBackward()
        let doc = c.currentBlocks()
        guard case .blockQuote(let q) = doc[0] else { return XCTFail("quote gone") }
        XCTAssertEqual(q.children.count, 3, "the quote keeps all three lines")
        guard case .paragraph(let child1) = q.children[1] else { return XCTFail("middle child gone") }
        XCTAssertEqual(child1.text, "c", "the first char of the middle line is deleted")
        XCTAssertEqual(doc.count, 2, "the empty following block is NOT removed (was the bug)")
    }

    func test_backspace_objectReplacementRange_atNonFirstQuoteChild_emptyFollowingBlock_notRemoved() {
        // Same object-replacement RANGE, but the block AFTER the quote is EMPTY — the actual device repro.
        // resolveBox mis-resolves the quote-child position to that empty following block; because a BlockQuoteBox
        // IS a non-paragraph atom, the "empty paragraph after an atom" handler REMOVES the following block (no log,
        // never reaching applySelectionReplaceOutcome). It must instead merge the quote's empty 2nd line and leave the
        // following block alone.
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "text")])),
                .paragraph(ParagraphBlock(id: BlockID("p2"), runs: [])),
            ], collapsed: false, author: [])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [])),   // EMPTY following block
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let child1End = box.children.boxes[0].leafRegions().first!.globalStart + 4
        let child2Start = box.children.boxes[1].leafRegions().first!.globalStart
        c.setSelectionForTesting(anchor: child1End, head: child2Start)
        c.deleteBackward()

        let doc = c.currentBlocks()
        guard case .blockQuote(let q) = doc[0] else { return XCTFail("quote gone") }
        XCTAssertEqual(q.children.count, 1, "the empty second line should have merged back into the first")
        XCTAssertEqual(doc.count, 2, "the empty following block must NOT be removed (was the bug)")
        guard case .paragraph(let afterPara) = doc[1] else { return XCTFail("following block removed/changed") }
        XCTAssertEqual(afterPara.id, BlockID("after"), "the same following block survives, not merged away")
    }

    func test_doubleReturn_emptyTrailingChild_exitsAfterQuote() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")])),
            .paragraph(ParagraphBlock(id: BlockID("e"), runs: []))], collapsed: false)   // empty trailing child
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.children.boxes[1].leafRegions().first!.globalStart      // caret on the empty trailing child
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.insertText("\n")
        let doc = c.currentBlocks()
        XCTAssertEqual(doc.count, 2)                        // quote + a body paragraph after it
        guard case .blockQuote(let q) = doc[0] else { return XCTFail() }
        XCTAssertEqual(q.children.count, 1)                        // empty trailing child consumed
        guard case .paragraph(let after) = doc[1], after.style == .body else { return XCTFail("no body after") }
    }

    func test_backspace_emptyLoneChild_unquotes() {
        let bq = BlockQuote(id: BlockID("q"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: []))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()                                  // Backspace (same seam as other backspace tests)
        let doc = c.currentBlocks()
        for b in doc { if case .blockQuote = b { return XCTFail("still quoted") } }   // un-quoted to a plain paragraph
    }

    /// Bug 1 regression: a LONE child with CONTENT at local 0 must also un-quote on Backspace.
    /// Before the fix the branch required `child.textLength == 0`, so a lone child with content
    /// would fall through and do a normal character delete instead of removing the quote wrapper.
    func test_backspace_nonEmptyLoneChild_atStart_unquotes_preservingContent() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes.first as! BlockQuoteBox
        // Caret at local 0 (the very start of the child, before the "h")
        let pos = box.children.boxes[0].leafRegions().first!.globalStart
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        let doc = c.currentBlocks()
        // The quote wrapper is gone — children are spliced to the parent
        for b in doc { if case .blockQuote = b { return XCTFail("quote wrapper should have been removed") } }
        // Content is preserved (the text "hello" was NOT deleted)
        guard case .paragraph(let p) = doc.first else { return XCTFail("expected a body paragraph") }
        XCTAssertEqual(p.text, "hello", "content must be preserved after un-quoting the lone child")
    }

    func test_wrapInBlockQuote_insideTableCell_isNoOp() {
        // A table with one cell containing "Hello". Position the caret inside the cell and attempt to
        // wrap in a block quote — this should be a no-op (a table cellStack can't host a BlockQuoteBox).
        let cell = Cell(id: BlockID("c"), blocks: [
            .paragraph(ParagraphBlock(id: BlockID("cp"), runs: [TextRun(text: "Hello")]))])
        let table = TableBlock(id: BlockID("t"),
                               columns: [ColumnSpec(width: 300)],
                               rows: [Row(id: BlockID("r"), cells: [cell])])
        let c = canvas([.table(table)])
        // Find the cell paragraph's leaf region and place the caret inside it.
        guard let cellRegion = c.allLeafRegions().first(where: { $0.ref == .paragraph(BlockID("cp")) }) else {
            return XCTFail("cell region not found")
        }
        let pos = cellRegion.globalStart + 2
        c.setSelectionForTesting(anchor: pos, head: pos)
        let blocksBefore = c.currentBlocks()
        c.wrapInBlockQuote()
        // The document must be byte-identical to before — no block quote was created.
        XCTAssertEqual(c.currentBlocks().count, blocksBefore.count, "no new top-level block should appear")
        guard case .table(let outTable) = c.currentBlocks()[0] else { return XCTFail("table disappeared") }
        guard case .paragraph(let cellPara) = outTable.rows[0].cells[0].blocks[0] else {
            return XCTFail("cell content changed")
        }
        XCTAssertEqual(cellPara.text, "Hello", "cell content must be unchanged")
        for b in c.currentBlocks() { if case .blockQuote = b { XCTFail("block quote was created inside a table") } }
    }

    // MARK: - Task 5: author-region caret / delete / toggle

    /// A bold toggle whose selection lies entirely in a quote's author line is a no-op — the author is
    /// always-bold (ambient), so toggling must not mutate its (rendered) attributes nor dirty the model.
    func test_toggleBold_isNoOp_inAuthorRegion() {
        let c = canvas([.blockQuote(BlockQuote(id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hi")]))],
            collapsed: false, author: [TextRun(text: "Ada")]))])
        let box = c.boxes.first as! BlockQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("q")) }) else {
            return XCTFail("no author region")
        }
        // Snapshot the author's rendered attributes before the toggle.
        let before = authorRegion.layout.attributedString.copy() as! NSAttributedString
        // Select the whole author line ("Ada") and toggle bold.
        c.setSelectionForTesting(anchor: authorRegion.globalStart, head: authorRegion.globalStart + authorRegion.length)
        c.toggleBold()
        // The author's stored/rendered attributes are UNCHANGED — bold in the author region is inert.
        XCTAssertEqual(authorRegion.layout.attributedString, before,
                       "toggleBold in the author region must not mutate the author's attributes")
        // And the model author round-trips bold-free (ambient bold is stripped on read-back).
        guard case let .blockQuote(out) = box.currentBlock() else { return XCTFail() }
        XCTAssertTrue(out.author.allSatisfy { $0.attributes.bold == false })
    }

    /// Backspace with a collapsed caret at the START (local 0) of a quote's author line relocates the caret
    /// to the end of the quote's last child (recursive via `prevTextPosition`) — it never merges the author
    /// into the body and never deletes the quote.
    func test_backspace_atAuthorStart_relocatesToEndOfLastChild_neverDeletesQuote() {
        let c = canvas([.blockQuote(BlockQuote(id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "body")]))],
            collapsed: false, author: [TextRun(text: "Ada")]))])
        let box = c.boxes.first as! BlockQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("q")) }) else {
            return XCTFail("no author region")
        }
        c.setSelectionForTesting(anchor: authorRegion.globalStart, head: authorRegion.globalStart)   // caret at author local 0
        c.deleteBackward()
        // Quote still present, author intact, caret now at the end of the body child.
        guard case let .blockQuote(out) = box.currentBlock() else { return XCTFail("quote deleted") }
        XCTAssertEqual(out.author.map(\.text).joined(), "Ada")
        XCTAssertEqual(out.children.count, 1)
        let bodyRegion = box.leafRegions().first(where: { $0.ref == .paragraph(BlockID("p")) })!
        XCTAssertEqual(c.head, bodyRegion.globalStart + bodyRegion.length)   // end of last child
    }

    /// Arrow-right from the end of a block quote's last child enters a NON-empty author region.
    func test_arrowRight_intoNonEmptyBlockQuoteAuthor_entersAuthorRegion() {
        let c = canvas([.blockQuote(BlockQuote(id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "body")]))],
            collapsed: false, author: [TextRun(text: "Ada")]))])
        let box = c.boxes.first as! BlockQuoteBox
        let childRegion = box.children.boxes[0].leafRegions().first!
        let childEnd = childRegion.globalStart + childRegion.length
        let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("q")) })!
        XCTAssertEqual(c.nextTextPosition(after: childEnd), authorRegion.globalStart,
                       "arrow-right from the last child's end enters the non-empty author region")
    }

    /// A tap in a block quote's author line area routes to the author region (directly editable).
    func test_tapInBlockQuoteAuthorArea_placesCaretInAuthor() {
        let v = laidOutCanvas([.blockQuote(BlockQuote(id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "body")]))],
            collapsed: false, author: [TextRun(text: "Ada")]))])
        let box = v.boxes.first as! BlockQuoteBox
        let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("q")) })!
        let p = CGPoint(x: authorRegion.canvasOrigin.x + 4, y: authorRegion.canvasOrigin.y + 4)
        let resolved = v.closestGlobalPosition(to: p)
        XCTAssertTrue(resolved >= authorRegion.globalStart && resolved <= authorRegion.globalStart + authorRegion.length,
                      "a tap in the block-quote author area must resolve into the author region")
    }

    /// Select-All + Backspace on a block-quote-WITH-author removes the whole quote INCLUDING its author
    /// (the quote's nodeSize covers the trailing author region), leaving an empty document.
    func test_selectAll_delete_blockQuoteWithAuthor_removesQuoteAndAuthor() {
        let c = canvas([.blockQuote(BlockQuote(id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "body")]))],
            collapsed: false, author: [TextRun(text: "Ada")]))])
        c.selectAllText()
        c.deleteBackward()
        XCTAssertFalse(c.boxes.contains { $0 is BlockQuoteBox },
                       "the block quote (with its author) is removed by Select-All + delete")
        let joined = c.currentBlocks().compactMap { block -> String? in
            if case .paragraph(let p) = block { return p.text } else { return nil }
        }.joined()
        XCTAssertFalse(joined.contains("Ada"), "author text must not survive")
        XCTAssertFalse(joined.contains("body"), "body text must not survive")
    }

    /// The OS delivers Backspace at author-start as an object-replacement RANGE (anchored at the previous
    /// child's text end, head at the author start) rather than a collapsed caret. That range spans only the
    /// structural slots before the author, so it is collapsed to a caret and relocated exactly like the
    /// collapsed-caret form — the quote/author survive and nothing is edited.
    func test_backspace_authorStartObjectReplacementRange_relocatesWithoutEditing() {
        let c = canvas([.blockQuote(BlockQuote(id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "body")]))],
            collapsed: false, author: [TextRun(text: "Ada")]))])
        let um = UndoManager(); c.undoManagerOverride = um
        let box = c.boxes.first as! BlockQuoteBox
        let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("q")) })!
        let bodyRegion = box.children.boxes[0].leafRegions().first!
        let bodyEnd = bodyRegion.globalStart + bodyRegion.length
        // Object-replacement RANGE: anchor at the previous child's text end, head at the author start.
        c.setSelectionForTesting(anchor: bodyEnd, head: authorRegion.globalStart)
        c.deleteBackward()
        guard case let .blockQuote(out) = box.currentBlock() else { return XCTFail("quote deleted") }
        XCTAssertEqual(out.author.map(\.text).joined(), "Ada", "author preserved")
        XCTAssertEqual(out.children.count, 1)
        XCTAssertEqual(c.head, bodyEnd, "caret relocates to the end of the last child")
        XCTAssertFalse(um.canUndo, "the RANGE form relocates without registering a content edit")
    }

    /// Runtime bug: the author is a SECOND leaf region on the box (outside its primary child stack), so
    /// the plain `applyReplaceOutcome`/`activeStack` insert path used to mis-route a collapsed-caret author
    /// insert into the FOLLOWING top-level paragraph instead of the author.
    func test_insertText_atEmptyBlockQuoteAuthor_landsInAuthorNotNextParagraph() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"),
                children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "body")]))],
                collapsed: false, author: [])),
            .paragraph(ParagraphBlock(id: BlockID("next"), runs: [TextRun(text: "next")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("q")) }) else {
            return XCTFail("no author region")
        }
        c.setSelectionForTesting(anchor: authorRegion.globalStart, head: authorRegion.globalStart)   // caret at author local 0
        c.insertText("X")
        guard case let .blockQuote(out) = box.currentBlock() else { return XCTFail("expected .blockQuote") }
        XCTAssertEqual(out.author.map(\.text).joined(), "X", "typed char must land in the author line")
        XCTAssertEqual(out.children.count, 1, "the quote's children must be unchanged")
        guard case .paragraph(let p) = out.children.first else { return XCTFail("expected a paragraph child") }
        XCTAssertEqual(p.text, "body", "the quote's child paragraph must be unchanged")
        guard case .paragraph(let next) = c.currentBlocks()[1] else { return XCTFail("expected the following paragraph") }
        XCTAssertEqual(next.text, "next", "the following paragraph must be unaffected by the author insert")
    }

    /// Runtime bug: a selection-replace (select "Ada" then type "Bob") confined to a block quote's author
    /// region must land the replacement in the author — not in the following top-level paragraph. Mirrors
    /// `test_selectionReplace_viaInsertText_atPullQuoteAuthor_landsInAuthorNotNextParagraph`.
    func test_selectionReplace_viaInsertText_atBlockQuoteAuthor_landsInAuthorNotNextParagraph() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"),
                children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "body")]))],
                collapsed: false, author: [TextRun(text: "Ada")])),
            .paragraph(ParagraphBlock(id: BlockID("next"), runs: [TextRun(text: "next")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("q")) }) else {
            return XCTFail("no author region")
        }
        c.setSelectionForTesting(anchor: authorRegion.globalStart, head: authorRegion.globalStart + authorRegion.length)
        c.insertText("Bob")
        guard case let .blockQuote(out) = box.currentBlock() else { return XCTFail("expected .blockQuote") }
        XCTAssertEqual(out.author.map(\.text).joined(), "Bob", "the replacement must land in the author line")
        XCTAssertEqual(out.children.count, 1, "the quote's children must be unchanged")
        guard case .paragraph(let p) = out.children.first else { return XCTFail("expected a paragraph child") }
        XCTAssertEqual(p.text, "body", "the quote's child paragraph must be unchanged")
        guard case .paragraph(let next) = c.currentBlocks()[1] else { return XCTFail("expected the following paragraph") }
        XCTAssertEqual(next.text, "next", "the following paragraph must be unaffected by the author replace")
    }

    // MARK: - Author appears/disappears live with content (Task 2)

    func test_blockQuote_authorAppearsWhenBodyTyped_thenDisappears_caretUnmoved() {
        let c = canvas([.blockQuote(BlockQuote(id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: []))], collapsed: false, author: []))])
        let box = c.boxes[0] as! BlockQuoteBox
        XCTAssertFalse(box.shouldShowAuthor)
        let bodyStart = box.leafRegions()[0].globalStart
        c.setCaret(global: bodyStart)   // caret in the empty body paragraph
        c.insertText("x")
        XCTAssertTrue(box.shouldShowAuthor)
        let caretAfterType = c.head
        // Select the just-typed "x" and delete it via a RANGE (rather than a collapsed-caret Backspace,
        // which — independent of this feature — hits a pre-existing `resolveBox` limitation for a lone
        // top-level container box; see the Task 2 report). The selection-replace path correctly resolves
        // into the quote's child via `activeStack`/`leafRegions()`.
        c.setSelectionForTesting(anchor: bodyStart, head: caretAfterType)
        c.deleteBackward()
        XCTAssertFalse(box.shouldShowAuthor)
        XCTAssertEqual(c.head, bodyStart, "caret stays in the body, unmoved by the author toggle")
    }

    /// When a block quote's body is emptied, its (empty) author region is removed and the caret — which
    /// legitimately ends in the now-empty body after the selection-delete — remains a valid position in
    /// that body paragraph. No stale-caret snap code is needed: emptying the body REQUIRES a caret/selection
    /// in the body (as here), so a caret literally stranded inside the author cannot coexist with an empty
    /// body; any purely-programmatic out-of-range caret is already covered by the existing `clampGlobal`.
    func test_blockQuote_authorRemovedOnBodyEmptied_caretLandsInBody() {
        let c = canvas([.blockQuote(BlockQuote(id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))],
            collapsed: false, author: []))])
        let box = c.boxes[0] as! BlockQuoteBox
        XCTAssertTrue(box.shouldShowAuthor)   // author shown, because the body has "ab"
        // Empty the body via a selection-replace covering the body text (the caret legitimately ends in the
        // body). A collapsed-caret `deleteBackward()` is deliberately NOT used here — a pre-existing (not
        // this-feature) `resolveBox` limitation no-ops a collapsed-caret backspace inside a lone container box;
        // see the Task 2 report / `test_blockQuote_authorAppearsWhenBodyTyped_thenDisappears_caretUnmoved` above.
        let bodyRegion = box.children.boxes[0].leafRegions().first!
        c.setSelectionForTesting(anchor: bodyRegion.globalStart, head: bodyRegion.globalStart + bodyRegion.length)   // "ab"
        c.insertText("")   // delete the selection → body empty → author hides
        // 1. The author region is genuinely GONE.
        XCTAssertFalse(box.shouldShowAuthor)
        XCTAssertTrue(box.leafRegions().allSatisfy {
            if case .quoteAuthor = $0.ref { return false } else { return true }
        }, "no .quoteAuthor region may remain once the body is empty")
        // 2. The caret is valid AND lands in the BODY paragraph, not the removed author.
        guard let (region, _) = c.leafRegion(containingGlobal: c.head) else {
            return XCTFail("caret must resolve to a real region after the author is removed")
        }
        XCTAssertEqual(region.ref, .paragraph(BlockID("p")), "caret must land in the body paragraph")
        // 3. The caret is within the document.
        XCTAssertLessThanOrEqual(c.head, c.documentSizeValue)
    }

    func test_editorState_blockQuoteDepth() {
        let inner = BlockQuote(id: BlockID("in"), children: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hi")]))], collapsed: false)
        let outer = BlockQuote(id: BlockID("out"), children: [.blockQuote(inner)], collapsed: false)
        let c = canvas([.paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "x")])), .blockQuote(outer)])
        // caret in the top-level paragraph → depth 0
        let topPos = c.boxes[0].leafRegions().first!.globalStart
        c.setSelectionForTesting(anchor: topPos, head: topPos)
        XCTAssertEqual(c.blockQuoteDepth(at: c.head), 0)
        // caret inside the doubly-nested paragraph → depth 2
        let outerBox = c.boxes[1] as! BlockQuoteBox
        let innerBox = outerBox.children.boxes.compactMap { $0 as? BlockQuoteBox }.first!
        let deep = innerBox.children.boxes[0].leafRegions().first!.globalStart + 1
        c.setSelectionForTesting(anchor: deep, head: deep)
        XCTAssertEqual(c.blockQuoteDepth(at: c.head), 2)
    }

    // MARK: - Bug repro: collapsed-caret Backspace with text before it inside a block quote

    /// Collapsed-caret Backspace at the END of a lone block quote's body must delete the last character —
    /// not silently no-op. `resolveBox(at:)` can't resolve a position inside the container (its
    /// `textLength == 0`; the real text lives in the child, found via `leafRegions()`), so without a
    /// block-quote-aware branch this falls through to the container-degenerate-range fallback and does
    /// nothing.
    func test_backspace_collapsedCaret_loneBlockQuote_deletesLastCharOfBody() {
        let c = canvas([.blockQuote(BlockQuote(id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))],
            collapsed: false, author: []))])
        let box = c.boxes[0] as! BlockQuoteBox
        let pos = box.leafRegions()[0].globalStart + 2   // end of "ab"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        guard case .blockQuote(let out) = box.currentBlock() else { return XCTFail("quote gone") }
        guard case .paragraph(let p) = out.children.first else { return XCTFail("expected a paragraph child") }
        XCTAssertEqual(p.text, "a", "backspace at the end of the quote body must delete one character")
    }

    /// Same bug, but with a block AFTER the quote: a collapsed-caret Backspace at the end of the quote's
    /// body must delete from the body — not mis-route to (or merge with) the following top-level paragraph.
    func test_backspace_collapsedCaret_blockQuoteFollowedByParagraph_deletesInBodyNotFollowingParagraph() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"),
                children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))],
                collapsed: false, author: [])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes[0] as! BlockQuoteBox
        let pos = box.leafRegions()[0].globalStart + 2   // end of "ab"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        guard case .blockQuote(let out) = box.currentBlock() else { return XCTFail("quote gone") }
        guard case .paragraph(let p) = out.children.first else { return XCTFail("expected a paragraph child") }
        XCTAssertEqual(p.text, "a", "backspace must delete from the quote body")
        guard case .paragraph(let after) = c.currentBlocks()[1] else { return XCTFail("expected the following paragraph") }
        XCTAssertEqual(after.text, "after", "the following paragraph must be unaffected")
    }

    /// Checks whether the author line has the SAME bug: collapsed-caret Backspace at the END of a non-empty
    /// author must delete the author's last character (distinct from the already-covered `local == 0`
    /// author-start relocation branch, which never touches this `local > 0` case).
    func test_backspace_collapsedCaret_atEndOfNonEmptyAuthor_deletesLastCharOfAuthor() {
        let c = canvas([.blockQuote(BlockQuote(id: BlockID("q"),
            children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))],
            collapsed: false, author: [TextRun(text: "Ada")]))])
        let box = c.boxes[0] as! BlockQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("q")) }) else {
            return XCTFail("no author region")
        }
        let pos = authorRegion.globalStart + authorRegion.length   // end of "Ada"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        guard case .blockQuote(let out) = box.currentBlock() else { return XCTFail("quote gone") }
        XCTAssertEqual(out.author.map(\.text).joined(), "Ad",
                       "backspace at the end of a non-empty author must delete one character")
    }

    // MARK: - Bug repro: Return in a quote AUTHOR line must split like a media caption

    /// Return at the END of a block quote's author must NOT insert a newline into the following
    /// sibling block — it must split the author (whole text stays as author) and drop a NEW empty
    /// body paragraph immediately after the quote, caret there. Before the fix, `insertText("\n")`
    /// routed through `insertParagraphBreak`'s general path (the author-aware branch sits after the
    /// `"\n"` dispatch and is never reached), whose `activeStack`/`resolveBox` can't resolve an author
    /// position and mis-routes the break into the FOLLOWING top-level paragraph ("after").
    func test_return_atEndOfBlockQuoteAuthor_splitsAuthor_newBodyParagraphAfterQuote() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"),
                children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))],
                collapsed: false, author: [TextRun(text: "Ada Lovelace")])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("q")) }) else {
            return XCTFail("no author region")
        }
        let pos = authorRegion.globalStart + authorRegion.length   // end of "Ada Lovelace"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.insertText("\n")
        let doc = c.currentBlocks()
        XCTAssertEqual(doc.count, 3, "quote + new empty body paragraph + the untouched following paragraph")
        guard case .blockQuote(let q) = doc[0] else { return XCTFail("expected the quote first") }
        XCTAssertEqual(q.author.map(\.text).joined(), "Ada Lovelace", "author text unchanged")
        guard case .paragraph(let inserted) = doc[1] else { return XCTFail("expected a new body paragraph after the quote") }
        XCTAssertEqual(inserted.text, "", "the new paragraph is empty (caret was at author end)")
        XCTAssertEqual(inserted.style, .body)
        guard case .paragraph(let afterPara) = doc[2] else { return XCTFail("expected the original following paragraph") }
        XCTAssertEqual(afterPara.text, "after", "the following paragraph must be untouched")
        // Caret lands at the start of the new paragraph.
        let newBox = c.boxes[1] as! BlockBox
        XCTAssertEqual(c.head, newBox.textStart)
    }

    /// Same, but the caret sits MID-author ("Ada" | " Lovelace"): the head half stays as the author,
    /// the tail half becomes the new body paragraph after the quote.
    func test_return_midBlockQuoteAuthor_splitsAtCaret_tailBecomesNewBodyParagraph() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"),
                children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))],
                collapsed: false, author: [TextRun(text: "Ada Lovelace")])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("q")) }) else {
            return XCTFail("no author region")
        }
        let pos = authorRegion.globalStart + 3   // after "Ada"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.insertText("\n")
        let doc = c.currentBlocks()
        XCTAssertEqual(doc.count, 3)
        guard case .blockQuote(let q) = doc[0] else { return XCTFail("expected the quote first") }
        XCTAssertEqual(q.author.map(\.text).joined(), "Ada", "head half stays as the author")
        guard case .paragraph(let inserted) = doc[1] else { return XCTFail("expected a new body paragraph after the quote") }
        XCTAssertEqual(inserted.text, " Lovelace", "tail half becomes the new paragraph")
        guard case .paragraph(let afterPara) = doc[2] else { return XCTFail("expected the original following paragraph") }
        XCTAssertEqual(afterPara.text, "after", "the following paragraph must be untouched")
        let newBox = c.boxes[1] as! BlockBox
        XCTAssertEqual(c.head, newBox.textStart, "caret at the start of the new paragraph")
    }

    /// Same behavior for a PULL quote's author line.
    func test_return_atEndOfPullQuoteAuthor_splitsAuthor_newBodyParagraphAfterQuote() {
        let c = canvas([
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Quote")], author: [TextRun(text: "Ada")])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! PullQuoteBox
        guard let authorRegion = box.leafRegions().first(where: { $0.ref == .quoteAuthor(BlockID("pq")) }) else {
            return XCTFail("no author region")
        }
        let pos = authorRegion.globalStart + authorRegion.length   // end of "Ada"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.insertText("\n")
        let doc = c.currentBlocks()
        XCTAssertEqual(doc.count, 3, "pull quote + new empty body paragraph + the untouched following paragraph")
        guard case .pullQuote(let pq) = doc[0] else { return XCTFail("expected the pull quote first") }
        XCTAssertEqual(pq.author.map(\.text).joined(), "Ada", "author text unchanged")
        guard case .paragraph(let inserted) = doc[1] else { return XCTFail("expected a new body paragraph after the pull quote") }
        XCTAssertEqual(inserted.text, "", "the new paragraph is empty (caret was at author end)")
        guard case .paragraph(let afterPara) = doc[2] else { return XCTFail("expected the original following paragraph") }
        XCTAssertEqual(afterPara.text, "after", "the following paragraph must be untouched")
        let newBox = c.boxes[1] as! BlockBox
        XCTAssertEqual(c.head, newBox.textStart)
    }

    /// REGRESSION: Return inside a quote's BODY (a child paragraph, not the author) must still split INSIDE
    /// the quote (adds a child paragraph) — not exit the quote, and not touch the author or the following
    /// sibling block. Guards that the new author-aware Return branch above only fires for a caret actually
    /// IN the author region.
    func test_return_insideBlockQuoteBody_stillSplitsInsideQuote_notAfter() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"),
                children: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "ab")]))],
                collapsed: false, author: [TextRun(text: "Ada")])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let bodyRegion = box.children.boxes[0].leafRegions().first!
        let pos = bodyRegion.globalStart + 1   // between "a" and "b"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.insertText("\n")
        let doc = c.currentBlocks()
        XCTAssertEqual(doc.count, 2, "quote (now with 2 children) + the untouched following paragraph")
        guard case .blockQuote(let q) = doc[0] else { return XCTFail("expected the quote first") }
        XCTAssertEqual(q.children.count, 2, "Return split the body into two children, still inside the quote")
        XCTAssertEqual(q.author.map(\.text).joined(), "Ada", "author untouched")
        guard case .paragraph(let after) = doc[1] else { return XCTFail("expected the following paragraph") }
        XCTAssertEqual(after.text, "after", "the following paragraph must be untouched")
    }

    // MARK: - Bug repro: Backspace at the START of an EMPTY first child in a MULTI-child quote

    /// Reported bug: Backspace at the start of a block quote's EMPTY first line, when the quote has MORE
    /// children after it, must remove that empty first line — not mis-route to (and delete from) the
    /// FOLLOWING top-level block. `resolveBox` cannot resolve a local-0 position inside the degenerate
    /// container and falls back to the following sibling; the fix intercepts this via `activeStack` before
    /// that fallback runs.
    func test_backspace_emptyFirstChild_multiChildQuote_removesEmptyLine_notFollowingBlock() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("empty"), runs: [])),
                .paragraph(ParagraphBlock(id: BlockID("second"), runs: [TextRun(text: "second")])),
            ], collapsed: false)),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.leafRegions().first!.globalStart   // start of the empty first child (local 0)
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        let doc = c.currentBlocks()
        guard case .blockQuote(let q) = doc[0] else { return XCTFail("quote gone") }
        XCTAssertEqual(q.children.count, 1, "the empty first line should be removed")
        guard case .paragraph(let onlyChild) = q.children.first else { return XCTFail("expected a paragraph child") }
        XCTAssertEqual(onlyChild.text, "second", "the remaining child is the former second child")
        let newFirstRegion = box.children.boxes.first!.leafRegions().first!
        XCTAssertEqual(c.head, newFirstRegion.globalStart, "caret at the start of the (now only) child")
        guard doc.count > 1, case .paragraph(let afterPara) = doc[1] else { return XCTFail("expected the following paragraph") }
        XCTAssertEqual(afterPara.text, "after", "the following paragraph must be UNCHANGED")
    }

    /// Sibling case (also fixed): Backspace at the START of a NON-first, non-empty child merges it into
    /// its previous sibling within the quote — the following top-level block must stay unaffected.
    func test_backspace_secondChildStart_multiChildQuote_mergesIntoPreviousSibling() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("one"), runs: [TextRun(text: "one")])),
                .paragraph(ParagraphBlock(id: BlockID("two"), runs: [TextRun(text: "two")])),
            ], collapsed: false)),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "after")])),
        ])
        let box = c.boxes.first as! BlockQuoteBox
        let pos = box.children.boxes[1].leafRegions().first!.globalStart   // start of "two"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        let doc = c.currentBlocks()
        guard case .blockQuote(let q) = doc[0] else { return XCTFail("quote gone") }
        XCTAssertEqual(q.children.count, 1, "the two children should have merged into one")
        guard case .paragraph(let merged) = q.children.first else { return XCTFail("expected a paragraph child") }
        XCTAssertEqual(merged.text, "onetwo", "the children merge into one paragraph")
        XCTAssertEqual(c.head, box.children.boxes[0].leafRegions().first!.globalStart + 3,
                       "caret at the join (offset 3, len(\"one\"))")
        guard doc.count > 1, case .paragraph(let afterPara) = doc[1] else { return XCTFail("expected the following paragraph") }
        XCTAssertEqual(afterPara.text, "after", "the following paragraph must be UNCHANGED")
    }

    // MARK: - Backspace at the START of a NON-empty FIRST child of a multi-child quote → un-quote that line

    /// Case 1a: a preceding top-level block, then a quote whose first child is NON-empty and has a sibling
    /// after it. Backspace at the very start of the first child extracts it as a plain top-level paragraph
    /// immediately BEFORE the quote; the remaining children stay quoted; the preceding block is untouched.
    func test_backspace_nonEmptyFirstChild_multiChildQuote_unquotesLine_precededByBlock() {
        let c = canvas([
            .paragraph(ParagraphBlock(id: BlockID("intro"), runs: [TextRun(text: "Intro")])),
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("first"), runs: [TextRun(text: "First")])),
                .paragraph(ParagraphBlock(id: BlockID("second"), runs: [TextRun(text: "Second")])),
            ], collapsed: false)),
        ])
        let box = c.boxes[1] as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart   // start of "First"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        let doc = c.currentBlocks()
        XCTAssertEqual(doc.count, 3, "Intro, un-quoted First, and the quote (now just Second)")
        guard case .paragraph(let intro) = doc[0] else { return XCTFail("Intro missing") }
        XCTAssertEqual(intro.text, "Intro", "preceding block unchanged")
        guard case .paragraph(let first) = doc[1] else { return XCTFail("expected First as a plain top-level paragraph") }
        XCTAssertEqual(first.text, "First")
        XCTAssertEqual(first.style, .body, "un-quoted line is a plain body paragraph")
        guard case .blockQuote(let q) = doc[2] else { return XCTFail("expected the quote to survive") }
        XCTAssertEqual(q.children.count, 1)
        guard case .paragraph(let second) = q.children.first else { return XCTFail("expected Second still quoted") }
        XCTAssertEqual(second.text, "Second")
        // Caret at the start of the newly un-quoted "First" paragraph.
        let newBox = c.boxes[1] as! BlockBox
        XCTAssertEqual(c.head, newBox.textStart)
    }

    /// Case 1b: same, but the quote is the document's FIRST block (no preceding top-level block).
    func test_backspace_nonEmptyFirstChild_multiChildQuote_unquotesLine_quoteIsFirstBlock() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("first"), runs: [TextRun(text: "First")])),
                .paragraph(ParagraphBlock(id: BlockID("second"), runs: [TextRun(text: "Second")])),
            ], collapsed: false)),
        ])
        let box = c.boxes[0] as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart   // start of "First"
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        let doc = c.currentBlocks()
        XCTAssertEqual(doc.count, 2, "un-quoted First, then the quote (now just Second)")
        guard case .paragraph(let first) = doc[0] else { return XCTFail("expected First as a plain top-level paragraph") }
        XCTAssertEqual(first.text, "First")
        guard case .blockQuote(let q) = doc[1] else { return XCTFail("expected the quote to survive") }
        XCTAssertEqual(q.children.count, 1)
        guard case .paragraph(let second) = q.children.first else { return XCTFail("expected Second still quoted") }
        XCTAssertEqual(second.text, "Second")
        let newBox = c.boxes[0] as! BlockBox
        XCTAssertEqual(c.head, newBox.textStart)
    }

    /// Case 1, NESTED: the quote sits inside an outer quote. Un-quoting the first child moves it up ONE
    /// level only — it becomes a direct child of the OUTER quote, not a top-level paragraph.
    func test_backspace_nonEmptyFirstChild_nestedQuote_unquotesIntoOuterQuoteLevel() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("outer"), children: [
                .paragraph(ParagraphBlock(id: BlockID("lead"), runs: [TextRun(text: "Lead")])),
                .blockQuote(BlockQuote(id: BlockID("inner"), children: [
                    .paragraph(ParagraphBlock(id: BlockID("first"), runs: [TextRun(text: "First")])),
                    .paragraph(ParagraphBlock(id: BlockID("second"), runs: [TextRun(text: "Second")])),
                ], collapsed: false)),
            ], collapsed: false)),
        ])
        let outerBox = c.boxes[0] as! BlockQuoteBox
        let innerBox = outerBox.children.boxes.compactMap { $0 as? BlockQuoteBox }.first!
        let pos = innerBox.children.boxes[0].leafRegions().first!.globalStart
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        guard case .blockQuote(let outer) = c.currentBlocks()[0] else { return XCTFail("outer quote gone") }
        XCTAssertEqual(outer.children.count, 3, "Lead, un-quoted First (now at the outer level), inner quote (now just Second)")
        guard case .paragraph(let lead) = outer.children[0] else { return XCTFail() }
        XCTAssertEqual(lead.text, "Lead")
        guard case .paragraph(let first) = outer.children[1] else { return XCTFail("expected First spliced into the OUTER quote") }
        XCTAssertEqual(first.text, "First")
        guard case .blockQuote(let inner) = outer.children[2] else { return XCTFail("expected inner quote to survive") }
        XCTAssertEqual(inner.children.count, 1)
        guard case .paragraph(let second) = inner.children.first else { return XCTFail() }
        XCTAssertEqual(second.text, "Second")
    }

    // MARK: - Backspace at the START of a LIST-ITEM child of a block quote → peel one list level in place

    /// Case 2: a list item that is a CHILD of a block quote. A NESTED item (level > 0) outdents by one
    /// level and stays a list item, still inside the quote; a further Backspace at level 0 breaks the list
    /// (plain paragraph), still inside the quote — the quote itself is untouched by either step (peeling
    /// the list is not the same as un-quoting).
    func test_backspace_listItemChildOfQuote_nestedLevel_outdentsThenBreaksList_stayingInQuote() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("item"), list: ListMembership(marker: .bullet, level: 1),
                                          runs: [TextRun(text: "item")])),
                .paragraph(ParagraphBlock(id: BlockID("next"), runs: [TextRun(text: "next")])),
            ], collapsed: false)),
        ])
        let box = c.boxes[0] as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart   // start of the list item
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        var doc = c.currentBlocks()
        guard case .blockQuote(let q1) = doc[0] else { return XCTFail("quote gone after first backspace") }
        guard case .paragraph(let item1) = q1.children.first else { return XCTFail() }
        XCTAssertEqual(item1.list?.level, 0, "list level decremented to 0")
        XCTAssertEqual(item1.list?.marker, .bullet, "still a list item")
        XCTAssertEqual(item1.text, "item", "content unchanged")
        XCTAssertEqual(q1.children.count, 2, "still quoted, still 2 children")

        // A SECOND Backspace at the (still level-0) item start now breaks the list.
        let box2 = c.boxes[0] as! BlockQuoteBox
        let pos2 = box2.children.boxes[0].leafRegions().first!.globalStart
        c.setSelectionForTesting(anchor: pos2, head: pos2)
        c.deleteBackward()
        doc = c.currentBlocks()
        guard case .blockQuote(let q2) = doc[0] else { return XCTFail("quote gone after second backspace") }
        guard case .paragraph(let item2) = q2.children.first else { return XCTFail() }
        XCTAssertNil(item2.list, "list membership cleared — plain paragraph")
        XCTAssertEqual(item2.style, .body)
        XCTAssertEqual(item2.text, "item", "content unchanged")
        XCTAssertEqual(q2.children.count, 2, "still quoted (peeling the list does not un-quote)")
    }

    /// Case 2, TOP-LEVEL list level: a quoted list item that starts at level 0 breaks straight to a plain
    /// paragraph on the FIRST Backspace (no intermediate outdent step, since there is no level to cancel).
    func test_backspace_listItemChildOfQuote_topLevel_breaksListImmediately() {
        let c = canvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("item"), list: ListMembership(marker: .ordered, level: 0),
                                          runs: [TextRun(text: "item")])),
                .paragraph(ParagraphBlock(id: BlockID("next"), runs: [TextRun(text: "next")])),
            ], collapsed: false)),
        ])
        let box = c.boxes[0] as! BlockQuoteBox
        let pos = box.children.boxes[0].leafRegions().first!.globalStart
        c.setSelectionForTesting(anchor: pos, head: pos)
        c.deleteBackward()
        let doc = c.currentBlocks()
        guard case .blockQuote(let q) = doc[0] else { return XCTFail("quote gone") }
        guard case .paragraph(let item) = q.children.first else { return XCTFail() }
        XCTAssertNil(item.list, "list membership cleared on the very first backspace at level 0")
        XCTAssertEqual(item.style, .body)
        XCTAssertEqual(item.text, "item")
        XCTAssertEqual(q.children.count, 2, "still quoted")
    }
}
#endif
