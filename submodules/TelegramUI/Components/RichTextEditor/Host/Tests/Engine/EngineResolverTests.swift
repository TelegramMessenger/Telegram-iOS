import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// One section per structural situation (spec §3). Every test here asserts the corrected state
/// SYNCHRONOUSLY, right after the keystroke returns — the assertion that fails under the deferred
/// repair model — then that one undo restores the previous document, that untouched identities are
/// unchanged, and where the caret is (after a run-loop turn, since the caret is placed by a
/// run-loop block behind the controller's own selection update).
@available(iOS 18.4, *)
final class EngineResolverTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    // MARK: helpers

    func texts() -> [String] { editor.engine.attributedBlocks.map { $0.string.replacingOccurrences(of: "\u{2028}", with: "⏎") } }
    func kinds() -> [String] {
        editor.currentRoles.map { role in
            if role.owningTable != nil { return "cell" }
            if let kind = role.secondaryKind { return "secondary.\(kind)" }
            if role.innermostAncestor != nil { return "child" }
            return "std"
        }
    }
    func ids() -> [UUID] { editor.engine.tgid_blockIdentifiers }
    func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    func undo() { editor.engine.undoManager?.undo() }
    func redo() { editor.engine.undoManager?.redo() }
    func canUndo() -> Bool { editor.engine.undoManager?.canUndo ?? false }
    func font(_ index: Int, at offset: Int = 0) -> UIFont? {
        let s = editor.engine.attributedBlocks[index]
        guard s.length > offset else { return nil }
        return s.attribute(.font, at: offset, effectiveRange: nil) as? UIFont
    }
    func alignment(_ index: Int) -> NSTextAlignment? {
        let s = editor.engine.attributedBlocks[index]
        guard s.length > 0 else { return nil }
        return (s.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment
    }
    func caret() -> Int { editor.engineSelectedRange.location }

    // MARK: skeleton

    func test_replaceFlatGoesThroughTheControllerSoUndoSeesIt() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "hello")]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.replaceFlat(NSRange(location: 5, length: 0), with: " there")
        XCTAssertEqual(texts(), ["hello there"])
        XCTAssertTrue(canUndo(), "a replaceFlat is a controller edit")
        undo()
        XCTAssertEqual(texts(), ["hello"])
    }

    func test_restyleFlatChangesStyleOnlyAndRegistersItsOwnUndo() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "hello")]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let before = font(0)?.pointSize
        editor.restyleFlat(NSRange(location: 0, length: 5), with: [.font: UIFont.systemFont(ofSize: 29)])
        XCTAssertEqual(texts(), ["hello"])
        XCTAssertEqual(font(0)?.pointSize, 29)
        undo()
        XCTAssertEqual(font(0)?.pointSize, before, "the restyle's own undo restored the previous attributes")
    }

    // MARK: language line

    private func codeDocument() -> Document {
        Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
    }

    func test_returnInTheLanguageLineMovesIntoTheCodeSynchronously() {
        editor.document = codeDocument()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let idsBefore = ids()
        editor.engineSelectedRange = NSRange(location: 9, length: 0)   // "before\n" 7 + "sw|ift"
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["before", "swift", "let x = 1"], "the line is never split")
        XCTAssertEqual(kinds(), ["std", "secondary.codeLanguage", "std"])
        XCTAssertEqual(ids(), idsBefore, "no identity churned")
        XCTAssertEqual(caret(), 13, "the code's start: 7 + 5 + 1")
        XCTAssertFalse(canUndo(), "a caret move registers no undo step")
    }

    /// A newline inside delivered text becomes a space, as `UITextField` does with one: the words stay
    /// apart (composer harness, p12, `HarnessSingleLineFieldNewlineTests`; this pinned the newline
    /// being deleted, which glued them).
    func test_pastingNewlinesIntoTheLanguageLineKeepsTheWordsApart() {
        editor.document = codeDocument()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 12, length: 0)   // swift|
        editor.engine.insertText("a\nb")
        XCTAssertEqual(texts(), ["before", "swifta b", "let x = 1"])
        XCTAssertEqual(kinds(), ["std", "secondary.codeLanguage", "std"])
        XCTAssertEqual(caret(), 15)
        undo()
        XCTAssertEqual(texts(), ["before", "swift", "let x = 1"])
    }

    // MARK: author lines

    private func quoteWithAuthor() -> Document {
        Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("q0"), runs: [TextRun(text: "quoted")]))
            ], author: [TextRun(text: "Author")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
    }

    func test_returnInTheMiddleOfAnAuthorLineCarriesTheTailIntoABodyParagraphAfterTheQuote() {
        editor.document = quoteWithAuthor()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        // "quoted\n" 7, author "Author" 7..13; caret after "Auth"
        editor.engineSelectedRange = NSRange(location: 11, length: 0)
        let quoteIDs = Array(ids().prefix(2))
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["quoted", "Auth", "or", "after"], "the split stands; the tail is outside the quote already")
        XCTAssertEqual(kinds(), ["child", "secondary.blockQuoteAuthor", "std", "std"], "declared a body paragraph")
        XCTAssertEqual(Array(ids().prefix(2)), quoteIDs)
        XCTAssertEqual(font(2)?.pointSize, editor.bridge.styleSheet.metrics.body.size, "restyled to the body face")
        XCTAssertFalse(font(2)?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true, "not the author's bold")
        XCTAssertEqual(caret(), 12, "start of the tail")
        guard case let .blockQuote(quote) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(quote.author.map(\.text).joined(), "Auth")
        undo()
        XCTAssertEqual(texts(), ["quoted", "Author", "after"], "one undo: split and restyle both revert")
        XCTAssertTrue(font(1)?.fontDescriptor.symbolicTraits.contains(.traitBold) == true, "the author's bold is back")
    }

    func test_returnAtTheEndOfAnAuthorLineOpensAnEmptyBodyParagraphAfterTheQuote() {
        editor.document = Document(blocks: [.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quoted")], author: [TextRun(text: "Me")]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 9, length: 0)   // "quoted\n" 7 + "Me" → 9
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["quoted", "Me", ""])
        XCTAssertEqual(kinds(), ["std", "secondary.pullQuoteAuthor", "std"])
        XCTAssertEqual(caret(), 10)
        editor.engine.insertText("x")
        XCTAssertEqual(font(2)?.pointSize, editor.bridge.styleSheet.metrics.body.size, "typed with the paragraph's attributes, not the author's")
        XCTAssertEqual(alignment(2), .natural, "not the pull quote's centring")
    }

    /// The author is one line: a newline inside delivered text becomes a space (see the language
    /// line's case above).
    func test_pastingNewlinesIntoAnAuthorLineJoinsThemWithASpace() {
        editor.document = quoteWithAuthor()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 13, length: 0)   // Author|
        editor.engine.insertText("a\nb")
        XCTAssertEqual(texts(), ["quoted", "Authora b", "after"])
        XCTAssertEqual(kinds(), ["child", "secondary.blockQuoteAuthor", "std"])
        XCTAssertEqual(caret(), 16)
    }

    // MARK: leaf bodies — newlines and legacy's double Return

    private func pullQuoteDocument(_ text: String = "quoted text") -> Document {
        Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("pq"), runs: text.isEmpty ? [] : [TextRun(text: text)], author: [TextRun(text: "Me")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
    }
    private func codeDocument2(_ text: String = "let x", language: String = "swift") -> Document {
        Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: language, runs: text.isEmpty ? [] : [TextRun(text: text)])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
    }

    func test_returnInsideAPullQuoteBodyIsANewlineInsideTheQuote() {
        editor.document = pullQuoteDocument()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let bodyID = ids()[0]
        editor.engineSelectedRange = NSRange(location: 6, length: 0)   // "quoted| text"
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["quoted⏎ text", "Me", "after"], "a line inside the quote")
        XCTAssertEqual(kinds(), ["std", "secondary.pullQuoteAuthor", "std"])
        XCTAssertEqual(ids()[0], bodyID)
        guard case let .pullQuote(quote) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(quote.runs.map(\.text).joined(), "quoted\n text", "the model spells it as a newline")
        XCTAssertEqual(caret(), 7)
        undo()
        XCTAssertEqual(texts(), ["quoted text", "Me", "after"])
        XCTAssertFalse(canUndo())
    }

    func test_aReturnAfterABlankLastLineLeavesThePullQuoteAfterIt() {
        editor.document = pullQuoteDocument()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 11, length: 0)   // quoted text|
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["quoted text⏎", "Me", "after"], "the first Return is a blank last line")
        XCTAssertEqual(caret(), 12)
        turn()   // a separate keystroke: its own undo group
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["quoted text", "Me", "", "after"], "the second removes it and opens a paragraph after the quote")
        XCTAssertEqual(kinds(), ["std", "secondary.pullQuoteAuthor", "std", "std"])
        XCTAssertEqual(caret(), 15, "11 + 1 + 2 + 1")
        turn()   // a separate keystroke: its own undo group
        editor.engine.insertText("x")
        XCTAssertEqual(font(2)?.pointSize, editor.bridge.styleSheet.metrics.body.size)
        XCTAssertEqual(alignment(2), .natural)
        undo(); undo()
        XCTAssertEqual(texts(), ["quoted text⏎", "Me", "after"], "one undo per keystroke")
    }

    func test_aReturnAfterABlankFirstLineLeavesThePullQuoteBeforeIt() {
        editor.document = pullQuoteDocument()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["⏎quoted text", "Me", "after"])
        XCTAssertEqual(caret(), 1)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["", "quoted text", "Me", "after"], "the blank first line goes; a paragraph opens before the quote")
        XCTAssertEqual(kinds(), ["std", "std", "secondary.pullQuoteAuthor", "std"])
        XCTAssertEqual(caret(), 0)
        editor.engine.insertText("x")
        XCTAssertEqual(font(0)?.pointSize, editor.bridge.styleSheet.metrics.body.size)
        XCTAssertEqual(alignment(0), .natural)
    }

    func test_typingAfterATrailingNewlineInAPullQuoteTakesTheBodysFace() {
        editor.document = pullQuoteDocument()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let bodyFace = font(0)
        editor.engineSelectedRange = NSRange(location: 11, length: 0)   // quoted text|
        editor.engine.insertText("\n")
        turn()
        editor.engine.insertText("x")
        XCTAssertEqual(texts(), ["quoted text⏎x", "Me", "after"])
        XCTAssertEqual(font(0, at: 12), bodyFace, "measured on device: the text after the newline took the author line's face")
        XCTAssertEqual(font(0, at: 11), bodyFace, "the line separator itself carries the body's face")
    }

    func test_anEmptyFirstLineDoesNotWidenThePullQuotesPill() {
        editor.document = pullQuoteDocument()
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let hugBefore = editor.containerDecorationViews[BlockID("pq")]?.frame.width ?? -1
        let contentBefore = editor.contentWidth(ofBlockAt: 0)
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.insertText("\n")
        turn()
        editor.layoutIfNeeded()
        XCTAssertEqual(texts(), ["⏎quoted text", "Me", "after"])
        XCTAssertEqual(editor.contentWidth(ofBlockAt: 0), contentBefore, accuracy: 0.5, "the empty line has no ink; the widest line is still the text")
        XCTAssertEqual(editor.containerDecorationViews[BlockID("pq")]?.frame.width ?? -1, hugBefore, accuracy: 0.5, "measured on device: a full-width pill")
    }

    func test_returnsOnAWhollyBlankPullQuoteUnmakeIt() {
        editor.document = pullQuoteDocument("")
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["⏎", "Me", "after"], "an empty body takes the newline: a blank two-line quote")
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["", "after"], "a quote of nothing but blank lines becomes one paragraph")
        XCTAssertEqual(kinds(), ["std", "std"])
        XCTAssertEqual(caret(), 0)
    }

    func test_returnInsideACodeBodyIsANewline() {
        editor.document = codeDocument2()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 9, length: 0)   // "swift\n" 6 + "let| x"
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["swift", "let⏎ x", "after"])
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "std", "std"])
        guard case let .code(code) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(code.runs.map(\.text).joined(), "let\n x")
        XCTAssertEqual(caret(), 10)
    }

    func test_aReturnAfterABlankLastLineLeavesTheCodeBlockAfterIt() {
        editor.document = codeDocument2()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 11, length: 0)   // let x|
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["swift", "let x⏎", "after"])
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["swift", "let x", "", "after"])
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "std", "std", "std"])
        XCTAssertEqual(caret(), 12)
        editor.engine.insertText("y")
        XCTAssertEqual(font(2)?.familyName.contains("Menlo"), false, "typed in the body face, not the code's")
    }

    func test_aReturnAfterABlankFirstLineLeavesTheCodeBlockBeforeIt() {
        editor.document = codeDocument2()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 6, length: 0)   // |let x
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["swift", "⏎let x", "after"])
        XCTAssertEqual(caret(), 7)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["", "swift", "let x", "after"], "the paragraph opens before the whole block, language line included")
        XCTAssertEqual(kinds(), ["std", "secondary.codeLanguage", "std", "std"])
        XCTAssertEqual(caret(), 0)
    }

    func test_returnsOnAWhollyBlankCodeBlockUncodeIt() {
        editor.document = codeDocument2("", language: "")
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 1, length: 0)   // the empty body
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["", "⏎", "after"])
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["", "after"])
        XCTAssertEqual(kinds(), ["std", "std"])
        XCTAssertEqual(caret(), 0)
    }

    // MARK: quote children

    func test_returnInsideAQuoteChildMakesANewChildWithNoEdit() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("q0"), runs: [TextRun(text: "one two")])),
                .paragraph(ParagraphBlock(id: BlockID("q1"), runs: [TextRun(text: "three")])),
            ])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 3, length: 0)   // "one| two"
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["one", " two", "three", ""])
        XCTAssertEqual(kinds(), ["child", "child", "child", "secondary.blockQuoteAuthor"], "the new block is a child, declared")
        guard case let .blockQuote(quote) = editor.document.blocks[0] else { return XCTFail() }
        XCTAssertEqual(quote.children.count, 3)
        undo()
        XCTAssertEqual(texts(), ["one two", "three", ""])
    }

    // MARK: table cells

    private func sandwich() -> Document {
        Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .table(TableBlock(id: BlockID("t0"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                              rows: [Row(id: BlockID("r0"), cells: [Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "aa")]))]),
                                                                   Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "bb")]))])]),
                                     Row(id: BlockID("r1"), cells: [Cell(id: BlockID("c"), blocks: [.paragraph(ParagraphBlock(id: BlockID("cp"), runs: [TextRun(text: "cc")]))]),
                                                                   Cell(id: BlockID("d"), blocks: [.paragraph(ParagraphBlock(id: BlockID("dp"), runs: [TextRun(text: "dd")]))])])])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
    }
    // flat: before 0..6 | aa 7..9 | bb 10..12 | cc 13..15 | dd 16..18 | after 19..

    func test_returnInACellIsACaretMoveWithNothingToUndo() {
        editor.document = sandwich()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let idsBefore = ids()
        editor.engineSelectedRange = NSRange(location: 8, length: 0)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["before", "aa", "bb", "cc", "dd", "after"], "the cell is never split")
        XCTAssertEqual(ids(), idsBefore)
        XCTAssertEqual(caret(), 10, "placed before the keystroke returns")
        XCTAssertFalse(canUndo(), "a caret move registers no undo step")
    }

    func test_returnInTheLastCellOfATrailingTableOpensABodyParagraph() {
        var blocks = sandwich().blocks; blocks.removeLast()
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 18, length: 0)   // dd|
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["before", "aa", "bb", "cc", "dd", ""])
        XCTAssertEqual(kinds().last, "std")
        XCTAssertEqual(caret(), 19)
        editor.engine.insertText("x")
        XCTAssertEqual(font(5)?.pointSize, editor.bridge.styleSheet.metrics.body.size)
        undo()   // the typed x
        undo()   // the paragraph the Return opened, one group
        XCTAssertEqual(texts(), ["before", "aa", "bb", "cc", "dd"])
    }

    func test_returnMidCellInTheLastCellOfATrailingTableRejoinsAndOpensAParagraph() {
        var blocks = sandwich().blocks; blocks.removeLast()
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 17, length: 0)   // d|d
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["before", "aa", "bb", "cc", "dd", ""], "the cell is whole; the paragraph follows the table")
        XCTAssertEqual(caret(), 19)
    }

    func test_pastingNewlinesIntoACellBecomesLineSeparators() {
        editor.document = sandwich()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 8, length: 0)
        editor.engine.insertText("x\ny")
        XCTAssertEqual(texts(), ["before", "ax⏎ya", "bb", "cc", "dd", "after"])
        XCTAssertEqual(caret(), 11)
        undo()
        XCTAssertEqual(texts(), ["before", "aa", "bb", "cc", "dd", "after"])
    }

    func test_aSelectionSpanningCellsIsReplacedPerCellInOneUndoGroup() {
        editor.document = sandwich()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let firstCellID = ids()[1]
        editor.engineSelectedRange = NSRange(location: 8, length: 6)   // a|a … c|c
        editor.engine.insertText("X")
        XCTAssertEqual(texts(), ["before", "aX", "", "c", "dd", "after"])
        XCTAssertEqual(kinds(), ["std", "cell", "cell", "cell", "cell", "std"], "four cells, declared")
        XCTAssertEqual(ids()[1], firstCellID)
        XCTAssertEqual(caret(), 9)
        undo()
        XCTAssertEqual(texts(), ["before", "aa", "bb", "cc", "dd", "after"], "one undo")
        XCTAssertEqual(kinds(), ["std", "cell", "cell", "cell", "cell", "std"], "the re-minted cells are cells again")
        XCTAssertFalse(canUndo())
        redo()
        XCTAssertEqual(texts(), ["before", "aX", "", "c", "dd", "after"])
        XCTAssertEqual(kinds(), ["std", "cell", "cell", "cell", "cell", "std"])
    }

    func test_typingIntoAnEmptyCellNeverTriggersACorrection() {
        var doc = sandwich()
        guard case var .table(t) = doc.blocks[1] else { return XCTFail() }
        t.rows[0].cells[1].blocks = []
        doc.blocks[1] = .table(t)
        editor.document = doc
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 10, length: 0)
        editor.engine.insertText("x")
        editor.engine.insertText("y")
        XCTAssertEqual(texts(), ["before", "aa", "xy", "cc", "dd", "after"])
        XCTAssertEqual(kinds(), ["std", "cell", "cell", "cell", "cell", "std"])
    }

    // MARK: author-line presence

    func test_typingIntoAnEmptyQuoteAddsItsAuthorLineSynchronously() {
        editor.document = Document(blocks: [.blockQuote(BlockQuote(id: BlockID("q"), children: []))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        XCTAssertEqual(kinds(), ["child"], "an empty quote has no author line")
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.insertText("q")
        XCTAssertEqual(texts(), ["q", ""])
        XCTAssertEqual(kinds(), ["child", "secondary.blockQuoteAuthor"], "appeared inside the keystroke")
        turn()
        XCTAssertEqual(caret(), 1, "the caret stayed in the child")
        undo()
        XCTAssertEqual(texts(), [""])
        XCTAssertEqual(kinds(), ["child"], "one undo takes the author line with the character")
    }

    func test_emptyingAQuoteRemovesItsAuthorLineSynchronously() {
        editor.document = Document(blocks: [.blockQuote(BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("q0"), runs: [TextRun(text: "q")]))]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        XCTAssertEqual(kinds(), ["child", "secondary.blockQuoteAuthor"])
        editor.engineSelectedRange = NSRange(location: 1, length: 0)
        editor.engine.deleteBackward()
        XCTAssertEqual(texts(), [""])
        XCTAssertEqual(kinds(), ["child"])
        undo()
        XCTAssertEqual(texts(), ["q", ""])
        XCTAssertEqual(kinds(), ["child", "secondary.blockQuoteAuthor"], "the replay re-minted the line; its role came back with it")
        redo()
        XCTAssertEqual(texts(), [""])
        XCTAssertEqual(kinds(), ["child"])
    }

    func test_returnInTheLastCellThroughTheControllersReplaceTypesTheBodyFace() {
        // The keyboard inserts through the controller's own replace, not the view's insertText.
        var blocks = sandwich().blocks; blocks.removeLast()
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 18, length: 0)   // dd|
        editor.engine.replace(editor.engine.selectedTextRange!, withText: "\n")
        XCTAssertEqual(texts(), ["before", "aa", "bb", "cc", "dd", ""])
        turn()
        editor.engine.insertText("x")
        XCTAssertEqual(font(5)?.pointSize, editor.bridge.styleSheet.metrics.body.size, "the body face, not the cell's")
        XCTAssertEqual(alignment(5), .natural, "not the cell's centring")
    }

    // MARK: block quotes — legacy's double Return

    private func quoteDocument(_ children: [String]) -> Document {
        Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: children.enumerated().map { index, text in
                .paragraph(ParagraphBlock(id: BlockID("c\(index)"), runs: text.isEmpty ? [] : [TextRun(text: text)]))
            })),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
    }

    func test_aReturnInAnEmptyTrailingChildLeavesTheQuoteAfterIt() {
        editor.document = quoteDocument(["one"])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 3, length: 0)   // one|
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["one", "", "", "after"], "a new empty child (the author line follows)")
        XCTAssertEqual(kinds(), ["child", "child", "secondary.blockQuoteAuthor", "std"])
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["one", "", "", "after"])
        XCTAssertEqual(kinds(), ["child", "secondary.blockQuoteAuthor", "std", "std"], "the empty child went; a paragraph follows the quote")
        XCTAssertEqual(caret(), 5, "3 + 1 + 0 + 1")
        editor.engine.insertText("x")
        XCTAssertEqual(texts(), ["one", "", "x", "after"])
        XCTAssertEqual(font(2)?.pointSize, editor.bridge.styleSheet.metrics.body.size)
    }

    func test_aReturnAtTheStartAfterAnEmptyLeadingChildLeavesTheQuoteBeforeIt() {
        editor.document = quoteDocument(["one"])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["", "one", "", "after"], "an empty first child above the content")
        XCTAssertEqual(kinds(), ["child", "child", "secondary.blockQuoteAuthor", "std"])
        XCTAssertEqual(caret(), 1)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["", "one", "", "after"])
        XCTAssertEqual(kinds(), ["std", "child", "secondary.blockQuoteAuthor", "std"], "the empty child became the paragraph before the quote")
        XCTAssertEqual(caret(), 0)
    }

    func test_returnsInAWhollyEmptyQuoteUnquoteIt() {
        editor.document = quoteDocument([""])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        XCTAssertEqual(kinds(), ["child", "std"], "an empty quote has no author line")
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["", "", "after"], "the first Return adds a second empty child")
        XCTAssertEqual(kinds(), ["child", "child", "std"])
        editor.engine.insertText("\n")
        XCTAssertEqual(texts(), ["", "after"], "the second un-quotes")
        XCTAssertEqual(kinds(), ["std", "std"])
        XCTAssertEqual(caret(), 0)
    }

    // MARK: fast typing — the caret a correction places must be there before the next keystroke

    func test_fastTypingIntoAFreshPullQuoteStaysInItsBody() {
        editor.document = Document(blocks: [
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.insertText("q")   // the author line appears: a correction, and a caret to place
        XCTAssertEqual(caret(), 1, "placed before the keystroke returns, not on the next run-loop pass")
        editor.engine.insertText("u")   // no run-loop turn between the two: typing fast
        XCTAssertEqual(texts(), ["qu", "", "after"], "measured on device: the second character landed in the paragraph after the quote")
        XCTAssertEqual(caret(), 2)
    }

    func test_fastTypingIntoAFreshBlockQuoteStaysInItsChild() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.insertText("q")
        editor.engine.insertText("u")
        XCTAssertEqual(texts(), ["qu", "", "after"])
        XCTAssertEqual(kinds(), ["child", "secondary.blockQuoteAuthor", "std"])
    }

    func test_fastReturnThenTypingInACellLandsInTheNextCell() {
        editor.document = sandwich()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 9, length: 0)   // aa|
        editor.engine.insertText("\n")
        editor.engine.insertText("x")   // typed before any run-loop turn
        XCTAssertEqual(texts(), ["before", "aa", "xbb", "cc", "dd", "after"], "the Return's caret move was in place for the next key")
    }

    // MARK: bypass paths — text that reached the controller without passing the surface

    private func insertBypassingTheSurface(_ text: String) {
        let controller = editor.engine.value(forKey: "id_behaviorInput") as AnyObject
        _ = controller.perform(#selector(UIKeyInput.insertText(_:)), with: text)
    }

    func test_aNewlineDictatedIntoACellIsRejoinedAtSettle() {
        editor.document = sandwich()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 8, length: 0)
        insertBypassingTheSurface("\n")
        XCTAssertEqual(texts(), ["before", "a⏎a", "bb", "cc", "dd", "after"], "a line inside the cell, as a paste would be")
        XCTAssertEqual(kinds(), ["std", "cell", "cell", "cell", "cell", "std"])
    }

    func test_aNewlineDictatedIntoAPullQuoteIsRejoinedAtSettle() {
        editor.document = pullQuoteDocument()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 6, length: 0)
        insertBypassingTheSurface("\n")
        XCTAssertEqual(texts(), ["quoted⏎ text", "Me", "after"])
        XCTAssertEqual(kinds(), ["std", "secondary.pullQuoteAuthor", "std"])
    }

    func test_aNewlineDictatedIntoTheLanguageLineIsJoinedAtSettle() {
        editor.document = codeDocument()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 9, length: 0)
        insertBypassingTheSurface("\n")
        XCTAssertEqual(texts(), ["before", "swift", "let x = 1"])
        XCTAssertEqual(kinds(), ["std", "secondary.codeLanguage", "std"])
    }
}
