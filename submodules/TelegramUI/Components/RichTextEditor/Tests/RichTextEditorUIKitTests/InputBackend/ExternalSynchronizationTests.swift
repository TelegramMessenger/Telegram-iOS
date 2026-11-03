#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 39b — the five HOST-ORIGINATED document-change sites now declare an explicit
/// `RichTextInputExternalChangeReason` + `RichTextMarkedTextPolicy` through
/// `DocumentCanvasView.synchronizingExternalChange(...)`, instead of mutating the document behind the
/// backend's back.
///
/// **The bracket is on ORIGINATION POINTS, never on the shared `setBlocks` primitive.** `setBlocks`
/// has six callers and only two of them (`reload`, the `registerUndo` restore) are host-originated;
/// the other three real ones (`+Clipboard`'s two paste splices and `replaceRange`) run INSIDE
/// `editing { }` and are keyboard mutations. Reporting those as external changes is the mirror of
/// what the spec forbids — a counterfeit EXTERNAL change standing in for a real keyboard one — so
/// three of this file's four negative controls exist to catch exactly that (`insertText` alone
/// cannot: it never reaches `setBlocks`).
/// FIX ROUND 1 (review Major 1) — a `UITextInputDelegate` that samples ONE backend-internal value at
/// each of the four notification points. It exists so the ordering claim ("the synchronization lands
/// before `textDidChange`") is measured against something the backend actually owns, rather than
/// against a host callback the fix now suppresses.
@MainActor
@available(iOS 16.0, *)
private final class AdoptedRevisionProbe: NSObject, UITextInputDelegate {
    private let sample: () -> UInt64
    private(set) var atTextWillChange: UInt64?
    private(set) var atTextDidChange: UInt64?

    init(sample: @escaping () -> UInt64) { self.sample = sample }

    func textWillChange(_ ti: UITextInput?) { atTextWillChange = sample() }
    func textDidChange(_ ti: UITextInput?) { atTextDidChange = sample() }
    func selectionWillChange(_ ti: UITextInput?) {}
    func selectionDidChange(_ ti: UITextInput?) {}
    @available(iOS 18.4, *)
    func conversationContext(_ context: UIConversationContext?, didChange ti: UITextInput?) {}
}

@MainActor
@available(iOS 16.0, *)
final class ExternalSynchronizationTests: XCTestCase {

    // MARK: - Fixtures

    /// A spy-backed canvas. The spy records every `synchronizeAfterExternalChange` argument and
    /// answers no witness, so anything this file drives has to be a CANVAS-side path — which is
    /// exactly the population the bracket lives in.
    private func spyCanvas(_ texts: [String] = ["Alpha", "Beta"]) -> (DocumentCanvasView, SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        spy.reset()
        return (v, spy)
    }

