import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, indenting or outdenting a list item with the hardware
/// keyboard's Tab / Shift-Tab registers NO undo step. ⌘Z then undoes the edit BEFORE it, together
/// with the indent:
///
///     - one / - two / (nested) - nested
///     type "x" after "one" → caret to the end of "nested" → Shift-Tab (nested → level 0)
///     undo → "onex" back to "one" AND "nested" back to level 1, in one step; redo restores both
///
/// The same after a markdown paste: Tab right after pasting a list, then undo, reverts the paste's rich
/// step (the composer shows the raw `- one` text) while the indent disappears with it.
///
/// **How it was seen.** K1, 2026-09-23, sixth roam: the Tab key command (`handleListTab:` /
/// `handleListShiftTab:`, the actions of the editor view's own `keyCommands`) sent through lldb, undo via
/// the text view's `undoManager`. Seen 3× (Tab after typing, Tab after a paste, Shift-Tab after typing).
/// `canUndo` stays exactly as it was before the key.
///
/// **Suspected cause.** `indent()` / `outdent()` (`RichTextEngineEditorView+Paragraph.swift`) go through
/// `mutateTouchedParagraphs`, which applies the blocks with `applyEngineParallelBlocks` and records no
/// undo step. The list rules in `+Lists.swift` (`endList`, `outdentItem`) do record one, through
/// `applyParagraphShape(_:restoring:at:)`.
///
/// **Tier 1**: the key command's action is performed exactly as UIKit would, on the responder that
/// declares it; the undo manager is the text view's.
final class HarnessListIndentUndoTests: XCTestCase {
    private func item(_ text: String, level: Int32) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: level),
                                             runs: [ChatInputRun(text: text)]))
    }

    private func level(_ content: ChatInputContent, _ text: String) -> Int32? {
        for block in content.blocks {
            if case let .paragraph(paragraph) = block, paragraph.text == text {
                return paragraph.list?.level
            }
        }
        return nil
    }

    /// Types "x" after "one", moves the caret to `caret`, performs the Tab (or Shift-Tab) key command,
    /// then undoes once. Returns the content after the key and after the undo.
    private func run(shift: Bool, caret: Int) throws -> (afterKey: ChatInputContent, afterUndo: ChatInputContent) {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(ChatInputContent(blocks: [self.item("one", level: 0), self.item("two", level: 0), self.item("nested", level: 1)]))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        defer { _ = node.resignInputFirstResponder() }

        let textView = try HarnessEngine.textView(in: root)
        let undoManager = try XCTUnwrap(textView.undoManager)
        undoManager.removeAllActions()

        node.selectedRange = NSRange(location: 3, length: 0)
        HarnessEngine.settle(root)
        (textView as? UIKeyInput)?.insertText("x")
        HarnessEngine.settle(root)
        XCTAssertTrue(node.currentInputContent().content.plainText.hasPrefix("onex"), "precondition: typing did not land")

        node.selectedRange = NSRange(location: caret, length: 0)
        HarnessEngine.settle(root)

        // The responder that declares the list's Tab commands: the engine editor view above the text view.
        var responder: UIView? = textView
        var command: UIKeyCommand?
        while let view = responder, command == nil {
            command = view.keyCommands?.first { $0.input == "\t" && $0.modifierFlags == (shift ? .shift : []) }
            if command == nil {
                responder = view.superview
            }
        }
        let tab = try XCTUnwrap(command, "precondition: no list Tab key command is offered with the caret in a list item")
        let action = try XCTUnwrap(tab.action)
        _ = try XCTUnwrap(responder).perform(action, with: tab)
        HarnessEngine.settle(root)
        let afterKey = node.currentInputContent().content

        undoManager.undo()
        HarnessEngine.settle(root)
        return (afterKey, node.currentInputContent().content)
    }

    func testUndoAfterTabRevertsOnlyTheIndent() throws {
        // "onex\ntwo\nnested": the caret at the end of "two" is 8.
        let result = try self.run(shift: false, caret: 8)
        XCTAssertEqual(self.level(result.afterKey, "two"), 1, "precondition: Tab did not indent \"two\": \(result.afterKey.blocks)")
        XCTAssertEqual(self.level(result.afterUndo, "two"), 0, "undo did not revert the indent: \(result.afterUndo.blocks)")
        XCTAssertTrue(result.afterUndo.plainText.hasPrefix("onex"),
                      "undo after Tab also reverted the typing before it, so the indent had no step of its own: \(result.afterUndo.blocks)")
    }

    func testUndoAfterShiftTabRevertsOnlyTheOutdent() throws {
        // The caret at the end of "nested" is 15.
        let result = try self.run(shift: true, caret: 15)
        XCTAssertEqual(self.level(result.afterKey, "nested"), 0, "precondition: Shift-Tab did not outdent: \(result.afterKey.blocks)")
        XCTAssertEqual(self.level(result.afterUndo, "nested"), 1, "undo did not revert the outdent: \(result.afterUndo.blocks)")
        XCTAssertTrue(result.afterUndo.plainText.hasPrefix("onex"),
                      "undo after Shift-Tab also reverted the typing before it, so the outdent had no step of its own: \(result.afterUndo.blocks)")
    }
}
