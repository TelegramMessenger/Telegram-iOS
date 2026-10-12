import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, any edit that leaves an EMPTY LAST LINE after a QUOTE or
/// CODE block loses that line break outside UIKit's undo stack, and the next Undo raises an uncaught
/// `NSRangeException` (a crash in the app):
///
///     [code "abc"] [p "x = 1"] → select "x = 1" (4..<9) → Backspace
///       legacy: text "abc" (the line break went too), model [code "abc"], canUndo = true
///       → Undo: NSMutableRLEArray insertObject:range:: Out of bounds (NSRangeException)
///     the same after a block quote; Backspace over the only character of the last line ("x") too
///     [code "abc def"] → select " def" (3..<7) → Return
///       legacy: text "abc" (the typed line break is gone) → Undo: NSMutableRLEArray
///       replaceObjectsInRange:withObject:length:: Out of bounds (NSRangeException)
///     control, after a plain paragraph: text "abc\n", model [p "abc"] [p ""], Undo restores "x = 1"
///     Return with the caret at the end of the block: the view shows "abc def\n" but the model has no
///     such line (the node's selection lies past the model's end) — no echo, so no crash, but the
///     chat's state and the screen disagree
///
/// **How it was seen.** The seeded fuzz (`HarnessComposerFuzzTests`, legacy, seeds 15 and 18 of
/// 1-60, 2026-09-23): an undo raised mid-sequence in both legacy mixes (seed 15: Return over a
/// selection reaching the end of a code block; seed 18: Backspace over the paragraph after one);
/// reduced by replay.
///
/// **Mechanism (traced, text-storage edit notifications + the ObjC exception preprocessor).**
/// 1. `-[UITextInputController deleteBackward]` deletes the five characters: storage `"abc\n"`.
/// 2. `textViewDidChange` → `ChatTextInputPanelNode.chatInputTextNodeDidUpdateText` →
///    `updateTextInputStateAndMode`: the node reads `"abc\n"` back as `[code "abc"]` (an empty line
///    after a block is not representable in the flat attributed text: the line break reads as the
///    block's own terminator), which differs from the chat's previous state, so the chat pushes it
///    back — `ChatControllerNode.swift:3736` does so whenever `effectiveInputState` changed, and the
///    harness host copies that condition — and `setInputContent` → `ChatInputTextView.attributedText`
///    → `-[UITextView setAttributedText:]` writes `"abc"` (characters changed, so not the in-place path).
/// 3. That set does NOT remove UIKit's typing-undo operation for the deletion (`canUndo` stays true).
/// 4. Undo → `-[_UITextUndoOperationTyping _undoRedo]` → `textView(_:shouldChangeTextIn:)` for range
///    `{4, 0}` → `ChatTextInputPanelNode.chatInputTextNode(shouldChangeTextIn:replacementText:)` →
///    `replaceCharacters(in:with:)` on a 3-character copy → `NSRangeException`.
///
/// **Fixed (2026-10-12)** at step 2: `chatInputContent(from:)` (TextFormat) reads a line break that is
/// the text's LAST character, right after a carved block, as an empty trailing paragraph. So
/// `"abc\n"` reads back as `[code "abc"] [p ""]`, the chat pushes back what is on screen, and UIKit's
/// undo operation still describes the text it was recorded against. The same rule puts the line that
/// Return adds after a quote or code block into the model. Pinned below the harness by
/// `ChatInputContentConversionTests.test_chatCurrencyRoundTrip_emptyLastLineAfterACarvedBlock`.
///
/// **Tier 1**: `deleteBackward` and the view's `undoManager` are what the keyboard and ⌘Z / shake call;
/// the push-back is the chat's own condition. Before the fix the exception was caught by XCTest and
/// recorded as a failure of the case that raised it, so the undo cases were red by raising.
final class HarnessLegacyDeleteLineAfterBlockUndoTests: XCTestCase {
    private static let afterCode = ChatInputContent(blocks: [
        .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "abc")])),
        HarnessEngine.paragraph("x = 1"),
    ])
    private static let afterQuote = ChatInputContent(blocks: [
        .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("abc")]), collapsed: false)),
        HarnessEngine.paragraph("x = 1"),
    ])

    private func deleteLastLine(_ content: ChatInputContent, undo: Bool) throws -> (afterDelete: String, afterUndo: String?) {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(content)
        arranged = value
        let undoManager = try XCTUnwrap(value.textView.undoManager)
        undoManager.removeAllActions()

        HarnessLegacy.select(value, NSRange(location: 4, length: 5))
        value.textView.deleteBackward()
        HarnessEngine.settle(value.root)
        let afterDelete = value.textView.text ?? ""
        guard undo else {
            return (afterDelete, nil)
        }
        XCTAssertTrue(undoManager.canUndo, "precondition: the deletion registered no undo step")
        undoManager.undo()
        HarnessEngine.settle(value.root)
        return (afterDelete, value.textView.text ?? "")
    }

    func testEmptyingTheLineAfterACodeBlockKeepsTheLineBreak() throws {
        let result = try self.deleteLastLine(Self.afterCode, undo: false)
        XCTAssertEqual(result.afterDelete, "abc\n", "emptying the line after a code block also removed its line break (outside the undo stack)")
    }

    func testEmptyingTheLineAfterAQuoteKeepsTheLineBreak() throws {
        let result = try self.deleteLastLine(Self.afterQuote, undo: false)
        XCTAssertEqual(result.afterDelete, "abc\n", "emptying the line after a quote also removed its line break (outside the undo stack)")
    }

    /// Raised `NSRangeException` inside `undo()` before the fix.
    func testUndoAfterEmptyingTheLineAfterACodeBlockRestoresIt() throws {
        let result = try self.deleteLastLine(Self.afterCode, undo: true)
        XCTAssertEqual(result.afterUndo, "abc\nx = 1", "undo did not restore the deleted line")
    }

    /// The everyday path: Backspace over the last character of a one-character line after a code block.
    func testBackspacingTheLastCharacterAfterACodeBlockKeepsTheLineBreak() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(ChatInputContent(blocks: [
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "abc")])),
            HarnessEngine.paragraph("x"),
        ]))
        arranged = value
        value.textView.undoManager?.removeAllActions()
        HarnessLegacy.select(value, NSRange(location: 5, length: 0))
        value.textView.deleteBackward()
        HarnessEngine.settle(value.root)
        XCTAssertEqual(value.textView.text, "abc\n", "Backspacing the last character after a code block also removed its line break")
    }

    /// Return at the end of a block that ends the message, and Return over a selection reaching it.
    private func returnAtEnd(_ content: ChatInputContent, select: NSRange, undo: Bool) throws -> (afterReturn: String, afterUndo: String?) {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(content)
        arranged = value
        let undoManager = try XCTUnwrap(value.textView.undoManager)
        undoManager.removeAllActions()
        HarnessLegacy.select(value, select)
        value.textView.insertText("\n")
        HarnessEngine.settle(value.root)
        let afterReturn = value.textView.text ?? ""
        guard undo else {
            return (afterReturn, nil)
        }
        undoManager.undo()
        HarnessEngine.settle(value.root)
        return (afterReturn, value.textView.text ?? "")
    }

    private static let codeOnly = ChatInputContent(blocks: [.code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "abc def")]))])
    private static let quoteOnly = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(
        content: ChatInputContent(blocks: [HarnessEngine.paragraph("abc def")]), collapsed: false))])

    func testReturnAtTheEndOfACodeBlockAddsALine() throws {
        let result = try self.returnAtEnd(Self.codeOnly, select: NSRange(location: 7, length: 0), undo: false)
        XCTAssertEqual(result.afterReturn, "abc def\n", "Return at the end of a code block added no line")
    }

    func testReturnAtTheEndOfAQuoteAddsALine() throws {
        let result = try self.returnAtEnd(Self.quoteOnly, select: NSRange(location: 7, length: 0), undo: false)
        XCTAssertEqual(result.afterReturn, "abc def\n", "Return at the end of a quote added no line")
    }

    /// The other face of the same gap (fuzz seeds 43 and 45, per-step): Return with the caret at the
    /// end of a block that ends the message puts a line in the VIEW that the MODEL (and so the chat's
    /// state) does not have, and the node's selection lies past the model's end.
    func testReturnAtTheEndOfAQuoteIsInTheModel() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try HarnessLegacy.arrange(ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro line."),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Quoted text here.")]), collapsed: false)),
        ]))
        arranged = value
        HarnessLegacy.select(value, NSRange(location: 29, length: 0))
        value.textView.insertText("\n")
        HarnessEngine.settle(value.root)
        let model = value.node.currentInputContent().content
        XCTAssertEqual(value.textView.text, "Intro line.\nQuoted text here.\n", "precondition: Return added no line")
        XCTAssertEqual(model.plainText, value.textView.text, "the new line is on screen but not in the model")
        XCTAssertLessThanOrEqual(NSMaxRange(value.node.selectedRange), model.length, "the node's selection lies past the model's end")
    }

    /// Seed 15's shape: Return over a selection that reaches the end of the code block.
    func testReturnOverTheEndOfACodeBlockKeepsTheLineBreak() throws {
        let result = try self.returnAtEnd(Self.codeOnly, select: NSRange(location: 3, length: 4), undo: false)
        XCTAssertEqual(result.afterReturn, "abc\n", "Return over the end of a code block lost the typed line break")
    }

    func testUndoAfterReturnOverTheEndOfACodeBlockRestoresIt() throws {
        let result = try self.returnAtEnd(Self.codeOnly, select: NSRange(location: 3, length: 4), undo: true)
        XCTAssertEqual(result.afterUndo, "abc def", "undo did not restore the replaced text")
    }

    /// Control: after a plain paragraph the empty line stays and undo restores it.
    func testControlAfterAParagraph() throws {
        let result = try self.deleteLastLine(HarnessContent.plainText("abc\nx = 1"), undo: true)
        XCTAssertEqual(result.afterDelete, "abc\n", "control: the empty last line did not stay")
        XCTAssertEqual(result.afterUndo, "abc\nx = 1", "control: undo did not restore the line")
    }
}
