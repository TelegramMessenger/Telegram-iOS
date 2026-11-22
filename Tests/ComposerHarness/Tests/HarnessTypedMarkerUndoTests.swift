import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** On the engine backend, text typed INSIDE a spoiler or an inline-code (Monospace)
/// run loses that marker when a LATER, unrelated edit is undone. The undo restores the document of
/// the moment before the later edit — except that the character typed inside the spoiler comes back
/// as plain text, splitting the spoiler in two:
///
///     "First paragraph." → select "First" → Format ▸ Spoiler → caret after "Fi" → type "Z"
///       model: [sp "FiZrst"] " paragraph."                 (correct, the spoiler continues)
///     → caret to the end of the text → type "Y" → undo
///       engine: [sp "Fi"] "Z" [sp "rst"] " paragraph."     (Z is no longer hidden)
///       expected: [sp "FiZrst"] " paragraph."
///
/// Monospace behaves the same (`[m "Fi"] "Z" [m "rst"]`). Bold — a trait the engine's typing
/// attributes carry natively — does not (`[b "FiZrst"]` after the same undo), which is the control
/// in this test. A spoiler losing a character on undo reveals that character in the sent message.
///
/// **How it was seen.** K1, 2026-09-23, twice for Spoiler and once for Monospace, Bold as control,
/// via the Format menu's own `UIAction`s (read out of `tgid_editMenuElementsProvider`),
/// `insertText:` and `undoManager.undo` on the engine text view. Legacy is not a usable control:
/// it never continues a spoiler into typed text in the first place (`[sp "Fi"] "Z" [sp "rst"]`
/// straight after typing, measured), whereas the engine continues it deliberately — so the oracle
/// here is the engine's own model BEFORE the undo.
///
/// **Suspected cause.** The undo baseline (`lastSettledUndoSnapshot`, captured by
/// `commitUndoSnapshotAfterSettle` in `RichTextEngineEditorView+UndoStack.swift`) is taken from
/// `document` before the markers that `attributesForTypedText` copies forward
/// (`markersThatAlwaysContinue` in `+TypedText.swift`: `.rtSpoiler`, `.rtInlineCode`) are part of
/// what `document` reads back for the typed character — so the snapshot records "Z" plain while
/// the live model (read later) shows it inside the spoiler.
///
/// **Tier 1**: the format command is the one the menu calls (`performFormatAction`), typing and
/// undo are the calls the keyboard and shake/⌘Z make, and the defect is in the model.
final class HarnessTypedMarkerUndoTests: XCTestCase {
    private func runsAfterUndo(format: ChatRichTextFormatAction) throws -> [ChatInputRun] {
        let root = try HarnessEngine.root()
        let host = try XCTUnwrap(root.panelHost)
        let node = try HarnessEngine.node(host)

        host.setInputContent(HarnessContent.plainText("First paragraph."))
        HarnessEngine.settle(root)
        _ = node.makeInputFirstResponder()
        HarnessEngine.settle(root)
        let textView = try HarnessEngine.textView(in: root)
        let keyInput = try XCTUnwrap(textView as? UIKeyInput)
        let undoManager = try XCTUnwrap(textView.undoManager, "precondition: the engine view has no undo manager")

        node.selectedRange = NSRange(location: 0, length: 5)
        HarnessEngine.settle(root)
        node.performFormatAction(format)
        HarnessEngine.settle(root)

        node.selectedRange = NSRange(location: 2, length: 0)
        HarnessEngine.settle(root)
        keyInput.insertText("Z")
        HarnessEngine.settle(root)

        node.selectedRange = NSRange(location: 17, length: 0)
        HarnessEngine.settle(root)
        keyInput.insertText("Y")
        HarnessEngine.settle(root)

        undoManager.undo()
        HarnessEngine.settle(root)

        let blocks = node.currentInputContent().content.blocks
        _ = node.resignInputFirstResponder()
        guard case let .paragraph(paragraph)? = blocks.first, blocks.count == 1 else {
            XCTFail("unexpected structure after undo: \(blocks)")
            return []
        }
        XCTAssertEqual(paragraph.runs.map(\.text).joined(), "FiZrst paragraph.",
                       "precondition: the undo did not remove exactly the later \"Y\"")
        return paragraph.runs
    }

    /// The characters of `runs` that carry `flag`, as a string.
    private func flagged(_ runs: [ChatInputRun], _ flag: (ChatInputInlineAttributes) -> Bool) -> String {
        return runs.filter { flag($0.attributes) }.map(\.text).joined()
    }

    func testBoldControlSurvivesUndoOfALaterEdit() throws {
        let runs = try self.runsAfterUndo(format: .bold)
        XCTAssertEqual(self.flagged(runs, { $0.bold }), "FiZrst",
                       "control: bold typed inside bold no longer survives the undo")
    }

    func testSpoilerTypedInsideASpoilerSurvivesUndoOfALaterEdit() throws {
        let runs = try self.runsAfterUndo(format: .spoiler)
        XCTAssertEqual(self.flagged(runs, { $0.spoiler }), "FiZrst",
                       "undoing a later edit stripped the spoiler from text typed inside it: \(runs)")
    }

    func testMonospaceTypedInsideInlineCodeSurvivesUndoOfALaterEdit() throws {
        let runs = try self.runsAfterUndo(format: .monospace)
        XCTAssertEqual(self.flagged(runs, { $0.monospace }), "FiZrst",
                       "undoing a later edit stripped inline code from text typed inside it: \(runs)")
    }
}
