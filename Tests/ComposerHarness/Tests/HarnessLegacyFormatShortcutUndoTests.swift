import XCTest
import UIKit
import TelegramCore
import TextFormat
import AccountContext
import ChatPresentationInterfaceState
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the LEGACY composer, the chat's keyboard shortcut ⌘B (and ⌘I, ⌘U, ⇧⌘M, ⇧⌘X,
/// ⇧⌘P, ⇧⌘N) recorded no undo step: undo after it took back the TYPING before it and left the bold
/// on nothing. The shortcut's legacy path hands `chatTextInputAddFormattingAttribute` to the chat's
/// `updateTextInputStateAndMode`, which wraps it in the node's `performUndoableInputChange`; on the
/// legacy node that ran the body bare, the echo came back as an attribute-only write (which keeps
/// UIKit's typing steps) and nothing registered the change. The Format menu wraps the same command in
/// the text view's `performUndoableTextChange` and undid correctly, so the two disagreed.
///
/// **How it was seen.** Code review of the InputDec squash (2026-10-12), traced through
/// `ChatControllerKeyShortcuts` → `ChatControllerLoadDisplayNode.updateTextInputStateAndMode` →
/// `ChatInputTextView.attributedText`.
///
/// **Tier 1**: the shortcut's legacy path is `ChatTextInputPanelNode.performLegacyFormatShortcut`,
/// which `ChatControllerKeyShortcuts` calls; typing is `insertText(_:)`; the stack is the text view's
/// `undoManager`.
final class HarnessLegacyFormatShortcutUndoTests: XCTestCase {
    private func arrangeTypedAndSelected() throws -> HarnessLegacy.Arranged {
        let value = try HarnessLegacy.arrange(ChatInputContent())
        value.textView.insertText("hello world")
        HarnessEngine.settle(value.root)
        HarnessLegacy.select(value, NSRange(location: 6, length: 5))
        HarnessEngine.settle(value.root)
        return value
    }

    private func boldRuns(_ value: HarnessLegacy.Arranged) -> [String] {
        var bold: [String] = []
        for block in HarnessLegacy.content(value).blocks {
            if case let .paragraph(paragraph) = block {
                bold += paragraph.runs.filter { $0.attributes.bold }.map(\.text)
            }
        }
        return bold
    }

    func testUndoAfterTheBoldShortcutRemovesTheBoldAndKeepsTheText() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try self.arrangeTypedAndSelected()
        arranged = value

        // The shortcut's legacy path: the panel method `ChatControllerKeyShortcuts` calls.
        XCTAssertTrue(value.host.panel.performLegacyFormatShortcut { chatTextInputAddFormattingAttribute($0, attribute: ChatTextInputAttributes.bold, value: nil) },
                      "precondition: the legacy text view took the shortcut")
        HarnessEngine.settle(value.root)
        XCTAssertEqual(self.boldRuns(value), ["world"], "precondition: the shortcut did not bold the selection")

        let undoManager = try XCTUnwrap(value.textView.undoManager)
        undoManager.undo()
        HarnessEngine.settle(value.root)
        XCTAssertEqual(HarnessLegacy.content(value).plainText, "hello world", "undo after ⌘B took back the typing")
        XCTAssertEqual(self.boldRuns(value), [], "undo after ⌘B left the bold in place")
    }

    /// Control, and the re-entrancy check: the Format menu wraps the same command in the text view's
    /// own `performUndoableTextChange`, which now nests the node's. One undo must still revert exactly
    /// the bold, and the next one the typing.
    func testTheFormatMenuIsStillOneStepWithTheTypingBeneathIt() throws {
        var arranged: HarnessLegacy.Arranged?
        defer { HarnessLegacy.restore(arranged) }
        let value = try self.arrangeTypedAndSelected()
        arranged = value

        value.host.panel.formatAttributesBold(self)
        HarnessEngine.settle(value.root)
        XCTAssertEqual(self.boldRuns(value), ["world"], "precondition: Format ▸ Bold did not bold the selection")

        let undoManager = try XCTUnwrap(value.textView.undoManager)
        undoManager.undo()
        HarnessEngine.settle(value.root)
        XCTAssertEqual(HarnessLegacy.content(value).plainText, "hello world")
        XCTAssertEqual(self.boldRuns(value), [], "one undo did not revert the Format menu's bold")
        undoManager.undo()
        HarnessEngine.settle(value.root)
        XCTAssertEqual(HarnessLegacy.content(value).plainText, "", "the second undo did not revert the typing")
    }
}
