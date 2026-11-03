#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

/// Double-return (Enter on an empty line inside a code block) exits the block: trailing/empty line →
/// after, first line → before, wholly-empty → un-code. The triggering empty line is removed.
/// Shift+Return special handling is gone.
@available(iOS 13.0, *)
final class DoubleReturnExitTests: XCTestCase {
    private func makeCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        return c
    }
    private func style(_ box: CanvasBlock) -> ParagraphStyleName? { (box as? BlockBox)?.style }
    private func bodyListItem(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .body, list: ListMembership(marker: .bullet),
                                  runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func list(_ box: CanvasBlock) -> ListMembership? { (box as? BlockBox)?.listMembership }

    func test_plainList_emptyItemReturn_endsIntoBodyParagraph_unchanged() {
        // A plain (non-quote) list: an empty item + Return ends into body.
        let canvas = makeCanvas([bodyListItem("l1", "A"), bodyListItem("l2", "")])
        canvas.setCaret(global: canvas.boxes[1].textStart)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        XCTAssertEqual(style(canvas.boxes[1]), .body, "a plain empty list item ends into a body paragraph")
        XCTAssertNil(list(canvas.boxes[1]))
    }

    // MARK: Shift+Return removed

    func test_shiftReturn_keyCommandRemoved() {
        let canvas = DocumentCanvasView()
        let hasShiftReturn = (canvas.keyCommands ?? []).contains { $0.input == "\r" && $0.modifierFlags == .shift }
        XCTAssertFalse(hasShiftReturn, "Shift+Return key command is removed")
    }

    func test_keyCommands_includeEditorOwnedFormattingShortcuts() {
        // ⌘B etc. must be owned by the editor (the app-level shortcuts mutate the legacy NSAttributedString
        // state the native editor doesn't use). As first responder these take precedence.
        let cmds = DocumentCanvasView().keyCommands ?? []
        func has(_ input: String, _ mods: UIKeyModifierFlags) -> Bool {
            cmds.contains { $0.input == input && $0.modifierFlags == mods }
        }
        XCTAssertTrue(has("B", .command), "⌘B (bold)")
        XCTAssertTrue(has("I", .command), "⌘I (italic)")
        XCTAssertTrue(has("U", .command), "⌘U (underline)")
        XCTAssertTrue(has("X", [.command, .shift]), "⇧⌘X (strikethrough)")
        XCTAssertTrue(has("M", [.command, .shift]), "⇧⌘M (monospace)")
        XCTAssertTrue(has("\t", []) && has("\t", .shift), "Tab / Shift-Tab still present")
    }

    // MARK: Hardware Return → host send hook

    func test_keyCommands_includeHardwareReturn() {
        let cmds = DocumentCanvasView().keyCommands ?? []
        XCTAssertTrue(cmds.contains { $0.input == "\r" && $0.modifierFlags == [] }, "plain Return")
        XCTAssertTrue(cmds.contains { $0.input == "\r" && $0.modifierFlags == .command }, "⌘Return")
    }

    func test_hardwareReturn_hostConsumes_noNewlineInserted() {
        let c = makeCanvas([.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hi")]))])
        c.setCaret(global: c.boxes[0].leafRegions().first!.globalStart + 2)   // end of "hi"
        var seen: UIKeyModifierFlags?
        c.onHardwareReturn = { flags in seen = flags; return false }          // host sent the message
        c.performHardwareReturn([])
        XCTAssertEqual(seen, [], "host hook was invoked with the modifier flags")
        XCTAssertEqual(c.boxes.count, 1, "no new paragraph — the host consumed the Return")
        guard case .paragraph(let p) = c.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertEqual(p.text, "hi", "text unchanged")
    }

    func test_hardwareReturn_hostDeclines_insertsNewline() {
        let c = makeCanvas([.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hi")]))])
        c.setCaret(global: c.boxes[0].leafRegions().first!.globalStart + 2)
        c.onHardwareReturn = { _ in true }                                   // insert a newline instead
        c.performHardwareReturn([])
        XCTAssertEqual(c.boxes.count, 2, "a new paragraph was inserted")
    }

    func test_hardwareReturn_noHost_insertsNewline() {
        let c = makeCanvas([.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hi")]))])
        c.setCaret(global: c.boxes[0].leafRegions().first!.globalStart + 2)
        c.performHardwareReturn([])                                          // onHardwareReturn unset → default newline
        XCTAssertEqual(c.boxes.count, 2, "standalone editor inserts a newline by default")
    }

    // MARK: Return in a heading → next paragraph is body

    func test_return_atEndOfHeading_nextParagraphIsBody() {
        let canvas = makeCanvas([.paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Title")]))])
        canvas.setCaret(global: canvas.boxes[0].leafRegions().first!.globalStart + 5)   // end of "Title"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        XCTAssertEqual(style(canvas.boxes[0]), .heading1, "the heading stays a heading")
        XCTAssertEqual(style(canvas.boxes[1]), .body, "the new paragraph is body, not another heading")
    }

    func test_return_midHeading_lowerHalfIsBody() {
        let canvas = makeCanvas([.paragraph(ParagraphBlock(id: BlockID("h"), style: .heading2, runs: [TextRun(text: "Title")]))])
        canvas.setCaret(global: canvas.boxes[0].leafRegions().first!.globalStart + 2)   // "Ti|tle"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        XCTAssertEqual(style(canvas.boxes[0]), .heading2, "the first part stays a heading")
        XCTAssertEqual(style(canvas.boxes[1]), .body, "the split-off tail becomes body")
        guard case .paragraph(let lower) = canvas.boxes[1].currentBlock() else { return XCTFail() }
        XCTAssertEqual(lower.text, "tle")
    }

    func test_return_midHeading_lowerTail_rendersAtBodyFontSize_notHeading() {
        let canvas = makeCanvas([.paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Title")]))])
        canvas.setCaret(global: canvas.boxes[0].leafRegions().first!.globalStart + 2)   // "Ti|tle"
        canvas.insertText("\n")
        guard case .paragraph(let lower) = canvas.boxes[1].currentBlock() else { return XCTFail() }
        // Reference: a plain body paragraph "tle" — its read-back run font size is the body size.
        let ref = makeCanvas([.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "tle")]))])
        guard case .paragraph(let refBody) = ref.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertEqual(lower.runs.first?.attributes.fontSize, refBody.runs.first?.attributes.fontSize,
                       "the heading tail must render at the BODY font size, not the pinned heading size")
    }

    func test_backspace_bodyStartIntoHeading_mergedTailRendersAtHeadingSize() {
        let c = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Head")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "small")])),
        ])
        c.setCaret(global: c.boxes[1].leafRegions().first!.globalStart)   // start of "small"
        c.deleteBackward()                                                // merge "small" into the heading
        XCTAssertEqual(c.boxes.count, 1)
        guard case .paragraph(let merged) = c.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertEqual(merged.style, .heading1)
        XCTAssertEqual(merged.text, "Headsmall")
        // Reference all-heading paragraph — the merged-in tail must render at the SAME (heading) size.
        let ref = makeCanvas([.paragraph(ParagraphBlock(id: BlockID("r"), style: .heading1, runs: [TextRun(text: "Headsmall")]))])
        guard case .paragraph(let refH) = ref.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertEqual(merged.runs.last?.attributes.fontSize, refH.runs.last?.attributes.fontSize,
                       "the merged-in body text renders at the heading size, not the pinned body size")
    }

    func test_backspace_RANGE_bodyStartIntoHeading_mergedTailRendersAtHeadingSize() {
        // iOS delivers Backspace at a paragraph's START as a RANGE [previous paragraph end, this start], NOT a
        // collapsed caret — so it goes through applySelectionReplaceOutcome, not the collapsed-caret merge branch.
        let c = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Head")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "small")])),
        ])
        let headEnd = c.boxes[0].leafRegions().first!.globalStart + 4     // end of "Head"
        let bodyStart = c.boxes[1].leafRegions().first!.globalStart        // start of "small"
        c.setSelectionForTesting(anchor: headEnd, head: bodyStart)   // the object-replacement range
        c.deleteBackward()
        XCTAssertEqual(c.boxes.count, 1)
        guard case .paragraph(let merged) = c.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertEqual(merged.style, .heading1)
        XCTAssertEqual(merged.text, "Headsmall")
        let ref = makeCanvas([.paragraph(ParagraphBlock(id: BlockID("r"), style: .heading1, runs: [TextRun(text: "Headsmall")]))])
        guard case .paragraph(let refH) = ref.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertEqual(merged.runs.last?.attributes.fontSize, refH.runs.last?.attributes.fontSize,
                       "merged-in body text renders at the heading size (range path)")
    }

    func test_return_inBody_staysBody() {
        let canvas = makeCanvas([.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "text")]))])
        canvas.setCaret(global: canvas.boxes[0].leafRegions().first!.globalStart + 4)
        canvas.insertText("\n")
        XCTAssertEqual(style(canvas.boxes[1]), .body, "body stays body (unchanged)")
    }

    // MARK: Code-block double-return

    // Typing two newlines at the BEGINNING of a code block exits before it (the first Enter lands the caret
    // on the content line past the new "\n"; the second Enter at the start-of-content-after-a-leading-blank
    // exits). Reachability of the first-line→before case.
    func test_codeBlock_twoNewlinesAtBeginning_exitsBefore() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "abc")]))])
        canvas.setCaret(global: canvas.boxes[0].textStart)
        canvas.insertText("\n")
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2, "the second newline at the beginning exits before the code block")
        XCTAssertEqual(style(canvas.boxes[0]), .body, "an empty body paragraph before the code block")
        guard case let .code(cb) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .code second") }
        XCTAssertEqual(cb.text, "abc", "no stray leading blank lines remain in the code block")
    }

    func test_codeBlock_doubleReturnOnTrailingEmptyLine_exitsAfter() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "abc\n")]))])
        canvas.setCaret(global: canvas.documentSize - 1)   // the trailing blank line
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code first") }
        XCTAssertEqual(cb.text, "abc", "the trailing blank line is removed")
        XCTAssertEqual(style(canvas.boxes[1]), .body, "an empty body paragraph after the code block")
    }

    func test_codeBlock_doubleReturnOnFirstEmptyLine_exitsBefore() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "\nabc")]))])
        canvas.setCaret(global: canvas.boxes[0].textStart)   // local 0 — the empty first line
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        XCTAssertEqual(style(canvas.boxes[0]), .body, "an empty body paragraph before the code block")
        guard case let .code(cb) = canvas.boxes[1].currentBlock() else { return XCTFail("expected .code second") }
        XCTAssertEqual(cb.text, "abc", "the empty first line is removed")
        XCTAssertEqual(canvas.head, canvas.boxes[0].textStart, "caret in the new body paragraph")
    }

    // REPRO: two-line code block, caret at the start of the (non-empty) first line, one Return → a leading
    // newline is inserted and the block grows by a line.
    func test_codeBlock_returnAtStartOfNonEmptyFirstLine_insertsLeadingNewline_growsHeight() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "A\nB")]))])
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        canvas.simulateParentLayout()
        let before = (canvas.boxes[0] as! CodeBlockBox).height
        let beforeFrame = (canvas.boxes[0] as! CodeBlockBox).frame.height
        let beforeMeasured = (canvas.boxes[0] as! CodeBlockBox).measuredHeight(forWidth: 320)
        canvas.setCaret(global: canvas.boxes[0].textStart)      // local 0 — start of the first (non-empty) line
        canvas.insertText("\n")
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "\nA\nB", "Return at the line start inserts a leading newline")
        let after = (canvas.boxes[0] as! CodeBlockBox).height
        XCTAssertGreaterThan(after, before, "the code block grows by one line")
        let afterFrame = (canvas.boxes[0] as! CodeBlockBox).frame.height
        XCTAssertGreaterThan(afterFrame, beforeFrame, "the code block laid-out FRAME grows by one line")
        let afterMeasured = (canvas.boxes[0] as! CodeBlockBox).measuredHeight(forWidth: 320)
        XCTAssertGreaterThan(afterMeasured, beforeMeasured, "the code block PURE MEASURE (field-sizing path) grows by one line")
    }

    func test_codeBlock_singleReturnOnEmptyBlock_addsLine_doesNotUncode() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: []))])
        canvas.setCaret(global: 1)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("still a code block after one Return") }
        XCTAssertEqual(cb.text, "\n", "the first Return adds a blank line (no un-code — the escape requires \\n\\n)")
    }

    func test_codeBlock_doubleReturnOnEmptyBlock_uncodes() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: []))])
        canvas.setCaret(global: 1)
        canvas.insertText("\n")   // adds a blank line
        canvas.insertText("\n")   // \n\n → un-code
        XCTAssertEqual(canvas.boxes.count, 1)
        XCTAssertEqual(style(canvas.boxes[0]), .body, "\\n\\n un-codes the empty code block to a body paragraph")
    }

    // MARK: Block-quote leading exit (\n\n at the beginning)

    func test_blockQuote_doubleReturnAtBeginningOfContent_exitsBefore() {
        let canvas = makeCanvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))
            ], collapsed: false, author: []))
        ])
        let box = canvas.boxes[0] as! BlockQuoteBox
        canvas.setCaret(global: box.children.boxes[0].leafRegions().first!.globalStart)   // start of "hello"
        canvas.insertText("\n")   // splits → ["", "hello"], caret on "hello"
        canvas.insertText("\n")   // \n\n at the beginning → exit before
        XCTAssertEqual(canvas.boxes.count, 2, "an empty body paragraph BEFORE the quote")
        XCTAssertEqual(style(canvas.boxes[0]), .body, "the body paragraph is first")
        guard case .blockQuote(let q) = canvas.boxes[1].currentBlock() else { return XCTFail("second still a quote") }
        XCTAssertEqual(q.children.count, 1, "the quote keeps just \"hello\" (leading blank dropped)")
        guard case .paragraph(let only) = q.children.first else { return XCTFail("expected a paragraph child") }
        XCTAssertEqual(only.text, "hello")
    }

    func test_blockQuote_singleReturnAtStartOfContent_addsLeadingLine_doesNotExit() {
        let canvas = makeCanvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))
            ], collapsed: false, author: []))
        ])
        let box = canvas.boxes[0] as! BlockQuoteBox
        canvas.setCaret(global: box.children.boxes[0].leafRegions().first!.globalStart)
        canvas.insertText("\n")   // one Return at the start → a leading blank line, still inside the quote
        XCTAssertEqual(canvas.boxes.count, 1, "a single Return does NOT exit")
        guard let q = canvas.boxes.first as? BlockQuoteBox else { return XCTFail("still a quote") }
        XCTAssertEqual(q.children.boxes.count, 2, "a leading empty line was added inside the quote")
    }

    // MARK: Block-quote wholly-empty requires \n\n (single Return must NOT escape)

    private func emptyQuote() -> Block {
        .blockQuote(BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: []))
        ], collapsed: false, author: []))
    }

    func test_blockQuote_singleReturnInWhollyEmptyQuote_addsLine_doesNotEscape() {
        let canvas = makeCanvas([emptyQuote()])
        let box = canvas.boxes[0] as! BlockQuoteBox
        canvas.setCaret(global: box.children.boxes[0].leafRegions().first!.globalStart)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1, "a single Return must NOT escape the empty quote")
        guard let q = canvas.boxes.first as? BlockQuoteBox else { return XCTFail("still a quote after one Return") }
        XCTAssertEqual(q.children.boxes.count, 2, "the first Return adds a second empty line inside the quote")
    }

    func test_blockQuote_doubleReturnInWhollyEmptyQuote_escapesToBody() {
        let canvas = makeCanvas([emptyQuote()])
        let box = canvas.boxes[0] as! BlockQuoteBox
        canvas.setCaret(global: box.children.boxes[0].leafRegions().first!.globalStart)
        canvas.insertText("\n")   // adds a line
        canvas.insertText("\n")   // \n\n → escape
        XCTAssertEqual(canvas.boxes.count, 1, "the wholly-empty quote is replaced by a single body paragraph")
        XCTAssertFalse(canvas.boxes[0] is BlockQuoteBox, "no longer a quote")
        XCTAssertEqual(style(canvas.boxes[0]), .body, "escaped to a body paragraph")
    }

    func test_blockQuote_doubleReturnAtEndOfContent_exitsAfter_unchanged() {
        let canvas = makeCanvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello")]))
            ], collapsed: false, author: []))
        ])
        let box = canvas.boxes[0] as! BlockQuoteBox
        canvas.setCaret(global: box.children.boxes[0].leafRegions().first!.globalStart + 5)   // end of "hello"
        canvas.insertText("\n")   // adds empty trailing line inside the quote
        canvas.insertText("\n")   // \n\n → exit after
        XCTAssertEqual(canvas.boxes.count, 2, "quote + body paragraph after it")
        guard case .blockQuote(let q) = canvas.boxes[0].currentBlock() else { return XCTFail("first still a quote") }
        XCTAssertEqual(q.children.count, 1, "the quote keeps just \"hello\" (the trailing empty line is dropped)")
        XCTAssertEqual(style(canvas.boxes[1]), .body, "a body paragraph after the quote")
    }

    func test_codeBlock_returnOnMiddleEmptyLine_insertsNewline() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "a\n\nb")]))])
        canvas.setCaret(global: canvas.boxes[0].textStart + 2)   // the empty middle line (between the two \n)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1, "a middle empty line stays inside the code block")
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "a\n\n\nb", "another newline is inserted (no exit)")
    }

    // MARK: Table header-cell double-return (exit ABOVE the table)

    /// A single-column table: header row (row 0) whose cell holds `headerText` (empty → one empty
    /// paragraph), plus a body row "body". Optionally preceded by a top-level paragraph `lead`.
    private func headerTableCanvas(headerText: String, lead: String? = nil) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        var blocks: [Block] = []
        if let lead {
            blocks.append(.paragraph(ParagraphBlock(id: BlockID("lead"), style: .body,
                                                    runs: lead.isEmpty ? [] : [TextRun(text: lead)])))
        }
        let headerCell = Cell(id: BlockID("h0"), blocks: [
            .paragraph(ParagraphBlock(id: BlockID("h0p"), runs: headerText.isEmpty ? [] : [TextRun(text: headerText)]))
        ])
        let bodyCell = Cell(id: BlockID("b0"), blocks: [
            .paragraph(ParagraphBlock(id: BlockID("b0p"), runs: [TextRun(text: "body")]))
        ])
        blocks.append(.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [headerCell]),
                   Row(id: BlockID("r1"), isHeader: false, cells: [bodyCell])])))
        c.setBlocks(blocks, width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 500); c.layoutIfNeeded()
        return c
    }

    private func table(in c: DocumentCanvasView) -> TableBlockBox {
        c.boxes.first { $0 is TableBlockBox } as! TableBlockBox
    }

    /// (block count, first paragraph text) of cell (row,col), read back from the live model.
    private func cellInfo(_ c: DocumentCanvasView, _ row: Int, _ col: Int) -> (blocks: Int, firstText: String) {
        guard case .table(let model) = table(in: c).currentBlock() else { return (0, "") }
        let cell = model.rows[row].cells[col]
        let texts = cell.blocks.compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
        return (cell.blocks.count, texts.first ?? "")
    }

    func test_headerCell_emptyCell_doubleReturn_exitsAboveTable() {
        // Empty header cell; the table is the document's FIRST block (covers the "insert at index 0" case).
        let c = headerTableCanvas(headerText: "")
        c.setCaret(global: table(in: c).cellTextStart(row: 0, column: 0)!)
        c.insertText("\n")   // [""] -> ["", ""], caret on the empty second block
        c.insertText("\n")   // leading-blank double-return -> exit ABOVE the table
        XCTAssertEqual(c.boxes.count, 2, "a body paragraph was inserted before the table")
        XCTAssertEqual(style(c.boxes[0]), .body, "the new block is a body paragraph")
        XCTAssertTrue(c.boxes[1] is TableBlockBox, "the table follows it")
        XCTAssertEqual(c.head, c.boxes[0].textStart, "caret lands in the new body paragraph")
        XCTAssertEqual(cellInfo(c, 0, 0).blocks, 1, "the header cell keeps a single (empty) block")
    }

    func test_headerCell_contentAtStart_doubleReturn_exitsAbove_keepsContentAndInsertsBeforeTable() {
        // "Intro" paragraph, then a table whose header cell is "Name". Caret at the START of "Name".
        let c = headerTableCanvas(headerText: "Name", lead: "Intro")
        let region = c.allLeafRegions().first { $0.ref == .paragraph(BlockID("h0p")) }!
        c.setCaret(global: region.globalStart)   // start of "Name"
        c.insertText("\n")   // ["", "Name"] in the cell, caret at start of "Name"
        c.insertText("\n")   // leading-blank double-return -> exit above
        // Order becomes: [ "Intro", body(""), table ].
        XCTAssertEqual(c.boxes.count, 3)
        XCTAssertEqual(style(c.boxes[0]), .body)
        guard case .paragraph(let intro) = c.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertEqual(intro.text, "Intro", "the preceding paragraph is untouched")
        XCTAssertEqual(style(c.boxes[1]), .body, "the new empty body paragraph sits between it and the table")
        guard case .paragraph(let inserted) = c.boxes[1].currentBlock() else { return XCTFail() }
        XCTAssertEqual(inserted.text, "")
        XCTAssertTrue(c.boxes[2] is TableBlockBox)
        XCTAssertEqual(c.head, c.boxes[1].textStart, "caret in the inserted paragraph")
        XCTAssertEqual(cellInfo(c, 0, 0).firstText, "Name", "the header cell keeps its content")
        XCTAssertEqual(cellInfo(c, 0, 0).blocks, 1, "the leading blank is dropped")
    }

    func test_headerCell_directLeadingBlankState_singleReturnAtStartOfSecondBlock_exitsAbove() {
        // Directly build a header cell already in the ["", "Name"] state; a single Return at the start
        // of "Name" exits (the pure trigger, independent of the first-Return flow).
        let c = DocumentCanvasView()
        let headerCell = Cell(id: BlockID("h0"), blocks: [
            .paragraph(ParagraphBlock(id: BlockID("h0p0"), runs: [])),               // empty first block
            .paragraph(ParagraphBlock(id: BlockID("h0p1"), runs: [TextRun(text: "Name")])),
        ])
        c.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [headerCell])]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 500); c.layoutIfNeeded()
        let region = c.allLeafRegions().first { $0.ref == .paragraph(BlockID("h0p1")) }!
        c.setCaret(global: region.globalStart)   // local 0 of "Name"
        c.insertText("\n")
        XCTAssertEqual(c.boxes.count, 2)
        XCTAssertEqual(style(c.boxes[0]), .body)
        XCTAssertTrue(c.boxes[1] is TableBlockBox)
        XCTAssertEqual(cellInfo(c, 0, 0).firstText, "Name")
        XCTAssertEqual(cellInfo(c, 0, 0).blocks, 1)
    }

    func test_headerCell_singleReturnInEmptyCell_doesNotExit() {
        let c = headerTableCanvas(headerText: "")
        c.setCaret(global: table(in: c).cellTextStart(row: 0, column: 0)!)
        c.insertText("\n")   // ONE Return only
        XCTAssertEqual(c.boxes.count, 1, "no exit on a single Return — the table stays the only block")
        XCTAssertTrue(c.boxes[0] is TableBlockBox)
        XCTAssertEqual(cellInfo(c, 0, 0).blocks, 2, "a leading blank line was added inside the cell")
    }

    func test_headerCell_trailingBlank_doubleReturn_doesNotExit() {
        // Caret at the END of "Name": the blank goes BELOW the content, so the previous block is not
        // empty and the exit must NOT fire.
        let c = headerTableCanvas(headerText: "Name")
        let region = c.allLeafRegions().first { $0.ref == .paragraph(BlockID("h0p")) }!
        c.setCaret(global: region.globalStart + 4)   // end of "Name"
        c.insertText("\n")   // ["Name", ""]
        c.insertText("\n")   // previous block is "Name" (not empty) -> normal split, no exit
        XCTAssertEqual(c.boxes.count, 1, "the table is still the only top-level block")
        XCTAssertTrue(c.boxes[0] is TableBlockBox)
        XCTAssertEqual(cellInfo(c, 0, 0).blocks, 3, "the cell grew by two trailing blank lines")
    }

    func test_bodyCell_doubleReturn_doesNotExit() {
        // Same gesture in the row-1 (body) cell -> normal in-cell split, table intact.
        let c = headerTableCanvas(headerText: "H")
        let region = c.allLeafRegions().first { $0.ref == .paragraph(BlockID("b0p")) }!
        c.setCaret(global: region.globalStart)   // start of "body"
        c.insertText("\n")
        c.insertText("\n")
        XCTAssertEqual(c.boxes.count, 1, "no top-level paragraph is inserted for a body cell")
        XCTAssertTrue(c.boxes[0] is TableBlockBox)
        XCTAssertEqual(cellInfo(c, 1, 0).blocks, 3, "the body cell split in place into \"\", \"\", \"body\"")
    }

    func test_headerCell_multiColumn_secondColumnCell_doubleReturn_exitsAbove() {
        // A 2-column header row; caret in the SECOND column's header cell. The predicate keys on the
        // cell-LOCAL index, so a non-first column exits too.
        let c = DocumentCanvasView()
        let h0 = Cell(id: BlockID("h0"), blocks: [.paragraph(ParagraphBlock(id: BlockID("h0p"), runs: [TextRun(text: "A")]))])
        let h1 = Cell(id: BlockID("h1"), blocks: [.paragraph(ParagraphBlock(id: BlockID("h1p"), runs: [TextRun(text: "B")]))])
        c.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [h0, h1])]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 500); c.layoutIfNeeded()
        let region = c.allLeafRegions().first { $0.ref == .paragraph(BlockID("h1p")) }!
        c.setCaret(global: region.globalStart)   // start of "B" in the second column
        c.insertText("\n")   // ["", "B"] in that cell
        c.insertText("\n")   // exit above
        XCTAssertEqual(c.boxes.count, 2)
        XCTAssertEqual(style(c.boxes[0]), .body)
        XCTAssertTrue(c.boxes[1] is TableBlockBox)
        XCTAssertEqual(c.head, c.boxes[0].textStart, "caret in the new body paragraph")
        XCTAssertEqual(cellInfo(c, 0, 1).firstText, "B", "the second-column header cell keeps its content")
        XCTAssertEqual(cellInfo(c, 0, 0).firstText, "A", "the first-column header cell is untouched")
    }

    func test_headerCell_exit_undo_revertsCellAndTopLevelInOneStep() {
        // Build the header cell already in the pre-exit ["", "Name"] state so a SINGLE Return IS the exit
        // (one `editing { }` edit). One undo must revert BOTH the cell-block removal and the top-level
        // body-paragraph insert together, landing back in ["", "Name"].
        let c = DocumentCanvasView()
        let headerCell = Cell(id: BlockID("h0"), blocks: [
            .paragraph(ParagraphBlock(id: BlockID("h0p0"), runs: [])),
            .paragraph(ParagraphBlock(id: BlockID("h0p1"), runs: [TextRun(text: "Name")])),
        ])
        c.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [headerCell])]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 500); c.layoutIfNeeded()
        let um = UndoManager(); um.groupsByEvent = true   // matches production + the sibling undo tests
        c.undoManagerOverride = um
        let region = c.allLeafRegions().first { $0.ref == .paragraph(BlockID("h0p1")) }!
        c.setCaret(global: region.globalStart)   // local 0 of "Name"
        c.insertText("\n")                        // the single exit edit
        XCTAssertEqual(c.boxes.count, 2, "sanity: the exit fired")
        XCTAssertEqual(cellInfo(c, 0, 0).blocks, 1, "sanity: the cell keeps just \"Name\"")
        c.effectiveUndoManager!.undo()
        XCTAssertEqual(c.boxes.count, 1, "one undo reverts both the top-level insert and the cell mutation")
        XCTAssertTrue(c.boxes[0] is TableBlockBox, "the table is the only block again")
        guard case .table(let model) = table(in: c).currentBlock() else { return XCTFail("expected a table") }
        let restoredTexts = model.rows[0].cells[0].blocks.compactMap { block -> String? in
            if case .paragraph(let p) = block { return p.text } else { return nil }
        }
        XCTAssertEqual(restoredTexts, ["", "Name"], "the cell's exact pre-exit content [\"\", \"Name\"] is restored")
    }

    func test_headerCell_midContentSecondBlock_return_doesNotExit() {
        // Header cell already ["", "Name"], but the caret is MID-content of the second block (not local 0)
        // -> the local == 0 guard blocks the exit; Return splits "Name".
        let c = DocumentCanvasView()
        let headerCell = Cell(id: BlockID("h0"), blocks: [
            .paragraph(ParagraphBlock(id: BlockID("h0p0"), runs: [])),
            .paragraph(ParagraphBlock(id: BlockID("h0p1"), runs: [TextRun(text: "Name")])),
        ])
        c.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [headerCell])]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 500); c.layoutIfNeeded()
        let region = c.allLeafRegions().first { $0.ref == .paragraph(BlockID("h0p1")) }!
        c.setCaret(global: region.globalStart + 2)   // "Na|me"
        c.insertText("\n")
        XCTAssertEqual(c.boxes.count, 1, "no exit from a mid-content caret")
        XCTAssertTrue(c.boxes[0] is TableBlockBox)
        XCTAssertEqual(cellInfo(c, 0, 0).blocks, 3, "the cell now holds \"\", \"Na\", \"me\"")
    }
}
#endif
