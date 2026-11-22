#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task D4c — **the façade's mutation baseline must survive a document change that does not move a
/// single character.**
///
/// D4b's differential corpus found `deleteBackward()` doing NOTHING AT ALL when it followed a
/// formatting toggle: `delete-run-boundary` and `backspace-block-boundary` (both in
/// `Tests/DifferentialSupport/TextInputScenarios/inline-formatting-ios26.5-v1.json`) left the
/// document byte-identical, 18 differing fields between them, while stock UIKit deleted/merged
/// normally.
///
/// **The mechanism, measured (see this task's report for the raw instrumentation):** a bold toggle
/// runs through `DocumentCanvasView.synchronizingExternalChange`, which bumps the canvas's
/// `documentRevision` (`+Editing.swift:384`, "one revision per editing transaction, even for a
/// no-op body") and is adopted by `IDTextEditorBackend.synchronizeAfterExternalChange` — but it
/// changes ATTRIBUTES ONLY, so the document's plain text is untouched. The kernel-driven mutation
/// path (`deleteBackward()`, `setMarkedText(_:selectedRange:)` — anything UIKit's private
/// controller drives itself) hands `TGRichTextInputDecTextStorageFacade.revision` to
/// `prepareAndCommitReplacementInRange:…expectedRevision:` as the transaction's baseline, and
/// `TelegramDocumentInputClient.prepareMutation` opens with
/// `guard expectedRevision == revision else { return terminal(.revisionMismatch) }`
/// (`TelegramDocumentInputClient.swift:120`). A rejection reports through
/// `lifecycleClient.backendDidRejectMutation`, whose Telegram implementation is an EMPTY BODY
/// (`TelegramLifecycleInputClient.swift:44-45`) — hence "nothing at all", with no contract
/// violation and no trace.
///
/// `insertText(_:)` is immune only because it refreshes that baseline itself
/// (`IDTextEditorBackend.swift`, `bridge.storage.revision = state.documentRevision`); the
/// kernel-driven witnesses have no such line and rely on
/// `synchronizeMirrorWithDocumentIfNeeded` to keep it fresh — which it did on its
/// content-differs path and NOT on its "already in sync" fast path. That asymmetry is the bug.
///
/// Gated like every other `.inputDec` suite: `isSupported()` is false off the certified band.
@available(iOS 17.0, *)
@MainActor
final class IDBackendFormattingThenDeleteTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// Places the caret through the REAL `position(from:offset:)` + `selectedTextRange` pair rather
    /// than `setSelectionForTesting` — the same deviation, for the same reason,
    /// `IDBackendDifferentialTraceTests` documents at length: the raw test seam never touches
    /// `state.documentRevision`, which silently rejects every subsequent `.inputDec` mutation and
    /// would make this suite pass by no-oping.
    private func caret(_ canvas: DocumentCanvasView, _ offset: Int) {
        let p = canvas.position(from: canvas.beginningOfDocument, offset: offset)!
        canvas.selectedTextRange = canvas.textRange(from: p, to: p)
    }

    private func selection(_ canvas: DocumentCanvasView, _ from: Int, _ to: Int) {
        let a = canvas.position(from: canvas.beginningOfDocument, offset: from)!
        let b = canvas.position(from: canvas.beginningOfDocument, offset: to)!
        canvas.selectedTextRange = canvas.textRange(from: a, to: b)
    }

    /// The corpus's own `checkpoint` transaction, reduced to the one thing that matters here: it
    /// CAPTURES THE DOCUMENT'S TEXT, and the only route to that is `text(in:)` → the kernel →
    /// `-[TGRichTextInputDecTextStorageFacade string]` → `synchronizeMirrorWithDocumentIfNeeded`.
    ///
    /// **Load-bearing, not scaffolding.** The pre-fix bug needs the mirror to be ALREADY in sync
    /// when the attribute-only change lands: only then does the next sync take the "already in
    /// sync" fast path (which forgot `revision`) rather than the content-differs rebuild (which
    /// refreshed it as a side effect). Drop these calls and the two tests below pass against the
    /// broken façade — measured, and the reason they are written this way. Every corpus scenario
    /// opens with a `baseline` checkpoint, so this is what the real run does.
    @discardableResult
    private func checkpoint(_ canvas: DocumentCanvasView) -> String {
        guard let range = canvas.textRange(from: canvas.beginningOfDocument, to: canvas.endOfDocument)
        else { return "" }
        return canvas.text(in: range) ?? ""
    }

    /// `delete-run-boundary`, transaction for transaction: select "A", bold it, collapse the caret
    /// to the run boundary, backspace. The document must lose the "A".
    func test_deleteBackwardAfterAFormattingToggle_mutatesTheDocument() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["AB"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas
        let um = h.undoManager

        checkpoint(canvas)                     // scenario transaction 1: `baseline`
        selection(canvas, 0, 1)
        checkpoint(canvas)                     // `operation-01`
        um.beginUndoGrouping(); canvas.toggleBold(); um.endUndoGrouping()
        let revisionAfterToggle = canvas.documentRevision
        checkpoint(canvas)                     // `operation-02`
        caret(canvas, 1)
        checkpoint(canvas)                     // `operation-03`

        um.beginUndoGrouping(); canvas.deleteBackward(); um.endUndoGrouping()

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["B"],
                       "a backspace immediately after a formatting toggle must delete the character "
                       + "before the caret — an attribute-only change ahead of it must not turn the "
                       + "delete into a silent no-op")
        XCTAssertGreaterThan(canvas.documentRevision, revisionAfterToggle,
                             "the delete must have run a real document transaction")
    }

    /// `backspace-block-boundary`, the second corpus scenario of this shape: bold the second
    /// paragraph, put the caret at its start, backspace. The two paragraphs must merge.
    func test_backspaceAtABlockBoundaryAfterAFormattingToggle_mergesTheParagraphs() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["A", "B"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas
        let um = h.undoManager

        checkpoint(canvas)
        // "A" occupies [0,1) on the axis `position(from: beginningOfDocument, offset:)` walks; the
        // top-level paragraph boundary takes TWO slots (1→2, 2→3), so "B" starts at 3 — the same
        // arithmetic `IDBackendDifferentialTraceTests`' `backspace-merges-paragraphs` documents for
        // "Alpha"/"Beta" (5 + 2 = 7).
        selection(canvas, 3, 4)
        checkpoint(canvas)
        um.beginUndoGrouping(); canvas.toggleBold(); um.endUndoGrouping()
        let revisionAfterToggle = canvas.documentRevision
        checkpoint(canvas)
        caret(canvas, 3)
        checkpoint(canvas)

        um.beginUndoGrouping(); canvas.deleteBackward(); um.endUndoGrouping()

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["AB"],
                       "a backspace at a block boundary immediately after a formatting toggle must "
                       + "still merge the two paragraphs")
        XCTAssertGreaterThan(canvas.documentRevision, revisionAfterToggle,
                             "the merge must have run a real document transaction")
    }

    /// The CONTROL, and the reason the two tests above are about the toggle rather than about
    /// backspace: the identical backspace with no formatting toggle in front of it already works.
    func test_deleteBackwardWithoutAFormattingToggle_stillMutatesTheDocument() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["AB"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas
        let um = h.undoManager

        checkpoint(canvas)
        caret(canvas, 1)
        checkpoint(canvas)
        um.beginUndoGrouping(); canvas.deleteBackward(); um.endUndoGrouping()

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["B"])
    }

    /// The narrow, MECHANISM-level pin, one layer below the three behavioural tests above: after an
    /// attribute-only document change (revision moves, plain text does not),
    /// `TGRichTextInputDecTextStorageFacade.revision` — the value every kernel-driven mutation hands
    /// `prepareAndCommitReplacementInRange:…expectedRevision:` — must have caught up. Would fail
    /// against the pre-fix façade, whose "already in sync" fast path adopted
    /// `_lastSyncedBridgeRevision` but left `revision` behind.
    func test_facadeAdoptsANewRevision_whenTheDocumentChangedWithoutMovingACharacter() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["AB"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas
        let facade = h.storageFacade!
        let um = h.undoManager

        // One read first, so the mirror is genuinely in sync before the toggle — otherwise the
        // content-differs path would refresh `revision` as a side effect and the test would be
        // vacuous.
        _ = facade.string
        XCTAssertEqual(facade.string, "AB")

        selection(canvas, 0, 1)
        um.beginUndoGrouping(); canvas.toggleBold(); um.endUndoGrouping()
        _ = facade.string   // the corpus's own post-toggle checkpoint reads the text here

        XCTAssertEqual(facade.revision, canvas.documentRevision,
                       "the façade's mutation baseline must track a document change that moved no "
                       + "characters; otherwise the next kernel-driven mutation is rejected as "
                       + "revisionMismatch and does nothing at all")
    }
}
#endif
