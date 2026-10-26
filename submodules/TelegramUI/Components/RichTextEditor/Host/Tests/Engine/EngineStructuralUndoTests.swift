import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// Undo and redo of the edits that change STRUCTURE — the ones the gate decides and settle follows.
///
/// One undo restores a whole `Document` snapshot and the setter derives the roles from it
/// (`+UndoStack.swift`), so text and structure cannot come back out of step. That was the hard part
/// under the previous stack, where UIKit replayed the TEXT and re-inserted blocks under fresh engine
/// identities no identity table could know, and the roles had to be reinstated positionally around
/// the replay.
///
/// Nothing here asserts text alone, and that has outlived the mechanism it was written for: the text
/// can be right while the roles come back as loose paragraphs, and the difference is a code block
/// that reads as code and no longer behaves as one.
@available(iOS 18.4, *)
final class EngineStructuralUndoTests: XCTestCase {
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
    /// One run-loop cycle: an undo group closes per cycle, so a redo needs the undo's own
    /// registrations grouped before it runs.
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    private func undo() { editor.engine.undoManager?.undo(); turn() }
    private func redo() { editor.engine.undoManager?.redo(); turn() }

    // MARK: - A container dropped by a selection comes back as that container

    func test_undoRestoresACodeBlockDroppedBySelectAll() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")]))])
        selectAll()
        editor.engine.deleteBackward()
        turn()
        XCTAssertEqual(kinds(), ["std"])
        undo()
        XCTAssertEqual(strings(), ["swift", "x"], "the language line and the body")
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code"])
        guard case .code = editor.document.blocks.first else { return XCTFail("\(editor.document.blocks)") }
        redo()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
    }

    func test_undoRestoresAPullQuoteDroppedBySelectAll() {
        load([.pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "quoted")], author: [TextRun(text: "Me")]))])
        selectAll()
        editor.engine.deleteBackward()
        turn()
        XCTAssertEqual(kinds(), ["std"])
        undo()
        XCTAssertEqual(strings(), ["quoted", "Me"])
        XCTAssertEqual(kinds(), ["pullQuote", "secondary.pullQuoteAuthor"])
        guard case .pullQuote = editor.document.blocks.first else { return XCTFail("\(editor.document.blocks)") }
        redo()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
    }

    func test_undoRestoresABlockQuoteDroppedBySelectAll() {
        load([.blockQuote(BlockQuote(id: BlockID("b"), children: [para("b0", "one"), para("b1", "two")], author: [TextRun(text: "Ada")]))])
        selectAll()
        editor.engine.deleteBackward()
        turn()
        XCTAssertEqual(kinds(), ["std"])
        undo()
        XCTAssertEqual(strings(), ["one", "two", "Ada"])
        XCTAssertEqual(kinds(), ["child", "child", "secondary.blockQuoteAuthor"])
        guard case .blockQuote = editor.document.blocks.first else { return XCTFail("\(editor.document.blocks)") }
        redo()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
    }

    func test_undoRestoresATableDroppedBySelectAll() {
        load([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                                rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("a"), blocks: [para("ap", "aa")]),
                                                                     Cell(id: BlockID("b"), blocks: [para("bp", "bb")])])]))])
        selectAll()
        editor.engine.deleteBackward()
        turn()
        XCTAssertEqual(kinds(), ["std"])
        undo()
        XCTAssertEqual(strings(), ["aa", "bb"])
        XCTAssertEqual(kinds(), ["cell", "cell"])
        guard case .table = editor.document.blocks.first else { return XCTFail("\(editor.document.blocks)") }
        redo()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
    }

    // MARK: - A partial range across blocks

    /// The truncate branch: both endpoints stay their own blocks. Undo must give back the code
    /// block AND the language line the range swallowed — settle re-added an empty one on the way in.
    func test_undoRestoresBothBlocksOfATruncatingRange() {
        load([para("p0", "before"), .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "xyz")]))])
        editor.engineSelectedRange = NSRange(location: 2, length: 12)   // "be|fore\nswift\nx|yz"
        editor.engine.deleteBackward()
        turn()
        XCTAssertEqual(kinds(), ["std", "secondary.codeLanguage", "code"])
        undo()
        XCTAssertEqual(strings(), ["before", "swift", "xyz"])
        XCTAssertEqual(kinds(), ["std", "secondary.codeLanguage", "code"])
    }

    /// Typing over a cross-block selection is the same rule with text: one undo takes back the
    /// typed character and the structure together.
    func test_undoOfTypingOverACrossBlockSelectionRestoresTheContainer() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")]))])
        selectAll()
        editor.engine.insertText("z")
        turn()
        XCTAssertEqual(strings(), ["z"])
        XCTAssertEqual(kinds(), ["std"])
        undo()
        XCTAssertEqual(strings(), ["swift", "x"])
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code"])
    }

    /// Cut is a copy plus the same replacement, so it undoes as one step too.
    func test_undoRestoresAPullQuoteRemovedByCut() {
        load([.pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "quoted")], author: [TextRun(text: "Me")]))])
        selectAll()
        editor.engine.cut(nil)
        turn()
        XCTAssertEqual(kinds(), ["std"])
        undo()
        XCTAssertEqual(strings(), ["quoted", "Me"])
        XCTAssertEqual(kinds(), ["pullQuote", "secondary.pullQuoteAuthor"])
    }

    // MARK: - The exits

    /// Legacy's double-Return exit: the blank last line goes and a body paragraph opens after the
    /// container. Both edits are the gate's, in one group, so one undo takes back both.
    func test_undoOfADoubleReturnExitPutsTheCaretBackInTheCodeBlock() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")]))])
        editor.engineSelectedRange = NSRange(location: 7, length: 0)   // "swift\nx|"
        editor.engine.insertText("\n")   // a line separator inside the body
        turn()
        editor.engine.insertText("\n")   // the exit
        turn()
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code", "std"])
        undo()
        XCTAssertEqual(strings(), ["swift", "x⏎"], "the blank last line is back")
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code"])
    }

    /// The un-make: a body of nothing but blank lines becomes one body paragraph. Undo restores the
    /// code block with its blank body.
    func test_undoOfAnUnmakeRestoresTheCodeBlock() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "")]))])
        editor.engineSelectedRange = NSRange(location: 6, length: 0)   // "swift\n|"
        editor.engine.insertText("\n")   // an empty body takes the newline: a blank two-line body
        turn()
        editor.engine.insertText("\n")   // nothing but blank lines: un-make
        turn()
        XCTAssertEqual(kinds(), ["std"])
        undo()
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code"])
        XCTAssertEqual(strings(), ["swift", "⏎"])
    }

    // MARK: - The container COMMANDS

    private func quote(_ id: String, _ children: [Block]) -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children))
    }
    private func depths() -> [Int] { editor.currentRoles.map(\.containerDepth) }

    /// The Quote command's WRAP branch rebuilds the document through the setter, whose edit the
    /// `isApplyingHostDocument` guard swallows — so nothing marked structure touched, settle never
    /// ran, and no role snapshot was registered. On undo the engine replays the text with no
    /// snapshot to install, and the roles are rebuilt BY IDENTITY against a table the set had just
    /// overwritten: the engine keeps the identity of the first block an edit touches, so block 0
    /// comes back still wrapped while every later block comes back a fresh top-level paragraph, and
    /// the regroup makes a HALF-WRAPPED document.
    func test_undoOfAQuoteWrapAcrossAQuoteAndItsNeighbourRestoresBoth() {
        load([quote("q", [para("a", "one")]), para("p", "two")])
        // one 0..3 | q author 4 | two 5..8
        XCTAssertEqual(depths(), [1, 1, 0])
        editor.engineSelectedRange = NSRange(location: 0, length: 7)
        editor.wrapInBlockQuote()
        XCTAssertEqual(depths(), [2, 2, 1, 1], "the old quote is a child of the new one")
        undo()
        XCTAssertEqual(strings(), ["one", "", "two"])
        XCTAssertEqual(depths(), [1, 1, 0], "the wrap is gone whole, not just from the block the engine kept")
        guard case .blockQuote = editor.document.blocks.first, editor.document.blocks.count == 2 else {
            return XCTFail("half-wrapped: \(editor.document.blocks)")
        }
    }

    /// `makeCodeBlock` goes through the same setter and registers the same nothing.
    func test_undoOfMakeCodeBlockRestoresTheParagraphs() {
        load([para("a", "one"), para("b", "two")])
        editor.engineSelectedRange = NSRange(location: 0, length: 7)
        editor.makeCodeBlock()
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code"])
        undo()
        XCTAssertEqual(strings(), ["one", "two"])
        XCTAssertEqual(kinds(), ["std", "std"])
    }

    func test_undoOfMakePullQuoteRestoresTheParagraphs() {
        load([para("a", "one"), para("b", "two")])
        editor.engineSelectedRange = NSRange(location: 0, length: 7)
        editor.makePullQuote()
        XCTAssertEqual(kinds(), ["pullQuote", "secondary.pullQuoteAuthor"])
        undo()
        XCTAssertEqual(strings(), ["one", "two"])
        XCTAssertEqual(kinds(), ["std", "std"])
    }
}
