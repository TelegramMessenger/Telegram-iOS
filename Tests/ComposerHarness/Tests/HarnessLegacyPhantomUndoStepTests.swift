import XCTest
import UIKit
import TelegramCore
@testable import ComposerHarnessLib

/// **What broke.** A first fix for the legacy format-shortcut undo (2026-10-12) made the legacy node's
/// `performUndoableInputChange` run its body through `ChatInputTextView.performUndoableTextChange`. The
/// panel syncs EVERY keystroke and caret move through the chat's `updateTextInputStateAndMode`, which
/// wraps the sync in that call, and with a custom emoji in the draft the echo never compares equal —
/// `ChatTextInputTextCustomEmojiAttribute.isEqual` is identity and the echo builds fresh ones — so each
/// caret move registered an empty undo step: an undo press that changed nothing, and a cleared redo.
///
/// **How it was seen.** Review of that fix wave, traced through `chatInputTextNodeDidChangeSelection` →
/// `updateTextInputStateAndMode` → `performUndoableTextChange` → `registerTextRestore`.
///
/// **Tier 1**: the panel's own sync path and the text view's `undoManager`, as the chat runs them.
final class HarnessLegacyPhantomUndoStepTests: XCTestCase {
    func testACaretMoveRegistersNoUndoStepWithACustomEmojiInTheDraft() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let emoji = ChatInputInlineAttributes(entity: .customEmoji(fileId: 5_000_000_001, file: nil, enableAnimation: true))
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(runs: [
            ChatInputRun(text: "Hi ", attributes: ChatInputInlineAttributes()),
            ChatInputRun(text: "😀", attributes: emoji),
            ChatInputRun(text: " there", attributes: ChatInputInlineAttributes()),
        ]))])
        let value = try HarnessLegacy.arrange(content)
        arranged = value
        let undoManager = try XCTUnwrap(value.textView.undoManager)

        let end = (value.textView.text as NSString).length
        HarnessLegacy.select(value, NSRange(location: end, length: 0))
        HarnessEngine.settle(value.root)
        value.textView.insertText("!")
        HarnessEngine.settle(value.root)
        XCTAssertTrue(HarnessLegacy.content(value).plainText.hasSuffix("!"), "precondition: the typing landed")

        HarnessLegacy.select(value, NSRange(location: 1, length: 0))
        HarnessEngine.settle(value.root)
        HarnessLegacy.select(value, NSRange(location: 2, length: 0))
        HarnessEngine.settle(value.root)

        undoManager.undo()
        HarnessEngine.settle(value.root)
        XCTAssertFalse(HarnessLegacy.content(value).plainText.contains("!"),
                       "the first undo after two caret moves changed nothing: a caret move registered an undo step")
    }
}
