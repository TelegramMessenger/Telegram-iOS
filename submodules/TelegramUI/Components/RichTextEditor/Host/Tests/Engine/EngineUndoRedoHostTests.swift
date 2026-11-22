import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The article editor's toolbar Undo / Redo pair — `currentState().canUndo`/`canRedo` and the two
/// verbs they gate (`RichTextEditorProtocol`), which the engine answered with two constants and two
/// traps until R10-undo.
///
/// The stack underneath is the editor's own (`+UndoStack.swift`), and the sibling suites reach it
/// through `engine.undoManager`, which is pointed at it — so ⌘Z and these verbs are one object.
/// What this suite is about is the HOST SURFACE on top: that the availability the toolbar reads is
/// a real read, that it is accurate at the moment the host is told to re-read it, and that a
/// composition is part of the run it was typed into. Granularity itself is certified against a
/// stock `UITextView` in `EngineTypingUndoParityTests`.
@available(iOS 18.4, *)
final class EngineUndoRedoHostTests: XCTestCase {
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
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    private func texts() -> [String] { editor.engine.attributedBlocks.map { $0.string } }
    private func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }

    // MARK: - Availability is a real read

    /// **Nothing is undoable before an edit — including a caret move.**
    ///
    /// This is the one answer the constants got right by accident, and the one that is easiest to
    /// get wrong once they become reads: legacy keeps a PRIVATE per-canvas `UndoManager`
    /// specifically so UIKit's own selection registrations cannot surface as "undo is available on
    /// the first tap, before anything was typed" (package CLAUDE.md, device-observed). The engine
    /// reads the text-input controller's manager instead, so the same question has to be asked of
    /// it directly rather than assumed.
    func test_nothingIsUndoableBeforeAnEdit() {
        load([para("p0", "alpha"), para("p1", "beta")])
        caret(3)
        turn()
        XCTAssertFalse(editor.currentState().canUndo, "a caret move is not an edit")
        XCTAssertFalse(editor.currentState().canRedo)
        editor.engineSelectedRange = NSRange(location: 0, length: 5)
        turn()
        XCTAssertFalse(editor.currentState().canUndo, "selecting is not an edit")
        XCTAssertFalse(editor.currentState().canRedo)
    }

    func test_typingMakesUndoAvailableAndTheHostVerbRevertsIt() {
        load([para("p0", "alpha")])
        caret(5)
        editor.engine.insertText("X")
        turn()
        XCTAssertEqual(texts(), ["alphaX"])
        XCTAssertTrue(editor.currentState().canUndo, "typing recorded nothing")
        XCTAssertFalse(editor.currentState().canRedo)

        editor.undo()
        turn()
        XCTAssertEqual(texts(), ["alpha"])
        XCTAssertTrue(editor.currentState().canRedo, "the undone edit is not redoable")
    }

    func test_redoReappliesWhatUndoReverted() {
        load([para("p0", "alpha")])
        caret(5)
        editor.engine.insertText("X")
        turn()
        editor.undo()
        turn()
        XCTAssertEqual(texts(), ["alpha"])

        editor.redo()
        turn()
        XCTAssertEqual(texts(), ["alphaX"])
        XCTAssertTrue(editor.currentState().canUndo)
        XCTAssertFalse(editor.currentState().canRedo, "nothing is left to redo")
    }

    // MARK: - The host is told to re-read AFTER the stack has settled

    /// **The availability the host reads from the verb's own `onChange` is the FINAL one.**
    ///
    /// The legacy editor documents this as a shipped defect and fires a trailing `onChange` after
    /// `UndoManager.undo()` returns to close it: the undo closure's own refresh runs WHILE STILL
    /// INSIDE `undo()`, so a host that re-reads availability from it sees the stack before the
    /// manager finished popping the group — stale for the LAST undo, whose button then stays
    /// enabled with nothing behind it.
    ///
    /// Asserted on the LAST delivery rather than the count, because the count is a policy this
    /// suite has no opinion about; what the toolbar needs is that the last thing it was told is
    /// true.
    func test_theLastChangeNotificationOfAnUndoReportsTheSettledAvailability() {
        load([para("p0", "alpha")])
        caret(5)
        editor.engine.insertText("X")
        turn()

        var seen: [Bool] = []
        editor.onChange = { [weak editor] in seen.append(editor?.currentState().canUndo ?? true) }
        editor.undo()
        XCTAssertFalse(seen.isEmpty, "undo told the host nothing, so the toolbar never re-reads")
        XCTAssertEqual(seen.last, false, "the host was last told undo is still available")
    }

    func test_theLastChangeNotificationOfARedoReportsTheSettledAvailability() {
        load([para("p0", "alpha")])
        caret(5)
        editor.engine.insertText("X")
        turn()
        editor.undo()
        turn()

        var seen: [Bool] = []
        editor.onChange = { [weak editor] in seen.append(editor?.currentState().canRedo ?? true) }
        editor.redo()
        XCTAssertFalse(seen.isEmpty, "redo told the host nothing")
        XCTAssertEqual(seen.last, false, "the host was last told redo is still available")
    }

    // MARK: - Structural commands

    /// A command that rebuilds through the document setter registers ONE entry that restores the
    /// whole pre-command document (`recordUndoStepForStructuralChange`). The toolbar's Undo must reach
    /// it like any other.
    func test_undoOfAStructuralCommandRestoresTheDocument() {
        load([para("p0", "alpha")])
        let before = editor.document
        caret(5)
        editor.insertTable(rows: 2, cols: 2)
        turn()
        XCTAssertTrue(editor.document.blocks.contains { if case .table = $0 { return true } else { return false } },
                      "the table never landed, so this proves nothing about undoing it")
        XCTAssertTrue(editor.currentState().canUndo)

        editor.undo()
        turn()
        XCTAssertEqual(editor.document, before)
    }

    // MARK: - A composition, and who closes it

    /// **A composition is part of the run it was typed into — one undo, like a stock text view.**
    ///
    /// This used to cost one step MORE than stock, and the extra step moved no text: UIKit registers
    /// a fresh operation for each marked-text update, so the composition never folded into what
    /// preceded it, and `normalisePresentation` restyling the composed text added an entry of its
    /// own. Both were properties of a stack made of UIKit's text operations.
    ///
    /// The editor's own stack (`+UndoStack.swift`) has neither problem: a composition's updates
    /// continue the open run explicitly, and presentation is derived on the way back in rather than
    /// registered. So typing `X` and composing `か` is one run and one undo, which is what the stock
    /// oracle does with the same input.
    ///
    /// The composition must still be CLOSED by the undo — replaying around a live one would strand
    /// it — and that half the engine supplies, measured: the end state is identical with an
    /// `unmarkText()` first and without one.
    func test_aCompositionIsPartOfTheRunItWasTypedInto() {
        load([para("p0", "alpha")])
        caret(5)
        editor.engine.insertText("X")
        turn()
        editor.engine.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        turn()
        XCTAssertNotNil(editor.engine.markedTextRange, "no composition open, so this proves nothing")
        XCTAssertEqual(texts(), ["alphaXか"])

        editor.undo()
        turn()
        XCTAssertNil(editor.engine.markedTextRange, "undo left a composition open")
        XCTAssertEqual(texts(), ["alpha"], "the typed run and its composition did not come back together")
        XCTAssertFalse(editor.currentState().canUndo, "the run was more than one step")
    }

    /// A multi-step composition is still ONE step: an IME sends `setMarkedText:` per keystroke, and
    /// each replaces the last, so without an explicit rule every `かんじ` would step back through
    /// `かん` and `か`. Measured as exactly that before the editor owned its stack.
    func test_aMultiStepCompositionIsStillOneStep() {
        load([para("p0", "alpha")])
        caret(5)
        editor.engine.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        turn()
        editor.engine.setMarkedText("かん", selectedRange: NSRange(location: 2, length: 0))
        turn()
        editor.engine.setMarkedText("かんじ", selectedRange: NSRange(location: 3, length: 0))
        turn()
        XCTAssertEqual(texts(), ["alphaかんじ"])

        editor.undo()
        turn()
        XCTAssertEqual(texts(), ["alpha"], "undo stepped back through the composition's own states")
    }

    // MARK: - The empty stack

    /// The buttons are gated on the pair above, so this is unreachable from the UI — but the verb
    /// is public and a host may call it, and an empty-stack undo that trapped or edited would be a
    /// defect the gate merely hides.
    func test_undoAndRedoOnAnEmptyStackChangeNothing() {
        load([para("p0", "alpha")])
        caret(5)
        let before = editor.document
        editor.undo()
        editor.redo()
        turn()
        XCTAssertEqual(editor.document, before)
        XCTAssertEqual(texts(), ["alpha"])
    }
}
