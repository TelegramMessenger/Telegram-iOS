import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, Backspace at the START of a quote that follows a plain
/// paragraph pulls that paragraph INTO the quote: the joined line is drawn quoted and the model
/// (what is sent) quotes text the user never quoted. Undo brings the line break back but not the
/// paragraph's un-quoted state (both lines stay inside the quote).
///
///     "First paragraph.\nSecond paragraph." → Format ▸ Quote on "Second paragraph." → caret before
///     "Second" → Backspace
///       legacy: [quote "First paragraph.Second paragraph."]         ← "First paragraph." now quoted
///       engine: [p "First paragraph."] [p "Second paragraph."]      (the quote unwraps)
///
///     "Alpha line.\nBeta line.\nSecond paragraph." with "Beta line." quoted → Backspace before "Beta"
///       legacy: [quote "Alpha line.Beta line."] [p "Second paragraph."]
///
/// Either outcome that leaves the preceding paragraph unquoted is acceptable: unwrapping the quote
/// (the engine's rule) or joining the quote's text onto the plain paragraph. Absorbing the plain
/// paragraph into the quote is not.
///
/// **How it was seen.** K1, 2026-09-23, seventh roam: the panel's `formatAttributesQuote:` and the
/// text view's `deleteBackward` through lldb; the screenshot shows the whole joined line inside the
/// quote bar. Seen 2× (two- and three-paragraph documents); engine oracle unwraps.
///
/// **Suspected cause.** Deleting the "\n" leaves one text paragraph whose characters are only partly
/// quote-attributed; the panel's edit path (`chatInputTextNode(shouldChangeTextIn:)`) rebuilds the
/// state through `chatInputContent(from:)`, which classifies a paragraph containing any quoted
/// characters as a quote, and the state pushed back re-attributes the whole line.
///
/// **Tier 1**: `deleteBackward()` on the text view is the keyboard's Backspace.
final class HarnessLegacyQuoteBackspaceTests: XCTestCase {
    func testBackspaceAtTheStartOfAQuoteDoesNotQuoteThePreviousParagraph() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText("First paragraph.\nSecond paragraph."))
        arranged = value

        HarnessLegacy.select(value, NSRange(location: 17, length: 17))
        value.host.panel.formatAttributesQuote(self)
        HarnessEngine.settle(value.root)
        guard HarnessLegacy.content(value).blocks.count == 2, case .blockQuote = HarnessLegacy.content(value).blocks[1] else {
            return XCTFail("precondition: the quote was not applied: \(HarnessLegacy.content(value).blocks)")
        }

        value.textView.selectedRange = NSRange(location: 17, length: 0)
        HarnessEngine.settle(value.root)
        value.textView.deleteBackward()
        HarnessEngine.settle(value.root)

        let content = HarnessLegacy.content(value)
        var quoted = ""
        for block in content.blocks {
            if case let .blockQuote(quote) = block {
                quoted += quote.content.plainText
            }
        }
        XCTAssertFalse(quoted.contains("First paragraph."),
                       "Backspace at the start of the quote pulled the plain paragraph into it: \(content.blocks)")
    }
}
