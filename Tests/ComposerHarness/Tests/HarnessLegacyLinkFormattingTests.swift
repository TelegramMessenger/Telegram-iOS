import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, Format ▸ Link strips every other attribute from the linked
/// text, and inside a QUOTE that includes the quote itself, so the quote is cut in three and line
/// breaks are inserted into the text:
///
///     "The quick brown fox…" → "quick brown" Bold → select "quick" → Link https://telegram.org
///       legacy: [url] "quick" [b] " brown"          ← "quick" is no longer bold
///       engine: [b,url] "quick" [b] " brown"
///
///     "First paragraph.\nSecond paragraph." → quote "Second paragraph." → select "paragraph" → Link
///       legacy: [p "First paragraph."] [quote "Second "] [p url"paragraph"] [quote "."]
///               text "First paragraph.\nSecond \nparagraph\n."   ← two line breaks inserted
///
/// Removing a link (the prompt's Remove) goes through the same stripping. Italic + link: italic lost.
///
/// **How it was seen.** K1, 2026-09-23, seventh roam: `formatAttributesLink:` through lldb, the
/// harness link alert answered by triggering its Apply action, model from the readout. Bold ×1,
/// italic ×1, quote split ×1; the engine keeps bold (oracle).
///
/// **Suspected cause.** `chatTextInputAddLinkAttribute` / `chatTextInputRemoveLinkAttribute`
/// (`ChatPresentationInterfaceState/Sources/ChatTextFormat.swift`) queue EVERY attribute key found in
/// the range for removal (`attributesToRemove.append((key, nsRange))` for any key other than
/// `textUrl`) — bold, italic, spoiler and the block-quote attribute alike. The state is then rebuilt
/// with `chatInputContent(from:)`, which turns the un-quoted middle into its own paragraph. Only an
/// existing `textUrl` should be removed. The harness's link path mirrors `openLinkEditing` in
/// `ChatControllerLoadDisplayNode.swift:3874-3878`, which calls the same two functions.
///
/// **Tier 1**: the command and the link answer are in-process (`linkPromptOverride`); the loss is in
/// the input state.
final class HarnessLegacyLinkFormattingTests: XCTestCase {
    private func link(_ value: HarnessLegacy.Arranged, _ url: String) {
        value.root.linkPromptOverride = { _, _ in url }
        defer { value.root.linkPromptOverride = nil }
        value.host.panel.formatAttributesLink(self)
        HarnessEngine.settle(value.root)
    }

    func testLinkingBoldTextKeepsItBold() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText("The quick brown fox jumps over the lazy dog."))
        arranged = value

        HarnessLegacy.select(value, NSRange(location: 4, length: 11))
        value.host.panel.formatAttributesBold(self)
        HarnessEngine.settle(value.root)
        HarnessLegacy.select(value, NSRange(location: 4, length: 5))
        self.link(value, "https://telegram.org")

        let content = HarnessLegacy.content(value)
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.entity == .url("https://telegram.org") }), "quick",
                       "precondition: the link was not applied: \(content.blocks)")
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.bold }), "quick brown",
                       "Link stripped the bold from the linked text: \(content.blocks)")
    }

    func testLinkingTextInsideAQuoteKeepsTheQuoteWhole() throws {
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

        HarnessLegacy.select(value, NSRange(location: 24, length: 9))
        self.link(value, "https://telegram.org")

        let content = HarnessLegacy.content(value)
        XCTAssertEqual(content.plainText, "First paragraph.\nSecond paragraph.",
                       "Link inside a quote changed the text: \(content.blocks)")
        XCTAssertEqual(content.blocks.count, 2, "Link inside a quote split the quote: \(content.blocks)")
        if content.blocks.count == 2, case let .blockQuote(quote) = content.blocks[1] {
            XCTAssertEqual(HarnessLegacy.text(in: quote.content, where: { $0.entity == .url("https://telegram.org") }), "paragraph",
                           "the link is not inside the quote: \(content.blocks)")
        } else {
            XCTFail("the second block is no longer a quote: \(content.blocks)")
        }
    }
}
