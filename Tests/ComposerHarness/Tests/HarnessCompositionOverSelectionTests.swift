import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, an IME composition started over a SELECTION that spans
/// blocks is not decided by the surface gate, so it does not do what typing the same text over the
/// same selection does. Two faces:
///
/// 1. From a paragraph INTO a block quote, the composition's FIRST candidate is left behind as
///    committed text in front of the composition:
///
///        [p "First para"] [quote "Quoted text"], select 5..<15 ("␣para⏎Quot"),
///        compose k → か, commit         → [p "Firstkかed text"]     (a stray "k")
///        insertText("か") over the same  → [p "Firstかed text"]
///        Korean ㅎ → 하 → 한 → 한글     → [p "Firstㅎ한글ed text"]  (a stray "ㅎ")
///    The same from a quote into the paragraph after it ("Quotek漢字er para").
///
/// 2. Over a selection that covers a TABLE in part (from inside a cell to the end of the last cell),
///    the composition empties the covered cells in the MODEL while the engine drops their lines, so
///    model and screen disagree (`[table ("Na漢字" | ) ( | )]` vs engine lines `T / Na漢字 / after`).
///
/// A composition within one block (paragraph, quote, code, pull quote, cell, heading, list item,
/// details title/body) and one from a paragraph into a code block, a heading or a list item behave
/// (controls below and in the probe log).
///
/// **How it was seen.** p11 roam, 2026-09-24: hosted probe of Japanese/Korean candidate sequences
/// (`setMarkedText(_:selectedRange:)` then `unmarkText()`) over cross-block selections, compared
/// with `insertText` of the committed text over the same selection.
///
/// **Suspected cause.** `TGIDObservingBlockTextView` routes `insertText:` and `replaceRange:withText:`
/// through `tgid_textInputGate` but not `setMarkedText:selectedRange:` (inherited from
/// `IDBlockTextView+TextInput.m`, straight to the behaviour input), and the gate is skipped outright
/// while `markedTextRange != nil` (`tgid_textThroughGate:`). So the first candidate replaces the
/// cross-block range through the controller's own identity merge; settle then re-derives the
/// structure (the quote's band and author line go), which moves text under the marked range, and the
/// next candidate replaces a range that no longer starts where the first one did.
///
/// **Tier 1**: the calls are the keyboard's; `insertText` over the same selection is the oracle.
final class HarnessCompositionOverSelectionTests: XCTestCase {
    private struct Outcome {
        let content: ChatInputContent
        let engineText: String
    }

