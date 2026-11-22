import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What this pins.** Cutting a whole document that ends in a container (block quote, code block,
/// pull quote) and pasting it straight back restores every block intact — and then adds ONE empty
/// body paragraph after the container, with the caret in it.
///
/// That trailing line is a product rule, not a defect: "the caret goes after all the inserted
/// content; if the inserted content ends in a block other than body/header AND the insertion is at
/// the end of the document, a line is added" (RichTextEditor `CLAUDE.md`, 2026-09-17, recorded as
/// asked for; `RichTextEngineEditorView+ArticleHost.swift` `replaceRange`). The fifth roam filed it
/// as a failed round trip; the fix wave traced it to that rule and stopped, and the rule stands.
///
/// What IS a defect, and what this guards: losing or changing a block on the way (the fourth roam's
/// paragraph case duplicated an empty host paragraph; the third roam's quote copy dropped the quote),
/// or more than the one documented line, or a caret that is not in that line.
///
/// **Tier 1**: `cut(_:)` / `paste(_:)` are what the edit menu calls, the pasteboard is this process's
/// own, and the result is in the model.
final class HarnessContainerCutPasteRoundTripTests: XCTestCase {
    private func roundTrip(_ second: ChatInputBlock, _ what: String,
                           file: StaticString = #filePath, line: UInt = #line) throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        let original = ChatInputContent(blocks: [HarnessEngine.paragraph("First paragraph."), second])
        host.setInputContent(original)
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        let textView = try HarnessEngine.textView(in: root)
        let before = node.currentInputContent().content.blocks

        _ = textView.perform(#selector(UIResponderStandardEditActions.selectAll(_:)), with: nil)
        HarnessEngine.settle(root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.cut(_:)), with: nil)
        HarnessEngine.settle(root)
        XCTAssertFalse(node.currentInputContent().content.plainText.contains("paragraph"),
                       "precondition (\(what)): the cut did not remove the text", file: file, line: line)

        _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(root)
        let after = node.currentInputContent().content.blocks
        defer { _ = node.resignInputFirstResponder() }

        XCTAssertEqual(after.count, before.count + 1,
                       "\(what): expected the original blocks plus the one documented trailing line: \(after)", file: file, line: line)
        XCTAssertEqual(Array(after.prefix(before.count)).map { ChatInputContent(blocks: [$0]).plainText },
                       before.map { ChatInputContent(blocks: [$0]).plainText },
                       "\(what): a block changed on the way through cut + paste: \(after)", file: file, line: line)
        guard case let .paragraph(trailing)? = after.last else {
            return XCTFail("\(what): the documented trailing line is not a paragraph: \(after)", file: file, line: line)
        }
        XCTAssertTrue(trailing.runs.map(\.text).joined().isEmpty, "\(what): the trailing line is not empty", file: file, line: line)
        let caret = node.selectedRange
        XCTAssertEqual(caret.length, 0, file: file, line: line)
        XCTAssertEqual(caret.location, ChatInputContent(blocks: after).plainText.utf16.count,
                       "\(what): the caret is not in the trailing line", file: file, line: line)
    }

    func testCutPasteOfADocumentEndingInACodeBlockRestoresItAndAddsTheDocumentedLine() throws {
        try self.roundTrip(.code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "Second paragraph.")])), "code block")
    }

    func testCutPasteOfADocumentEndingInAPullQuoteRestoresItAndAddsTheDocumentedLine() throws {
        try self.roundTrip(.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "Second paragraph.")])), "pull quote")
    }

    func testCutPasteOfADocumentEndingInAQuoteRestoresItAndAddsTheDocumentedLine() throws {
        try self.roundTrip(.blockQuote(ChatInputBlockQuote(
            content: ChatInputContent(blocks: [HarnessEngine.paragraph("Second paragraph.")]),
            collapsed: false)), "block quote")
    }
}
