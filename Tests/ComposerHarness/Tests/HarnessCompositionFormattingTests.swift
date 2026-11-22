import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, text committed by an IME composition inside a SPOILER or an
/// INLINE-CODE (Monospace) run loses that marker, although the same text typed with `insertText`
/// keeps it (the typed-text policy). Bold survives, so the message sends the CJK/Korean word revealed
/// or out of the code span:
///
///     [sp "First"], caret after "Fi", compose k → か → かん → かんじ → 漢字, commit
///       engine:  [sp "Fi"] "漢字" [sp "rst"]
///       typing the same "漢字" there:  [sp "Fi漢字rst"]
///     [m "First"] the same → [m "Fi"] "漢字" [m "rst"];  Korean ㅎ → 하 → 한 → 한글 the same
///
/// **How it was seen.** p11 roam, 2026-09-24: hosted probe of every formatted run with Japanese and
/// Korean candidate sequences (`setMarkedText(_:selectedRange:)` then `unmarkText()`), compared with
/// `insertText` of the committed string; spoiler and monospace lost, bold and link kept.
///
/// **Suspected cause.** The composition's text never meets the typed-text policy: the controller
/// inserts marked text through its own replacement, and both host hooks that decide typed text's
/// attributes decline while `markedTextRange != nil` (`TGIDObservingBlockTextView.m`,
/// `replaceRange:withText:` → `tgid_replacementAttributesHandler`; the gate's
/// `tgid_textThroughGate:`), and nothing re-attributes the text when the composition commits. The
/// same family as the autocorrect row (a keyboard replacement drops spoiler and inline code; bold,
/// an engine-native trait, survives).
///
/// **Tier 1**: `setMarkedText(_:selectedRange:)` / `unmarkText()` on the engine view are exactly the
/// calls a CJK/Korean keyboard makes; `insertText` of the committed string is the oracle.
final class HarnessCompositionFormattingTests: XCTestCase {
    private let japanese = ["k", "か", "かn", "かん", "かんj", "かんじ", "漢字"]
    private let korean = ["ㅎ", "하", "한", "한ㄱ", "한그", "한글"]

    private func run(_ attributes: ChatInputInlineAttributes, steps: [String], composing: Bool) throws -> ChatInputContent {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: [HarnessEngine.paragraph("First", attributes)]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        HarnessEngine.settle(root)
        let view = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        node.selectedRange = NSRange(location: 2, length: 0)
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
        XCTAssertNil(view.markedTextRange, "precondition: the composition is still open")
        return node.currentInputContent().content
    }

    private func marked(_ content: ChatInputContent, _ keep: (ChatInputInlineAttributes) -> Bool) -> String {
        return HarnessLegacy.text(in: content, where: keep)
    }

    func testAJapaneseCompositionInsideASpoilerStaysSpoilered() throws {
        var spoiler = ChatInputInlineAttributes()
        spoiler.spoiler = true
        let typed = try self.run(spoiler, steps: self.japanese, composing: false)
        XCTAssertEqual(self.marked(typed, { $0.spoiler }), "Fi漢字rst", "control: typed text inside a spoiler is no longer spoilered: \(typed.blocks)")
        let composed = try self.run(spoiler, steps: self.japanese, composing: true)
        XCTAssertEqual(composed.plainText, "Fi漢字rst", "precondition: the composition did not commit its text")
        XCTAssertEqual(self.marked(composed, { $0.spoiler }), "Fi漢字rst",
                       "a composition committed inside a spoiler came out revealed: \(composed.blocks)")
    }

    func testAJapaneseCompositionInsideInlineCodeStaysMonospace() throws {
        var code = ChatInputInlineAttributes()
        code.monospace = true
        let typed = try self.run(code, steps: self.japanese, composing: false)
        XCTAssertEqual(self.marked(typed, { $0.monospace }), "Fi漢字rst", "control: typed text inside inline code is no longer code: \(typed.blocks)")
        let composed = try self.run(code, steps: self.japanese, composing: true)
        XCTAssertEqual(self.marked(composed, { $0.monospace }), "Fi漢字rst",
                       "a composition committed inside inline code fell out of the code span: \(composed.blocks)")
    }

    func testAKoreanCompositionInsideInlineCodeStaysMonospace() throws {
        var code = ChatInputInlineAttributes()
        code.monospace = true
        let composed = try self.run(code, steps: self.korean, composing: true)
        XCTAssertEqual(composed.plainText, "Fi한글rst", "precondition: the composition did not commit its text")
        XCTAssertEqual(self.marked(composed, { $0.monospace }), "Fi한글rst",
                       "a Korean composition committed inside inline code fell out of the code span: \(composed.blocks)")
    }

    /// Control: bold (an engine-native trait) survives a composition.
    func testControlACompositionInsideBoldStaysBold() throws {
        var bold = ChatInputInlineAttributes()
        bold.bold = true
        let composed = try self.run(bold, steps: self.japanese, composing: true)
        XCTAssertEqual(self.marked(composed, { $0.bold }), "Fi漢字rst", "control: a composition inside bold lost bold: \(composed.blocks)")
    }

