import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, Return at the start of a heading followed by Backspace —
/// the ordinary "I did not mean that" pair — demotes the heading to body text. Since the sixth wave,
/// Return at a heading's start inserts an empty BODY paragraph above and keeps the heading
/// (`decideReturnAtStartOfHeading`); Backspace at the heading's start then joins the heading INTO that
/// empty body paragraph, and the joined block keeps the upper block's style:
///
///     [p "intro"] [h2 "Second"], caret before "Second", Return
///       → [p "intro"] [p ""] [h2 "Second"]          (correct, the sixth-wave fix)
///     Backspace
///       engine:   [p "intro"] [p "Second"]          ← the heading is gone
///       expected: [p "intro"] [h2 "Second"]
///
/// The same at the document start (`## Head` first, Return, Backspace → `[p "Head"]`). More
/// generally, Backspace at the start of any heading whose previous paragraph is EMPTY demotes it;
/// with an empty previous line the natural result is to delete that line.
///
/// **How it was seen.** K1, 2026-09-23, seventh roam, while sweeping the sixth wave's heading fix
/// for side effects: headings from markdown paste, `insertText:@"\n"` and `deleteBackward` on the
/// engine text view through lldb. Seen 2× (mid-document h2, document-start h2). Undo restores it.
///
/// **Suspected cause.** The Backspace join (`+BackspaceRules.swift` / the controller's merge) keeps
/// the upper block's identity and style as the survivor even when the upper block is an empty
/// paragraph; there is no rule that an empty upper block yields to the lower one.
///
/// **Tier 1**: `insertText("\n")` and `deleteBackward()` are the keyboard's Return and Backspace; the
/// loss is in the model.
final class HarnessHeadingReturnBackspaceTests: XCTestCase {
    private func style(of text: String, in content: ChatInputContent) -> ChatInputParagraphStyle? {
        for block in content.blocks {
            if case let .paragraph(paragraph) = block, paragraph.text == text {
                return paragraph.style
            }
        }
        return nil
    }

    private func returnThenBackspace(_ blocks: [ChatInputBlock], caret: Int, heading: String) throws -> ChatInputContent {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: blocks))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        node.selectedRange = NSRange(location: caret, length: 0)
        HarnessEngine.settle(root)
        let keyInput = try XCTUnwrap(try HarnessEngine.textView(in: root) as? UIKeyInput)

        keyInput.insertText("\n")
        HarnessEngine.settle(root)
        let afterReturn = node.currentInputContent().content
        XCTAssertEqual(afterReturn.blocks.count, blocks.count + 1, "precondition: Return did not add a line: \(afterReturn.blocks)")
        XCTAssertEqual(self.style(of: heading, in: afterReturn), .heading2, "precondition: Return demoted the heading: \(afterReturn.blocks)")
        XCTAssertEqual(node.selectedRange, NSRange(location: caret + 1, length: 0), "precondition: the caret is not at the heading's start")

        keyInput.deleteBackward()
        HarnessEngine.settle(root)
        return node.currentInputContent().content
    }

    func testReturnThenBackspaceAtAHeadingsStartKeepsTheHeading() throws {
        let content = try self.returnThenBackspace([
            HarnessEngine.paragraph("intro"),
            .paragraph(ChatInputParagraph(style: .heading2, list: nil, runs: [ChatInputRun(text: "Second")])),
        ], caret: 6, heading: "Second")
        XCTAssertEqual(content.blocks.count, 2, "Backspace did not remove the inserted line: \(content.blocks)")
        XCTAssertEqual(self.style(of: "Second", in: content), .heading2,
                       "Return + Backspace at the heading's start demoted it: \(content.blocks)")
    }

    func testReturnThenBackspaceAtALeadingHeadingKeepsTheHeading() throws {
        let content = try self.returnThenBackspace([
            .paragraph(ChatInputParagraph(style: .heading2, list: nil, runs: [ChatInputRun(text: "Head")])),
            HarnessEngine.paragraph("body"),
        ], caret: 0, heading: "Head")
        XCTAssertEqual(content.blocks.count, 2, "Backspace did not remove the inserted line: \(content.blocks)")
        XCTAssertEqual(self.style(of: "Head", in: content), .heading2,
                       "Return + Backspace at the document-start heading demoted it: \(content.blocks)")
    }
}
