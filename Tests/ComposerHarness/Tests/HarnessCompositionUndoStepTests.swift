import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, an IME composition made after a Backspace that UNQUOTES a
/// paragraph (the first paragraph of a block quote that follows a paragraph) or UN-NESTS one (the
/// first paragraph of a nested quote) joins that Backspace's undo step — even with the caret moved
/// elsewhere in between. One undo then takes back both the composition and the structural change:
///
///     [p "Intro line."] [quote "Quoted text here."], caret at the quote's start, Backspace
///       → [p "Intro line."] [p "Quoted text here."]            (unquoted, correct)
///     caret to 3, compose k → か → 漢字, commit → [p "Int漢字ro line."] [p "Quoted text here."]
///     undo → [p "Intro line."] [quote "Quoted text here."]      (the quote is back as well)
///     typing "x" instead of composing: undo → [p "Intro line."] [p "Quoted text here."]  (control)
///
/// Pull quote / code unwrap, list outdent, Shift-Tab, a heading's Return and Format ▸ Quote before
/// the composition all undo correctly (probe log), as does a composition after plain typing or a
/// plain Backspace. A stock `UITextView` undoes only the composition.
///
/// **How it was seen.** p11 roam, 2026-09-24: the fuzz's new `compose` op (invariant: one undo
/// reverts exactly the composition), seed 43 of the first sweep — `.edge(12, .backspace)` on a nested
/// quote, then a composition elsewhere — and seeds 13 / 26 / 37 with the same "undo went further back"
/// signature; reduced by a hosted probe of structural keystrokes followed by a composition.
///
/// **Suspected cause.** `recordUndoForEngineEdit` (`RichTextEngineEditorView+UndoStack.swift`) lets a
/// composition continue ANY open typing run (`if composing || contiguous`), and the quote-unwrapping
/// Backspace rules (`+BackspaceRules.swift`) leave a run open that the later caret moves do not end —
/// `refreshUndoBaselineSelection`, which ends a run on a caret move, bails out while
/// `isSettling` / `isIssuingHostEdit`, or the run is re-opened by the rule's own settle after the
/// moves. Typing is immune only because a non-contiguous insert opens a step of its own.
///
/// **Tier 1**: the keystroke, the caret moves, the composition and the undo are all the keyboard's
/// calls on the engine view.
final class HarnessCompositionUndoStepTests: XCTestCase {
    private func run(_ start: ChatInputContent, backspaceAt offset: Int, composeAt caret: Int, composing: Bool) throws -> (before: ChatInputContent, undone: ChatInputContent) {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(start)
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }
        HarnessEngine.settle(root)
        let view = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UITextInput))
        view.undoManager?.removeAllActions()
        func place(_ offset: Int) throws {
            let position = try XCTUnwrap(view.position(from: view.beginningOfDocument, offset: offset))
            view.selectedTextRange = view.textRange(from: position, to: position)
            HarnessEngine.settle(root)
        }
        try place(offset)
        (view as? UIKeyInput)?.deleteBackward()
        HarnessEngine.settle(root)
        let before = FuzzModel.normalized(node.currentInputContent().content)
        try place(0)
        try place(caret)
        if composing {
            for step in ["k", "か", "漢字"] {
                view.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0))
                HarnessEngine.settle(root, seconds: 0.03)
            }
            view.unmarkText()
        } else {
            view.insertText("x")
        }
        HarnessEngine.settle(root)
        XCTAssertNotEqual(FuzzModel.normalized(node.currentInputContent().content), before, "precondition: nothing was inserted")
        view.undoManager?.undo()
        HarnessEngine.settle(root)
        return (before, FuzzModel.normalized(node.currentInputContent().content))
    }

    private var paragraphThenQuote: ChatInputContent {
        return ChatInputContent(blocks: [
            HarnessEngine.paragraph("Intro line."),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Quoted text here.")]), collapsed: false)),
        ])
    }

    func testUndoAfterUnquotingAndComposingRevertsOnlyTheComposition() throws {
        // "Intro line." 0..<11, "\n", the quote's paragraph from 12.
        let result = try self.run(self.paragraphThenQuote, backspaceAt: 12, composeAt: 3, composing: true)
        guard case .paragraph? = result.before.blocks.last else {
            return XCTFail("precondition: Backspace at the quote's start did not unquote it: \(FuzzModel.describe(result.before))")
        }
        XCTAssertEqual(result.undone, result.before,
                       "one undo after a composition also reverted the unquoting Backspace before it:\n  before \(FuzzModel.describe(result.before))\n  undone \(FuzzModel.describe(result.undone))")
    }

    func testUndoAfterUnnestingAndComposingRevertsOnlyTheComposition() throws {
        let nested = ChatInputContent(blocks: [.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [
            HarnessEngine.paragraph("Outer line."),
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Deep line.")]), collapsed: false)),
        ]), collapsed: false))])
        let result = try self.run(nested, backspaceAt: 12, composeAt: 3, composing: true)
        XCTAssertEqual(result.undone, result.before,
                       "one undo after a composition also reverted the un-nesting Backspace before it:\n  before \(FuzzModel.describe(result.before))\n  undone \(FuzzModel.describe(result.undone))")
    }

    /// Control: typing instead of composing undoes only the typing.
    func testControlTypingAfterUnquotingUndoesOnlyTheTyping() throws {
        let result = try self.run(self.paragraphThenQuote, backspaceAt: 12, composeAt: 3, composing: false)
        XCTAssertEqual(result.undone, result.before, "control: \(FuzzModel.describe(result.undone))")
    }

    /// Fuzz seed 29 (2026-09-24, after the fix above): the FIRST character composed into an empty
    /// quote gives the quote content, so settle mints its author line — a structural edit that closed
    /// the run the composition had just opened, and the next candidate opened a step of its own. One
    /// undo then left the first candidate behind. Typing the same text there is the control.
    func testOneUndoRevertsACompositionIntoAnEmptyQuote() throws {
        for composing in [false, true] {
            let root = try HarnessEngine.root()
            let host = try XCTUnwrap(root.panelHost)
            let node = try HarnessEngine.node(host)
            host.setInputContent(ChatInputContent(blocks: [
                .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("")]), collapsed: false)),
            ]))
            HarnessEngine.settle(root)
            _ = node.makeInputFirstResponder()
            defer { _ = node.resignInputFirstResponder() }
            HarnessEngine.settle(root)
            let view = try XCTUnwrap(HarnessEngine.textView(in: root) as? (UIView & UITextInput))
            view.undoManager?.removeAllActions()
            view.selectedTextRange = view.textRange(from: view.beginningOfDocument, to: view.beginningOfDocument)
            HarnessEngine.settle(root)
            let before = FuzzModel.normalized(node.currentInputContent().content)
            if composing {
                for step in ["a", "あ", "あr", "あり"] {
                    view.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0))
                    HarnessEngine.settle(root, seconds: 0.03)
                }
                view.unmarkText()
            } else {
                for character in ["a", "b", "c"] {
                    view.insertText(character)
                    HarnessEngine.settle(root, seconds: 0.03)
                }
            }
            HarnessEngine.settle(root)
            XCTAssertNotEqual(FuzzModel.normalized(node.currentInputContent().content), before, "precondition: nothing was inserted")
            // Fuzz seed 29, third signature: the author line settle minted while the FIRST candidate
            // was still marked moved text under the marked range, and the commit kept "a" in front.
            XCTAssertEqual(node.currentInputContent().content.plainText, composing ? "あり" : "abc",
                           "\(composing ? "composing" : "typing") into an empty quote: \(FuzzModel.describe(node.currentInputContent().content))")
            view.undoManager?.undo()
            HarnessEngine.settle(root)
            let undone = FuzzModel.normalized(node.currentInputContent().content)
            XCTAssertEqual(undone, before, "\(composing ? "composing" : "typing"): one undo left \(FuzzModel.describe(undone))")
        }
    }
}
