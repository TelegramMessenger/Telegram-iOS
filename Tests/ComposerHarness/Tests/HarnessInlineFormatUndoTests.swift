import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, undoing an inline format toggle (Bold / Italic from the
/// Format menu) and then redoing it does not bring the formatting back, and the undo itself drops
/// the selection:
///
/// 1. select "quick", Format ▸ Bold → `quick` is bold, selection 4..<9;
/// 2. undo → the bold is gone, but the selection is the caret at 44..<44 (the end of the text,
///    i.e. where the scenario seed left it), not the 4..<9 the user had selected;
/// 3. redo → `canUndo` becomes true again (the step ran) but the text stays plain.
///
/// Structural commands do not have this problem: Format ▸ Code, undo, redo round-trips (and the
/// undo restores the selection), and a text edit round-trips too. So does an italic toggle that is
/// followed by a paste before undoing twice — only the toggle as the most recent step is broken.
///
/// **How it was seen.** K1, engine, 2026-09-22, three times (Bold once, Italic twice), `undo`/`redo`
/// sent to the first responder's `undoManager` — what shake-to-undo and ⌘Z call; neither can be
/// delivered to K1 (no shake in simctl; HID key events do not reach the app). Screenshot after the
/// redo confirms the word is not bold. Legacy is not a usable control in the harness: its Format
/// menu routes through `updateTextInputStateAndMode`, which the harness does not push back into the
/// panel (see findings, harness gaps).
///
/// **Suspected cause.** Inline toggles (`RichTextEngineEditorView+Formatting.swift`) do not record a
/// command step with the pre-toggle snapshot (`recordUndoStepForCommand(restoring:)`) the way
/// structural commands do; the step comes from the attribute-only edit going through
/// `recordUndoForEngineEdit`, which restores `lastSettledUndoSnapshot` (stale selection), alongside
/// whatever `IDInlineTextFormattingController` registers into the same manager.
///
/// **Tier 1**: `NSUndoManager.undo()`/`redo()` on the engine view's own manager is exactly the call
/// the system makes, and the model is readable in-process.
final class HarnessInlineFormatUndoTests: XCTestCase {
    private func quickRun(_ node: ChatRichTextInputNode) -> ChatInputInlineAttributes? {
        let content = node.currentInputContent().content
        guard case let .paragraph(paragraph)? = content.blocks.first else {
            return nil
        }
        var offset = 0
        for run in paragraph.runs {
            let end = offset + run.text.utf16.count
            if offset <= 4 && 9 <= end {
                return run.attributes
            }
            offset = end
        }
        return nil
    }

    func testUndoingAndRedoingBoldRoundTrips() throws {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)
        host.setInputContent(HarnessContent.plainText("The quick brown fox jumps over the lazy dog."))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)

        node.selectedRange = NSRange(location: 4, length: 5)
        HarnessEngine.settle(root)
        node.performFormatAction(.bold)
        HarnessEngine.settle(root)
        XCTAssertEqual(self.quickRun(node)?.bold, true, "precondition: Format ▸ Bold did not bold \"quick\"")

        let undoManager = try XCTUnwrap(try HarnessEngine.textView(in: root).undoManager,
                                        "precondition: the engine view has no undo manager")
        XCTAssertTrue(undoManager.canUndo, "precondition: the bold toggle registered no undo step")

        undoManager.undo()
        HarnessEngine.settle(root)
        XCTAssertEqual(self.quickRun(node)?.bold, false, "undo did not remove the bold")
        XCTAssertEqual(node.selectedRange, NSRange(location: 4, length: 5),
                       "undo did not restore the selection the format was applied to")

        XCTAssertTrue(undoManager.canRedo, "precondition: nothing to redo after undoing the bold")
        undoManager.redo()
        HarnessEngine.settle(root)
        XCTAssertEqual(self.quickRun(node)?.bold, true, "redo did not re-apply the bold")

        _ = node.resignInputFirstResponder()
    }
}