    /// A real-backend canvas, for the two questions the spy cannot answer: delegate ORDERING (the spy
    /// emits no `UITextInputDelegate` notification) and the backend's own revision-continuity guard
    /// (the spy has none).
    private func realCanvas(_ texts: [String] = ["Alpha", "Beta"]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    private func paragraph(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }

    private func assertOneChange(_ spy: SpyRichTextInputBackend,
                                 reason: RichTextInputExternalChangeReason,
                                 policy: RichTextMarkedTextPolicy,
                                 _ message: String = "",
                                 file: StaticString = #filePath, line: UInt = #line) -> RichTextInputExternalChange? {
        XCTAssertEqual(spy.observedExternalChanges.count, 1,
                       "expected exactly one external change \(message) — got \(spy.observedExternalChanges.count)",
                       file: file, line: line)
        guard let change = spy.observedExternalChanges.first else { return nil }
        XCTAssertEqual(change.reason, reason, message, file: file, line: line)
        XCTAssertEqual(change.markedTextPolicy, policy, message, file: file, line: line)
        return change
    }

    // MARK: - The five sites

    func test_reloadSynchronizesAsDocumentReplacementWithDiscard() {
        let (v, spy) = spyCanvas()
        v.reload([paragraph("q", "Gamma")], width: 300)
        _ = assertOneChange(spy, reason: .documentReplacement, policy: .discard, "reload")
    }

    /// The responder path: a system Cmd-Z reaches `registerUndo`'s closure directly, WITHOUT the
    /// facade's `finalizeMarkedText()` — which is why the closure's policy is `.discard`.
    func test_undoThroughTheResponderPathSynchronizesAsUndoWithDiscard() {
        let (v, spy) = spyCanvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.setCaret(global: v.boxes[0].textStart + 1)
        um.beginUndoGrouping()
        v.editing { v.applyReplaceOutcome(globalFrom: v.head, globalTo: v.head, text: "x") }
        um.endUndoGrouping()
        spy.reset()
        um.undo()
        _ = assertOneChange(spy, reason: .undo, policy: .discard, "responder undo")
    }

    /// The closure re-registers its own inverse, so the SAME body serves redo — and must say so.
    func test_redoSynchronizesAsRedo() {
        let (v, spy) = spyCanvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.setCaret(global: v.boxes[0].textStart + 1)
        um.beginUndoGrouping()
        v.editing { v.applyReplaceOutcome(globalFrom: v.head, globalTo: v.head, text: "x") }
        um.endUndoGrouping()
        um.undo()
        spy.reset()
        um.redo()
        _ = assertOneChange(spy, reason: .redo, policy: .discard, "responder redo")
    }

    /// RULING 2 (coordinator supplement §2) — **the facade does NOT get its own bracket.**
    /// `RichTextEditorView.undo()` is `canvas.finalizeMarkedText(); canvas.effectiveUndoManager?.undo();
    /// onChange?()`, and that middle statement INVOKES the `registerUndo` closure. A bracket on both
    /// would emit two external changes for one user-visible undo. This test drives the facade's two
    /// canvas statements verbatim and pins the count at one.
    ///
    /// (It runs on a spy-backed CANVAS rather than a real `RichTextEditorView`, because the facade
    /// builds its own canvas with `let canvas = DocumentCanvasView()` and offers no backend
    /// injection point. The two statements below are copied from `RichTextEditorView.swift:440`;
    /// the third, `onChange?()`, cannot synchronize anything — it is a host callback.)
    func test_theFacadeUndoPathSynchronizesExactlyOnce() {
        let (v, spy) = spyCanvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.setCaret(global: v.boxes[0].textStart + 1)
        um.beginUndoGrouping()
        v.editing { v.applyReplaceOutcome(globalFrom: v.head, globalTo: v.head, text: "x") }
        um.endUndoGrouping()
        spy.reset()
        _ = v.finalizeMarkedText(); v.effectiveUndoManager?.undo()
        _ = assertOneChange(spy, reason: .undo, policy: .discard, "facade undo path")
    }

    func test_boldToggleSynchronizesAsFormattingWithPreserveIfRebasable() {
        let (v, spy) = spyCanvas()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 3)
        spy.reset()
        v.toggleBold()
        _ = assertOneChange(spy, reason: .formatting, policy: .preserveIfRebasable, "toggleBold")
    }

