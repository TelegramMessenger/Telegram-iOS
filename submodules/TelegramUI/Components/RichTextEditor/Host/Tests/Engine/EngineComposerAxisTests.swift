import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The protocol's `composerSelectedRange` is the chat composer's flat axis (tables, media, language
/// and author lines off it), while the editor works in the engine's axis (every block counted).
@available(iOS 18.4, *)
final class EngineComposerAxisTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }
    /// Engine: before 0..6 | aa 7..9 | bb 10..12 | cc 13..15 | dd 16..18 | after 19..24.
    /// Composer: before 0..6 | after 7..12.
    private func sandwich() -> Document {
        Document(blocks: [
            para("p0", "before"),
            .table(TableBlock(id: BlockID("t0"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                              rows: [Row(id: BlockID("r0"), cells: [cell("a", "aa"), cell("b", "bb")]),
                                     Row(id: BlockID("r1"), cells: [cell("c", "cc"), cell("d", "dd")])])),
            para("p1", "after"),
        ])
    }

    func test_paragraphsOnlyTheTwoAxesCoincide() {
        editor.document = Document(blocks: [para("a", "one"), para("b", "two")])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.composerSelectedRange = NSRange(location: 5, length: 2)
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 5, length: 2))
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 5, length: 2))
    }

    func test_aTableContributesNothingToTheComposerAxis() {
        editor.document = sandwich()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 21, length: 0)   // "af|ter"
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 9, length: 0), "before(6) + separator + 2")
        editor.composerSelectedRange = NSRange(location: 7, length: 0)   // start of "after"
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 19, length: 0))
        editor.composerSelectedRange = NSRange(location: 3, length: 6)   // "ore" + separator + "af" → clamps inside the axis
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 3, length: 18), "spans the table in engine offsets")
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 3, length: 6))
    }

    func test_aCaretInsideACellReadsAsTheEndOfTheFlatTextAndTheEchoLeavesItAlone() {
        editor.document = sandwich()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 8, length: 0)   // a|a
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 12, length: 0), "off-axis: the end of the flat text, as legacy")
        // The chat composer's echo: the state carries what the editor reported; the same value written
        // back must be a no-op comparison, never a caret move — the node only writes on a difference.
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 12, length: 0))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 8, length: 0), "reading did not move it")
    }

    func test_languageAndAuthorLinesAreOffTheComposerAxis() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "let x")])),
            .pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "quoted")], author: [TextRun(text: "Me")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        // Engine: swift 0..5 | let x 6..11 | quoted 12..18 | Me 19..21. Composer: let x 0..5 | quoted 6..12.
        editor.engineSelectedRange = NSRange(location: 8, length: 0)   // le|t x
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 2, length: 0))
        editor.composerSelectedRange = NSRange(location: 8, length: 0)   // qu|oted
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 14, length: 0))
    }

    func test_theFirstSelectionRectTakesTheComposerAxis() {
        editor.document = sandwich()
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let viaComposer = editor.composerFirstSelectionRect(forFlatRange: NSRange(location: 7, length: 2))   // "af"
        guard let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: 19),
              let end = editor.engine.position(from: start, offset: 2),
              let range = editor.engine.textRange(from: start, to: end) else { return XCTFail() }
        let viaEngine = editor.engine.selectionRects(for: range).first?.rect
        XCTAssertNotNil(viaComposer)
        XCTAssertEqual(viaComposer, viaEngine)
    }
}
