import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// **`insertDocument` lands where the caret is, at any depth** — the rule `insertMediaBlock` was
/// given on 2026-09-08 and this sibling never received.
///
/// It carried the identical stale guard, with the identical justification: *"§8.5: the quote no-op
/// the media spec already states for both inserts — inserting top-level roles between a quote's
/// children would split it."* That reasoning is sound about roles built at TOP LEVEL and says
/// nothing about whether the insert should happen — and `EngineDocumentBridge` has carried an
/// ancestry-aware entry point since R7-nesting, whose own comment names this exact case: building a
/// fragment at top level and re-parenting the roles afterwards *"gives correct structure wrapped
/// around wrong TEXT"*, because a quoted block renders through the quote mapper and is indented.
///
/// What a user saw: with the caret in a quote, the article editor's **AI ▸ generate** did nothing,
/// and so did attaching a file and the style-paragraph insert. Silently — the guard returns before
/// the framing, so there is not even an `onChange`. That is the same symptom the media guard
/// produced on K3 ("to a user holding a quote the + button simply did nothing"), one command over.
@available(iOS 18.4, *)
final class EngineInsertDocumentDepthTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 900))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func quote(_ id: String, _ children: [Block]) -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children))
    }
    private func caret(inRoleWithBlockID id: String, offset: Int = 0) {
        guard let index = editor.currentRoles.firstIndex(where: { $0.blockID == BlockID(id) }) else {
            return XCTFail("no role for \(id)")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: index) + offset, length: 0)
    }
    /// The quote's children as plain text, so "did it land INSIDE" reads at a glance.
    private func quoteChildren(_ id: String) -> [String]? {
        for block in editor.document.blocks {
            guard case let .blockQuote(q) = block, q.id == BlockID(id) else { continue }
            return q.children.map { block -> String in
                guard case let .paragraph(p) = block else { return "<\(block.caseNameForDiagnostics)>" }
                return p.runs.map(\.text).joined()
            }
        }
        return nil
    }

    func test_insertingADocumentInsideAQuoteMakesItAChildOfTheQuote() {
        editor.document = Document(blocks: [quote("q0", [para("q0p", "inside")]), para("after", "after")])
        caret(inRoleWithBlockID: "q0p", offset: 6)

        editor.insertDocument(Document(blocks: [para("new", "landed")]))

        XCTAssertEqual(quoteChildren("q0"), ["inside", "landed"],
                       "the block belongs to the quote the caret was in, not to the document")
        XCTAssertEqual(editor.document.blocks.count, 2, "the quote must not have been split")
    }

    /// Parity with the top-level rule: an empty caret paragraph is CONSUMED rather than appended to.
    func test_insertingOnAnEmptyQuotedParagraphReplacesIt() {
        editor.document = Document(blocks: [quote("q0", [para("q0p", "")])])
        caret(inRoleWithBlockID: "q0p")

        editor.insertDocument(Document(blocks: [para("new", "landed")]))

        XCTAssertEqual(quoteChildren("q0"), ["landed"],
                       "the empty paragraph is replaced, exactly as it is at top level")
    }

    /// The control. A caret in a CELL still places after the whole table — that is the container
    /// rule, not a depth rule, and it must not change with the guard.
    func test_aCaretInACellStillPlacesAfterTheWholeTable() {
        editor.document = Document(blocks: [.table(TableBlock.empty(rows: 1, columns: 2)), para("tail", "t")])
        guard let cell = editor.currentRoles.firstIndex(where: { $0.owningTable != nil }) else {
            return XCTFail("expected a cell role")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: cell), length: 0)

        editor.insertDocument(Document(blocks: [para("new", "landed")]))

        let kinds = editor.document.blocks.map { $0.caseNameForDiagnostics }
        XCTAssertEqual(kinds.first, "table", "the table stays first")
        XCTAssertEqual(kinds.count, 3, "the block lands beside the table, never inside a cell")
    }

    /// The top-level behaviour is unchanged.
    func test_atTopLevelAnEmptyParagraphIsStillReplaced() {
        editor.document = Document(blocks: [para("p0", "")])
        caret(inRoleWithBlockID: "p0")

        editor.insertDocument(Document(blocks: [para("new", "landed")]))

        XCTAssertEqual(editor.document.blocks.count, 1)
    }
}
