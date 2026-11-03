import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, typing a space or a punctuation mark INSIDE a link — with
/// linked text on both sides of the caret — splits the link in two: the typed character is unlinked
/// and the message gets two separate links to the same URL with a plain gap between them.
///
///     "abc  xyz" all linked → caret at 4 (between the two spaces) → type "is " on the keyboard
///       engine: [url "abc is"] " " [url " xyz"]
///       legacy: [url "abc is  xyz"]           (one link)
///     same, `insertText(" ")` / `insertText("!")` mid-link: the character is unlinked, the link splits
///
/// The typed-text policy's rule — "a link joins a word typed against it and stops at punctuation or
/// a space, otherwise a sentence typed after a URL is swallowed into it" — is right at a link's END;
/// in its interior there is nothing to swallow and the rule breaks the link instead. Autocorrect
/// inside a link hits it too (the space after the corrected word).
///
/// **How it was seen.** K1, 2026-09-23, eighth roam: software keyboard (`axe touch` on key rects)
/// 2× ("teh ", "is "), lldb `insertText:` 2× (space, "!"). Legacy control on the keyboard 1×.
///
/// **Suspected cause.** `attributesForTypedText(current:preceding:insertedText:)`
/// (`RichTextEngineEditorView+TypedText.swift`) looks only at the PRECEDING character's link; it does
/// not check whether the FOLLOWING character carries the same link (caret inside the link), which is
/// when the link should continue whatever is typed.
///
/// **Tier 1**: `insertText(_:)` on the engine view is the keyboard's typing entry point and the
/// policy decision is visible in the model; no real touches are needed.
final class HarnessLinkInteriorTypingTests: XCTestCase {
    private func typeInsideLink(_ text: String, at caret: Int) throws -> ChatInputContent {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        var linked = ChatInputInlineAttributes()
        linked.entity = .url("https://l.example")
        host.setInputContent(ChatInputContent(blocks: [HarnessEngine.paragraph("abc xyz", linked)]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let textView = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UIKeyInput),
                                     "precondition: the engine view is not a UIKeyInput")
        node.selectedRange = NSRange(location: caret, length: 0)
        HarnessEngine.settle(root)
        textView.insertText(text)
        HarnessEngine.settle(root)
        let content = node.currentInputContent().content
        _ = node.resignInputFirstResponder()
        return content
    }

    private func linkedText(_ content: ChatInputContent) -> String {
        return HarnessLegacy.text(in: content, where: { $0.entity != nil })
    }

    func testASpaceTypedInsideALinkKeepsOneLink() throws {
        let content = try self.typeInsideLink(" ", at: 4)
        XCTAssertEqual(content.plainText, "abc  xyz", "precondition: the space did not land")
        XCTAssertEqual(self.linkedText(content), "abc  xyz", "a space typed inside the link split it: \(content.blocks)")
    }

    func testPunctuationTypedInsideALinkKeepsOneLink() throws {
        let content = try self.typeInsideLink("!", at: 3)
        XCTAssertEqual(content.plainText, "abc! xyz", "precondition: the character did not land")
        XCTAssertEqual(self.linkedText(content), "abc! xyz", "punctuation typed inside the link split it: \(content.blocks)")
    }

    /// Control (the designed rule): a space typed at the link's END does not join it.
    func testControlASpaceTypedAtTheEndOfALinkIsNotLinked() throws {
        let content = try self.typeInsideLink(" ", at: 7)
        XCTAssertEqual(self.linkedText(content), "abc xyz", "control: a space typed after the link joined it: \(content.blocks)")
    }
}