    private func run(_ start: ChatInputContent, select range: NSRange, steps: [String], composing: Bool) throws -> Outcome {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(start)
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        HarnessEngine.settle(root)
        let view = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        let from = try XCTUnwrap(view.position(from: view.beginningOfDocument, offset: range.location))
        let to = try XCTUnwrap(view.position(from: view.beginningOfDocument, offset: NSMaxRange(range)))
        view.selectedTextRange = view.textRange(from: from, to: to)
        HarnessEngine.settle(root)
        if composing {
            for step in steps {
                view.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0))
                HarnessEngine.settle(root, seconds: 0.03)
            }
            view.unmarkText()
        } else {
            view.insertText(steps.last ?? "")
        }
        HarnessEngine.settle(root)
        let all = try XCTUnwrap(view.textRange(from: view.beginningOfDocument, to: view.endOfDocument))
        return Outcome(content: node.currentInputContent().content, engineText: view.text(in: all) ?? "")
    }

    private var paragraphThenQuote: ChatInputContent {
        return ChatInputContent(blocks: [
            HarnessEngine.paragraph("First para"),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Quoted text")]), collapsed: false)),
        ])
    }

    func testACompositionFromAParagraphIntoAQuoteCommitsOnlyItsFinalText() throws {
        // Engine axis: "First para" 0..<10, "\n", "Quoted text" 11..<22. 5..<15 = " para\nQuot".
        let typed = try self.run(self.paragraphThenQuote, select: NSRange(location: 5, length: 10), steps: ["か"], composing: false)
        XCTAssertEqual(typed.content.plainText, "Firstかed text", "control: typing over the selection no longer gives the gate's merge")
        let composed = try self.run(self.paragraphThenQuote, select: NSRange(location: 5, length: 10), steps: ["k", "か"], composing: true)
        XCTAssertEqual(composed.content.plainText, typed.content.plainText,
                       "a composition over a paragraph→quote selection kept its first candidate: \(FuzzModel.describe(composed.content))")
    }

    func testAKoreanCompositionFromAParagraphIntoAQuoteCommitsOnlyItsFinalText() throws {
        let composed = try self.run(self.paragraphThenQuote, select: NSRange(location: 5, length: 10),
                                    steps: ["ㅎ", "하", "한", "한ㄱ", "한그", "한글"], composing: true)
        XCTAssertEqual(composed.content.plainText, "First한글ed text",
                       "a Korean composition over a paragraph→quote selection kept its first jamo: \(FuzzModel.describe(composed.content))")
    }

    func testACompositionOverATableCoveredInPartKeepsModelAndScreenInStep() throws {
        func cell(_ text: String) -> ChatInputTableCell { ChatInputTableCell(runs: [ChatInputRun(text: text)]) }
        let start = ChatInputContent(blocks: [
            HarnessEngine.paragraph("T"),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [
                ChatInputTableRow(isHeader: true, cells: [cell("Name"), cell("Val")]),
                ChatInputTableRow(cells: [cell("a"), cell("1")]),
            ])),
            HarnessEngine.paragraph("after"),
        ])
        // Engine axis: "T" 0, "Name" 2..<6, "Val" 7..<10, "a" 11, "1" 13, "after" 15..<20; 4..<14 runs
        // from inside "Name" to the end of the last cell.
        let typed = try self.run(start, select: NSRange(location: 4, length: 10), steps: ["漢字"], composing: false)
        XCTAssertNil(FuzzModel.engineAxisMismatch(typed.content, engineText: typed.engineText),
                     "control: typing over the partial table selection already leaves model and screen apart")
        let composed = try self.run(start, select: NSRange(location: 4, length: 10), steps: ["k", "か", "かん", "漢字"], composing: true)
        XCTAssertNil(FuzzModel.engineAxisMismatch(composed.content, engineText: composed.engineText),
                     "a composition over a table covered in part left model and screen apart")
        XCTAssertEqual(FuzzModel.normalized(composed.content), FuzzModel.normalized(typed.content),
                       "a composition over a table covered in part did not do what typing does:\n  typed    \(FuzzModel.describe(typed.content))\n  composed \(FuzzModel.describe(composed.content))")
    }

    /// Control: a paragraph → code block selection composes like typing.
    ///
    /// **Corrected 2026-09-24 (with the fix).** This control first asserted `"First漢字t x = 1"` — the
    /// controller's identity merge, which pulled the code block's text into the paragraph. Typing
    /// `漢字` over the same selection gives `[p "First漢字"] [code "t x = 1"]` (the gate's rule: a leaf
    /// container covered in part keeps its remainder as its own block; measured in this class, engine
    /// text `"First漢字\n\nt x = 1"`), so the old expectation was the ungated path agreeing with
    /// itself, not with typing. It now compares with typing over the same selection, the oracle the
    /// rest of the class uses.
    func testControlACompositionFromAParagraphIntoACodeBlock() throws {
        let start = ChatInputContent(blocks: [
            HarnessEngine.paragraph("First para"),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")])),
        ])
        // "First para" 0..<10, language line 11, body 12..<21; 5..<14 = " para\n\nle".
        let typed = try self.run(start, select: NSRange(location: 5, length: 9), steps: ["漢字"], composing: false)
        let composed = try self.run(start, select: NSRange(location: 5, length: 9), steps: ["k", "か", "漢字"], composing: true)
        XCTAssertEqual(FuzzModel.normalized(composed.content), FuzzModel.normalized(typed.content),
                       "control:\n  typed    \(FuzzModel.describe(typed.content))\n  composed \(FuzzModel.describe(composed.content))")
        XCTAssertEqual(composed.engineText, typed.engineText, "control: the screen differs from typing's")
    }

    /// A paragraph → heading and a paragraph → list-item selection compose like typing too (added with
    /// the fix; the probe had called both "behaving" against a hard-coded answer, like the code case).
    func testACompositionFromAParagraphIntoAHeadingOrAListItemComposesLikeTyping() throws {
        for second in [
            ChatInputBlock.paragraph(ChatInputParagraph(style: .heading2, list: nil, runs: [ChatInputRun(text: "Heading two")])),
            ChatInputBlock.paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: 0), runs: [ChatInputRun(text: "Item text")])),
        ] {
            let start = ChatInputContent(blocks: [HarnessEngine.paragraph("First para"), second])
            let typed = try self.run(start, select: NSRange(location: 5, length: 9), steps: ["漢字"], composing: false)
            let composed = try self.run(start, select: NSRange(location: 5, length: 9), steps: ["k", "か", "漢字"], composing: true)
            XCTAssertEqual(FuzzModel.normalized(composed.content), FuzzModel.normalized(typed.content),
                           "\n  typed    \(FuzzModel.describe(typed.content))\n  composed \(FuzzModel.describe(composed.content))")
            XCTAssertEqual(composed.engineText, typed.engineText)
        }
    }

    /// The gate's deletion and the composition that follows it are ONE undo step, as a stock text
    /// view's composition over a selection is: one undo brings the selected text back. Added with the
    /// fix (2026-09-24) — the deletion is the gate's own edit, and a structural edit closes its run.
    func testOneUndoRevertsACompositionOverACrossBlockSelection() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(self.paragraphThenQuote)
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        HarnessEngine.settle(root)
        let view = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        view.undoManager?.removeAllActions()
        let before = FuzzModel.normalized(node.currentInputContent().content)
        let from = try XCTUnwrap(view.position(from: view.beginningOfDocument, offset: 5))
        let to = try XCTUnwrap(view.position(from: view.beginningOfDocument, offset: 15))
        view.selectedTextRange = view.textRange(from: from, to: to)
        HarnessEngine.settle(root)
        for step in ["k", "か", "漢字"] {
            view.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0))
            HarnessEngine.settle(root, seconds: 0.03)
        }
        view.unmarkText()
        HarnessEngine.settle(root)
        XCTAssertEqual(node.currentInputContent().content.plainText, "First漢字ed text", "precondition")
        view.undoManager?.undo()
        HarnessEngine.settle(root)
        let undone = FuzzModel.normalized(node.currentInputContent().content)
        XCTAssertEqual(undone, before, "one undo did not revert the whole composition over the selection: \(FuzzModel.describe(undone))")
    }
}
