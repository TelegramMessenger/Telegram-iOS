import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, Cut puts only plain text on the pasteboard, so cutting and
/// pasting formatted text drops the formatting (bold, italic, spoiler, links, quotes). Copy of the
/// same selection writes `private.telegramtext` + RTF + plain text and pastes back formatted.
///
///     "quick" Italic → select "quick" → Cut → caret at the end → Paste
///       legacy: "…lazy dog. quick"   all plain           (pasteboard types: public.utf8-plain-text)
///       Copy instead of Cut: the pasted "quick" is italic     (private.telegramtext, public.utf8-plain-text, public.rtf)
///       engine: Cut keeps the formatting (its fragment type)
///
/// Also seen: Select All → Cut → Paste of a paragraph + bold + a quote comes back as two plain paragraphs.
///
/// **How it was seen.** K1, 2026-09-23, seventh roam: `cut:` / `copy:` / `paste:` sent to the
/// `ChatInputTextView` through lldb, the pasteboard's `pasteboardTypes` read after each. Seen 3×
/// (Select All with bold + quote, a bold word, an italic word).
///
/// **Suspected cause.** `ChatInputTextViewImpl.m` overrides `copy:` (to let the panel's
/// `chatInputTextNodeShouldCopy` write the rich representation via `storeInputTextInPasteboard`) and
/// `paste:`, but not `cut:`, so Cut is UIKit's plain-text default. A `cut:` that stores the rich
/// representation and then deletes the selection would match Copy.
///
/// **Tier 1**: `cut(_:)` / `paste(_:)` on the text view are exactly what the edit menu sends; the
/// test writes the pasteboard (by cutting) before it reads it.
final class HarnessLegacyCutFormattingTests: XCTestCase {
    private func roundTrip(cut: Bool) throws -> ChatInputContent {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(HarnessContent.plainText("The quick brown fox jumps over the lazy dog."))
        arranged = value

        HarnessLegacy.select(value, NSRange(location: 4, length: 5))
        value.host.panel.formatAttributesItalic(self)
        HarnessEngine.settle(value.root)
        XCTAssertEqual(HarnessLegacy.text(in: HarnessLegacy.content(value), where: { $0.italic }), "quick",
                       "precondition: italic was not applied")

        HarnessLegacy.select(value, NSRange(location: 4, length: 5))
        if cut {
            value.textView.cut(nil)
        } else {
            value.textView.copy(nil)
            value.textView.selectedRange = NSRange(location: 4, length: 5)
            value.textView.deleteBackward()
        }
        HarnessEngine.settle(value.root)
        XCTAssertFalse(HarnessLegacy.content(value).plainText.contains("quick"), "precondition: the selection was not removed")

        // Paste at the end (UIKit's smart delete may have taken a space with the cut).
        value.textView.selectedRange = NSRange(location: (value.textView.text as NSString).length, length: 0)
        HarnessEngine.settle(value.root)
        value.textView.paste(nil)
        HarnessEngine.settle(value.root)
        return HarnessLegacy.content(value)
    }

    func testCutAndPasteKeepsTheFormatting() throws {
        let content = try self.roundTrip(cut: true)
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.italic }), "quick",
                       "Cut + Paste lost the italic: \(content.blocks)")
    }

    /// Control: Copy + delete + Paste of the same selection keeps it.
    func testCopyAndPasteKeepsTheFormatting() throws {
        let content = try self.roundTrip(cut: false)
        XCTAssertEqual(HarnessLegacy.text(in: content, where: { $0.italic }), "quick",
                       "Copy + Paste lost the italic: \(content.blocks)")
    }
}
