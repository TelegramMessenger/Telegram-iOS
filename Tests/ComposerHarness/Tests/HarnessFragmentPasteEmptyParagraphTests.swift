import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, pasting the editor's own clipboard (a copied or cut
/// selection, which travels as the private fragment type) into an EMPTY paragraph leaves an extra
/// empty paragraph after the pasted text. The commonest form: copy a line, clear the composer (or
/// open an empty one), paste — the field is now two lines tall, the second empty, and that empty
/// paragraph is sent.
///
///     two-paragraphs → select "First paragraph." (0..<16) → Cut → Paste
///       engine: [p "First paragraph."] [p ""] [p "Second paragraph."]      (cut/paste is not a round trip)
///     empty composer → Paste a copied "First paragraph."
///       engine: [p "First paragraph."] [p ""]
///     legacy (same copy, paste into an empty last line): no extra paragraph
///
/// Pasting the same fragment into a NON-empty paragraph (caret mid-word, or at its start) splices
/// it inline correctly, and a plain-text paste (another app's string) into an empty composer is also
/// correct — only a fragment into an empty host paragraph adds the block. A partial selection
/// ("First") and a list fragment (three bullets) pasted into an empty paragraph do it too.
///
/// **How it was seen.** K1, 2026-09-23, five times on the engine: cut/paste of 0..<16 (with and
/// without a spoiler in it), paste into the empty composer, paste of "First" and of a bulleted-list
/// fragment into an empty paragraph made by Return. `copy:`/`cut:`/`paste:` sent to the engine
/// text view, the model read from the harness readout. Legacy control: copy of "First paragraph.",
/// paste into an empty last line → three paragraphs, none empty.
///
/// **Suspected cause.** `pasteFragmentFromPasteboard()` (`RichTextEngineEditorView+Clipboard.swift`)
/// splices at a collapsed caret with `replaceRange(from: caret, to: caret, with: fragment)`; the
/// `Document.replacingRange` path folds an inline-mergeable first block into a NON-empty host
/// paragraph, but for an empty host it inserts the fragment's blocks and keeps the empty host
/// paragraph after them.
///
/// **Tier 1**: `copy(_:)`, `cut(_:)` and `paste(_:)` on the engine view are what the edit menu
/// calls, the pasteboard is this process's own (no paste prompt), and the defect is in the model.
final class HarnessFragmentPasteEmptyParagraphTests: XCTestCase {
    private func emptyParagraphs(_ blocks: [ChatInputBlock]) -> Int {
        return blocks.filter { block in
            if case let .paragraph(paragraph) = block {
                return paragraph.runs.map(\.text).joined().isEmpty
            }
            return false
        }.count
    }

    func testCutThenPasteOfAWholeParagraphIsARoundTrip() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        let original = HarnessContent.plainText("First paragraph.\nSecond paragraph.")
        host.setInputContent(original)
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        let textView = try HarnessEngine.textView(in: root)

        node.selectedRange = NSRange(location: 0, length: 16)
        HarnessEngine.settle(root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
        HarnessEngine.settle(root)
        XCTAssertEqual(node.selectedRange, NSRange(location: 0, length: 0),
                       "precondition: the cut did not leave the caret in the emptied first paragraph")
        XCTAssertNotNil(UIPasteboard.general.data(forPasteboardType: "org.telegram.richtexteditor.fragment"),
                        "precondition: the cut did not put the editor's fragment on the pasteboard")

        _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(root)

        let blocks = node.currentInputContent().content.blocks
        _ = node.resignInputFirstResponder()
        XCTAssertEqual(self.emptyParagraphs(blocks), 0,
                       "cut + paste of a whole paragraph left an empty paragraph behind: \(blocks)")
        XCTAssertEqual(node.currentInputContent().content.plainText, "First paragraph.\nSecond paragraph.",
                       "cut + paste of a whole paragraph is not a round trip")
    }

    func testPastingACopiedLineIntoTheEmptyComposerAddsNoEmptyParagraph() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        host.setInputContent(HarnessContent.plainText("First paragraph.\nSecond paragraph."))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        let textView = try HarnessEngine.textView(in: root)
        node.selectedRange = NSRange(location: 0, length: 16)
        HarnessEngine.settle(root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessEngine.settle(root)

        host.setInputContent(ChatInputContent())
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        node.selectedRange = NSRange(location: 0, length: 0)
        HarnessEngine.settle(root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(root)

        let blocks = node.currentInputContent().content.blocks
        _ = node.resignInputFirstResponder()
        XCTAssertEqual(blocks.count, 1, "pasting one copied line into the empty composer made \(blocks.count) blocks: \(blocks)")
        XCTAssertEqual(self.emptyParagraphs(blocks), 0, "the paste left an empty paragraph: \(blocks)")
    }
}
