import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, Backspace at the start of a PULL QUOTE that follows a
/// paragraph merges the quote's text into that paragraph and, in doing so, turns the pull quote's
/// italic PRESENTATION into real italic formatting in the model, and leaves a stray empty paragraph
/// behind:
///
///     before: [paragraph "First paragraph."] [pullQuote "Second paragraph."], caret at 17
///     after:  [paragraph "First paragraph." + "Second paragraph."(italic)] [paragraph ""]
///
/// The user never applied italic; sending now would send it. The same keystroke at the start of a
/// block quote or a code block unwraps the container to plain paragraph(s) (first pass, and
/// re-checked for code here), so the pull quote is also the odd one out. Legacy has no pull quotes.
///
/// **How it was seen.** K1, engine, 2026-09-22, twice: `two-paragraphs` → select a word in the
/// second paragraph → Format ▸ Pull Quote (the command leaves the caret at 17, the quote's start) →
/// keyboard Backspace. Screenshot shows "First paragraph.*Second paragraph.*" with the second half
/// italic. (At the very start of the document the same Backspace does nothing at all.)
///
/// **Suspected cause.** No rule in `RichTextEngineEditorView+BackspaceRules.swift` handles the start
/// of a pull quote's body, so the engine's own block merge runs; the merged text keeps the italic
/// run attribute the pull-quote role styling put on it, and the pull quote's author line survives
/// as an empty paragraph.
///
/// **Tier 1**: `deleteBackward()` on the engine's text view is the call the keyboard makes, and the
/// result is in the model.
final class HarnessPullQuoteBackspaceTests: XCTestCase {
    func testBackspaceAtAPullQuoteStartDoesNotInventItalicOrAnEmptyParagraph() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: [
            HarnessEngine.paragraph("First paragraph."),
            .pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "Second paragraph.")])),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        node.selectedRange = NSRange(location: 17, length: 0)
        HarnessEngine.settle(root)
        XCTAssertEqual(node.selectedRange, NSRange(location: 17, length: 0),
                       "precondition: the caret is not at the pull quote's start")

        let keyInput = try XCTUnwrap(try HarnessEngine.textView(in: root) as? UIKeyInput)
        keyInput.deleteBackward()
        HarnessEngine.settle(root)

        let content = node.currentInputContent().content
        var italicRuns: [String] = []
        var emptyParagraphs = 0
        for block in content.blocks {
            if case let .paragraph(paragraph) = block {
                italicRuns += paragraph.runs.filter { $0.attributes.italic }.map(\.text)
                if paragraph.runs.allSatisfy({ $0.text.isEmpty }) {
                    emptyParagraphs += 1
                }
            }
        }
        XCTAssertEqual(italicRuns, [], "Backspace turned the pull quote's styling into italic text")
        XCTAssertEqual(emptyParagraphs, 0, "Backspace left an empty paragraph behind: \(content.blocks)")
        XCTAssertTrue(["First paragraph.\nSecond paragraph.", "First paragraph.Second paragraph."]
                        .contains(content.plainText),
                      "unexpected text after Backspace: \(content.plainText.debugDescription)")

        _ = node.resignInputFirstResponder()
    }
}
