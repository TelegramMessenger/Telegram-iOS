#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

@available(iOS 13.0, *)
final class CodeBlockEditingTests: XCTestCase {
    func makeCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        return c
    }

    func test_codeBlock_enterInsertsNewlineDoesNotSplit() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "ab")]))])
        // A code block is a container [languagePara, codePara]; derive the code text start rather than
        // hard-coding it, since it moves with the language line's length.
        canvas.setCaret(global: canvas.boxes[0].textStart + 1)   // after "a"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)            // still ONE code block
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "a\nb")
    }

    func test_codeBlock_enterAtEnd_insertsNewlineDoesNotSplit() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "line1")]))])
        canvas.setCaret(global: canvas.boxes[0].textStart + 5)   // after "line1"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "line1\n")
    }

    func test_codeBlock_enterAtStart_insertsNewlineAtFront() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "ab")]))])
        canvas.setCaret(global: canvas.boxes[0].textStart)       // start of the code text
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "\nab")
    }

    func test_codeBlock_caretAdvancesAfterNewline() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "ab")]))])
        let codeStart = canvas.boxes[0].textStart
        canvas.setCaret(global: codeStart + 1)   // after "a"
        canvas.insertText("\n")
        // caret should land after the inserted "\n", i.e. before "b"
        XCTAssertEqual(canvas.head, codeStart + 2)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "a\nb")
    }

    func test_codeBlock_enterReplacesSelectionWithNewline() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "abcd")]))])
        // "bc" occupies the two globals after the code text start.
        canvas.setSelectionAnchor(global: canvas.boxes[0].textStart + 1)
        canvas.setSelectionHead(global: canvas.boxes[0].textStart + 3)
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "a\nd")
    }

    // MARK: Task 7 — boundary/exit rules (mirror the quote affordances)

    // (A) Backspace in a fully-EMPTY code block converts it to a body paragraph.
    func test_codeBlock_backspaceInEmptyConvertsToBody() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: []))])
        canvas.setCaret(global: canvas.boxes[0].textStart)   // the single position inside the empty code block
        canvas.deleteBackward()
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case let .paragraph(p) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .paragraph") }
        XCTAssertEqual(p.style, .body)
    }

    // (B) Enter on an empty trailing line EXITS the code block to a body paragraph.
    func test_codeBlock_enterOnTrailingBlankLineExits() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "x\n")]))])
        canvas.setCaret(global: canvas.documentSize - 1)   // end of "x\n"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 2)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code first") }
        XCTAssertEqual(cb.text, "x")                       // trailing blank line removed
        XCTAssertTrue({ if case .paragraph = canvas.boxes[1].currentBlock() { return true }; return false }())
    }

    // A NON-empty trailing line is NOT an exit — Enter just inserts another newline (regression guard).
    func test_codeBlock_enterAtEndOfNonBlankLine_doesNotExit() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "x")]))])
        canvas.setCaret(global: canvas.documentSize - 1)   // end of "x"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.boxes.count, 1)
        guard case let .code(cb) = canvas.boxes[0].currentBlock() else { return XCTFail("expected .code") }
        XCTAssertEqual(cb.text, "x\n")
    }

    // Backspace in an empty paragraph AFTER a code block. iOS does NOT deliver a collapsed caret here — it
    // overrides the selection with an object-replacement RANGE from the code block's text end to the empty
    // paragraph's start (device-log verified: setRange [8,10] then deleteBackward selFrom=8 selTo=10). The
    // empty paragraph must be removed and the caret parked at the code block's end — not a generic
    // selection-replace that mangles the boundary and strands the empty paragraph.
    func test_codeBlock_backspaceObjectReplacementRangeAfter_removesEmptyParagraph() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "code123")])),
            .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [])),
        ])
        let code = canvas.boxes[0], p = canvas.boxes[1]
        canvas.setSelectionAnchor(global: code.textStart + code.textLength)   // the object range's anchor (code end)
        canvas.setSelectionHead(global: p.textStart)                          // ...to the empty paragraph's start
        canvas.deleteBackward()
        XCTAssertEqual(canvas.boxes.count, 1, "the empty paragraph after the code block is removed")
        XCTAssertTrue(canvas.boxes.first is CodeBlockBox, "the code block remains")
        XCTAssertEqual(canvas.head, canvas.boxes[0].textStart + canvas.boxes[0].textLength,
                       "caret lands at the code block's end")
    }

    // Typing into a just-created (EMPTY) code block must use the monospace code font, not the body default.
    // The empty-storage typing path recovers a BlockBox paragraph's style/mapper; a CodeBlockBox isn't a
    // BlockBox, so without a code-specific case the first typed character lands non-monospace at body size.
    func test_codeBlock_emptyTypingAttributesAreMonospace() {
        let canvas = makeCanvas([.code(CodeBlock(id: BlockID("c1"), runs: []))])
        let codeStart = canvas.boxes[0].textStart   // inside the empty code block
        canvas.setCaret(global: codeStart)
        let font = canvas.typingAttributesAtGlobal(codeStart)[.font] as? UIFont
        XCTAssertEqual(font?.pointSize ?? 0, CodeBlockBox.fontSize, accuracy: 0.5,
                       "typing into an empty code block uses the 15pt code font, not the 17pt body default")
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) ?? false,
                      "typing into an empty code block uses a monospaced font")
    }

    // MARK: Task 8 — composer flat mapping + cross-block delete

    func test_composerFlatRange_countsCodeInterior() {
        // [body "ab"] \n [code "cd\nef"]  → composer flat string "ab\ncd\nef".
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "ab")])),
            .code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "cd\nef")])),
        ])
        canvas.setCaret(global: canvas.documentSize)        // caret at very end of doc
        let flatLen = ("ab\ncd\nef" as NSString).length    // 8
        XCTAssertEqual(canvas.composerSelectedRange.location, flatLen,
                       "code block interior must contribute to the flat composer offset")
    }

    func test_crossBlockDelete_keepsCodeBlock() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "ab")])),
            .code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "cd")])),
        ])
        // Select from the second char of the body ("b") to PARTWAY into the code text (before 'd').
        // Paragraph "ab": textStart = boxes[0].textStart (= 1), textLength = 2.
        // Code "cd":      textStart = boxes[1].textStart (= 5), textLength = 2.
        // Using codeHead = textStart + 1 (after 'c', before 'd') ensures the selection is partial inside
        // the code block (not fully covering it), so the truncate path fires and the block is kept.
        let bodyAnchor = canvas.boxes[0].textStart + 1   // after "a", before "b"
        let codeHead   = canvas.boxes[1].textStart + 1   // after "c", before "d" — partial coverage
        canvas.setSelectionAnchor(global: bodyAnchor)
        canvas.setSelectionHead(global: codeHead)
        canvas.deleteBackward()
        XCTAssertTrue(canvas.boxes.contains { $0 is CodeBlockBox },
                      "code block must survive a cross-block delete that ends inside it")
    }

    func test_crossBlockDelete_fullyCoveredCodeBlockIsDropped() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "ab")])),
            .code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "cd")])),
        ])
        // Select from inside the body through the END of the document — fully covers the code block.
        canvas.setSelectionAnchor(global: 2)
        canvas.setSelectionHead(global: canvas.documentSize)
        canvas.deleteBackward()
        XCTAssertFalse(canvas.boxes.contains { $0 is CodeBlockBox })   // fully-covered code block dropped
    }

    // (C) Tapping below a trailing code block inserts a body paragraph. Needs laid-out frames.
    private func laidOutCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 300)
        c.frame = CGRect(x: 0, y: 0, width: 300, height: 600)
        c.layoutIfNeeded()
        return c
    }

    func test_tapBelowTrailingCodeBlock_addsBodyParagraph() {
        let v = laidOutCanvas([.code(CodeBlock(id: BlockID("c1"), runs: [TextRun(text: "code")]))])
        let lastMaxY = v.boxes[0].frame.maxY
        XCTAssertGreaterThan(lastMaxY, 0, "precondition: the code box is laid out")
        v.performSingleTap(at: CGPoint(x: 20, y: lastMaxY + 40))
        XCTAssertEqual(v.boxes.count, 2)
        guard case let .paragraph(p) = v.boxes[1].currentBlock() else { return XCTFail("expected .paragraph") }
        XCTAssertEqual(p.style, .body, "tapping below the trailing code block starts a body paragraph after it")
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret moves into the new paragraph")
    }
}
#endif
