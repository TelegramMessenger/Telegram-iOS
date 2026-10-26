import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, pasting plain text of THREE or more lines into the body
/// of a code block pushes the last pasted line — and everything after the caret — OUT of the code
/// block into a new body paragraph:
///
///     code "Second paragraph.", caret after "Second ", paste "l1\nl2\nl3"
///     engine: [code "Second l1\nl2"] [paragraph "l3 paragraph."]
///     legacy: [code "Second l1\nl2\nl3 paragraph."]
///
/// Two lines stay inside (`"a\nb"` gave `code "Second a\nb paragraph."`), so the boundary is the
/// second newline. Pasting a snippet into a code block is the common case for code, and the tail
/// of the user's code silently stops being code.
///
/// **How it was seen.** K1, 2026-09-22, twice on the engine (`"line1\n\tline2\nline3"` and
/// `"l1\nl2\nl3"`), `two-paragraphs` → select the second paragraph → Format ▸ Code → caret inside
/// the body → `paste:` on the engine text view. Legacy control (same steps, legacy's
/// `formatAttributesCodeBlock`): all three lines stay in the code block.
///
/// **Suspected cause.** The paste reaches the structural gate as one multi-newline replacement
/// (`RichTextEngineEditorView+SurfaceGate.swift`, `decideTextInput`); the code-body continuation
/// rule keeps the FIRST new engine block (fresh blocks adopted in `declareFreshBlocks`,
/// `+Settle.swift`) but not the ones after it, so the last line lands standalone as a body paragraph.
///
/// **Tier 1**: `paste(_:)` on the engine text view is what the edit menu's Paste calls, and the
/// block structure is in the model.
final class HarnessCodeBlockPasteTests: XCTestCase {
    func testPastingSeveralLinesIntoACodeBlockKeepsThemInTheCodeBlock() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        // Flat axis: "Intro" 0..<5, then the code body from 6.
        host.setInputContent(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro"),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")])),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        node.selectedRange = NSRange(location: 10, length: 0) // "let |x = 1"
        HarnessEngine.settle(root)
        XCTAssertEqual(node.selectedRange, NSRange(location: 10, length: 0),
                       "precondition: the caret did not land in the code body")

        UIPasteboard.general.string = "a\nb\nc"
        let textView = try HarnessEngine.textView(in: root)
        XCTAssertTrue(textView.responds(to: #selector(UIResponderStandardEditActions.paste(_:))),
                      "precondition: the engine view does not implement paste:")
        _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(root)

        let blocks = node.currentInputContent().content.blocks
        XCTAssertEqual(blocks.count, 2, "the paste split the code block: \(blocks)")
        guard case let .code(code)? = blocks.last else {
            return XCTFail("the last block is no longer the code block: \(blocks)")
        }
        XCTAssertEqual(code.text, "let a\nb\ncx = 1", "the pasted lines did not all stay in the code block")

        _ = node.resignInputFirstResponder()
    }

    /// The same split in a PULL QUOTE, the other leaf container that keeps its lines as newlines in
    /// one block — and there the ejected paragraph also carries the pull quote's italic presentation
    /// as real `italic` in the model (K1: `[pullQuote "The quick l1\nl2"] [paragraph i"l3 brown fox…"]`).
    /// Quotes (container of paragraphs) and plain paragraphs split correctly.
    func testPastingSeveralLinesIntoAPullQuoteKeepsThemInThePullQuote() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        host.setInputContent(ChatInputContent(blocks: [
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "The quick brown fox")])),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        node.selectedRange = NSRange(location: 10, length: 0) // "The quick |brown fox"
        HarnessEngine.settle(root)
        XCTAssertEqual(node.selectedRange, NSRange(location: 10, length: 0),
                       "precondition: the caret did not land in the pull quote")

        UIPasteboard.general.string = "a\nb\nc"
        let textView = try HarnessEngine.textView(in: root)
        _ = textView.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        HarnessEngine.settle(root)

        let blocks = node.currentInputContent().content.blocks
        XCTAssertEqual(blocks.count, 1, "the paste split the pull quote: \(blocks)")
        guard case let .pullQuote(quote)? = blocks.first else {
            return XCTFail("the first block is no longer the pull quote: \(blocks)")
        }
        // " brown": a pull quote is prose, so the paste keeps UIKit's smart-insert space, exactly
        // as a stock UITextView and the legacy composer insert it (measured, 2026-09-23). The code
        // block above gets none because smart punctuation is off in code.
        XCTAssertEqual(quote.runs.map(\.text).joined(), "The quick a\nb\nc brown fox",
                       "the pasted lines did not all stay in the pull quote")
        let italic = blocks.flatMap { block -> [String] in
            guard case let .paragraph(paragraph) = block else {
                return []
            }
            return paragraph.runs.filter { $0.attributes.italic }.map(\.text)
        }
        XCTAssertEqual(italic, [], "the pull quote's styling leaked into the model as italic")

        _ = node.resignInputFirstResponder()
    }
}
