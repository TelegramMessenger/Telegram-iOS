import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, pasting the composer's own clipboard (Copy/Cut write
/// `private.telegramtext` + RTF) empties the undo stack: the paste cannot be undone, and nor can
/// anything typed before it. A plain-text paste (another app's string) is undoable.
///
///     "…lazy dog." → type "X" at the end (canUndo = true) → select "quick" → Copy
///       → caret at 0 → Paste
///       legacy: "quickThe quick…X", canUndo = false; undo does nothing
///       plain-text control (pasteboard := "hello"): canUndo = true, undo removes "hello "
///
/// The same happens for a formatted Cut + Paste (bold/italic kept, per the Cut fix, but the paste
/// wipes the history), and applies to every paste that `chatInputTextNodeShouldPaste` takes itself:
/// `private.telegramtext`, RTF/RTFD from other apps, and the custom-emoji marker reattach.
///
/// **How it was seen.** K1, 2026-09-23, eighth roam (sweep of the Format-undo and Cut fixes):
/// `insertText:`, `copy:`/`cut:` and `paste:` on the `ChatInputTextView` through lldb, then its
/// `undoManager` (`canUndo`, `undo`). Seen 2× (plain copy of "quick", formatted cut of
/// "quick brown"), plain-text control 1×.
///
/// **Suspected cause.** `ChatTextInputPanelNode.chatInputTextNodeShouldPaste()` applies these
/// pastes through `updateTextInputStateAndMode { current.replacingFlatRange(…) }`; the chat pushes the
/// new state back with `updateInputTextState`, which assigns the text view's `attributedText` — and a
/// programmatic set clears UITextView's undo stack. The Format commands were fixed by wrapping them
/// in `ChatInputTextView.performUndoableTextChange(_:)`; the paste path was not wrapped.
/// Shared with upstream.
///
/// **Tier 1**: the paste is the text view's own `paste(_:)` routed to the panel, the pasteboard is
/// written by this process before it is read (no paste prompt), and the stack is the text view's
/// `undoManager`.
final class HarnessLegacyRichPasteUndoTests: XCTestCase {
    func testPastingTheComposersOwnCopyIsUndoable() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText("The quick brown fox jumps over the lazy dog."))
        arranged = value

        value.textView.selectedRange = NSRange(location: 44, length: 0)
        HarnessEngine.settle(value.root)
        value.textView.insertText("X")
        HarnessEngine.settle(value.root)
        let undoManager = try XCTUnwrap(value.textView.undoManager)
        XCTAssertTrue(undoManager.canUndo, "precondition: typing registered no undo step")

        HarnessLegacy.select(value, NSRange(location: 4, length: 5))
        _ = value.textView.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessEngine.settle(value.root)
        XCTAssertNotNil(UIPasteboard.general.data(forPasteboardType: "private.telegramtext"),
                        "precondition: the legacy copy did not write the composer's own pasteboard type")

        HarnessLegacy.select(value, NSRange(location: 0, length: 0))
        _ = value.textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(value.root)
        XCTAssertTrue(HarnessLegacy.content(value).plainText.hasPrefix("quickThe quick"),
                      "precondition: the paste did not land: \(HarnessLegacy.content(value).plainText)")

        XCTAssertTrue(undoManager.canUndo, "pasting the composer's own copy emptied the undo stack")
        undoManager.undo()
        HarnessEngine.settle(value.root)
        XCTAssertEqual(HarnessLegacy.content(value).plainText, "The quick brown fox jumps over the lazy dog.X",
                       "undo did not revert exactly the paste")
    }

    /// Control: a plain-text paste (not taken by the panel) keeps UIKit's own undo step.
    func testControlAPlainTextPasteIsUndoable() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText("The quick brown fox jumps over the lazy dog."))
        arranged = value

        UIPasteboard.general.string = "hello"
        HarnessLegacy.select(value, NSRange(location: 0, length: 0))
        _ = value.textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(value.root)
        let undoManager = try XCTUnwrap(value.textView.undoManager)
        XCTAssertTrue(undoManager.canUndo, "control: a plain-text paste registered no undo step")
        undoManager.undo()
        HarnessEngine.settle(value.root)
        XCTAssertEqual(HarnessLegacy.content(value).plainText, "The quick brown fox jumps over the lazy dog.",
                       "control: undo did not revert the plain-text paste")
    }
}
