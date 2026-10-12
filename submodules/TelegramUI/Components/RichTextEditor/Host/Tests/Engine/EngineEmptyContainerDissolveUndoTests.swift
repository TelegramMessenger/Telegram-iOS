import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Backspace at the start of an EMPTY single-block container — a pull quote, a 1x1 table, a code
/// block with nothing in it — dissolves it into a body paragraph (`applyDissolveOfEmptyContainer`,
/// its LEAF arm). That is an edit the user made, so it is one undo step of its own: ⌘Z brings the
/// container back and nothing else, and a second ⌘Z takes back the edit before it.
///
/// The arm rebuilds through the `document` setter, which only moves the undo BASELINE — it never
/// registers a step, because a command that drives it registers its own. The dissolve did not, so
/// the step was missing and one ⌘Z took back the dissolve AND the edit before it (or, with nothing
/// before it, could not undo the dissolve at all). This was the parked SurfaceGate item, written
/// against the old UIKit replay stack; the stack is the editor's own now, and this is what is left.
///
/// Both doors are driven, because UIKit delivers this Backspace either as a caret or as the range
/// over the join above, and the two reach the rule from different places.
@available(iOS 18.4, *)
final class EngineEmptyContainerDissolveUndoTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private var emptyPullQuote: Block { .pullQuote(PullQuote(id: BlockID("c"))) }
    private var emptyCode: Block { .code(CodeBlock(id: BlockID("c"), runs: [])) }
    /// The CONTAINER arm: an empty block quote and an empty details unwrap through real engine edits
    /// (`performHostStructuralEdit`), not a document set, so they register through the funnel.
    private var emptyBlockQuote: Block {
        .blockQuote(BlockQuote(id: BlockID("c"), children: [para("c-child", "")], author: []))
    }
    private var emptyDetails: Block {
        .details(DetailsBlock(id: BlockID("c"), title: [], children: [para("c-child", "")], expanded: true))
    }
    private var emptyOneByOneTable: Block {
        var table = TableBlock.empty(rows: 1, columns: 1)
        table.id = BlockID("c")
        table.rows[0].cells[0].blocks = [para("cell", "")]
        return .table(table)
    }

    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }

    private enum Door { case caret, range }

    /// The role Backspace is pressed at: the primary text of `id`'s leaf container (a code block's
    /// BODY, not its language line; a table's one cell; a quote's or a details' child).
    private func primaryRoleIndex(ofContainer id: BlockID) -> Int? {
        editor.currentRoles.firstIndex { $0.containerID == id && $0.secondaryKind == nil }
    }

    private func backspace(atRole index: Int, through door: Door) {
        let offset = editor.flatOffset(ofRoleAt: index)
        switch door {
        case .caret:
            editor.engineSelectedRange = NSRange(location: offset, length: 0)
            editor.engine.deleteBackward()
        case .range:
            editor.engineSelectedRange = NSRange(location: offset - 1, length: 1)
            let start = editor.engine.position(from: editor.engine.beginningOfDocument, offset: offset - 1)!
            let end = editor.engine.position(from: start, offset: 1)!
            editor.engine.replace(editor.engine.textRange(from: start, to: end)!, withText: "")
        }
        turn()
    }

    /// Type "X" at the end of the paragraph above (one step), dissolve the container (a second),
    /// then walk the stack back and forward.
    private func assertDissolveIsItsOwnUndoStep(_ container: Block, through door: Door,
                                               pressingIn pressed: BlockID = BlockID("c"),
                                               file: StaticString = #filePath, line: UInt = #line) {
        editor?.removeFromSuperview()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        editor.document = Document(blocks: [para("p0", "before"), container])
        XCTAssertTrue(editor.engine.becomeFirstResponder(), file: file, line: line)
        let original = editor.document

        editor.engineSelectedRange = NSRange(location: 6, length: 0)
        editor.engine.insertText("X")
        turn()
        let typed = editor.document
        XCTAssertNotEqual(typed, original, "precondition: the typing changed nothing", file: file, line: line)

        guard let index = primaryRoleIndex(ofContainer: pressed) else {
            return XCTFail("precondition: no primary role for the container", file: file, line: line)
        }
        backspace(atRole: index, through: door)
        let dissolved = editor.document
        guard dissolved.blocks.count == 2, case .paragraph = dissolved.blocks[1],
              editor.currentRoles.allSatisfy({ $0.containerDepth == 0 }) else {
            return XCTFail("precondition: the empty container was not dissolved into a paragraph: "
                           + "\(dissolved.blocks)", file: file, line: line)
        }

        editor.undo()
        turn()
        XCTAssertEqual(editor.document, typed,
                       "one undo must bring the container back and keep the typing before it",
                       file: file, line: line)
        XCTAssertNotNil(primaryRoleIndex(ofContainer: pressed),
                        "the container's role did not come back with its text", file: file, line: line)

        editor.undo()
        turn()
        XCTAssertEqual(editor.document, original, "the second undo takes back the typing", file: file, line: line)

        editor.redo()
        turn()
        XCTAssertEqual(editor.document, typed, file: file, line: line)
        editor.redo()
        turn()
        XCTAssertEqual(editor.document, dissolved, "redo re-applies the dissolve", file: file, line: line)
    }

    func test_anEmptyPullQuote_caretDoor() { assertDissolveIsItsOwnUndoStep(emptyPullQuote, through: .caret) }
    func test_anEmptyPullQuote_rangeDoor() { assertDissolveIsItsOwnUndoStep(emptyPullQuote, through: .range) }
    func test_anEmptyOneByOneTable_caretDoor() { assertDissolveIsItsOwnUndoStep(emptyOneByOneTable, through: .caret) }
    func test_anEmptyOneByOneTable_rangeDoor() { assertDissolveIsItsOwnUndoStep(emptyOneByOneTable, through: .range) }
    func test_anEmptyCodeBlock_caretDoor() { assertDissolveIsItsOwnUndoStep(emptyCode, through: .caret) }
    func test_anEmptyCodeBlock_rangeDoor() { assertDissolveIsItsOwnUndoStep(emptyCode, through: .range) }
    func test_anEmptyBlockQuote_caretDoor() {
        assertDissolveIsItsOwnUndoStep(emptyBlockQuote, through: .caret, pressingIn: BlockID("c-child"))
    }
    func test_anEmptyBlockQuote_rangeDoor() {
        assertDissolveIsItsOwnUndoStep(emptyBlockQuote, through: .range, pressingIn: BlockID("c-child"))
    }
    func test_anEmptyDetails_caretDoor() {
        assertDissolveIsItsOwnUndoStep(emptyDetails, through: .caret, pressingIn: BlockID("c-child"))
    }
    func test_anEmptyDetails_rangeDoor() {
        assertDissolveIsItsOwnUndoStep(emptyDetails, through: .range, pressingIn: BlockID("c-child"))
    }
}