    func test_setLinkSynchronizesAsFormatting() {
        let (v, spy) = spyCanvas()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 3)
        spy.reset()
        v.setLink("https://telegram.org")
        _ = assertOneChange(spy, reason: .formatting, policy: .preserveIfRebasable, "setLink")
    }

    /// `.layoutOnly` is the one reason the backend must NOT adopt a new revision for — a reflow moves
    /// geometry, not content.
    func test_widthOnlyReflowSynchronizesAsLayoutOnlyAndKeepsTheRevision() {
        let (v, spy) = spyCanvas()
        let before = v.documentRevision
        v.setParagraphsWidthIfNeeded(260)
        let change = assertOneChange(spy, reason: .layoutOnly, policy: .preserveIfRebasable, "width reflow")
        XCTAssertEqual(change?.oldRevision, change?.newRevision,
                       "a `.layoutOnly` change must not move the revision")
        XCTAssertEqual(v.documentRevision, before, "a width reflow is not a content mutation")
    }

    /// RULING 5 (supplement §5) — the bracket goes AFTER `setParagraphsWidthIfNeeded`'s early-return
    /// guard. Wrapping the whole body would fire a `.layoutOnly` change on every layout pass where
    /// nothing changed, which is the guard's entire purpose.
    ///
    /// The frame change + `layoutContent()` between the two passes is REQUIRED, and reproduces what
    /// production does: `RichTextEditorView.performLayout` sets `canvas.frame` to the new size, calls
    /// `setParagraphsWidthIfNeeded(size.width)`, then `canvas.layoutContent()`. `BlockBox.setWidth`
    /// moves the LAYOUT container width, not the box's `frame`, and the guard compares `frame.width`
    /// — which only a layout pass (at the canvas's own `bounds.width`) updates. MEASURED: two
    /// back-to-back calls with no layout pass, or with a layout pass at the OLD frame width,
    /// legitimately both do work and synchronize twice.
    func test_aNoOpWidthPassSynchronizesNothing() {
        let (v, spy) = spyCanvas()
        v.frame = CGRect(x: 0, y: 0, width: 260, height: 300)
        v.setParagraphsWidthIfNeeded(260)
        v.layoutContent()
        v.setParagraphsWidthIfNeeded(260)   // identical width — the guard must swallow this one whole
        XCTAssertEqual(spy.observedExternalChanges.count, 1,
                       "a second pass at the same width must synchronize nothing")
    }

    /// The `.layoutOnly` sync must not reach the HOST. `synchronizeAfterExternalChange` ends in
    /// `publishState(reason: .externalSynchronization)`, which `TelegramLifecycleInputClient` maps onto
    /// `canvas.notifyContentSizeChanged()`; `setParagraphsWidthIfNeeded`'s one production caller is
    /// `RichTextEditorView.performLayout`, so that would fire `onChange` from inside the host's own
    /// layout pass — the recursion the facade's layout contract forbids. The site therefore holds
    /// `suppressHostChangeNotification` across the bracket. Real backend: the spy publishes nothing, so
    /// only this canvas can see the difference. (`CanvasContentMarginsTests
    /// .test_facade_updateWithMargins_doesNotSynchronouslyFireOnChange` is the facade-level pin, and it
    /// is what caught this; this one names the mechanism.)
    func test_aWidthReflowDoesNotNotifyTheHostOfAContentSizeChange() {
        let v = realCanvas()
        var contentSizeNotifications = 0
        v.onContentSizeChange = { contentSizeNotifications += 1 }
        let violations = capturingContractViolations {
            v.setParagraphsWidthIfNeeded(260)
        }
        XCTAssertEqual(violations, [])
        XCTAssertEqual(contentSizeNotifications, 0,
                       "a width reflow runs INSIDE the host's layout pass — notifying it recurses")
    }

    /// FIX ROUND 2 (review N3) — the THIRD thing the sync's publish can perturb, after the host
    /// notification and `lastCheckedCaret`. `nativeCheckOnSelectionChange` calls
    /// `clearAllCorrectionFlags()` BEFORE its own early-return guard, so a publish that reaches
    /// `refreshSelectionUI()` can drop an active autocorrect underline elsewhere in the document.
    ///
    /// Seeds a `.correction` flag in paragraph 0 and parks the caret in paragraph 1, which is exactly
    /// the `correctionIsElsewhere == true` condition that method tests.
    private func canvasWithACorrectionElsewhere() throws -> DocumentCanvasView {
        let v = realCanvas()
        _ = v.becomeFirstResponder()
        v.installNativeCheckingIfNeeded()
        try XCTSkipIf(v.nativeChecker == nil, "native checking controller unavailable in this runtime")
        v.setCaret(global: v.boxes[1].textStart + 1)   // caret in p1 …
        v.spellResults[BlockID("p0")] = (contentHash: 0,
                                         ranges: [(range: NSRange(location: 0, length: 5), style: .correction)])
        return v                                        // … correction in p0
    }

    private func correctionFlagCount(_ v: DocumentCanvasView) -> Int {
        v.spellResults.values.reduce(0) { $0 + $1.ranges.filter { $0.style == .correction }.count }
    }

    /// The one site where it is REACHABLE, and the measurement says so rather than the reasoning:
    /// `setParagraphsWidthIfNeeded`'s body runs no `refreshSelectionUI()` of its own and does not clear
    /// `spellResults`, so at BASE nothing touches the flag at all. GREEN at BASE, RED at HEAD before
    /// the checkpoint below covered it.
    func test_aWidthReflowDoesNotClearAnAutocorrectFlagElsewhere() throws {
        let v = try canvasWithACorrectionElsewhere()
        XCTAssertEqual(correctionFlagCount(v), 1, "precondition: the flag is seeded")
        v.setParagraphsWidthIfNeeded(260)
        XCTAssertEqual(correctionFlagCount(v), 1,
                       "a `.layoutOnly` publish must not clear an autocorrect underline elsewhere")
    }

    /// The formatting sites, measured rather than assumed — see the report's FR2.3. `editing`'s tail
    /// already runs the identical `refreshSelectionUI()` → `nativeCheckOnSelectionChange()` code with
    /// the identical caret and the identical `spellResults`, so the flag is cleared by the BODY, at
    /// BASE, before the synchronization exists. This test therefore characterises the PRE-EXISTING
    /// behaviour (the flag is gone either way) and exists so a future reader does not "fix" a
    /// difference that was never there.
    func test_aFormattingToggleClearsAnAutocorrectFlagElsewhere_asItAlreadyDidAtBase() throws {
        let v = try canvasWithACorrectionElsewhere()
        XCTAssertEqual(correctionFlagCount(v), 1, "precondition: the flag is seeded")
        v.setSelectionForTesting(anchor: v.boxes[1].textStart, head: v.boxes[1].textStart + 3)
        v.toggleBold()
        XCTAssertEqual(correctionFlagCount(v), 0,
                       "`editing`'s own tail clears it — this is BASE behaviour, not the sync's doing")
    }

    // MARK: - Negative controls
    //
    // A keyboard mutation is NOT an external change. Three of these four reach `setBlocks`, which is
    // the shared primitive the bracket must stay off; `insertText`'s control cannot see that at all.

    /// The canvas-side keystroke body a routed `insertText` reaches. Driving the WITNESS
    /// (`v.insertText`) here would be vacuous on a spy-backed canvas — the spy records the call and
    /// performs no edit — so this control calls the body directly, and asserts the edit really
    /// happened, so the control is armed (Rule 16).
    func test_aPlainKeystrokeDoesNotSynchronizeAnExternalChange() {
        let (v, spy) = spyCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        let before = v.documentRevision
        spy.reset()
        v.legacyInsertText("x")
        XCTAssertGreaterThan(v.documentRevision, before, "the control is only meaningful if the edit ran")
        XCTAssertTrue(spy.observedExternalChanges.isEmpty,
                      "a keystroke is a keyboard mutation, not an external change")
    }

    /// RULING 1a — reaches `setBlocks` through `spliceFragmentInEditing`, from inside `editing { }`.
    func test_pasteDoesNotSynchronizeAnExternalChange() {
        let (v, spy) = spyCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        let before = v.documentRevision
        spy.reset()
        v.pasteFragment(Document(blocks: [paragraph("f", "Frag")]))
        XCTAssertGreaterThan(v.documentRevision, before, "the control is only meaningful if the paste ran")
        XCTAssertTrue(spy.observedExternalChanges.isEmpty,
                      "a paste splice is a keyboard mutation, not an external change")
    }

    /// RULING 1a — `replaceRange` is a KIND-B primitive that owns its own `editing { }` and calls
    /// `setBlocks` inside it.
    func test_replaceRangeDoesNotSynchronizeAnExternalChange() {
        let (v, spy) = spyCanvas()
        let start = v.boxes[0].textStart
        let before = v.documentRevision
        spy.reset()
        v.replaceRange(globalFrom: start, globalTo: start + 3,
                       with: Document(blocks: [paragraph("r", "Zzz")]))
        XCTAssertGreaterThan(v.documentRevision, before, "the control is only meaningful if the replace ran")
        XCTAssertTrue(spy.observedExternalChanges.isEmpty,
                      "replaceRange is a keyboard-mutation primitive, not an external change")
    }

    /// The primitive itself. `setBlocks` is the document-SWAP mechanism shared by six callers; the
    /// bracket belongs to its host-originated callers, never to it.
    func test_setBlocksItselfSynchronizesNothing() {
        let (v, spy) = spyCanvas()
        let before = v.documentRevision
        v.setBlocks([paragraph("q", "Gamma")], width: 300)
        // FIX ROUND 1 (review Minor 2): the same armour the other three controls carry. `setBlocks` has
        // no early return TODAY, so this is armed either way — but it is one future guard away from
        // being green because nothing happened, which is the exact vacuity the other three guard against.
        XCTAssertGreaterThan(v.documentRevision, before, "the control is only meaningful if the swap ran")
        XCTAssertTrue(spy.observedExternalChanges.isEmpty,
                      "setBlocks is a shared primitive — three of its callers are keyboard mutations")
    }

    // MARK: - Ordering (real backend)

    /// RULING 3 (supplement §3) — the spec's "before the new document is published visually" is
    /// `textDidChange`, NOT `canvasContentSizeChanged`: the latter fires from INSIDE `setBlocks`, a
    /// primitive shared with three keyboard-mutation callers, so no caller-level bracket could
    /// precede it.
    ///
    /// **FIX ROUND 1 (review Major 1) — THE OBSERVABLE CHANGED, and the old one was itself the bug.**
    /// This test used to assert TWO `canvasContentSizeChanged` events and read the second as "the sync
    /// ran here". That second event was the sync's `publishState` reaching the HOST — an extra
    /// `onChange` this task introduced at four sites, which the fix now suppresses. Using a
    /// host-visible side effect as the probe for a backend event is exactly what let that ride in
    /// looking like a measurement.
    ///
    /// The observable is now a BACKEND-INTERNAL fact sampled from inside the delegate bracket: the
    /// revision the backend has ADOPTED. `synchronizeAfterExternalChange` adopts `change.newRevision`
    /// (`LegacyRichTextInputBackend.swift:934`), so if the sync ran before `textDidChange` the adopted
    /// value has already moved when `textDidChange` fires — and if it were deferred
    /// (`transactionPhase != .idle` → `deferredExternalChange`) it would still read the old baseline,
    /// because `reload` opens no transaction for `endTransaction()` to drain.
    func test_theChangeIsDeliveredBeforeTextDidChange() {
        let v = realCanvas()
        let probe = AdoptedRevisionProbe { v.inputBackend.state.documentRevision }
        v.inputDelegate = probe
        let adoptedBefore = v.inputBackend.state.documentRevision
        v.reload([paragraph("q", "Gamma")], width: 300)
        let adoptedAfter = v.inputBackend.state.documentRevision

        XCTAssertGreaterThan(adoptedAfter, adoptedBefore,
                             "precondition: the reload must have moved the backend's adopted revision at all")
        XCTAssertEqual(probe.atTextWillChange, adoptedBefore,
                       "the sync must not have run before the bracket opened")
        XCTAssertEqual(probe.atTextDidChange, adoptedAfter,
                       "the sync must have landed BEFORE textDidChange — a deferred change would still " +
                       "read \(adoptedBefore) here")
    }

    /// FIX ROUND 1 (review Major 1) — the delegate trace of a `reload` is byte-identical to BASE again.
    /// MEASURED at BASE (the five source files restored from `7c43541031`, this suite run against them):
    /// one `canvasContentSizeChanged`, `setBlocks`'s own. Before the fix this suite asserted two.
    func test_reloadEmitsThePreTaskDelegateTrace() {
        let v = realCanvas()
        let recorder = RichTextInputEventRecorder(); recorder.attach(canvas: v)
        recorder.reset()
        v.reload([paragraph("q", "Gamma")], width: 300)
        XCTAssertEqual(recorder.kinds,
                       [.textWillChange, .selectionWillChange,
                        .canvasContentSizeChanged,
                        .selectionDidChange, .textDidChange],
                       "trace:\n\(recorder.trace())")
    }

    /// FIX ROUND 1 (review Major 1) — **the enumeration the first round did not do.** The chain
    /// `synchronizeAfterExternalChange` → `publishState(.externalSynchronization)` →
    /// `TelegramLifecycleInputClient.backendDidPublishState` → `canvas.notifyContentSizeChanged()` →
    /// `onContentSizeChange` → the facade's `onChange` fires at EVERY site, not just the width reflow
    /// where a pre-existing test happened to notice. `synchronizingExternalChange` therefore holds
    /// `suppressHostChangeNotification` across the synchronize call itself — and around ONLY that call,
    /// never around `body()`, because every site's body legitimately notifies the host from
    /// pre-existing code (`setBlocks`, `editing`'s tail, `registerUndo`'s own call).
    ///
    /// **THIS TEST PINS INSTANCES; THE CODE CLOSES THE CLASS — and that distinction is the whole
    /// reason the chokepoint remedy beat the per-site one.** The suppression lives in
    /// `synchronizingExternalChange`, which every site funnels through, so a SIXTH site added by a
    /// later task inherits it automatically and this test does not need to grow for that site to be
    /// safe. The arms below exist to prove the chokepoint works and to give a future reader the BASE
    /// figures, not because the guarantee is enumerated site by site. (The round-1 defect was the
    /// opposite arrangement: a per-site fix at the one site a test could see.)
    ///
    /// Every number below was MEASURED at BASE (`7c43541031`'s five source files restored, this test
    /// run against them), not assumed. At HEAD before the round-1 fix they read 2 / 2 / 2 / 3 / 3.
    func test_noSiteAddsAHostContentSizeNotification() {
        func countingCanvas() -> (DocumentCanvasView, () -> Int) {
            let v = realCanvas()
            var n = 0
            v.onContentSizeChange = { n += 1 }
            return (v, { n })
        }

        let (r, reloadCount) = countingCanvas()
        r.reload([paragraph("q", "Gamma")], width: 300)
        XCTAssertEqual(reloadCount(), 1, "reload: `setBlocks`'s own notification, and no other")

        let (b, boldCount) = countingCanvas()
        b.setSelectionForTesting(anchor: b.boxes[0].textStart, head: b.boxes[0].textStart + 3)
        b.toggleBold()
        XCTAssertEqual(boldCount(), 1, "bold toggle: `editing`'s tail, and no other")

        // FIX ROUND 2 (review N2): the fifth site. `applyCharacterAttribute` is a separate call site
        // from `applyCharacterToggle` even though both wrap an `editing { }`.
        let (l, linkCount) = countingCanvas()
        l.setSelectionForTesting(anchor: l.boxes[0].textStart, head: l.boxes[0].textStart + 3)
        l.setLink("https://telegram.org")
        XCTAssertEqual(linkCount(), 1, "setLink: `editing`'s tail, and no other")

        let (u, undoCount) = countingCanvas()
        let um = UndoManager(); um.groupsByEvent = false; u.undoManagerOverride = um
        u.setCaret(global: u.boxes[0].textStart + 1)
        um.beginUndoGrouping()
        u.editing { u.applyReplaceOutcome(globalFrom: u.head, globalTo: u.head, text: "x") }
        um.endUndoGrouping()
        let beforeUndo = undoCount()
        um.undo()
        XCTAssertEqual(undoCount() - beforeUndo, 2,
                       "responder undo: `setBlocks`'s and `registerUndo`'s own, and no other")
        // FIX ROUND 2 (review N2): redo re-enters the SAME closure with `reason: .redo`, so it is the
        // same code path — measured anyway, because "same path" is an argument and this is a number.
        let beforeRedo = undoCount()
        um.redo()
        XCTAssertEqual(undoCount() - beforeRedo, 2,
                       "responder redo: `setBlocks`'s and `registerUndo`'s own, and no other")

        let (w, widthCount) = countingCanvas()
        w.setParagraphsWidthIfNeeded(260)
        XCTAssertEqual(widthCount(), 0, "width reflow: BASE notifies the host not at all")
    }

    /// FIX ROUND 1 (review Minor 3) — the SECOND host-observable the publish reaches, and the
    /// reviewer's "it disappears for free under Major 1's remedy" is WRONG: `suppressHostChangeNotification`
    /// gates `notifyContentSizeChanged` (`DocumentCanvasView.swift:1850`) and nothing else, while this
    /// path runs through `presentationClient.apply` → `refreshSelectionUI()` →
    /// `inputBackend.checkOnSelectionChange()` → `nativeCheckOnSelectionChange()`, whose
    /// `defer { lastCheckedCaret = now }` re-seeds the value `setBlocks` deliberately cleared
    /// ("a fresh document: nothing checked until the caret traverses it").
    ///
    /// `reload` is the only one of the five where it bites: the other four each run their own
    /// `refreshSelectionUI()` around the bracket, so the counter ends up seeded at BASE too. Fixed by
    /// checkpointing `lastCheckedCaret` across the synchronize call in `synchronizingExternalChange`,
    /// on the same principle as the notification suppression — the sync's publish is a NEW event and
    /// must not perturb pre-existing state.
    func test_aReloadStillLeavesNothingCheckedUntilTheCaretTraversesIt() throws {
        let v = realCanvas()
        _ = v.becomeFirstResponder()
        v.installNativeCheckingIfNeeded()
        try XCTSkipIf(v.nativeChecker == nil, "native checking controller unavailable in this runtime")
        v.setCaret(global: v.boxes[0].textStart + 2)
        XCTAssertNotNil(v.lastCheckedCaret, "precondition: a caret move seeds the counter")
        v.reload([paragraph("q", "Gamma")], width: 300)
        XCTAssertNil(v.lastCheckedCaret,
                     "a fresh document must leave nothing checked until the caret traverses it")
    }

    // MARK: - Revision continuity (real backend)
    //
    // `synchronizeAfterExternalChange` guards `change.oldRevision == documentRevision`, and
    // `RichTextInputContractViolation.report` is an `assertionFailure` in DEBUG unless a reporter is
    // installed — so a drifted revision is a TEST TRAP, not a soft failure. These probes install a
    // reporter so a failure is a readable assertion instead of a dead runner.

    private func capturingContractViolations(_ body: () -> Void) -> [String] {
        var captured: [String] = []
        let previous = RichTextInputContractViolation.reporter
        RichTextInputContractViolation.reporter = { captured.append($0) }
        defer { RichTextInputContractViolation.reporter = previous }
        body()
        return captured
    }

    /// The spy answers a CONSTANT `state.documentRevision` of 0, so the `oldRevision == newRevision`
    /// assertion above is real but weak. This is the same claim against the real backend, where the
    /// value moves: a `reload` drags the backend's adopted revision up to the canvas's, and a width
    /// reflow after it must leave that adopted value exactly where it was.
    func test_aWidthReflowDoesNotMoveTheBackendsAdoptedRevision() {
        let v = realCanvas()
        let violations = capturingContractViolations {
            v.reload([paragraph("q", "Gamma")], width: 300)
            let adopted = v.inputBackend.state.documentRevision
            XCTAssertEqual(adopted, v.documentRevision,
                           "a `.documentReplacement` sync must bring the backend's cache current")
            v.layoutContent()
            v.setParagraphsWidthIfNeeded(260)
            XCTAssertEqual(v.inputBackend.state.documentRevision, adopted,
                           "a `.layoutOnly` change must not move the adopted revision")
        }
        XCTAssertEqual(violations, [])
    }

    /// Supplement §6's required probe: a marked-text commit bumps the canvas revision from OUTSIDE
    /// the backend's mutation path (`+MarkedText.swift`), so a host-originated change right after it
    /// is the shape most likely to trip the continuity guard.
    func test_aMarkedTextCommitFollowedByReloadDoesNotTripTheContinuityGuard() {
        let v = realCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        let violations = capturingContractViolations {
            v.legacySetMarkedText("ab", selectedRange: NSRange(location: 2, length: 0))
            _ = v.finalizeMarkedText()
            v.reload([paragraph("q", "Gamma")], width: 300)
        }
        XCTAssertEqual(violations, [], "a marked-text commit then a reload must not violate continuity")
    }

    /// The broader shape, and the one this task actually has to survive: ORDINARY TYPING advances the
    /// canvas revision through a path that never updates the backend's cached copy, so any later
    /// host-originated change describes a baseline the backend has not adopted.
    func test_typingThenAHostOriginatedChangeDoesNotTripTheContinuityGuard() {
        let v = realCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        let violations = capturingContractViolations {
            v.insertText("x")
            v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 3)
            v.toggleBold()
            v.reload([paragraph("q", "Gamma")], width: 300)
            v.setParagraphsWidthIfNeeded(260)
        }
        XCTAssertEqual(violations, [], "typing must not poison every later host-originated change")
    }
}
#endif
