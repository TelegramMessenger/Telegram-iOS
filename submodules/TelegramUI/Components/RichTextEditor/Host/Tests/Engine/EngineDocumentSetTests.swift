import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

@available(iOS 18.4, *)
final class EngineDocumentSetTests: XCTestCase {
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

    func test_settingAnUnchangedDocumentTouchesNothing() {
        editor.document = Document(blocks: [para("a", "one"), para("b", "two")])
        let ids = editor.engine.tgid_blockIdentifiers
        editor.document = editor.document
        XCTAssertEqual(editor.engine.tgid_blockIdentifiers, ids)
    }

    func test_appendingABlockKeepsEveryExistingIdentity() {
        editor.document = Document(blocks: [para("a", "one"), para("b", "two")])
        let ids = editor.engine.tgid_blockIdentifiers
        editor.document = Document(blocks: [para("a", "one"), para("b", "two"), para("c", "three")])
        XCTAssertEqual(Array(editor.engine.tgid_blockIdentifiers.prefix(2)), ids)
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["one", "two", "three"])
    }

    func test_changingTheMiddleBlockKeepsTheOthersAndItsOwnIdentity() {
        editor.document = Document(blocks: [para("a", "one"), para("b", "two"), para("c", "three")])
        let ids = editor.engine.tgid_blockIdentifiers
        editor.document = Document(blocks: [para("a", "one"), para("b", "TWO"), para("c", "three")])
        XCTAssertEqual(editor.engine.tgid_blockIdentifiers, ids, "the first affected identity is kept by the engine; the rest were untouched")
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["one", "TWO", "three"])
    }

    func test_removingABlockKeepsTheRest() {
        editor.document = Document(blocks: [para("a", "one"), para("b", "two"), para("c", "three")])
        let ids = editor.engine.tgid_blockIdentifiers
        editor.document = Document(blocks: [para("a", "one"), para("c", "three")])
        XCTAssertEqual(editor.engine.tgid_blockIdentifiers, [ids[0], ids[2]])
    }

    func test_theSelectionSurvivesASetOutsideIt() {
        editor.document = Document(blocks: [para("a", "one"), para("b", "two")])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.composerSelectedRange = NSRange(location: 2, length: 0)
        editor.document = Document(blocks: [para("a", "one"), para("b", "two"), para("c", "three")])
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 2, length: 0))
    }

    func test_aSelectionInsideTheReplacedSpanClampsToItsEnd() {
        editor.document = Document(blocks: [para("a", "one"), para("b", "two")])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.composerSelectedRange = NSRange(location: 6, length: 0)   // "tw|o"
        editor.document = Document(blocks: [para("a", "one"), para("b", "2")])
        XCTAssertEqual(editor.composerSelectedRange, NSRange(location: 5, length: 0))
    }

    func test_aTablesScrollOffsetSurvivesAParagraphAppendedAfterIt() {
        let wide = TableBlock(id: BlockID("t0"), columns: (0..<4).map { _ in ColumnSpec(width: 100) },
                              rows: [Row(id: BlockID("r0"), cells: ["a", "b", "c", "d"].map {
                                  Cell(id: BlockID($0), blocks: [.paragraph(ParagraphBlock(id: BlockID("\($0)p"), runs: [TextRun(text: $0)]))]) })])
        editor.document = Document(blocks: [.table(wide)])
        editor.layoutIfNeeded()
        editor.engine.id_setPlacedRunContentOffset(60, forBlockAt: 0)
        editor.document = Document(blocks: [.table(wide), para("p", "after")])
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.id_placedRunContentOffsetForBlock(at: 0), 60, accuracy: 0.5,
                       "the run's scroll view was never recreated")
    }

    /// The expanded editor loads `Document()`; the engine always holds one block, so that is one
    /// empty paragraph with a role — and the "+" menu's Code works in a fresh document (measured
    /// on device: it did nothing until a Return and a Backspace had rebuilt the roles).
    func test_anEmptyDocumentIsOneEmptyParagraphWithARole() {
        editor.document = Document()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), [""])
        XCTAssertEqual(editor.currentRoles.count, 1)
        XCTAssertEqual(editor.document.blocks.count, 1)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.makeCodeBlock()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["", ""], "the language line and the code body")
        guard case .code = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0), "the caret opens the code body")
    }
}
