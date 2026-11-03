import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

final class EngineFormattingTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "alpha beta")]))])
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func selectAll() {
        let whole = editor.engine.textRange(from: editor.engine.beginningOfDocument,
                                            to: editor.engine.endOfDocument)!
        editor.engine.selectedTextRange = whole
    }

    /// R3's gate: our reported state IS the engine's, not a re-derivation from attributes.
    func test_boldStateAgreesWithTheEngine() {
        selectAll()
        editor.toggleBold()
        XCTAssertEqual(editor.currentInlineTraits().bold, .on,
                       "our bold state disagrees with the engine's own trait state")
    }

    func test_togglingBoldReachesTheDocument() {
        selectAll()
        editor.toggleBold()
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertTrue(paragraph.runs.contains { $0.attributes.bold },
                      "the engine's bold did not survive the round-trip into Document")
    }

    func test_togglingBoldTwiceReturnsToPlain() {
        selectAll()
        editor.toggleBold()
        editor.toggleBold()
        XCTAssertEqual(editor.currentInlineTraits().bold, .off)
    }

    /// The case with no prior coverage: a selection spanning bold and non-bold text must report
    /// `.mixed`, not collapse to `.off`/`.on` (that collapse is Task 9's decision, at the public
    /// boundary — not here).
    func test_mixedBoldSelectionReportsMixed() {
        // Bold only "alpha" (the first word), leave "beta" plain.
        let start = editor.engine.beginningOfDocument
        let alphaEnd = editor.engine.position(from: start, offset: 5)!
        editor.engine.selectedTextRange = editor.engine.textRange(from: start, to: alphaEnd)!
        editor.toggleBold()

        // Now select across both the bold word and the plain word.
        selectAll()
        XCTAssertEqual(editor.currentInlineTraits().bold, .mixed,
                       "a selection spanning bold and non-bold text should report mixed, not off/on")
    }

    func test_italicUnderlineAndStrikethroughEachReachTheDocument() {
        selectAll(); editor.toggleItalic()
        selectAll(); editor.toggleUnderline()
        selectAll(); editor.toggleStrikethrough()
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertTrue(paragraph.runs.contains { $0.attributes.italic })
        XCTAssertTrue(paragraph.runs.contains { $0.attributes.underline })
        XCTAssertTrue(paragraph.runs.contains { $0.attributes.strikethrough })
    }
}
