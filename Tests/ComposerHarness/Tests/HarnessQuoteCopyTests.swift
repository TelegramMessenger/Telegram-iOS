import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, copying a selection that starts OUTSIDE a block quote and
/// ends inside (or after) it drops the quote's text from the clipboard. Select All + Copy on
/// `[paragraph "First paragraph."] [quote "Second paragraph."]` puts only `"First paragraph."` on the
/// pasteboard — in all three representations (plain text, RTF, and the editor's own fragment JSON,
/// which holds a single paragraph block). Pasting it back therefore loses the quote; Cut deletes the
/// quote and keeps no copy of it.
///
///     engine: Select All → Copy → "First paragraph."
///     legacy: Select All → Copy → "First paragraph.\nSecond paragraph."
///
/// A selection INSIDE the quote copies correctly (`"ond p"`), and the same Select All copies both
/// blocks when the second one is a plain paragraph, a code block or a pull quote — the block quote,
/// the one container of paragraphs, is the odd one out.
///
/// **How it was seen.** K1, 2026-09-22, three times on the engine (selection 6..<25 across the
/// boundary; 0..<34; `selectAll:`), `copy:` sent to the engine text view and `UIPasteboard` read
/// back in-process. Legacy control (its own Format ▸ Quote, then the same Select All + Copy): both
/// paragraphs.
///
/// **Suspected cause.** `writeSelectionToPasteboard()` (`RichTextEngineEditorView+Clipboard.swift`)
/// builds the fragment from `selectedGlobalRange()` + `Document.extractFragment(globalFrom:globalTo:)`;
/// one of the two loses the part of the range that lies inside the nested quote.
///
/// **Tier 1**: `copy(_:)` on the engine view is what the edit menu's Copy calls, and the pasteboard is
/// readable in-process (this app owns what it just wrote, so no paste prompt).
final class HarnessQuoteCopyTests: XCTestCase {
    private func copiedText(_ blocks: [ChatInputBlock]) throws -> String? {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: blocks))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let textView = try HarnessEngine.textView(in: root)
        UIPasteboard.general.items = []
        _ = textView.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
        HarnessEngine.settle(root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessEngine.settle(root)
        _ = node.resignInputFirstResponder()
        return UIPasteboard.general.string
    }

    func testSelectAllCopyIncludesABlockQuote() throws {

        // Control: two plain paragraphs copy whole.
        let plain = try self.copiedText([
            HarnessEngine.paragraph("First paragraph."),
            HarnessEngine.paragraph("Second paragraph."),
        ])
        XCTAssertEqual(plain, "First paragraph.\nSecond paragraph.",
                       "control: Select All + Copy of two plain paragraphs changed")

        let quoted = try self.copiedText([
            HarnessEngine.paragraph("First paragraph."),
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [HarnessEngine.paragraph("Second paragraph.")]),
                collapsed: false)),
        ])
        XCTAssertTrue(quoted?.contains("Second paragraph.") == true,
                      "Select All + Copy dropped the block quote; the clipboard holds \(String(describing: quoted))")
    }
}
