import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// ↑ / ↓ over containers, as UIKit's hardware keyboard resolves them (composer harness p17,
/// `HarnessVerticalMoveAtDocumentEdgeTests`).
///
/// A held arrow key (or presses in a row) is `_moveDown:withHistory:` fed the history the previous press
/// returned, which UIKit resolves as `position(from: history.start, in: .down, offset: presses)` with
/// the history's goal x — so the multi-line offset IS the repeated press. It used to go backwards over a
/// code block, skip a table row and return to line 0 from the last line; a single ↑ from the start of
/// the line under a table landed in the table's LAST column.
@available(iOS 18.4, *)
final class EngineVerticalNavigationTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 360, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 360, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    private var codeDocument: Document {
        Document(blocks: [para("p0", "Code below:"), .code(CodeBlock(id: BlockID("c0"), language: "", runs: [TextRun(text: "let x = 1")]))])
    }

    /// "Table below:" / Name | Value (header) / alpha | 1 / "After the table." — flat offsets 0, 13, 18,
    /// 24, 30, 32.
    private var tableDocument: Document {
        var built = TableBlock.empty(rows: 2, columns: 2)
        built.id = BlockID("t")
        let texts = [["Name", "Value"], ["alpha", "1"]]
        for r in 0..<2 {
            for c in 0..<2 {
                built.rows[r].cells[c].blocks = [para("t-\(r)\(c)", texts[r][c])]
                built.rows[r].cells[c].isHeader = r == 0
            }
        }
        return Document(blocks: [para("p0", "Table below:"), .table(built), para("p1", "After the table.")])
    }

    private func arrange(_ document: Document) {
        editor.document = document
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        turn()
    }

    private func positions(_ direction: UITextLayoutDirection, from caret: Int, offsets: ClosedRange<Int>) -> [Int?] {
        let input = editor.engine
        guard let origin = input.position(from: input.beginningOfDocument, offset: caret) else { return [] }
        return offsets.map { n in
            input.position(from: origin, in: direction, offset: n).map { input.offset(from: input.beginningOfDocument, to: $0) }
        }
    }

    private typealias MoveFunction = @convention(c) (AnyObject, Selector, Bool, AnyObject?) -> AnyObject?

    private func walk(_ action: String, from caret: Int, presses: Int) throws -> [Int] {
        editor.engineSelectedRange = NSRange(location: caret, length: 0)
        turn()
        let target: NSObject = editor.engine
        let selector = NSSelectorFromString(action)
        let method = try XCTUnwrap(class_getInstanceMethod(type(of: target), selector))
        let function = unsafeBitCast(method_getImplementation(method), to: MoveFunction.self)
        var history: AnyObject?
        var result: [Int] = []
        for _ in 0 ..< presses {
            history = function(target, selector, false, history)
            turn()
            result.append(editor.engineSelectedRange.location)
        }
        return result
    }

    func test_positionDownByManyLines_overACodeBlock_countsEachLineAndClampsToTheEnd() {
        arrange(codeDocument)
        XCTAssertEqual(positions(.down, from: 0, offsets: 1...5), [12, 13, 22, 22, 22])
    }

    func test_positionDownByManyLines_overATable_visitsEveryRow() {
        arrange(tableDocument)
        XCTAssertEqual(positions(.down, from: 0, offsets: 1...5), [13, 24, 32, 48, 48])
    }

    func test_positionUpByManyLines_overATable_visitsEveryRowAndClampsToTheStart() {
        arrange(tableDocument)
        XCTAssertEqual(positions(.up, from: 32, offsets: 1...4), [24, 13, 0, 0])
    }

    func test_positionDownPastThePlainLastLine_isTheEnd() {
        arrange(Document(blocks: [para("a", "one"), para("b", "two"), para("c", "three")]))
        XCTAssertEqual(positions(.down, from: 0, offsets: 1...4), [4, 8, 13, 13])
        XCTAssertEqual(positions(.up, from: 8, offsets: 1...3), [4, 0, 0])
    }

    func test_heldDownArrow_overACodeBlock_neverGoesBack() throws {
        arrange(codeDocument)
        XCTAssertEqual(try walk("_moveDown:withHistory:", from: 0, presses: 4), [12, 13, 22, 22])
    }

    func test_heldUpArrow_fromUnderATable_visitsEveryRow() throws {
        arrange(tableDocument)
        XCTAssertEqual(try walk("_moveUp:withHistory:", from: 32, presses: 4), [24, 13, 0, 0])
    }

    /// x = 0 lies left of the table's first column: the nearest column is the first, not the last.
    func test_upIntoATable_fromTheLineStart_landsInTheFirstColumn() throws {
        arrange(tableDocument)
        let caret = try XCTUnwrap(try walk("_moveUp:withHistory:", from: 32, presses: 1).first)
        XCTAssertTrue((24...29).contains(caret), "↑ from the start of the line under the table went to \(caret)")
    }
}
