import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, REDO puts the caret where it was when the user pressed
/// undo, not after the redone text. Type at the end, tap elsewhere, undo (correct: the caret returns
/// to the undone insertion), redo: the character comes back, but the caret jumps to the unrelated
/// place the user had tapped before undoing:
///
///     "…lazy dog." caret 44 → type "A" → move caret to 4 → undo (caret 44, correct) → redo
///     engine: text "…dog.A", selection 4..<4       legacy / UITextView: selection 45..<45
///
/// A caret move AFTER the undo does not matter: undo, move to 10, redo still lands on 4, the caret of
/// the undo moment. Without any caret move (type, undo, redo) the engine is correct (45), and so is an
/// undo/redo of a mid-text insertion made with no move between the edit and the undo.
///
/// **How it was seen.** K1, 2026-09-23, fifth roam, regression sweep of the undo-caret fix: three
/// times on the engine, sending `insertText:` / `setSelectedTextRange:` / `undoManager undo|redo` to
/// the engine text view through lldb — the calls the keyboard, a tap and shake/⌘Z make. Legacy
/// control, identical steps: 45..<45.
///
/// **Suspected cause.** A side effect of the undo-caret fix: `refreshUndoBaselineSelection()`
/// (`RichTextEngineEditorView+UndoStack.swift`) keeps the undo baseline's selection live across caret
/// moves, and the undo step then registers its REDO counterpart with that live selection (the caret
/// at the moment undo was pressed) instead of the selection the undone edit produced.
///
/// **Tier 1**: the calls are exactly the ones UIKit makes, and the selection is readable in-process.
/// A stock `UITextView` driven the same way is the oracle, so the expectation is measured.
final class HarnessRedoCaretTests: XCTestCase {
    private static let text = "The quick brown fox jumps over the lazy dog."

    /// What a stock text view does with the same steps: the selection after redoing the insertion.
    private func stockSelectionAfterRedo(in root: HarnessRootViewController) -> NSRange? {
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 320.0, height: 120.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        guard textView.becomeFirstResponder() else {
            return nil
        }
        textView.text = Self.text
        textView.selectedRange = NSRange(location: 44, length: 0)
        HarnessEngine.settle(root, seconds: 0.1)
        textView.insertText("A")
        HarnessEngine.settle(root, seconds: 0.1)
        textView.selectedRange = NSRange(location: 4, length: 0)
        HarnessEngine.settle(root, seconds: 0.1)
        textView.undoManager?.undo()
        HarnessEngine.settle(root, seconds: 0.1)
        textView.undoManager?.redo()
        HarnessEngine.settle(root, seconds: 0.1)
        return textView.selectedRange
    }

    func testRedoPutsTheCaretAfterTheRedoneText() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        let oracle = self.stockSelectionAfterRedo(in: root)
        XCTAssertEqual(oracle, NSRange(location: 45, length: 0),
                       "control: a stock UITextView no longer puts the caret after the redone insertion")

        host.setInputContent(HarnessContent.plainText(Self.text))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let view = try HarnessEngine.textView(in: root)
        let keyInput = try XCTUnwrap(view as? UIKeyInput)
        let undoManager = try XCTUnwrap(view.undoManager, "precondition: the engine view has no undo manager")

        node.selectedRange = NSRange(location: 44, length: 0)
        HarnessEngine.settle(root)
        keyInput.insertText("A")
        HarnessEngine.settle(root)

        // The caret move under test: a tap elsewhere before pressing undo.
        node.selectedRange = NSRange(location: 4, length: 0)
        HarnessEngine.settle(root)

        undoManager.undo()
        HarnessEngine.settle(root)
        XCTAssertEqual(node.currentInputContent().content.plainText, Self.text, "precondition: undo did not remove the A")
        XCTAssertEqual(node.selectedRange, NSRange(location: 44, length: 0),
                       "precondition: undo did not return the caret to the undone insertion")

        undoManager.redo()
        HarnessEngine.settle(root)
        XCTAssertEqual(node.currentInputContent().content.plainText, Self.text + "A", "precondition: redo did not restore the A")
        XCTAssertEqual(node.selectedRange, NSRange(location: 45, length: 0),
                       "redo put the caret where it was when undo was pressed, not after the redone text")

        _ = node.resignInputFirstResponder()
    }
}
