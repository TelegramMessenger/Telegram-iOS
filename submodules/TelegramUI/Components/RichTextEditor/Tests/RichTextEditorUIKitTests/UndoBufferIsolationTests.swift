#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The editor must own a PRIVATE undo manager in production rather than the shared responder-chain
/// `UIResponder.undoManager`. Falling back to the app-wide manager let foreign entries — other responders'
/// and the system text-input subsystem's selection/typing undos — surface in the editor's `canUndo` /
/// `undo()`, the reported "a selection change is undoable / undo is active on the first tap before any
/// content edit" bug. Every undo test injects its own manager via `undoManagerOverride`; this pins the
/// PRODUCTION fallback (no override) to a private, per-canvas manager so the buffer can't be polluted.
final class UndoBufferIsolationTests: XCTestCase {
    private func canvas(_ text: String) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: text)]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        return v
    }

    /// Without an injected override, each canvas owns its OWN undo manager — not a single shared one that
    /// other responders could write into.
    func test_freshCanvas_withoutOverride_hasPrivateUndoManager() {
        let a = DocumentCanvasView()
        let b = DocumentCanvasView()
        XCTAssertNotNil(a.effectiveUndoManager, "the editor must always have an undo manager")
        XCTAssertFalse(a.effectiveUndoManager === b.effectiveUndoManager,
                       "each canvas must own a PRIVATE undo manager, not a shared responder-chain one")
    }

    /// Seeding content (no user edit yet) must leave undo unavailable. A shared/polluted manager would
    /// report `canUndo == true` here — the "undo active before any content edit" symptom.
    func test_freshCanvas_reportsNoUndoBeforeAnyEdit() {
        let v = canvas("hello")
        XCTAssertFalse(v.currentState().canUndo, "canUndo must be false before any content edit")
    }

    /// A real content edit enables undo, and one canvas's buffer never affects another's.
    func test_contentEdit_enablesUndo_andIsIsolatedPerCanvas() {
        let v = canvas("hello")
        let other = canvas("world")
        v.setSelectionForTesting(anchor: v.allLeafRegions().first!.globalStart + 5, head: v.allLeafRegions().first!.globalStart + 5)
        v.insertText("!")
        XCTAssertTrue(v.currentState().canUndo, "a content edit enables undo")
        XCTAssertFalse(other.currentState().canUndo, "another canvas's undo buffer is unaffected")
    }

    /// Undoing the only edit must drive `canUndo` back to false (so the host can disable the undo control).
    func test_canUndo_reachesFalse_afterUndoingTheOnlyEdit() {
        let v = canvas("hello")
        v.setSelectionForTesting(anchor: v.allLeafRegions().first!.globalStart + 5, head: v.allLeafRegions().first!.globalStart + 5)
        v.insertText("!")
        XCTAssertTrue(v.currentState().canUndo, "the edit is undoable")
        v.effectiveUndoManager?.undo()
        XCTAssertFalse(v.currentState().canUndo, "after undoing the only edit, canUndo must be false")
        XCTAssertTrue(v.currentState().canRedo, "and redo is now available")
    }

    /// The façade's `undo()`/`redo()` MUST fire `onChange` after the manager settles — even on an empty stack
    /// — so a host toolbar re-reads the now-final `canUndo`/`canRedo`. The undo closure's own refresh fires
    /// WHILE STILL INSIDE `UndoManager.undo()` (pre-settle), leaving the host stale after the LAST undo/redo
    /// (the control that should disable stays enabled until an unrelated layout pass). Asserting the empty-stack
    /// case isolates the explicit notify from the closure path (no closure runs when there's nothing to undo).
    func test_undoRedo_fireOnChange_soHostRefreshesAvailability() {
        let view = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        view.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "hi")]))])
        var changes = 0
        view.onChange = { changes += 1 }
        view.undo()   // empty undo stack → no closure runs; the explicit notify must still fire
        XCTAssertGreaterThanOrEqual(changes, 1, "undo() must fire onChange so a stale toolbar refreshes")
        let afterUndo = changes
        view.redo()   // empty redo stack → likewise
        XCTAssertGreaterThan(changes, afterUndo, "redo() must fire onChange too")
    }

    /// The editor's OWN manager is exposed to the responder chain (as `UIResponder.undoManager`), so the
    /// SYSTEM undo affordances — hardware ⌘Z / ⌘⇧Z, shake-to-undo, and the Edit-menu Undo/Redo — act on our
    /// edits. Without this override, `UIResponder.undoManager` returns the app-wide shared manager, which our
    /// edits never touch, so ⌘Z does nothing. (Regression guard for the "⌘Z stopped working after going
    /// private" report.)
    func test_undoManager_isTheEditorsOwnManager() {
        let v = DocumentCanvasView()
        XCTAssertTrue(v.undoManager === v.effectiveUndoManager,
                      "UIResponder.undoManager must be the editor's own manager so ⌘Z acts on our edits")
    }

    /// The exposed `undoManager` tracks `undoManagerOverride`, so the responder-chain wiring can never
    /// silently diverge from `effectiveUndoManager` (what every other undo path uses).
    func test_undoManager_followsInjectedOverride() {
        let v = DocumentCanvasView()
        let um = UndoManager()
        v.undoManagerOverride = um
        XCTAssertTrue(v.undoManager === um, "the exposed undoManager must track undoManagerOverride")
    }
}
#endif