    // MARK: - Over a SELECTION (reduced from the fuzz, 2026-09-24)
    //
    // The fuzz's broader signature (models equal once inline attributes are stripped) was a second
    // defect, not this class's first: a composition over a SELECTION was attributed by the
    // controller's marked-text rule rather than by what typing over that selection uses. Seeds 3 and
    // 11 (pinyin over a Select-All-and-Bold selection committed plain where typing stays bold), and
    // seeds 12/14/29 (a selection ending in spoiler or italic: the composition took the end's
    // attributes, typing the start's). Fixed with the class's first defect: the commit re-applies
    // the typing attributes the composition started with, then the typed-text policy.

    private func runOverSelection(_ content: ChatInputContent, select range: NSRange, steps: [String], commit: FuzzCommit?) throws -> ChatInputContent {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(content)
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        HarnessEngine.settle(root)
        let view = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        let from = try XCTUnwrap(view.position(from: view.beginningOfDocument, offset: range.location))
        let to = try XCTUnwrap(view.position(from: view.beginningOfDocument, offset: NSMaxRange(range)))
        view.selectedTextRange = view.textRange(from: from, to: to)
        HarnessEngine.settle(root)
        if let commit {
            for step in steps {
                view.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0))
                HarnessEngine.settle(root, seconds: 0.03)
            }
            switch commit {
            case .unmark, .cancel: view.unmarkText()
            case .insertFinal: view.insertText(steps.last ?? "")
            }
        } else {
            view.insertText(steps.last ?? "")
        }
        HarnessEngine.settle(root)
        XCTAssertNil(view.markedTextRange, "precondition: the composition is still open")
        return FuzzModel.normalized(node.currentInputContent().content)
    }

    private func assertComposesLikeTyping(_ content: ChatInputContent, select range: NSRange, _ what: String,
                                          file: StaticString = #filePath, line: UInt = #line) throws {
        let typed = try self.runOverSelection(content, select: range, steps: self.japanese, commit: nil)
        for commit in [FuzzCommit.unmark, .insertFinal] {
            let composed = try self.runOverSelection(content, select: range, steps: self.japanese, commit: commit)
            XCTAssertEqual(composed, typed, "\(what) (.\(commit.rawValue)):\n  typed    \(FuzzModel.describe(typed))\n  composed \(FuzzModel.describe(composed))",
                           file: file, line: line)
        }
    }

    /// Seed 11: Select All over bold paragraphs, then a composition — the gate deletes the selection
    /// and the composition began in the emptied block with ITS typing attributes (plain), where
    /// typing over the selection keeps bold.
    func testACompositionOverABoldCrossBlockSelectionIsBoldLikeTyping() throws {
        var bold = ChatInputInlineAttributes()
        bold.bold = true
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "pasted q", attributes: bold)])),
            .paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "hello", attributes: bold)])),
        ])
        try self.assertComposesLikeTyping(content, select: NSRange(location: 0, length: 14), "a composition over a bold cross-block selection")
    }

    /// Seed 14: a selection inside a run whose start is inline code. Typing over a selection gets the
    /// typing attributes alone (no typed-text policy), and the composition continued the preceding
    /// run's inline code through the policy.
    func testACompositionOverASelectionAfterInlineCodeIsAttributedLikeTyping() throws {
        var code = ChatInputInlineAttributes()
        code.monospace = true
        var italicCode = code
        italicCode.italic = true
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, list: nil, runs: [
            ChatInputRun(text: "c", attributes: code), ChatInputRun(text: "ode", attributes: italicCode), ChatInputRun(text: " span"),
        ]))])
        try self.assertComposesLikeTyping(content, select: NSRange(location: 1, length: 3), "a composition over a selection after inline code")
    }

    /// Control: a selection within one block that starts plain (or italic) and ends in formatting
    /// composes like typing. It passes with the fix neutered too (measured) — it is the within-block
    /// shape seeds 3/29 were suspected of, and it did not reproduce them; the fuzz is their check.
    func testControlACompositionOverASelectionEndingInFormattingIsAttributedLikeTyping() throws {
        var spoiler = ChatInputInlineAttributes()
        spoiler.spoiler = true
        spoiler.bold = true
        var italic = ChatInputInlineAttributes()
        italic.italic = true
        for runs in [
            [ChatInputRun(text: "plain "), ChatInputRun(text: "hidden", attributes: spoiler), ChatInputRun(text: " tail")],
            [ChatInputRun(text: "sl", attributes: italic), ChatInputRun(text: "anted plain tail")],
        ] {
            try self.assertComposesLikeTyping(ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, list: nil, runs: runs))]),
                                              select: NSRange(location: 1, length: 9), "a composition over a selection")
        }
    }
}
