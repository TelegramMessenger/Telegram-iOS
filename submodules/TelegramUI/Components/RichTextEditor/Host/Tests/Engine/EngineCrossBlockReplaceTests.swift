import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// Legacy's one rule for a replacement across blocks, at the gate: select all and Backspace over
/// any container leaves one empty body paragraph; a leaf container covered in part keeps its
/// remainder; a range into a table is refused. Selection deletions reach the gate through the host
/// view's `deleteBackward` and `cut:`.
@available(iOS 18.4, *)
final class EngineCrossBlockReplaceTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }
    private func strings() -> [String] { editor.engine.attributedBlocks.map { $0.string.replacingOccurrences(of: "\u{2028}", with: "⏎") } }
    private func kinds() -> [String] {
        editor.currentRoles.map { role in
            if role.owningTable != nil { return "cell" }
            if let kind = role.secondaryKind { return "secondary.\(kind)" }
            if role.innermostAncestor != nil { return "child" }
            switch role.shape { case .media: return "media"; case .buttonRow: return "buttonRow"; case .code: return "code"; case .pullQuote: return "pullQuote"; case .collapsedQuote: return "collapsedQuote"; case .paragraph: return "std" }
        }
    }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    private func selectAll() {
        let length = editor.engine.attributedBlocks.reduce(0) { $0 + $1.length } + max(0, editor.engine.attributedBlocks.count - 1)
        editor.engineSelectedRange = NSRange(location: 0, length: length)
    }
    private func para(_ id: String, _ text: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)])) }

    // MARK: select all, Backspace

    func test_selectAllAndBackspaceOverAPullQuoteLeavesOneEmptyParagraph() {
        load([.pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "quoted")], author: [TextRun(text: "Me")]))])
        selectAll()
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
        guard case .paragraph = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 0))
    }

    /// A block quote inside a start-to-end selection goes with everything else, author line and all.
    func test_selectAllAndBackspaceOverABlockQuoteLeavesOneEmptyParagraph() {
        load([.blockQuote(BlockQuote(id: BlockID("b"), children: [para("b0", "one"), para("b1", "two")], author: [TextRun(text: "Ada")]))])
        selectAll()
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
        guard case .paragraph = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        editor.engine.undoManager?.undo()
        XCTAssertEqual(strings(), ["one", "two", "Ada"], "undo brings the quote back")
        XCTAssertEqual(kinds(), ["child", "child", "secondary.blockQuoteAuthor"])
    }

    /// The chat composer's select all is on ITS axis, which leaves the author line out of the
    /// range; the quote's children are wholly covered, so the quote goes, author line included.
    func test_composerSelectAllAndBackspaceOverABlockQuoteWithAnAuthorRemovesIt() {
        load([.blockQuote(BlockQuote(id: BlockID("b"), children: [para("b0", "one"), para("b1", "two")], author: [TextRun(text: "Ada")]))])
        editor.composerSelectedRange = NSRange(location: 0, length: 7)   // "one\ntwo"
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
    }

    /// A quote between paragraphs, wholly inside the range, goes with the middle; the first
    /// paragraph's identity survives.
    func test_selectAllOverParagraphsAroundABlockQuoteLeavesTheFirstParagraphEmpty() {
        load([para("p0", "before"),
              .blockQuote(BlockQuote(id: BlockID("b"), children: [para("b0", "one")], author: [TextRun(text: "Ada")])),
              para("p1", "after")])
        selectAll()
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(editor.document.blocks.map(\.id), [BlockID("p0")])
    }

    func test_selectAllAndBackspaceOverACodeBlockLeavesOneEmptyParagraph() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")]))])
        selectAll()
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
    }

    /// The middle table is dropped whole; the first paragraph's identity survives (legacy: the start
    /// paragraph's identity and style carry the merge).
    func test_selectAllOverParagraphsAroundATableLeavesTheFirstParagraphEmpty() {
        load([para("p0", "before"),
              .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                                rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("a"), blocks: [para("ap", "aa")])])])),
              para("p1", "after")])
        selectAll()
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(editor.document.blocks.map(\.id), [BlockID("p0")])
    }

    /// A code block alone, then a paragraph: the paragraph's identity survives, empty.
    func test_selectAllOverACodeBlockAndAParagraphKeepsTheParagraphsIdentity() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")])), para("p1", "after")])
        selectAll()
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(editor.document.blocks.map(\.id), [BlockID("p1")])
    }

    // MARK: typing over a selection

    func test_typingOverSelectAllOverACodeBlockTypesInTheBodyFace() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")]))])
        selectAll()
        editor.engine.insertText("z")
        XCTAssertEqual(strings(), ["z"])
        XCTAssertEqual(kinds(), ["std"])
        let font = editor.engine.attributedBlocks[0].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace), false, "not the code face")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0))
    }

    // MARK: partial coverage keeps a leaf's remainder

    /// "be|fore" into "x|yz": the paragraph keeps its head, the code keeps its tail as a code block,
    /// and the language line the range swallowed comes back empty.
    func test_aRangeFromAParagraphIntoACodeBodyTruncatesBoth() {
        load([para("p0", "before"), .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "xyz")]))])
        editor.engineSelectedRange = NSRange(location: 2, length: 12)   // "be|fore\nswift\nx|yz"
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["be", "", "yz"])
        XCTAssertEqual(kinds(), ["std", "secondary.codeLanguage", "code"])
        guard case let .code(code) = editor.document.blocks[1] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertNil(code.language, "the language text was inside the selection")
        XCTAssertEqual(code.text, "yz")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 2, length: 0))
    }

    /// "x|yz" out to "af|ter": the code keeps its head, the paragraph keeps its tail.
    func test_aRangeFromACodeBodyIntoAParagraphTruncatesBoth() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "xyz")])), para("p1", "after")])
        editor.engineSelectedRange = NSRange(location: 7, length: 5)   // "swift\nx|yz\naf|ter"
        editor.engine.insertText("!")
        XCTAssertEqual(strings(), ["swift", "x!", "ter"])
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code", "std"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 8, length: 0))
    }

    /// A range across two children of one quote merges them into one child; the quote stays.
    func test_aRangeAcrossTwoQuoteChildrenMergesThemInsideTheQuote() {
        load([.blockQuote(BlockQuote(id: BlockID("b"), children: [para("b0", "one"), para("b1", "two")]))])
        editor.engineSelectedRange = NSRange(location: 2, length: 3)   // "on|e\nt|wo"
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["onwo", ""], "one child left, and the author line the quote's content calls for")
        XCTAssertEqual(kinds(), ["child", "secondary.blockQuoteAuthor"])
    }

    // MARK: tables

    /// Reported from the device: select all with a table as the last block did nothing.
    func test_selectAllOverAParagraphAndATrailingTableLeavesTheParagraphEmpty() {
        load([para("p0", "before"),
              .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                                rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("a"), blocks: [para("ap", "aa")]),
                                                                     Cell(id: BlockID("b"), blocks: [para("bp", "bb")])])]))])
        selectAll()
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(editor.document.blocks.map(\.id), [BlockID("p0")])
        XCTAssertEqual(kinds(), ["std"])
    }

    func test_selectAllOverATableAloneLeavesOneEmptyParagraph() {
        load([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                                rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("a"), blocks: [para("ap", "aa")]),
                                                                     Cell(id: BlockID("b"), blocks: [para("bp", "bb")])])]))])
        selectAll()
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
        editor.engine.undoManager?.undo()
        XCTAssertEqual(strings(), ["aa", "bb"], "undo brings the table back")
        XCTAssertEqual(kinds(), ["cell", "cell"])
    }

    func test_selectAllOverATableAndAParagraphKeepsTheParagraphsIdentity() {
        load([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                                rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("a"), blocks: [para("ap", "aa")])])])),
              para("p1", "after")])
        selectAll()
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(editor.document.blocks.map(\.id), [BlockID("p1")])
    }

    func test_aRangeFromOutsideATableIntoACellIsRefused() {
        load([para("p0", "before"),
              .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                                rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("a"), blocks: [para("ap", "aa")])])]))])
        editor.engineSelectedRange = NSRange(location: 3, length: 5)   // "bef|ore\na|a"
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["before", "aa"], "unchanged, as legacy refuses a range across stacks")
    }

    // MARK: cut

    func test_cutOverSelectAllOverAPullQuoteLeavesOneEmptyParagraph() {
        load([.pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "quoted")], author: [TextRun(text: "Me")]))])
        selectAll()
        editor.engine.cut(nil)
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
    }
}
