import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, text that is BOTH italic and monospace loses its italic on
/// the next edit ANYWHERE in the composer — typing one character in another paragraph, Return, or
/// Format ▸ Quote on another paragraph. The model (and so what is sent) drops `italic`; the drawn
/// text stays monospace. Bold on the same monospace text survives, and so does italic that is not
/// monospace.
///
///     "First paragraph." → select 3..<10 → Format ▸ Italic → select 2..<8 → Format ▸ Monospace
///       model: "Fi" | [m] "r" | [i,m] "st pa" | [i] "ra" | "graph."      (correct)
///     → caret at the end of "Second paragraph." → type "X"
///       engine: "Fi" | [m] "rst pa" | [i] "ra" | …   (italic gone from the monospace run)
///     legacy, same steps (its own format commands, then Format ▸ Quote on paragraph 2): [i,m] kept
///
/// **How it was seen.** K1, 2026-09-23, fifth roam, during the format/undo stress pass: a Quote on
/// the second paragraph turned `[b,i,m]` into `[b,m]` in the first. Then reduced: Format ▸ Quote on
/// paragraph 2 ×2, typing "X" at the end of paragraph 2 ×1 and of paragraph 1 ×1, Return ×1 — all
/// drop the italic; Format ▸ Bold on paragraph 2 does not. Edits sent to the engine text view through
/// lldb, the model read from the harness readout. Legacy control: `[i,m]` survives.
///
/// **Suspected cause.** Presentation re-derivation after settle (`normalisePresentation` /
/// `EngineDocumentBridge` read-back): italic on a monospace run lives only as a font trait of the
/// monospace face, and reading the block back derives italic from the face (or its base-font key),
/// which the monospace face does not carry, so a re-read of the block forgets it. Bold survives
/// because it is carried differently. Which blocks get re-read also looks wider than the edit.
///
/// **Tier 1**: the edit is the keyboard's `insertText(_:)`, and the loss is in the model.
final class HarnessMonospaceItalicTests: XCTestCase {
    private func italicMonospaceText(_ blocks: [ChatInputBlock]) -> String {
        var result = ""
        for block in blocks {
            if case let .paragraph(paragraph) = block {
                for run in paragraph.runs where run.attributes.italic && run.attributes.monospace {
                    result += run.text
                }
            }
        }
        return result
    }

    private func arrange() throws -> (HarnessRootViewController, ChatRichTextInputNode) {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [
                ChatInputRun(text: "Fi"),
                ChatInputRun(text: "r", attributes: ChatInputInlineAttributes(monospace: true)),
                ChatInputRun(text: "st pa", attributes: ChatInputInlineAttributes(italic: true, monospace: true)),
                ChatInputRun(text: "ra", attributes: ChatInputInlineAttributes(italic: true)),
                ChatInputRun(text: "graph."),
            ])),
            HarnessEngine.paragraph("Second paragraph."),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        XCTAssertEqual(self.italicMonospaceText(node.currentInputContent().content.blocks), "st pa",
                       "setting the content already lost italic on the monospace run")
        return (root, node)
    }

    private func typeAndCheck(at location: Int, _ text: String, _ what: String) throws {
        let (root, node) = try self.arrange()
        node.selectedRange = NSRange(location: location, length: 0)
        HarnessEngine.settle(root)
        let keyInput = try XCTUnwrap(try HarnessEngine.textView(in: root) as? UIKeyInput)
        keyInput.insertText(text)
        HarnessEngine.settle(root)
        let blocks = node.currentInputContent().content.blocks
        _ = node.resignInputFirstResponder()
        XCTAssertEqual(self.italicMonospaceText(blocks), "st pa",
                       "\(what) stripped italic from the italic+monospace run: \(blocks)")
    }

    func testTypingInAnotherParagraphKeepsItalicOnMonospaceText() throws {
        try self.typeAndCheck(at: 34, "X", "typing at the end of the second paragraph")
    }

    func testTypingAtTheEndOfTheSameParagraphKeepsItalicOnMonospaceText() throws {
        try self.typeAndCheck(at: 16, "X", "typing at the end of the same paragraph")
    }

    func testReturnKeepsItalicOnMonospaceText() throws {
        try self.typeAndCheck(at: 34, "\n", "Return at the end of the second paragraph")
    }
}
