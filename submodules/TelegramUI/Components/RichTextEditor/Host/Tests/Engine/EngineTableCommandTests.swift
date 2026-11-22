import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-tables rung A — the table the caret is in, the state read off it, and the five commands.
///
/// The four state fields this pins were not merely unimplemented: they were CONSTANTS justified by
/// "the bridge TRAPS on `Block.table`", which stopped being true at R7-nesting. A constant justified
/// by a trap outlives the trap, and nothing in the type system says so.
@available(iOS 18.4, *)
final class EngineTableCommandTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    // MARK: Fixtures

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    /// A 2x2 table whose cells read "a" "b" / "c" "d".
    private func table(_ id: String = "t") -> Block {
        var built = TableBlock.empty(rows: 2, columns: 2)
        built.id = BlockID(id)
        let texts = [["a", "b"], ["c", "d"]]
        for r in 0..<2 {
            for c in 0..<2 {
                built.rows[r].cells[c].blocks = [para("\(id)-\(r)\(c)", texts[r][c])]
            }
        }
        return .table(built)
    }

    /// The flat offset of the first cell of the table with this id.
    private func firstCellOffset(ofTable id: String) -> Int {
        guard let index = editor.currentRoles.firstIndex(where: { $0.owningTable?.id == BlockID(id) })
        else { XCTFail("no table \(id) in roles"); return 0 }
        return editor.flatOffset(ofRoleAt: index)
    }

    private func putCaretInFirstCell(ofTable id: String = "t") {
        editor.engineSelectedRange = NSRange(location: firstCellOffset(ofTable: id), length: 0)
    }

    // MARK: State

    func test_theCaretInACellIsInATable() {
        editor.document = Document(blocks: [para("p", "before"), table()])
        putCaretInFirstCell()
        XCTAssertTrue(editor.currentState().isInTable)
    }

    func test_theCaretInAParagraphIsNotInATable() {
        editor.document = Document(blocks: [para("p", "before"), table()])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        XCTAssertFalse(editor.currentState().isInTable)
    }

    /// Legacy's rule is `isInsideTable(head) || isInsideTable(anchor)` — a selection that merely
    /// OVERLAPS a table still enables the table commands.
    func test_aSelectionWithOneEndpointInTheTableCounts() {
        editor.document = Document(blocks: [para("p", "before"), table()])
        _ = editor.engine.becomeFirstResponder()
        let cell = firstCellOffset(ofTable: "t")
        editor.engineSelectedRange = NSRange(location: 2, length: cell - 2 + 1)
        XCTAssertTrue(editor.currentState().isInTable)
    }

    func test_theFlagsAreReadFromTheTable() {
        editor.document = Document(blocks: [table()])
        putCaretInFirstCell()
        XCTAssertFalse(editor.currentState().isTableCompact)
        XCTAssertTrue(editor.currentState().isTableBordered)
    }

    /// Legacy's own defaults outside a table: not compact, and bordered TRUE.
    func test_theFlagsTakeLegacysDefaultsOutsideATable() {
        editor.document = Document(blocks: [para("p", "text")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        XCTAssertFalse(editor.currentState().isTableCompact)
        XCTAssertTrue(editor.currentState().isTableBordered)
    }

    // MARK: selectionIsTextOnly

    func test_aPlainTextSelectionIsTextOnly() {
        editor.document = Document(blocks: [para("p", "abcd")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 0, length: 4)
        XCTAssertTrue(editor.currentState().selectionIsTextOnly)
    }

    func test_anEmptySelectionIsNotTextOnly() {
        editor.document = Document(blocks: [para("p", "abcd")])
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        XCTAssertFalse(editor.currentState().selectionIsTextOnly)
    }

    func test_aSelectionOverAMediaBlockIsNotTextOnly() {
        editor.document = Document(blocks: [
            para("p", "ab"),
            .media(MediaBlock(id: BlockID("m"), items: [MediaItem(mediaID: "x", kind: .image,
                                                                  naturalSize: Size2D(width: 100, height: 50))])),
        ])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 0, length: editor.engine.attributedBlocks[0].length + 2)
        XCTAssertFalse(editor.currentState().selectionIsTextOnly)
    }

    /// A button row is text-free in exactly the way a media block is; legacy predates it, so its own
    /// rule names only media and tables.
    func test_aSelectionOverAButtonRowIsNotTextOnly() {
        editor.document = Document(blocks: [
            para("p", "ab"),
            .buttonRow(ButtonRowBlock(id: BlockID("r"), buttons: [ButtonRef(label: [], action: .url(""))])),
        ])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 0, length: editor.engine.attributedBlocks[0].length + 2)
        XCTAssertFalse(editor.currentState().selectionIsTextOnly)
    }

    func test_aSelectionWithAnEndpointInACellIsNotTextOnly() {
        editor.document = Document(blocks: [para("p", "before"), table()])
        _ = editor.engine.becomeFirstResponder()
        let cell = firstCellOffset(ofTable: "t")
        editor.engineSelectedRange = NSRange(location: 2, length: cell - 2 + 1)
        XCTAssertFalse(editor.currentState().selectionIsTextOnly)
    }

    // MARK: Toggles

    private func tableBlock(_ id: String = "t") -> TableBlock? {
        guard let block = editor.document.blocksByID[BlockID(id)], case let .table(table) = block
        else { return nil }
        return table
    }

    func test_bordersToggleOffAndBackOn() {
        editor.document = Document(blocks: [table()])
        putCaretInFirstCell()
        editor.toggleTableBordered()
        XCTAssertEqual(tableBlock()?.bordered, false)
        XCTAssertFalse(editor.currentState().isTableBordered)
        editor.toggleTableBordered()
        XCTAssertEqual(tableBlock()?.bordered, true)
    }

    func test_compactTogglesOnAndBackOff() {
        editor.document = Document(blocks: [table()])
        putCaretInFirstCell()
        editor.toggleTableCompact()
        XCTAssertEqual(tableBlock()?.compact, true)
        XCTAssertTrue(editor.currentState().isTableCompact)
        editor.toggleTableCompact()
        XCTAssertEqual(tableBlock()?.compact, false)
    }

    /// THE reason the toggles are a role plan rather than a document swap: `insertTable`'s
    /// `recordUndoStepForStructuralChange` CLEARS the undo history, so a borders toggle would throw away
    /// everything typed before it. Undoing the toggle must restore the flag AND leave the typing.
    func test_undoingAToggleKeepsEarlierTyping() {
        editor.document = Document(blocks: [table()])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        putCaretInFirstCell()
        editor.engine.insertText("Z")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        editor.toggleTableBordered()
        XCTAssertEqual(tableBlock()?.bordered, false)

        editor.engine.undoManager?.undo()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(tableBlock()?.bordered, true, "the toggle is undone")
        XCTAssertTrue(tableBlock()?.rows[0].cells[0].blocks.map(blockPlainText).joined().contains("Z") ?? false,
                      "and the typing before it survives — the undo history was not cleared")
    }

    func test_aToggleFiresExactlyOneChangeNotification() {
        editor.document = Document(blocks: [table()])
        putCaretInFirstCell()
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.toggleTableCompact()
        XCTAssertEqual(changes, 1)
    }

    func test_aToggleLeavesNoPresentationDrift() {
        editor.document = Document(blocks: [table()])
        putCaretInFirstCell()
        editor.toggleTableBordered()
        editor.layoutIfNeeded()
        guard let run = editor.roleRun(ofTableWithID: BlockID("t")) else { return XCTFail("no run") }
        for index in run {
            XCTAssertEqual(editor.presentationDrift(atBlock: index), [], "role \(index) drifted")
        }
    }

    // MARK: deleteTable

    private func blockKinds() -> [String] {
        editor.document.blocks.map { block in
            switch block {
            case .paragraph: return "p"
            case .table: return "table"
            case .blockQuote: return "quote"
            case .code: return "code"
            case .media: return "media"
            case .buttonRow: return "row"
            case .details: return "details"
            case .pullQuote: return "pull"
            }
        }
    }

    func test_deletingATableLeavesItsNeighboursIntact() {
        editor.document = Document(blocks: [para("p0", "before"), table(), para("p1", "after")])
        putCaretInFirstCell()
        editor.deleteTable()
        XCTAssertEqual(blockKinds(), ["p", "p"])
        XCTAssertEqual(editor.document.blocks.map(blockPlainText), ["before", "after"])
    }

    /// The engine always holds at least one block, so a document that is ONLY a table becomes one
    /// empty paragraph — `deleteButtonRow`'s rescue, and legacy's "never leave a stack with zero
    /// blocks".
    func test_deletingTheOnlyTableLeavesOneEmptyParagraph() {
        editor.document = Document(blocks: [table()])
        putCaretInFirstCell()
        editor.deleteTable()
        XCTAssertEqual(blockKinds(), ["p"])
        XCTAssertEqual(editor.document.blocks.map(blockPlainText), [""])
    }

    func test_deletingATableInsideAQuoteLeavesTheQuoteAlive() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [para("c", "kept"), table()], author: [])),
        ])
        putCaretInFirstCell()
        editor.deleteTable()
        guard case let .blockQuote(quote) = editor.document.blocks[0] else { return XCTFail("\(blockKinds())") }
        XCTAssertTrue(quote.children.contains { $0.id == BlockID("c") })
        XCTAssertFalse(quote.children.contains { $0.id == BlockID("t") })
    }

    func test_deletingATableFiresExactlyOneChangeNotification() {
        editor.document = Document(blocks: [para("p0", "before"), table()])
        putCaretInFirstCell()
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.deleteTable()
        XCTAssertEqual(changes, 1)
    }

    // MARK: convertCurrentTableToText

    /// One body paragraph per ROW, the row's cells joined by " " — Core's `tableFlattenedText`, which
    /// legacy uses for this AND for the plain-text pasteboard flavour, so the two cannot drift.
    func test_convertingATableYieldsOneParagraphPerRow() {
        editor.document = Document(blocks: [table()])
        putCaretInFirstCell()
        editor.convertCurrentTableToText()
        XCTAssertEqual(blockKinds(), ["p", "p"])
        XCTAssertEqual(editor.document.blocks.map(blockPlainText), ["a b", "c d"])
    }

    func test_convertingKeepsTheNeighbours() {
        editor.document = Document(blocks: [para("p0", "before"), table(), para("p1", "after")])
        putCaretInFirstCell()
        editor.convertCurrentTableToText()
        XCTAssertEqual(editor.document.blocks.map(blockPlainText), ["before", "a b", "c d", "after"])
    }

    /// A table of empty cells still becomes paragraphs — the block is not lost.
    func test_convertingAnEmptyTableYieldsEmptyParagraphs() {
        editor.document = Document(blocks: [.table(TableBlock.empty(rows: 2, columns: 2))])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.convertCurrentTableToText()
        XCTAssertEqual(blockKinds(), ["p", "p"])
    }

    func test_convertingFiresExactlyOneChangeNotification() {
        editor.document = Document(blocks: [table()])
        putCaretInFirstCell()
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.convertCurrentTableToText()
        XCTAssertEqual(changes, 1)
    }

    // MARK: copyCurrentTable

    final class FakePasteboard: EnginePasteboard {
        var items: [[String: Any]] = []
        func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any]) {
            self.items = items
        }
    }

    /// The private fragment UTI must carry the table WITH its cell text. Reading the SHAPE instead of
    /// the materialised block would put an empty grid here and look right in a debugger.
    func test_copyingATableWritesAllThreeRepresentations() throws {
        let pasteboard = FakePasteboard()
        editor.pasteboard = pasteboard
        editor.document = Document(blocks: [table()])
        putCaretInFirstCell()
        editor.copyCurrentTable()

        let item = try XCTUnwrap(pasteboard.items.first)
        XCTAssertNotNil(item[RichTextEditorClipboard.fragmentUTI])
        XCTAssertNotNil(item["public.rtf"])
        XCTAssertEqual(item["public.utf8-plain-text"] as? String, "a b\nc d")

        let data = try XCTUnwrap(item[RichTextEditorClipboard.fragmentUTI] as? Data)
        let restored = try DocumentCodec.decode(data)
        guard case let .table(restoredTable) = restored.blocks[0] else { return XCTFail("not a table") }
        XCTAssertEqual(restoredTable.rows[0].cells.map { $0.blocks.map(blockPlainText).joined() }, ["a", "b"])
    }

    /// A copy is a pure read: one that shows up in the undo stack is a defect a user reports as
    /// "undo did nothing".
    func test_copyingRegistersNoUndoStepAndFiresNoChange() {
        let pasteboard = FakePasteboard()
        editor.pasteboard = pasteboard
        editor.document = Document(blocks: [table()])
        putCaretInFirstCell()
        editor.engine.undoManager?.removeAllActions()
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.copyCurrentTable()
        XCTAssertEqual(changes, 0)
        XCTAssertEqual(editor.engine.undoManager?.canUndo, false)
    }

    // MARK: Refusals

    /// Spec §6: a command with the caret outside a table changes nothing AND registers no undo step —
    /// legacy makes the same point about `mergeSelectedCells`, "the single-cell check runs BEFORE
    /// `editing { }` so a no-op can't register a step".
    func test_everyCommandNoOpsOutsideATable() {
        let pasteboard = FakePasteboard()
        editor.pasteboard = pasteboard
        editor.document = Document(blocks: [para("p", "text"), table()])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        let before = editor.document
        editor.engine.undoManager?.removeAllActions()
        var changes = 0
        editor.onChange = { changes += 1 }

        editor.toggleTableBordered()
        editor.toggleTableCompact()
        editor.deleteTable()
        editor.convertCurrentTableToText()
        editor.copyCurrentTable()

        XCTAssertEqual(editor.document.blocks.count, before.blocks.count)
        XCTAssertEqual(editor.document.blocks.map(blockPlainText), before.blocks.map(blockPlainText))
        XCTAssertEqual(tableBlock()?.bordered, true)
        XCTAssertEqual(tableBlock()?.compact, false)
        XCTAssertEqual(changes, 0)
        XCTAssertEqual(editor.engine.undoManager?.canUndo, false)
        XCTAssertTrue(pasteboard.items.isEmpty)
    }
}
