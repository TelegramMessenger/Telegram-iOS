import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, undoing a text edit puts the caret back where the
/// PREVIOUS edit left it, not where the undone edit happened. Type at the end of the text, tap
/// somewhere else, type one character, undo: the character goes away, but the caret jumps back to
/// the end of the text (and the composer scrolls there) instead of staying where the user was
/// typing:
///
///     "…lazy dog." caret 44 → type "A" (caret 45) → move caret to 4 → type "X" (caret 5) → undo
///     engine: text restored, selection 45..<45     legacy / UITextView: selection 4..<4
///
/// The same stale caret follows every structural edit made after a caret move: Return at 20 (or 30,
/// or at the end of a quote) undid to the caret of the edit before it (11, 17), never to the place
/// Return was pressed.
///
/// **How it was seen.** K1, 2026-09-22, three times on the engine (plain paragraph ×2, Return in a
/// quote ×1), with `insertText:` / `undo` sent to the engine text view — the calls the keyboard and
/// shake/⌘Z make. Legacy control, identical steps: selection 4..<4.
///
/// **Suspected cause.** `RichTextEngineEditorView+UndoStack.swift`: an edit that opens a new run
/// registers `lastSettledUndoSnapshot`, whose selection is the one the last SETTLED EDIT left. A
/// caret move is not an edit, so it never refreshes that snapshot; the undo step therefore restores
/// the document correctly and the selection of an older moment. (The inline-format variant of the
/// same staleness was fixed by `recordingInlineFormatStep`; text edits still take this path.)
///
/// **Tier 1**: `insertText(_:)` on the engine view and `undoManager.undo()` are the exact calls the
/// keyboard and the system undo make, and the selection is readable in-process. A stock
/// `UITextView` driven the same way is the oracle, so the expectation is measured, not assumed.
final class HarnessUndoCaretTests: XCTestCase {
    /// What a stock text view does with the same steps: the selection after undoing an insertion.
    private func stockSelectionAfterUndo(in root: HarnessRootViewController) -> NSRange? {
        let textView = UITextView(frame: CGRect(x: 0.0, y: 100.0, width: 320.0, height: 120.0))
        root.view.addSubview(textView)
        defer {
            textView.resignFirstResponder()
            textView.removeFromSuperview()
        }
        guard textView.becomeFirstResponder() else {
            return nil
        }
        textView.text = "The quick brown fox jumps over the lazy dog."
        textView.selectedRange = NSRange(location: 44, length: 0)
        HarnessEngine.settle(root, seconds: 0.1)
        textView.insertText("A")
        HarnessEngine.settle(root, seconds: 0.1)
        textView.selectedRange = NSRange(location: 4, length: 0)
        HarnessEngine.settle(root, seconds: 0.1)
        textView.insertText("X")
        HarnessEngine.settle(root, seconds: 0.1)
        textView.undoManager?.undo()
        HarnessEngine.settle(root, seconds: 0.1)
        return textView.selectedRange
    }

    func testUndoRestoresTheCaretWhereTheUndoneEditHappened() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        let oracle = self.stockSelectionAfterUndo(in: root)
        XCTAssertEqual(oracle, NSRange(location: 4, length: 0),
                       "control: a stock UITextView no longer puts the caret at the undone insertion")

        host.setInputContent(HarnessContent.plainText("The quick brown fox jumps over the lazy dog."))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let keyInput = try XCTUnwrap(try HarnessEngine.textView(in: root) as? UIKeyInput)
        let undoManager = try XCTUnwrap(try HarnessEngine.textView(in: root).undoManager,
                                        "precondition: the engine view has no undo manager")

        node.selectedRange = NSRange(location: 44, length: 0)
        HarnessEngine.settle(root)
        keyInput.insertText("A")
        HarnessEngine.settle(root)

        // The caret move under test: a tap elsewhere, then one character.
        node.selectedRange = NSRange(location: 4, length: 0)
        HarnessEngine.settle(root)
        keyInput.insertText("X")
        HarnessEngine.settle(root)
        XCTAssertEqual(node.currentInputContent().content.plainText,
                       "The Xquick brown fox jumps over the lazy dog.A", "precondition: typing did not land")

        undoManager.undo()
        HarnessEngine.settle(root)
        XCTAssertEqual(node.currentInputContent().content.plainText,
                       "The quick brown fox jumps over the lazy dog.A", "undo did not remove the X")
        XCTAssertEqual(node.selectedRange, NSRange(location: 4, length: 0),
                       "undo put the caret where the PREVIOUS edit left it, not where the undone edit happened")

        _ = node.resignInputFirstResponder()
    }
}
