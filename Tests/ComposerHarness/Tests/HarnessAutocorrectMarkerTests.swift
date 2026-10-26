import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, an AUTOCORRECTED word typed inside a spoiler or an inline-code
/// (Monospace) run loses that marker; bold, italic and strikethrough survive the same correction.
///
///     "abc" → Format ▸ Spoiler → caret at the end → type " teh  " on the software keyboard
///       engine: [sp "abc "] "the. "        (Bold / Italic / Strikethrough: [b "abc the. "] …)
///     same, " xyz " (iOS corrects it to "cuz"): [sp "abc "] "cuz "
///     control, " xyz" before the space (no correction yet): [sp "abc xyz"]
///     accepting a predictive suggestion (" hel" → "he'll ") in a spoiler: [sp "abc "] "he'll "
///       (the same in bold keeps it: [b "abc held "])
///
/// So typing continues the spoiler (the typed-text policy's `markersThatAlwaysContinue`) and the
/// keyboard's correction then replaces the word with UNmarked text: the corrected word is revealed
/// in a message the user spoilered, or drops out of inline code.
///
/// **How it was seen.** K1, 2026-09-23, eighth roam, software keyboard driven by `axe touch` on the
/// key rects: spoiler 2× (" teh  ", " xyz "), monospace 2×, bold / italic / strikethrough controls.
/// Reduced to `replaceRange(_:withText:)` — what the keyboard sends to accept a correction — which
/// gives the same result in-process (spoiler lost, bold kept).
///
/// **Suspected cause.** `engine.typedTextAttributePolicy` (`RichTextEngineEditorView+TypedText.swift`)
/// copies the host markers forward for text INSERTED at the caret; a `replaceRange:withText:` over
/// a word takes its attributes from the engine's allowed typing attributes (font, colour, the four
/// traits), which carry bold/italic/strike but not `.rtSpoiler` / `.rtInlineCode`, and the policy is
/// not applied (or sees the replaced range, not the run) for a replacement.
///
/// **Tier 1**: `replaceRange(_:withText:)` on the engine's `UITextInput` view is the keyboard's own
/// correction entry point; autocorrect itself needs the software keyboard, which the hosted runner
/// does not have, and nothing else about the defect depends on real touches.
final class HarnessAutocorrectMarkerTests: XCTestCase {
    private func replaceLastWord(format: (ChatInputInlineAttributes) -> ChatInputInlineAttributes) throws -> ChatInputContent {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: [HarnessEngine.paragraph("abc xyz", format(ChatInputInlineAttributes()))]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let textView = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UITextInput),
                                     "precondition: the engine view is not a UITextInput")
        node.selectedRange = NSRange(location: 7, length: 0)
        HarnessEngine.settle(root)

        let start = try XCTUnwrap(textView.position(from: textView.beginningOfDocument, offset: 4))
        let end = try XCTUnwrap(textView.position(from: textView.beginningOfDocument, offset: 7))
        let range = try XCTUnwrap(textView.textRange(from: start, to: end))
        textView.replace(range, withText: "cuz")
        HarnessEngine.settle(root)
        let content = node.currentInputContent().content
        _ = node.resignInputFirstResponder()
        XCTAssertEqual(content.plainText, "abc cuz", "precondition: the replacement did not land")
        return content
    }

    private func text(_ content: ChatInputContent, where predicate: (ChatInputInlineAttributes) -> Bool) -> String {
        return HarnessLegacy.text(in: content, where: predicate)
    }

    func testACorrectedWordKeepsTheSpoiler() throws {
        let content = try self.replaceLastWord(format: { var a = $0; a.spoiler = true; return a })
        XCTAssertEqual(self.text(content, where: { $0.spoiler }), "abc cuz",
                       "the corrected word lost the spoiler: \(content.blocks)")
    }

    func testACorrectedWordKeepsInlineCode() throws {
        let content = try self.replaceLastWord(format: { var a = $0; a.monospace = true; return a })
        XCTAssertEqual(self.text(content, where: { $0.monospace }), "abc cuz",
                       "the corrected word lost inline code: \(content.blocks)")
    }

    /// NOT a control, although the roam wrote it as one: on K1 an autocorrected word kept its bold,
    /// but a programmatic `replace(_:withText:)` — the UITextInput call this reduction uses, and what
    /// dictation, text replacement and some keyboards issue — drops bold as well (controller,
    /// 2026-09-23). A stock UITextView gives the replacement the replaced text's attributes.
    func testACorrectedWordKeepsBold() throws {
        let content = try self.replaceLastWord(format: { var a = $0; a.bold = true; return a })
        XCTAssertEqual(self.text(content, where: { $0.bold }), "abc cuz",
                       "the corrected word lost bold: \(content.blocks)")
    }
}
