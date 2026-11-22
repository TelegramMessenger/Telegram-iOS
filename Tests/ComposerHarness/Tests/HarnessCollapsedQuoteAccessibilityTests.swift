import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke.** VoiceOver reads a custom emoji inside a FOLDED quote as an attachment character. The p14
/// fix gives every atom a text reading (a custom emoji reads as its alt text), and a folded quote reads as
/// its preview text — but the preview's own string holds each custom emoji as `U+FFFC`, so the reading
/// carries the bare character: `[p "a"] [quote folded [p "quoted " 😀]] [p "b"]` → `accessibilityValue`
/// `"a\nquoted \u{FFFC}\nb"`. Expanded, the same quote reads `"quoted 😀"` (control).
///
/// **How it was seen.** p19 roam, 2026-09-25: a probe comparing every fuzz starting document's
/// `accessibilityValue` with the model and the engine text.
///
/// **Suspected cause.** `accessibilityReading(of:)` (`RichTextEngineEditorView+Accessibility.swift`)
/// answers a `CollapsedQuoteTextAttachment` with `previewText.string` and does not read the preview's own
/// attachments the way `accessibilityText()` reads the engine's.
///
/// **Tier 1**: the engine view's `accessibilityValue`, which the host answers itself (the in-process AX
/// bundle is not needed for it; `HarnessAccessibilityTests`).
@available(iOS 18.4, *)
final class HarnessCollapsedQuoteAccessibilityTests: XCTestCase {
    private typealias E = HarnessEdited

    private func value(collapsed: Bool) throws -> String {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        driver.arrange(ChatInputContent(blocks: [
            E.paragraph([E.run("a")]),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("quoted "), E.emoji()])]), collapsed: collapsed)),
            E.paragraph([E.run("b")]),
        ]))
        return driver.view.accessibilityValue ?? ""
    }

    func testAFoldedQuotesCustomEmojiReadsAsItsText() throws {
        let value = try self.value(collapsed: true)
        XCTAssertFalse(value.contains("\u{FFFC}"), "VoiceOver reads an attachment character: \(fuzzEscaped(value))")
        XCTAssertTrue(value.contains("quoted 😀"), fuzzEscaped(value))
    }

    /// Control: the same quote expanded.
    func testControlAnExpandedQuotesCustomEmojiReadsAsItsText() throws {
        let value = try self.value(collapsed: false)
        XCTAssertFalse(value.contains("\u{FFFC}"), fuzzEscaped(value))
        XCTAssertTrue(value.contains("quoted 😀"), fuzzEscaped(value))
    }
}
