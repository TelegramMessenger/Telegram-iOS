import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// **After a replace, the caret goes AFTER everything that was inserted — and if there is nowhere
/// after it to stand, the document grows a line.**
///
/// Measured before this existed, pasting a fragment that ends in a table:
///
/// | fragment ends in | caret landed |
/// | --- | --- |
/// | paragraph / heading | end of it (correct) |
/// | **table**, at the document end AND mid-document | end of the paragraph BEFORE it |
/// | **code** | inside the code body, with no line after it |
///
/// The cause is in `Document.insertingFragment`: its caret is
/// `globalTextStart(ofBlockAt: last) + lastLen`, and `lastLen` falls to `0` for every block with no
/// trailing text (`default:` — table, media, button row, quote, details). That is a STRUCTURAL
/// position inside the block, not after it, so the engine's nearest-text scan then resolved it
/// backwards into the preceding paragraph.
///
/// The rule this pins, in the user's words: *the cursor should be placed after all the inserted
/// contents; if the inserted contents end at a block other than body/header and we are inserting at
/// the end of the document, a new line should be added below and the cursor should go there.*
///
/// Note `ParagraphStyleName` has no `.quote` — a quote is a CONTAINER block — so "body or header" is
/// every paragraph style a top-level block can actually hold, and every other BLOCK KIND is the
/// other side of the rule.
@available(iOS 18.4, *)
final class EnginePasteCaretTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 900))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.engine.becomeFirstResponder()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String, style: ParagraphStyleName = .body) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: style, runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func table() -> Block { .table(TableBlock.empty(rows: 2, columns: 2)) }
    private func code(_ id: String, _ text: String) -> Block {
        .code(CodeBlock(id: BlockID(id), language: "swift", runs: [TextRun(text: text)]))
    }
    private func kinds() -> [String] { editor.document.blocks.map { $0.caseNameForDiagnostics } }

    /// Replaces at the very end of the document.
    private func replaceAtEnd(with fragment: Document) {
        let size = DocumentTree.documentSize(editor.document)
        editor.replaceRange(from: size, to: size, with: fragment)
    }
    /// Which top-level block holds the caret, and how far into its text.
    private func caretBlock() -> (index: Int, local: Int)? {
        let caret = editor.engineSelectedRange.location
        guard let role = editor.roleIndex(atFlatOffset: caret) else { return nil }
        let id = editor.currentRoles[role].blockID
        guard let index = editor.document.blocks.firstIndex(where: { $0.id == id }) else { return nil }
        return (index, caret - editor.flatOffset(ofRoleAt: role))
    }

    // MARK: - The caret lands after the inserted content

    func test_afterAParagraphTheCaretIsAtItsEnd() {
        editor.document = Document(blocks: [para("t0", "target")])
        replaceAtEnd(with: Document(blocks: [para("f0", "one"), para("f1", "two")]))

        guard let caret = caretBlock() else { return XCTFail("no caret") }
        XCTAssertEqual(caret.index, editor.document.blocks.count - 1)
        XCTAssertEqual(caret.local, 3, "the end of two")
    }

    /// A heading is a "header", so it takes no extra line either.
    func test_afterAHeadingTheCaretIsAtItsEndAndNoLineIsAdded() {
        editor.document = Document(blocks: [para("t0", "target")])
        replaceAtEnd(with: Document(blocks: [para("h0", "Title", style: .heading1)]))

        XCTAssertEqual(kinds(), ["paragraph", "paragraph"], "no extra line for a header")
        guard let caret = caretBlock() else { return XCTFail("no caret") }
        XCTAssertEqual(caret.index, 1)
        XCTAssertEqual(caret.local, 5, "the end of Title")
    }

    // MARK: - A block with nowhere to stand after it, at the document end

    func test_aTableAtTheDocumentEndGrowsALineAndTakesTheCaret() {
        editor.document = Document(blocks: [para("t0", "target")])
        replaceAtEnd(with: Document(blocks: [para("f0", "lead"), table()]))

        XCTAssertEqual(kinds(), ["paragraph", "table", "paragraph"],
                       "a table cannot hold a caret after it, so the document grows a line")
        guard let caret = caretBlock() else { return XCTFail("no caret") }
        XCTAssertEqual(caret.index, 2, "the caret is in the new line, after the table")
        XCTAssertEqual(caret.local, 0)
    }

    func test_aCodeBlockAtTheDocumentEndGrowsALineAndTakesTheCaret() {
        editor.document = Document(blocks: [para("t0", "target")])
        replaceAtEnd(with: Document(blocks: [code("c0", "let x = 1")]))

        XCTAssertEqual(kinds(), ["paragraph", "code", "paragraph"])
        guard let caret = caretBlock() else { return XCTFail("no caret") }
        XCTAssertEqual(caret.index, 2, "not inside the code body")
    }

    // MARK: - The same block mid-document: no new line, caret moves past it

    func test_aTableMidDocumentTakesNoNewLineAndTheCaretGoesToTheNextBlock() {
        editor.document = Document(blocks: [para("t0", "target"), para("t1", "tail")])
        let afterFirst = editor.document.globalTextStart(ofBlockAt: 0) + 6
        editor.replaceRange(from: afterFirst, to: afterFirst,
                            with: Document(blocks: [para("f0", "lead"), table()]))

        XCTAssertEqual(kinds(), ["paragraph", "table", "paragraph"],
                       "the block after the table already exists — no line is added")
        guard let caret = caretBlock() else { return XCTFail("no caret") }
        XCTAssertEqual(caret.index, 2, "the caret is past the table, at the start of the existing block")
        XCTAssertEqual(caret.local, 0)
    }

    // MARK: - Controls

    /// A pure delete inserts nothing, so the policy must not fire and must not grow a line.
    func test_aPureDeleteAddsNoLine() {
        editor.document = Document(blocks: [para("t0", "target"), para("t1", "tail")])
        let doc = editor.document
        let from = doc.globalTextStart(ofBlockAt: 1)
        editor.replaceRange(from: from, to: from + 2, with: Document(blocks: []))

        XCTAssertEqual(kinds(), ["paragraph", "paragraph"], "no line is grown by a delete")
    }

    /// And deleting a block's WHOLE text empties the line rather than removing it — so the policy
    /// still adds nothing, and the user keeps the blank line they just cleared.
    func test_deletingAWholeBlocksTextEmptiesTheLineAndGrowsNothing() {
        editor.document = Document(blocks: [para("t0", "target"), para("t1", "tail")])
        let doc = editor.document
        let from = doc.globalTextStart(ofBlockAt: 1)
        editor.replaceRange(from: from, to: from + 4, with: Document(blocks: []))

        XCTAssertEqual(kinds(), ["paragraph", "paragraph"], "the emptied line stays, and no line is grown")
        guard case let .paragraph(p) = editor.document.blocks[1] else { return XCTFail("expected a paragraph") }
        XCTAssertEqual(p.text, "")
    }

    /// The document must not grow a line every time — pasting a paragraph at the end twice leaves
    /// exactly the blocks that were pasted.
    func test_repeatedParagraphPastesGrowNoSpareLines() {
        editor.document = Document(blocks: [para("t0", "target")])
        replaceAtEnd(with: Document(blocks: [para("f0", "one")]))
        replaceAtEnd(with: Document(blocks: [para("f1", "two")]))

        XCTAssertEqual(kinds(), ["paragraph"], "all three fold into one paragraph; no blank lines")
    }
}
