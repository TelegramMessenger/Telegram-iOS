import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **Suspected defect, NOT reproduced.** The fix for `HarnessUndoCaretTests` keeps the undo
/// baseline's selection live on a caret move, but only for a move made with no edit in flight
/// (`refreshUndoBaselineSelection()`, `RichTextEngineEditorView+UndoStack.swift`, whose guard skips
/// `isDecidingAtGate`). The concern was that a caret move made BY THE SURFACE GATE — Return on a
/// code block's language line vetoes the newline and parks the caret at the body's start — would
/// therefore never reach the baseline, so undoing the next typing would put the caret back on the
/// language line:
///
///     language "swift" → caret at the end of "swift" → Return (caret into the body)
///     → type "x" → undo: expected caret at the body start (where "x" went)
///
/// **Why it does not happen.** Every gate veto settles before it returns
/// (`installTextInputGate`, `+SurfaceGate.swift`: `.veto` → `settleAfterEdit()`), and settle ends
/// with `commitUndoSnapshotAfterSettle()`, which takes the LIVE selection — the one the gate just
/// set. So the baseline the next edit registers already holds the gate's caret. Measured green with
/// no code change, both from a pre-set language and from a language typed in the same run (an open
/// typing run the gate's move does not end: the body insert is not contiguous with it, so it still
/// opens a step of its own). Also measured, not pinned: the code body's double-Return exit, a
/// pull quote's double-Return exit and a details title's Return — all restored the caret to where
/// the undone typing happened.
///
/// Kept as a regression pin: if settle ever stops running on a veto, or stops committing the live
/// selection, these fail.
///
/// **Tier 1**: `insertText("\n")` / `insertText("x")` on the engine view and `undoManager.undo()`
/// are the calls the keyboard and the system undo make. A stock `UITextView` driven through the same
/// "caret move, type, undo" is the oracle.
final class HarnessGateCaretUndoTests: XCTestCase {
    /// Stock behaviour for the shape under test: a caret move, one typed character, undo.
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
        textView.text = "Intro\nswift\nlet x = 1"
        textView.selectedRange = NSRange(location: 11, length: 0)
        HarnessEngine.settle(root, seconds: 0.1)
        textView.selectedRange = NSRange(location: 12, length: 0)
        HarnessEngine.settle(root, seconds: 0.1)
        textView.insertText("x")
        HarnessEngine.settle(root, seconds: 0.1)
        textView.undoManager?.undo()
        HarnessEngine.settle(root, seconds: 0.1)
        return textView.selectedRange
    }

    private func engineSelection(_ input: UITextInput) -> NSRange? {
        guard let range = input.selectedTextRange else { return nil }
        let location = input.offset(from: input.beginningOfDocument, to: range.start)
        let length = input.offset(from: range.start, to: range.end)
        return NSRange(location: location, length: length)
    }

    func testUndoAfterReturnOnTheLanguageLineRestoresTheCaretInTheBody() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        XCTAssertEqual(self.stockSelectionAfterUndo(in: root), NSRange(location: 12, length: 0),
                       "control: a stock UITextView no longer puts the caret at the undone insertion")

        // Engine axis: "Intro" 0..<5, "\n", the language line "swift" 6..<11, "\n", the body at 12.
        host.setInputContent(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro"),
            .code(ChatInputCode(language: "swift", runs: [ChatInputRun(text: "let x = 1")])),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let textView = try HarnessEngine.textView(in: root)
        let input = try XCTUnwrap(textView as? (UITextInput & UIKeyInput))
        let undoManager = try XCTUnwrap(textView.undoManager, "precondition: the engine view has no undo manager")

        let languageEnd = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: 11))
        input.selectedTextRange = input.textRange(from: languageEnd, to: languageEnd)
        HarnessEngine.settle(root)
        XCTAssertEqual(self.engineSelection(input), NSRange(location: 11, length: 0),
                       "precondition: the caret is not at the end of the language line")

        // The keyboard's Return: the gate moves the caret into the body and edits nothing.
        input.insertText("\n")
        HarnessEngine.settle(root)
        XCTAssertEqual(self.engineSelection(input), NSRange(location: 12, length: 0),
                       "precondition: Return on the language line did not move the caret into the body")
        XCTAssertEqual(node.currentInputContent().content.plainText, "Intro\nlet x = 1",
                       "precondition: Return on the language line edited the document")

        input.insertText("x")
        HarnessEngine.settle(root)
        XCTAssertEqual(node.currentInputContent().content.plainText, "Intro\nxlet x = 1",
                       "precondition: typing did not land at the start of the body")

        undoManager.undo()
        HarnessEngine.settle(root)
        XCTAssertEqual(node.currentInputContent().content.plainText, "Intro\nlet x = 1", "undo did not remove the x")
        XCTAssertEqual(self.engineSelection(input), NSRange(location: 12, length: 0),
                       "undo put the caret where the caret was BEFORE the gate moved it, not where the undone edit happened")

        _ = node.resignInputFirstResponder()
    }

    /// The same Return with a typing run still open on the language line: the run is not ended by
    /// the gate's caret move, and the body insert must still be its own step restoring the body caret.
    func testUndoAfterTypingALanguageAndReturnRestoresBothCaretsInOrder() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        // Engine axis: "Intro" 0..<5, "\n", the (empty) language line at 6, "\n", the body at 7.
        host.setInputContent(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro"),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")])),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let textView = try HarnessEngine.textView(in: root)
        let input = try XCTUnwrap(textView as? (UITextInput & UIKeyInput))
        let undoManager = try XCTUnwrap(textView.undoManager, "precondition: the engine view has no undo manager")

        let languageStart = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: 6))
        input.selectedTextRange = input.textRange(from: languageStart, to: languageStart)
        HarnessEngine.settle(root)
        for character in "swift" {
            input.insertText(String(character))
            HarnessEngine.settle(root, seconds: 0.15)
        }
        XCTAssertEqual(self.engineSelection(input), NSRange(location: 11, length: 0),
                       "precondition: typing did not reach the end of the language line")

        input.insertText("\n")
        HarnessEngine.settle(root)
        XCTAssertEqual(self.engineSelection(input), NSRange(location: 12, length: 0),
                       "precondition: Return on the language line did not move the caret into the body")

        input.insertText("x")
        HarnessEngine.settle(root)
        XCTAssertEqual(node.currentInputContent().content.plainText, "Intro\nxlet x = 1",
                       "precondition: typing did not land at the start of the body")

        undoManager.undo()
        HarnessEngine.settle(root)
        XCTAssertEqual(node.currentInputContent().content.plainText, "Intro\nlet x = 1", "undo did not remove the x")
        XCTAssertEqual(self.engineSelection(input), NSRange(location: 12, length: 0),
                       "undo put the caret where the caret was BEFORE the gate moved it, not where the undone edit happened")

        undoManager.undo()
        HarnessEngine.settle(root)
        XCTAssertEqual(self.engineSelection(input), NSRange(location: 6, length: 0),
                       "the second undo should take back the typed language and restore the caret where it began")

        _ = node.resignInputFirstResponder()
    }
}
