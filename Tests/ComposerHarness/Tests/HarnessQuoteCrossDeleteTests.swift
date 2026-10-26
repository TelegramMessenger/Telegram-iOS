import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, deleting (or typing over) a selection that starts in a
/// paragraph and ends INSIDE a following block quote dissolves the quote into the paragraph — and
/// leaves an extra EMPTY paragraph where the quote was. The field stays two lines tall with an empty
/// last line (the engine text has a trailing newline too, so this is not only the model), and that
/// empty paragraph is part of what would be sent.
///
///     [p "First paragraph."] [quote [p "Second paragraph."]]
///     select 5..<25 ("First|… Second p|aragraph.") → Backspace
///       engine: [p "Firstaragraph."] [p ""]
///     same selection → type "X"
///       engine: [p "FirstXaragraph."] [p ""]
///     select 5..<17 (ends exactly at the quote's start) → Backspace
///       engine: [p "FirstSecond paragraph."] [p ""]
///
/// The same selections over a CODE block or a PULL QUOTE leave no stray block (the container keeps
/// its tail: `[p "FirstX"] [pullQuote "aragraph."]`), and Select All over any of them followed by
/// typing gives one clean paragraph — the block quote, a container of paragraphs, is the odd one out.
///
/// **How it was seen.** K1, 2026-09-23, four times on the engine (5..<25 typing ×2, 5..<25
/// Backspace, 5..<17 Backspace), the quote made with Format ▸ Quote, the selection set and the edit
/// sent through the engine text view's `UITextInput`/`UIKeyInput`. A screenshot shows the empty
/// second line in the field. Legacy control (its own Format ▸ Quote via `formatAttributesQuote:`,
/// same selections, Backspace): `[quote [p "Firstaragraph."]]` and
/// `[quote [p "FirstSecond paragraph."]]` — no stray paragraph.
///
/// **Suspected cause.** The cross-block deletion's structural rule in the surface gate /
/// `+BackspaceRules.swift` joins the quote's first child into the host paragraph but leaves the
/// quote's (now empty) child paragraph behind as a top-level paragraph instead of removing it with
/// the dissolved container.
///
/// **Tier 1**: the selection and the edit are the `UITextInput` calls the keyboard makes, and the
/// defect is in the model.
final class HarnessQuoteCrossDeleteTests: XCTestCase {
    private func contentAfterEdit(selection: NSRange, typing: String?) throws -> [ChatInputBlock] {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        host.setInputContent(ChatInputContent(blocks: [
            HarnessEngine.paragraph("First paragraph."),
            .blockQuote(ChatInputBlockQuote(
                content: ChatInputContent(blocks: [HarnessEngine.paragraph("Second paragraph.")]),
                collapsed: false)),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        node.selectedRange = selection
        HarnessEngine.settle(root)
        XCTAssertEqual(node.selectedRange, selection, "precondition: the selection did not land")

        let keyInput = try XCTUnwrap(try HarnessEngine.textView(in: root) as? UIKeyInput)
        if let typing {
            keyInput.insertText(typing)
        } else {
            keyInput.deleteBackward()
        }
        HarnessEngine.settle(root)
        let blocks = node.currentInputContent().content.blocks
        _ = node.resignInputFirstResponder()
        return blocks
    }

    private func assertNoEmptyParagraph(_ blocks: [ChatInputBlock], expectedText: String,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let empty = blocks.filter { block in
            if case let .paragraph(paragraph) = block {
                return paragraph.runs.map(\.text).joined().isEmpty
            }
            return false
        }
        XCTAssertEqual(empty.count, 0, "the edit left a stray empty paragraph: \(blocks)", file: file, line: line)
        let text = ChatInputContent(blocks: blocks).plainText.replacingOccurrences(of: "\n", with: "")
        XCTAssertEqual(text, expectedText, "precondition: the edit removed the wrong text", file: file, line: line)
    }

    func testBackspaceOverASelectionEndingInsideAQuoteLeavesNoEmptyParagraph() throws {
        let blocks = try self.contentAfterEdit(selection: NSRange(location: 5, length: 20), typing: nil)
        self.assertNoEmptyParagraph(blocks, expectedText: "Firstaragraph.")
    }

    func testTypingOverASelectionEndingInsideAQuoteLeavesNoEmptyParagraph() throws {
        let blocks = try self.contentAfterEdit(selection: NSRange(location: 5, length: 20), typing: "X")
        self.assertNoEmptyParagraph(blocks, expectedText: "FirstXaragraph.")
    }

    func testBackspaceOverASelectionEndingAtTheQuoteStartLeavesNoEmptyParagraph() throws {
        let blocks = try self.contentAfterEdit(selection: NSRange(location: 5, length: 12), typing: nil)
        self.assertNoEmptyParagraph(blocks, expectedText: "FirstSecond paragraph.")
    }
}
