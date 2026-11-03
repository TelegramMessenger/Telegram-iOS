import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Presentation is derived from the role and the model, never carried by the text: settle renders
/// every block an edit touched through the bridge again and applies what differs.
@available(iOS 18.4, *)
final class EnginePresentationTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    private func font(_ block: Int, at offset: Int) -> UIFont? {
        editor.engine.attributedBlocks[block].attribute(.font, at: offset, effectiveRange: nil) as? UIFont
    }
    private func para(_ id: String, _ text: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)])) }
    private func table(header: Bool = false) -> Block {
        .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                          rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("a"), blocks: [para("ap", "aa")], isHeader: header)])]))
    }

    /// Text ARRIVING in a cell takes the CELL's face, not the body's.
    ///
    /// This used to be driven by Backspace at the start of the paragraph after the table, which merged
    /// that text into the last cell — the shape originally reported from the device. R7-tables rung B
    /// made that Backspace SELECT the whole table instead (legacy's `selectPrecedingTableOnBackspace`,
    /// a deliberate parity choice), and a cross-block range delete does not merge out of a cell, so
    /// the merge has no route left. The invariant it was really about — presentation derived from the
    /// role — is pinned here through typing, which does.
    func test_textTypedIntoACellTakesTheCellsFace() {
        editor.document = Document(blocks: [table(), para("p1", "after")])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let cellFace = font(0, at: 0), bodyFace = font(1, at: 0)
        XCTAssertNotEqual(cellFace?.pointSize, bodyFace?.pointSize, "precondition: the two faces differ")
        editor.engineSelectedRange = NSRange(location: 2, length: 0)   // aa|
        editor.engine.insertText("z")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(strings(), ["aaz", "after"])
        XCTAssertEqual(font(0, at: 2)?.pointSize, cellFace?.pointSize, "the typed text takes the cell's size")
        XCTAssertEqual(font(0, at: 2)?.familyName, cellFace?.familyName)
        XCTAssertNotEqual(font(0, at: 2)?.pointSize, bodyFace?.pointSize)
    }

    func test_textTypedIntoAHeaderCellIsBold() {
        editor.document = Document(blocks: [table(header: true), para("p1", "after")])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        // Typed, for the reason the test above states: the merge route is gone.
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.engine.insertText("z")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(strings(), ["aaz", "after"])
        XCTAssertTrue(font(0, at: 2)?.fontDescriptor.symbolicTraits.contains(.traitBold) == true, "a header cell renders bold")
        guard case let .table(back) = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(back.rows[0].cells[0].blocks.first?.asParagraph?.runs.allSatisfy { !$0.attributes.bold }, true,
                       "and the bold is display-only")
    }

    /// A replacement across blocks whose survivor is a quote child: the tail that came from the body
    /// paragraph after the quote takes the quote's smaller size.
    func test_textMergedIntoAQuoteChildTakesTheQuotesFace() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("b"), children: [para("b0", "one")])),
            para("p1", "after"),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let quoteFace = font(0, at: 0), bodyFace = font(2, at: 0)
        XCTAssertNotEqual(quoteFace?.pointSize, bodyFace?.pointSize, "precondition: the quote scales its text")
        editor.engineSelectedRange = NSRange(location: 2, length: 5)   // "on|e\n\naf|ter": through the empty author line
        editor.engine.deleteBackward()
        XCTAssertEqual(strings(), ["onter", ""], "one child, and the author line the content calls for")
        XCTAssertEqual(font(0, at: 3)?.pointSize, quoteFace?.pointSize, "the merged tail takes the quote's size")
    }

    /// A keystroke that already has the right face writes nothing: the block's attributes are equal
    /// before and after settle, so the undo group holds the keystroke alone.
    func test_anOrdinaryKeystrokeIsNotRestyled() {
        editor.document = Document(blocks: [para("p0", "hello")])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 5, length: 0)
        let before = editor.engine.attributedBlocks[0]
        editor.engine.insertText("!")
        let after = editor.engine.attributedBlocks[0]
        XCTAssertEqual(after.string, "hello!")
        XCTAssertTrue(after.attributedSubstring(from: NSRange(location: 0, length: 5)).isEqual(to: before), "untouched text keeps its exact attributes")
        editor.engine.undoManager?.undo()
        XCTAssertEqual(strings(), ["hello"], "one undo step for the keystroke")
    }
}
