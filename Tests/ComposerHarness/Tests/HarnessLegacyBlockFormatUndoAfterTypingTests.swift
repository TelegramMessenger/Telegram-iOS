import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, Format ▸ Quote and Format ▸ Code are undoable only while
/// they are the LAST step. Typing anything afterwards removes the Quote/Code step from the undo
/// stack: undo reverts the typing, then `canUndo` is false and the quote stays for good.
///
///     "…lazy dog." → select "jumps" (20..<25) → Format ▸ Quote → caret at 2 → type "ZZ"
///       → undo → "ZZ" removed (correct), canUndo = false; undo again does nothing, quote stays
///     same with Format ▸ Code: identical
///     control, Format ▸ Bold instead: undo, undo → typing then bold reverted
///
/// The seventh roam's fix (`performUndoableTextChange`) documents that Quote/Code "drop the OLDER
/// typing steps"; what is observed is worse — the Quote/Code step itself is dropped by the NEXT edit,
/// so a quote cannot be undone once the user has typed a character. In a mixed sequence (Bold,
/// type, Italic, Return, Spoiler, Strike, Quote, type, Underline, Backspace, Monospace) undo-all
/// on legacy reverts only the last command.
///
/// **How it was seen.** K1, 2026-09-23, eighth roam: `formatAttributesQuote:` /
/// `formatAttributesCodeBlock:` / `formatAttributesBold:` on the panel, `insertText:` and the text
/// view's `undoManager` through lldb. Seen 2× Quote (isolated + inside an 11-step sequence), 1×
/// Code, Bold control 1×.
///
/// **Suspected cause.** A Quote/Code command changes CHARACTERS (it inserts line breaks) through the
/// text storage inside `ChatInputTextView.performUndoableTextChange(_:)`; the restore step it
/// registers targets the text view, and UIKit's text input drops/clears it when the next typing
/// step is recorded after an external character change (the same mechanism the fix measured for
/// older typing steps). The attribute-only commands (Bold …) do not trigger it.
///
/// **Tier 1**: the commands are the panel's own actions, `insertText(_:)` is the keyboard's typing
/// entry point, and the stack is the text view's `undoManager`.
final class HarnessLegacyBlockFormatUndoAfterTypingTests: XCTestCase {
    private func assertBlockFormatSurvivesLaterTyping(_ what: String, _ apply: (HarnessLegacy.Arranged) -> Void) throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let original = "The quick brown fox jumps over the lazy dog."
        let value = try HarnessLegacy.arrange(HarnessContent.plainText(original))
        arranged = value

        HarnessLegacy.select(value, NSRange(location: 20, length: 5))
        apply(value)
        HarnessEngine.settle(value.root)
        XCTAssertGreaterThan(HarnessLegacy.content(value).blocks.count, 1, "precondition: \(what) was not applied")

        value.textView.selectedRange = NSRange(location: 2, length: 0)
        HarnessEngine.settle(value.root)
        value.textView.insertText("ZZ")
        HarnessEngine.settle(value.root)
        let undoManager = try XCTUnwrap(value.textView.undoManager)

        undoManager.undo()
        HarnessEngine.settle(value.root)
        XCTAssertFalse(HarnessLegacy.content(value).plainText.contains("ZZ"), "precondition: undo did not revert the typing")
        XCTAssertTrue(undoManager.canUndo, "typing after \(what) removed the \(what) step from the undo stack")
        undoManager.undo()
        HarnessEngine.settle(value.root)
        let content = HarnessLegacy.content(value)
        XCTAssertEqual(content.blocks.count, 1, "undo did not revert \(what): \(content.blocks)")
        XCTAssertEqual(content.plainText, original, "undo of \(what) did not restore the text")
    }

    func testQuoteIsStillUndoableAfterTyping() throws {
        try self.assertBlockFormatSurvivesLaterTyping("Quote", { $0.host.panel.formatAttributesQuote(self) })
    }

    func testCodeIsStillUndoableAfterTyping() throws {
        try self.assertBlockFormatSurvivesLaterTyping("Code", { $0.host.panel.formatAttributesCodeBlock(self) })
    }
}
