import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, Return at the START of a heading (the usual way to open a line
/// above it) leaves an EMPTY heading above and turns the heading's own text into body text:
///
///     [p "intro"] [h2 "Second"] [p "body"], caret before "Second", Return
///       engine:   [p "intro"] [h2 ""] [p "Second"] [p "body"]        ← the heading is gone
///       expected: [p "intro"] [p ""]  [h2 "Second"] [p "body"]       (or an empty h2 above — the text stays h2)
///
/// Return at the END of a heading correctly continues with a body paragraph (control below), and Return in
/// the MIDDLE deliberately makes the tail body (legacy's documented "next paragraph style" rule). Offset 0
/// is where that rule stops making sense: the "tail" is the whole heading. The legacy rich editor shares
/// the rule (`DocumentCanvasView.insertParagraphBreak` demotes the lower half unconditionally), so parity
/// with it is not the oracle here; word processors keep the heading's text a heading.
///
/// **How it was seen.** K1, 2026-09-23, sixth roam: headings made by markdown paste (`# Title`,
/// `## Second`), `insertText:@"\n"` with the caret at the heading's start through lldb. Seen 3× (h1 at the
/// document start, h2 after a paragraph ×2). One undo restores it.
///
/// **Suspected cause.** The engine keeps the split block's identity on the UPPER (empty) half, so the lower
/// half — the heading's text — is a freshly minted block, which the bridge gives the default `.body` style
/// (`EngineDocumentBridge` / the Return reconciliation in `RichTextEngineEditorView+Paragraph.swift`).
///
/// **Tier 1**: `insertText("\n")` is the keyboard's Return; the model is readable in-process.
final class HarnessHeadingReturnAtStartTests: XCTestCase {
    private func returnAt(_ caret: Int) throws -> ChatInputContent {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: [
            HarnessEngine.paragraph("intro"),
            .paragraph(ChatInputParagraph(style: .heading2, list: nil, runs: [ChatInputRun(text: "Second")])),
            HarnessEngine.paragraph("body"),
        ]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        node.selectedRange = NSRange(location: caret, length: 0)
        HarnessEngine.settle(root)
        XCTAssertEqual(node.selectedRange, NSRange(location: caret, length: 0), "precondition: the caret did not land")
        (try HarnessEngine.textView(in: root) as? UIKeyInput)?.insertText("\n")
        HarnessEngine.settle(root)
        return node.currentInputContent().content
    }

    private func style(of text: String, in content: ChatInputContent) -> ChatInputParagraphStyle? {
        for block in content.blocks {
            if case let .paragraph(paragraph) = block, paragraph.text == text {
                return paragraph.style
            }
        }
        return nil
    }

    func testReturnAtTheStartOfAHeadingKeepsItsTextAHeading() throws {
        // "intro\nSecond\nbody": the heading starts at 6.
        let content = try self.returnAt(6)
        XCTAssertEqual(content.blocks.count, 4, "precondition: Return did not add a line: \(content.blocks)")
        XCTAssertEqual(self.style(of: "Second", in: content), .heading2,
                       "Return at the start of the heading demoted its text to body: \(content.blocks)")
    }

    /// Control: Return at the END of a heading continues with a body paragraph and leaves the heading alone.
    func testReturnAtTheEndOfAHeadingContinuesWithBody() throws {
        let content = try self.returnAt(12)
        XCTAssertEqual(content.blocks.count, 4, "\(content.blocks)")
        XCTAssertEqual(self.style(of: "Second", in: content), .heading2, "\(content.blocks)")
        guard content.blocks.count == 4, case let .paragraph(next) = content.blocks[2] else {
            return XCTFail("no paragraph after the heading: \(content.blocks)")
        }
        XCTAssertEqual(next.style, .body, "the line after a heading is not body: \(content.blocks)")
    }
}
