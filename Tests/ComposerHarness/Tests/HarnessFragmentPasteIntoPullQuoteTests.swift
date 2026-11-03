import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, pasting the editor's own clipboard (the private fragment
/// type) with the caret inside a PULL QUOTE splits the pull quote in two and inserts the pasted text
/// between the halves as a BODY paragraph, even when what was copied is one word:
///
///     [p "First paragraph."] [pull "Second paragraph."]
///     copy "First" (0..<5) → caret after "Second " in the pull quote → Paste
///       engine: [p "First paragraph."] [pull "Second "] [p "First"] [pull "paragraph."]
///       expected: [p "First paragraph."] [pull "Second Firstparagraph."]
///
/// The eighth wave's `replacingRangeInsideOneContainer` (Core `DocumentFragment.swift`) keeps a paste
/// inside a code block or a block quote; a pull quote was left to the general path, which splices
/// structure at the top level. `HarnessFragmentPasteIntoContainerTests` covers the other two.
///
/// **How it was seen.** K1, 2026-09-23, ninth roam, during the sweep of the eighth wave (recorded
/// there as the documented limit); reproduced here first.
///
/// **Tier 1**: `copy(_:)` and `paste(_:)` on the engine view are what the edit menu calls; the
/// pasteboard is this process's own (written before it is read).
final class HarnessFragmentPasteIntoPullQuoteTests: XCTestCase {
    private func pasteCopiedWord(caret: Int) throws -> [ChatInputBlock] {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: [
            HarnessEngine.paragraph("First paragraph."),
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "Second paragraph.")])),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let textView = try HarnessEngine.textView(in: root)

        node.selectedRange = NSRange(location: 0, length: 5)
        HarnessEngine.settle(root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.copy(_:)), with: nil)
        HarnessEngine.settle(root)
        XCTAssertNotNil(UIPasteboard.general.data(forPasteboardType: "org.telegram.richtexteditor.fragment"),
                        "precondition: the copy did not put the editor's fragment on the pasteboard")

        node.selectedRange = NSRange(location: caret, length: 0)
        HarnessEngine.settle(root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(root)
        let blocks = node.currentInputContent().content.blocks
        _ = node.resignInputFirstResponder()
        return blocks
    }

    func testAWordPastedInsideAPullQuoteStaysInThePullQuote() throws {
        let blocks = try self.pasteCopiedWord(caret: 24)
        XCTAssertEqual(blocks.count, 2, "pasting a copied word inside a pull quote split it: \(blocks)")
        guard blocks.count == 2, case let .pullQuote(quote) = blocks[1] else {
            XCTFail("the second block is no longer the pull quote: \(blocks)")
            return
        }
        XCTAssertEqual(quote.runs.map(\.text).joined(), "Second Firstparagraph.",
                       "the pasted word did not land inline in the pull quote: \(blocks)")
    }

    /// At the pull quote's END (the caret after its last character).
    func testAWordPastedAtThePullQuotesEndStaysInThePullQuote() throws {
        let blocks = try self.pasteCopiedWord(caret: 34)
        XCTAssertEqual(blocks.count, 2, "pasting a copied word at a pull quote's end split it: \(blocks)")
        guard blocks.count == 2, case let .pullQuote(quote) = blocks[1] else {
            XCTFail("the second block is no longer the pull quote: \(blocks)")
            return
        }
        XCTAssertEqual(quote.runs.map(\.text).joined(), "Second paragraph.First",
                       "the pasted word did not land inline at the pull quote's end: \(blocks)")
    }
}
