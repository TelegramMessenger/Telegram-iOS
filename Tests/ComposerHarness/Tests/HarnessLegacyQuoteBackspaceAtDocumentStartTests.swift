import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, Backspace at the start of a quote unquotes that paragraph
/// (the seventh roam's fix) — except when the quote starts the document, where it does nothing. That
/// is the commonest case: quote the whole message, then try to take the quote off.
///
///     "First paragraph.\nSecond paragraph." → Select All → Format ▸ Quote → caret at 0 → Backspace
///       legacy: [quote "First paragraph." / "Second paragraph."]   (unchanged)
///       engine: [p "First paragraph."] [quote "Second paragraph."] (oracle)
///     control — quote after a plain paragraph, caret at its start → Backspace
///       legacy: unquoted (the fix works there)
///
/// **How it was seen.** K1, 2026-09-23, eighth roam (sweep of the quote-Backspace fix):
/// `formatAttributesQuote:` on the panel and `deleteBackward` on the `ChatInputTextView` through
/// lldb, model from the readout. Seen 2× legacy; engine oracle 1×.
///
/// **Suspected cause.** `ChatTextInputPanelNode.unquoteParagraphOnBackspaceAtBlockStart()` guards on
/// `selection.location > 0` and on the character before the caret being a line break, so a block
/// that starts at offset 0 is never considered.
///
/// **Tier 1**: `deleteBackward()` on the text view is the keyboard's Backspace; the model is read
/// from the panel's input state.
final class HarnessLegacyQuoteBackspaceAtDocumentStartTests: XCTestCase {
    private func quotedText(_ content: ChatInputContent) -> String {
        var quoted = ""
        for block in content.blocks {
            if case let .blockQuote(quote) = block {
                quoted += quote.content.plainText
            }
        }
        return quoted
    }

    func testBackspaceAtTheStartOfAQuoteThatStartsTheDocumentUnquotesItsFirstParagraph() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText("First paragraph.\nSecond paragraph."))
        arranged = value

        HarnessLegacy.select(value, NSRange(location: 0, length: 34))
        value.host.panel.formatAttributesQuote(self)
        HarnessEngine.settle(value.root)
        XCTAssertTrue(self.quotedText(HarnessLegacy.content(value)).contains("First paragraph."),
                      "precondition: the quote was not applied: \(HarnessLegacy.content(value).blocks)")

        value.textView.selectedRange = NSRange(location: 0, length: 0)
        HarnessEngine.settle(value.root)
        value.textView.deleteBackward()
        HarnessEngine.settle(value.root)

        let content = HarnessLegacy.content(value)
        XCTAssertEqual(content.plainText, "First paragraph.\nSecond paragraph.", "Backspace at offset 0 changed the text")
        XCTAssertFalse(self.quotedText(content).contains("First paragraph."),
                       "Backspace at the start of a quote at the document start left its first paragraph quoted: \(content.blocks)")
        XCTAssertTrue(self.quotedText(content).contains("Second paragraph."),
                      "the rest of the quote should stay quoted: \(content.blocks)")
    }
}
