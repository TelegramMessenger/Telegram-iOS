import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-buttons Task 5 — `insertButtonRow()`, on the shared atom-unit placement.
@available(iOS 18.4, *)
final class EngineButtonRowCommandTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func shape() -> [String] {
        editor.document.blocks.map { block in
            switch block {
            case .paragraph: return "p"
            case .buttonRow: return "row"
            case .blockQuote: return "quote"
            case .details: return "details"
            case .table: return "table"
            case .media: return "media"
            case .code: return "code"
            case .pullQuote: return "pull"
            }
        }
    }
    private func firstRow() -> ButtonRowBlock? {
        for block in editor.document.blocks {
            if case let .buttonRow(row) = block { return row }
        }
        return nil
    }
    private func rowIndex() -> Int {
        editor.currentRoles.indices.first { editor.buttonRowShape(atRole: $0) != nil }!
    }
    private func rowCount() -> Int {
        editor.document.blocks.reduce(0) { if case .buttonRow = $1 { return $0 + 1 }; return $0 }
    }

    func test_anEmptyParagraphIsReplacedAndTheRowCarriesOneDefaultPill() {
        editor.document = Document(blocks: [para("p", "")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertButtonRow()
        XCTAssertEqual(shape(), ["row", "p"], "a trailing paragraph is minted — a row has nowhere to type")
        XCTAssertEqual(firstRow()?.buttons.count, 1)
        XCTAssertEqual(firstRow()?.buttons.first?.action, .url(""))
        XCTAssertEqual(firstRow()?.alignment, .justify)
    }

    func test_aCaretMidParagraphSplitsIt() {
        editor.document = Document(blocks: [para("p", "abcd")])
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.insertButtonRow()
        XCTAssertEqual(shape(), ["p", "row", "p"])
        XCTAssertEqual(editor.document.blocks[0].flatText, "ab")
        XCTAssertEqual(editor.document.blocks[2].flatText, "cd")
    }

    func test_aCaretInsideAQuoteMakesTheRowAChildOfThatQuote() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [para("c", "in")], author: [])),
        ])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertButtonRow()
        guard case let .blockQuote(quote) = editor.document.blocks[0] else { return XCTFail("\(shape())") }
        XCTAssertTrue(quote.children.contains { if case .buttonRow = $0 { return true }; return false },
                      "legacy refuses inside a quote; the engine places where the caret is")
    }

    func test_aCaretInACellPlacesTheRowAfterTheWholeTable() {
        editor.document = Document(blocks: [.table(TableBlock.empty(rows: 1, columns: 2)), para("a", "x")])
        let cell = editor.currentRoles.firstIndex { $0.owningTable != nil }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: cell), length: 0)
        editor.insertButtonRow()
        XCTAssertEqual(shape(), ["table", "row", "p"],
                       "never IN a cell — cellParagraph would drop it — and never a dead button either")
    }

    /// TWO run-loop events are REQUIRED for two undo groups: the private `UndoManager` uses default
    /// `groupsByEvent`, so typing and the insert issued in the same turn coalesce into ONE group and
    /// a single undo wipes both. Without the turn this test failed exactly that way, which is the
    /// test being wrong rather than the code — `EngineMediaUndoTests` spins the loop for the same
    /// reason.
    func test_theInsertIsOneUndoStepAndKeepsTheTypingBeforeIt() {
        editor.document = Document(blocks: [para("p", "")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertText("hello")
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        editor.insertButtonRow()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        XCTAssertEqual(shape(), ["p", "row", "p"])
        editor.engine.undoManager?.undo()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        XCTAssertEqual(shape(), ["p"])
        XCTAssertEqual(editor.document.blocks[0].flatText, "hello",
                       "insertTable's document set would have wiped this; insertMediaBlock's edit does not")
    }

    func test_theCaretLandsAfterTheRow() {
        editor.document = Document(blocks: [para("p", "")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertButtonRow()
        XCTAssertEqual(editor.engineSelectedRange.location,
                       editor.flatOffset(ofRoleAt: rowIndex()) + 2,
                       "one past the atom and its separator — the start of the trailing paragraph")
    }

    // MARK: - Backspace: the media walk, for a row

    private func rowOnly(_ id: String) -> Block {
        .buttonRow(ButtonRowBlock(id: BlockID(id), buttons: [ButtonRef(label: [], action: .url(""))]))
    }

    func test_pressOneFromTheParagraphBelowWalksIntoTheRow() {
        editor.document = Document(blocks: [rowOnly("r"), para("p", "after")])
        _ = editor.engine.becomeFirstResponder()
        let after = editor.currentRoles.firstIndex { $0.containerID == BlockID("p") }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: after), length: 0)
        editor.deleteBackward()
        let row = rowIndex()
        XCTAssertEqual(editor.engineSelectedRange.location,
                       editor.flatOffset(ofRoleAt: row) + editor.flatLength(ofRoleAt: row),
                       "press 1 walks INTO the unit; it does not delete")
        XCTAssertEqual(rowCount(), 1, "nothing deleted yet")
    }

    func test_pressTwoSelectsTheRowAndPressThreeDeletesIt() {
        editor.document = Document(blocks: [rowOnly("r"), para("p", "after")])
        _ = editor.engine.becomeFirstResponder()
        let after = editor.currentRoles.firstIndex { $0.containerID == BlockID("p") }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: after), length: 0)
        editor.deleteBackward()
        editor.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange, editor.flatRange(ofRoleAt: rowIndex()),
                       "press 2 selects the WHOLE row — pills are removed through the sheet, not here")
        editor.deleteBackward()
        XCTAssertEqual(rowCount(), 0, "press 3 deletes it")
    }

    func test_aCaretAtARowsStartTakesAGraphemeFromThePreviousSiblingParagraph() {
        editor.document = Document(blocks: [para("p", "ab"), rowOnly("r")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: rowIndex()), length: 0)
        editor.deleteBackward()
        XCTAssertEqual(editor.document.blocks[0].flatText, "a")
        XCTAssertEqual(rowCount(), 1, "the row itself is untouched")
    }

    func test_aCaretAtARowsStartSelectsAPrecedingRowInstead() {
        editor.document = Document(blocks: [rowOnly("r1"), rowOnly("r2")])
        _ = editor.engine.becomeFirstResponder()
        let first = editor.currentRoles.indices.first { editor.buttonRowShape(atRole: $0)?.id == BlockID("r1") }!
        let second = editor.currentRoles.indices.first { editor.buttonRowShape(atRole: $0)?.id == BlockID("r2") }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: second), length: 0)
        editor.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange, editor.flatRange(ofRoleAt: first),
                       "one atom kind reaches back to the other's — the generalisation, observed")
    }

    func test_aCaretAtARowsStartSelectsAPrecedingMediaAtom() {
        let audio = Block.media(MediaBlock(id: BlockID("a"),
                                           items: [MediaItem(mediaID: "m", kind: .audio,
                                                             naturalSize: Size2D(width: 0, height: 0))]))
        editor.document = Document(blocks: [audio, rowOnly("r")])
        _ = editor.engine.becomeFirstResponder()
        let atom = editor.currentRoles.firstIndex { if case .standalone(.media) = $0.position { return true }; return false }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: rowIndex()), length: 0)
        editor.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange, editor.flatRange(ofRoleAt: atom),
                       "the two kinds are one rule, so a row reaches back to a media atom")
    }

    // MARK: - The menu verbs and tap routing

    private func seededRow() -> ButtonRowBlock {
        ButtonRowBlock(id: BlockID("r"),
                       buttons: [ButtonRef(label: [TextRun(text: "A")], action: .url("https://a")),
                                 ButtonRef(label: [TextRun(text: "B")], action: .url("https://b"))],
                       alignment: .justify)
    }
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }

    func test_addingAButtonAppendsOnePill() {
        editor.document = Document(blocks: [.buttonRow(seededRow()), para("p", "")])
        editor.addButtonToRow(rowID: BlockID("r"))
        XCTAssertEqual(firstRow()?.buttons.count, 3)
    }

    func test_settingTheAlignmentIsOneUndoStep() {
        editor.document = Document(blocks: [.buttonRow(seededRow()), para("p", "")])
        _ = editor.engine.becomeFirstResponder()
        turn()
        editor.setButtonRowAlignment(rowID: BlockID("r"), .center)
        XCTAssertEqual(firstRow()?.alignment, .center)
        turn()
        editor.engine.undoManager?.undo()
        turn()
        XCTAssertEqual(firstRow()?.alignment, .justify)
    }

    func test_replacingAPillWithNilRemovesIt() {
        editor.document = Document(blocks: [.buttonRow(seededRow()), para("p", "")])
        editor.replaceButton(rowID: BlockID("r"), at: 0, with: nil)
        XCTAssertEqual(firstRow()?.buttons.map(\.labelText), ["B"])
    }

    func test_removingTheLastPillRemovesTheWholeRow() {
        editor.document = Document(blocks: [rowOnly("r"), para("p", "")])
        editor.replaceButton(rowID: BlockID("r"), at: 0, with: nil)
        XCTAssertEqual(rowCount(), 0, "as legacy does — a pill delete does not leave an empty row behind")
    }

    func test_deletingTheRowLeavesTheRestOfTheDocument() {
        editor.document = Document(blocks: [para("before", "x"), .buttonRow(seededRow()), para("p", "")])
        editor.deleteButtonRow(rowID: BlockID("r"))
        XCTAssertEqual(shape(), ["p", "p"])
        XCTAssertEqual(editor.document.blocks[0].flatText, "x")
    }

    func test_theMenuAffordanceAppearsOnlyWhenAHostIsListening() {
        editor.document = Document(blocks: [.buttonRow(seededRow()), para("p", "")])
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.buttonRowViews[BlockID("r")]?.menuButtonRect.isEmpty ?? false,
                      "no host wired: preservation-only, as the chat composer is")
        editor.onRequestButtonRowMenu = { _ in }
        editor.layoutIfNeeded()
        XCTAssertFalse(editor.buttonRowViews[BlockID("r")]?.menuButtonRect.isEmpty ?? true)
    }

    /// The affordance is part of the MEASUREMENT, not only the drawing: a row showing the control
    /// packs its pills into 34pt less width, so wiring a host must re-render live rows.
    func test_wiringTheMenuRepacksExistingRows() {
        editor.document = Document(blocks: [.buttonRow(seededRow()), para("p", "")])
        editor.layoutIfNeeded()
        let wide = editor.buttonRowViews[BlockID("r")]?.pillRect(0)?.width ?? 0
        editor.onRequestButtonRowMenu = { _ in }
        editor.layoutIfNeeded()
        let narrow = editor.buttonRowViews[BlockID("r")]?.pillRect(0)?.width ?? 0
        XCTAssertEqual(wide - narrow, 17.0, accuracy: 0.5,
                       "the 34pt reserve, split across two justified columns")
    }

    func test_aTapOnAPillAsksTheHostToEditIt() {
        editor.document = Document(blocks: [.buttonRow(seededRow()), para("p", "")])
        editor.layoutIfNeeded()
        var asked: (ButtonRef, Bool)?
        editor.onEditButtonRequested = { button, isBlockPill, _ in asked = (button, isBlockPill) }
        guard let view = editor.buttonRowViews[BlockID("r")], let rect = view.pillRect(1) else {
            return XCTFail("no row view")
        }
        let point = editor.engine.convert(CGPoint(x: rect.midX, y: rect.midY), from: view)
        XCTAssertTrue(editor.handleButtonRowTapIfNeeded(atPointInEngine: point))
        XCTAssertEqual(asked?.0.labelText, "B")
        XCTAssertEqual(asked?.1, true, "isBlockPill")
    }

    func test_aTapOnTheControlOpensTheRowMenu() {
        editor.document = Document(blocks: [.buttonRow(seededRow()), para("p", "")])
        var opened = false
        editor.onRequestButtonRowMenu = { _ in opened = true }
        editor.layoutIfNeeded()
        guard let view = editor.buttonRowViews[BlockID("r")] else { return XCTFail("no row view") }
        let rect = view.menuButtonRect
        let point = editor.engine.convert(CGPoint(x: rect.midX, y: rect.midY), from: view)
        XCTAssertTrue(editor.handleButtonRowTapIfNeeded(atPointInEngine: point))
        XCTAssertTrue(opened)
    }

    func test_aTapOutsideEveryRowIsNotTheRowsToHandle() {
        editor.document = Document(blocks: [.buttonRow(seededRow()), para("p", "text")])
        editor.onEditButtonRequested = { _, _, _ in XCTFail("not a pill") }
        editor.layoutIfNeeded()
        XCTAssertFalse(editor.handleButtonRowTapIfNeeded(atPointInEngine: CGPoint(x: 10, y: 400)))
    }

    /// The rule having a CALLER is pinned separately from the rule working. A hit-test rule with a
    /// passing test and no caller is a defect this project has already paid for once — the details
    /// chevron shipped exactly that way.
    func test_theRowViewCarriesATapRecogniserAndRefusesTextInteraction() {
        editor.document = Document(blocks: [.buttonRow(seededRow()), para("p", "")])
        editor.layoutIfNeeded()
        guard let view = editor.buttonRowViews[BlockID("r")] else { return XCTFail("no row view") }
        XCTAssertTrue(view.isUserInteractionEnabled)
        XCTAssertEqual(view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.count, 1)
        let inside = CGPoint(x: view.frame.midX, y: view.frame.midY)
        XCTAssertFalse(editor.textInteractionMayBegin(at: inside),
                       "a tap on a row is the host's, so the engine must not also place a caret")
    }

    /// A pill edit fires ONE `onChange`, not two.
    ///
    /// `applyButtonRowShape` used to call `deliverChangeNotificationNow()` after
    /// `performHostStructuralChange`, which already delivers exactly one — so every pill edit notified
    /// twice from the day the rung landed, with no test to say so. `applyMediaShape`, which it
    /// mirrors, never had that line.
    func test_aPillEditFiresExactlyOneChangeNotification() {
        editor.document = Document(blocks: [rowOnly("r")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.setButtonRowAlignment(rowID: BlockID("r"), .center)
        XCTAssertEqual(changes, 1)
    }
}
