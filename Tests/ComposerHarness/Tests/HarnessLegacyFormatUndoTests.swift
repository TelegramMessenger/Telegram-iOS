import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, any Format-menu command empties the undo stack. The
/// command cannot be undone, and neither can anything typed before it:
///
///     "…lazy dog." → type "X" at the end (canUndo = true) → select "quick" → Format ▸ Bold
///       legacy: canUndo = false; undo does nothing, the bold and the "X" both stay
///       engine: canUndo = true; undo reverts the bold, a second undo the "X"
///
/// Seen for Bold and Italic; Quote and Link go through the same path.
///
/// **How it was seen.** K1, 2026-09-23, seventh roam: `insertText:` on the `ChatInputTextView`, the
/// panel's `formatAttributesBold:` / `formatAttributesItalic:` through lldb, then the text view's
/// `undoManager` (`canUndo`, `undo`, `redo`). Seen 2× (Bold, Italic).
///
/// **Suspected cause.** Legacy applies a Format command by computing a new input state
/// (`chatTextInputAddFormattingAttribute`) and handing it up through `updateTextInputStateAndMode`;
/// the chat pushes it back with `updateInputTextState`, which ASSIGNS the text view's
/// `attributedText`. A `UITextView` clears its undo stack on a programmatic `attributedText` set.
/// The fix would register the change with the text view's `undoManager` (or apply it through the
/// text storage inside an undo grouping) instead of replacing the text wholesale.
///
/// **Tier 1**: the command is the panel's own action and the stack is the text view's `undoManager`,
/// both readable in-process; the defect needs no real touches.
final class HarnessLegacyFormatUndoTests: XCTestCase {
    private func assertFormatIsUndoable(_ what: String, _ apply: (HarnessLegacy.Arranged) -> Void,
                                        applied: (ChatInputInlineAttributes) -> Bool) throws {
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
        apply(value)
        HarnessEngine.settle(value.root)
        XCTAssertEqual(HarnessLegacy.text(in: HarnessLegacy.content(value), where: applied), "quick",
                       "precondition: \(what) was not applied")

        XCTAssertTrue(undoManager.canUndo, "\(what) emptied the undo stack")
        undoManager.undo()
        HarnessEngine.settle(value.root)
        let content = HarnessLegacy.content(value)
        XCTAssertEqual(HarnessLegacy.text(in: content, where: applied), "", "undo did not revert \(what): \(content.blocks)")
        XCTAssertTrue(content.plainText.hasSuffix("dog.X"), "undo of \(what) also reverted the typing: \(content.plainText)")
    }

    func testBoldIsUndoable() throws {
        try self.assertFormatIsUndoable("Bold", { $0.host.panel.formatAttributesBold(self) }, applied: { $0.bold })
    }

    func testItalicIsUndoable() throws {
        try self.assertFormatIsUndoable("Italic", { $0.host.panel.formatAttributesItalic(self) }, applied: { $0.italic })
    }
}
