#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Task 23: the mechanism every Phase-4 family task (24-34) proves its "one-line router" claim
/// against. These tests exercise the FIXTURE itself (`SpyRichTextInputBackend`, `RouterAssertions.swift`)
/// — per this plan's own hard-won rule "a fixture must exercise itself" — not any routed witness, since
/// none exists yet (Task 20's own audit: production calls only `attach`/`detach`/`editPolicyDidChange()`
/// on `inputBackend` today).
@MainActor
@available(iOS 16.0, *)
final class RouterHarnessTests: XCTestCase {

    private func makeCanvas() -> (canvas: DocumentCanvasView, spy: SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let canvas = DocumentCanvasView(inputBackend: spy)
        canvas.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])], width: 300)
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        canvas.layoutIfNeeded()
        // task-23 fix round 1 (review Minor 2): mirrors the plan's own Phase-4 factory, which resets
        // the spy after setup. Harmless today (verified: construction logs nothing to `calls` — the
        // only pre-Phase-4 backend calls are `attach`/`detach`/`editPolicyDidChange()`, and none of
        // those are logged, plus `editPolicyDidChange()` only fires behind a changed-value guard this
        // setup never trips), but the divergence would silently corrupt the first family test whose
        // OWN setup touches `editPolicy`.
        spy.reset()
        return (canvas, spy)
    }

    // MARK: - Loud, not plausible, defaults (task-23 fix round 1, review Major 1/2)

    /// `stubbedSelectionRects` must default to `[sentinelSelectionRect]`, NOT `[]` — `[]` is exactly
    /// what a non-routing canvas would answer for `selectionRects(for:)` given a nonsense sentinel
    /// range, so a bare `[]` default made Task 25's return-propagation assertion unfalsifiable.
    func test_stubbedSelectionRectsDefaultsToTheSentinelNotAnEmptyArray() {
        let spy = SpyRichTextInputBackend()
        XCTAssertEqual(spy.stubbedSelectionRects.count, 1)
        XCTAssertTrue((spy.stubbedSelectionRects[0] as AnyObject) === (spy.sentinelSelectionRect as AnyObject))
    }

    /// None of the five Bool stubs may equal the canvas's own pre-seam ("non-routing") answer — a
    /// `true` default for `hasText`/`canBecomeFirstResponder`/`isEditableForWritingTools`/
    /// `canPerformCommand` (all `true` pre-seam) made return-propagation a coincidental pass for
    /// Tasks 24/30/31.
    func test_boolStubsDefaultToFalse_notTheCanvassPreSeamAnswer() {
        let spy = SpyRichTextInputBackend()
        XCTAssertFalse(spy.stubbedHasText)
        XCTAssertFalse(spy.stubbedCanBecomeFirstResponder)
        XCTAssertFalse(spy.stubbedCanResignFirstResponder)
        XCTAssertFalse(spy.stubbedIsEditableForWritingTools)
        XCTAssertFalse(spy.stubbedCanPerformCommand)
    }

    // MARK: - The spy records member + arguments (and the positive half of `XCTAssertSingleBackendCall`)

    func test_spyRecordsMemberAndArguments() {
        let spy = SpyRichTextInputBackend()
        spy.insertText("hello")
        XCTAssertSingleBackendCall(spy, member: "insertText(_:)", arguments: ["hello"])
    }

    func test_resetClearsTheCallLog() {
        let spy = SpyRichTextInputBackend()
        spy.insertText("hello")
        XCTAssertFalse(spy.calls.isEmpty)
        spy.reset()
        XCTAssertTrue(spy.calls.isEmpty, "reset() must clear the call log")
    }

    // MARK: - Sentinel identity

    /// TASK 23 FIX ROUND 1 (review Major 3) — NARROWED from a canvas-backed version. Until family 1
    /// (Task 24) lands, `DocumentCanvasView` does not yet route ANY `UITextInput` witness to its
    /// backend, so there is no router here to prove anything about. The PRIOR version of this test
    /// reached the spy as `canvas.inputBackend.beginningOfDocument` — the review correctly flagged this
    /// as the ONE spelling that makes a Phase-4 family's router test vacuous (it proves the SPY returns
    /// its own sentinel, not that the CANVAS routes to it), and the only worked example in this tree, so
    /// exactly the shape eleven future authors would copy. This is now a PURE fixture self-test with NO
    /// canvas at all: it proves the spy's own sentinel-identity mechanism, nothing more.
    ///
    /// Task 24 MUST land the strong form as its OWN, separate test —
    /// `test_beginningOfDocument_returnsTheBackendsExactObject`, asserting
    /// `canvas.beginningOfDocument === spy.sentinelPosition` through the CANVAS surface, following the
    /// pattern: `spy.reset()` after setup, then all four clauses of exit criterion 3 per witness (ideally
    /// via `XCTAssertRoutesOnly`, added this fix round — see below) — never by strengthening THIS test
    /// back into a canvas-backed one. Task 24 should also consider a boundary rule (R14) banning the
    /// substring `.inputBackend.` inside `T/InputBackend/Routers/`, the test-side mirror of the plan's
    /// own `RouterWitnessBodyTests` and the only mechanical defence against this exact vacuity spelling;
    /// that decision is Task 24's to make, not this task's.
    func test_aStubbedPositionComesBackAsTheSameObject() {
        let spy = SpyRichTextInputBackend()
        XCTAssertTrue((spy.beginningOfDocument as AnyObject) === (spy.sentinelPosition as AnyObject),
                     "the spy's own beginningOfDocument must return the sentinel object itself, not a copy")
        XCTAssertSingleBackendCall(spy, member: "beginningOfDocument", arguments: [])
    }

    // MARK: - `XCTAssertRouterDidNoWork` — negative controls proving it can actually fail (it must, or
    // every Phase-4 family's "no work of its own" half of the exit criteria would be unfalsifiable).

    /// TASK 27b — the driver is `bumpDocumentRevision()`, NOT `canvas.insertText("x")` as earlier
    /// rounds wrote it. This canvas is SPY-backed, and Task 27b routed `insertText(_:)`: the spy
    /// performs no edit, so the revision stopped moving and this control went red with
    /// "Expected failure … but none recorded" — the control silently losing its ability to fail is
    /// exactly the hazard the sibling `test_assertRoutesOnly_failsWhenTheCanvasAlsoDidWorkOfItsOwn`
    /// was moved off `insertText` for in fix round 2, naming this task. `bumpDocumentRevision()` is the
    /// raw revision hook `editing { }` itself calls — a primitive, not a `UITextInput` witness, so it
    /// is not routed and will not become routed, exactly like the `setCaret(global:)` the selection
    /// sibling below uses.
    ///
    /// **TASK 27b FIX ROUND 1 (review m2) — the two halves below, because a driver alone cannot make
    /// this control fail for the reason its NAME claims.** No operation in this package moves
    /// `documentRevision` alone: `bumpDocumentRevision()` is its only writer and bumps
    /// `layoutGeneration` in the same breath (the pre-27b driver moved five of the seven watched
    /// fields), so half (a)'s failure is merely CONSISTENT with a revision change, not attributable to
    /// it — it would stay green with `revision` dropped from `==`, since a co-moving field still
    /// carries the inequality. Half (b) removes the ambiguity by construction: a baseline derived from
    /// the live canvas and varied in `revision` ONLY.
    ///
    /// **RED IF, per half** (corrected at Task 27b's second review round, which caught the first write-up
    /// attributing BOTH mutations below to (b) — the first is caught by (a) and leaves (b) GREEN, so a
    /// reader chasing it would have been sent to the wrong assertion):
    ///   * **(a)** the snapshot stops reading `canvas.documentRevision` (say it stores a constant): both
    ///     sides then read the same value and (a)'s precondition fails. (b) stays green — its synthetic
    ///     baseline still differs from that constant, so the helper still fails as expected. Verified:
    ///     `self.revision = 0` in the snapshot's canvas init reddens (a)'s precondition at :137 and
    ///     produces EXACTLY ONE failure, so (b) is green in that run.
    ///   * **(b)** a hand-written `==` that omits the revision term — the realistic "ignore this noisy
    ///     field" refactor. (a) stays green, because `layoutGeneration` moves with the revision and
    ///     carries the inequality on its own. Verified red against exactly that, with (a) observed still
    ///     green in the same run (see the task report's fix-round section).
    func test_routerStateSnapshotDetectsARevisionChange() {
        let (canvas, _) = makeCanvas()

        // (a) a real revision-moving operation is detected at all.
        let before = RouterStateSnapshot(canvas)
        canvas.bumpDocumentRevision()
        XCTAssertNotEqual(RouterStateSnapshot(canvas).revision, before.revision,
                          "precondition: the driver must actually move the revision")
        XCTExpectFailure("a revision change must be detected") { @MainActor in
            XCTAssertRouterDidNoWork(canvas, before)
        }

        // (b) …and the REVISION term is what carries it: this baseline agrees with the live canvas in
        // every one of the other six watched fields, so nothing else can be producing the failure.
        let settled = RouterStateSnapshot(canvas)
        XCTAssertRouterDidNoWork(canvas, settled)   // control: the pair is otherwise identical
        XCTExpectFailure("the revision term alone must be enough to fail the comparison") { @MainActor in
            XCTAssertRouterDidNoWork(canvas, settled.withRevision(settled.revision &- 1))
        }
    }

    /// TASK 28 — `undoRegistrationCount`'s control, built to the `withRevision(_:)` pattern because the
    /// field is in the same position `revision` was: **`editing(coalescing:_:)` is its ONLY writer
    /// anywhere in `Sources/`** (`DocumentCanvasView+Editing.swift`; verified by grep), and that one
    /// writer also bumps `revision`, `layoutGeneration` and — via its own
    /// `dismissEditMenuForSelectionOrTextChange()` — `dismissEditMenuCountForTesting`. So a real driver
    /// exists and is used below, but it cannot ATTRIBUTE the failure to this term on its own.
    ///
    /// The field matters for Tasks 28-30 specifically: it is one of the two terms that carry "the canvas
    /// did work of its own" for a MUTATION router, and a silent loss here is invisible by construction —
    /// nothing else in the snapshot notices that an undo step was registered.
    ///
    /// **RED IF, per half:**
    ///   * **(a)** the snapshot stops reading `canvas.undoRegistrationCount` (say it stores a constant):
    ///     both sides read the same value and (a)'s precondition fails. (b) stays green — its synthetic
    ///     baseline still differs from that constant.
    ///   * **(b)** a hand-written `==` that omits the `undoRegistrationCount` term — the realistic
    ///     "ignore this test-only counter" refactor. (a) stays GREEN, because `revision` /
    ///     `layoutGeneration` / the dismiss counter all move with it and carry the inequality on their
    ///     own. Verified red against exactly that, with (a) observed still green in the same run (see the
    ///     task report's red-check section).
    func test_routerStateSnapshotDetectsAnUndoRegistration() {
        let (canvas, _) = makeCanvas()

        // (a) a real undo-registering operation is detected at all. `editing { }` with an EMPTY body
        // still registers a step (deviation D10's sibling: the wrapper is unconditional), which is
        // exactly what makes it usable here without moving anchor/head as well.
        let before = RouterStateSnapshot(canvas)
        canvas.editing { .unchanged }
        XCTAssertNotEqual(RouterStateSnapshot(canvas).undoRegistrationCount, before.undoRegistrationCount,
                          "precondition: the driver must actually register an undo step")
        XCTExpectFailure("an undo registration must be detected") { @MainActor in
            XCTAssertRouterDidNoWork(canvas, before)
        }

        // (b) …and the UNDO term is what carries it: this baseline agrees with the live canvas in every
        // one of the other six watched fields, so nothing else can be producing the failure.
        let settled = RouterStateSnapshot(canvas)
        XCTAssertRouterDidNoWork(canvas, settled)   // control: the pair is otherwise identical
        XCTExpectFailure("the undoRegistrationCount term alone must be enough to fail the comparison") { @MainActor in
            XCTAssertRouterDidNoWork(canvas, settled.withUndoRegistrationCount(settled.undoRegistrationCount - 1))
        }
    }

    /// TASK 28 — `dismissEditMenuCountForTesting`'s control. Unlike `revision` and
    /// `undoRegistrationCount` this field **has a real, ISOLATING driver**: `dismissEditMenu()` bumps
    /// the counter and touches nothing else this snapshot watches (`DocumentCanvasView+EditMenu.swift`
    /// — it forwards to `UIEditMenuInteraction.dismissMenu()` on iOS 16+, which is a no-op when nothing
    /// is presented). So this control needs no synthetic baseline and gets no `withX(_:)` helper: the
    /// six equality assertions below establish the isolation from the LIVE canvas, which is a stronger
    /// statement than a fabricated one anyway.
    ///
    /// The field is the second of the two terms that carry "the canvas did work of its own" for a
    /// MUTATION router — `editing { }` dismisses the menu, so a router that ran a copy of the old body
    /// would move it.
    ///
    /// **RED IF:** a hand-written `==` that omits the `dismissEditMenuCountForTesting` term — the
    /// realistic "this is a test-only counter, drop it" refactor. Nothing else moved here, so no other
    /// term can carry the inequality; the six preconditions are what make that true by observation
    /// rather than by assumption. Verified red against exactly that (see the task report's red-check
    /// section).
    func test_routerStateSnapshotDetectsAnEditMenuDismissal() {
        let (canvas, _) = makeCanvas()
        let before = RouterStateSnapshot(canvas)

        canvas.dismissEditMenu()

        let after = RouterStateSnapshot(canvas)
        XCTAssertNotEqual(after.dismissEditMenuCountForTesting, before.dismissEditMenuCountForTesting,
                          "precondition: the driver must actually bump the dismiss counter")
        // …and it must move NOTHING else, which is what makes the failure below attributable.
        XCTAssertEqual(after.revision, before.revision)
        XCTAssertEqual(after.layoutGeneration, before.layoutGeneration)
        XCTAssertEqual(after.anchor, before.anchor)
        XCTAssertEqual(after.head, before.head)
        XCTAssertEqual(after.markedRange, before.markedRange)
        XCTAssertEqual(after.undoRegistrationCount, before.undoRegistrationCount)

        XCTExpectFailure("the dismiss counter alone must be enough to fail the comparison") { @MainActor in
            XCTAssertRouterDidNoWork(canvas, before)
        }
    }

    func test_routerStateSnapshotDetectsASelectionChange() {
        let (canvas, _) = makeCanvas()
        let before = RouterStateSnapshot(canvas)
        canvas.setCaret(global: canvas.boxes[0].textStart + 2)   // moves anchor/head, no content edit
        XCTExpectFailure("a selection change must be detected") { @MainActor in
            XCTAssertRouterDidNoWork(canvas, before)
        }
    }

    /// Positive control: `XCTAssertRouterDidNoWork` must NOT fail when nothing actually changed — the
    /// two negative controls above are meaningless if this one is broken (they would both be exercising
    /// a helper that ALWAYS fails, not one that fails only when state moved).
    func test_routerStateSnapshotPassesWhenNothingChanged() {
        let (canvas, _) = makeCanvas()
        let before = RouterStateSnapshot(canvas)
        XCTAssertRouterDidNoWork(canvas, before)
    }

    // MARK: - `XCTAssertSingleBackendCall` — negative controls for its "and nothing else" half, which is
    // the entire reason this helper exists rather than a plain "at least one call happened" check.

    func test_assertSingleBackendCall_failsWhenMoreThanOneCallIsRecorded() {
        let spy = SpyRichTextInputBackend()
        spy.insertText("a")
        spy.insertText("b")
        XCTExpectFailure("two recorded calls must not satisfy \"exactly one\"") {
            XCTAssertSingleBackendCall(spy, member: "insertText(_:)", arguments: ["a"])
        }
    }

    func test_assertSingleBackendCall_failsWhenArgumentsDiffer() {
        let spy = SpyRichTextInputBackend()
        spy.insertText("a")
        XCTExpectFailure("a recorded call with the wrong argument must not satisfy the expectation") {
            XCTAssertSingleBackendCall(spy, member: "insertText(_:)", arguments: ["different"])
        }
    }

    func test_assertSingleBackendCall_failsWhenMemberDiffers() {
        let spy = SpyRichTextInputBackend()
        spy.insertText("a")
        XCTExpectFailure("a recorded call against the wrong member name must not satisfy the expectation") {
            XCTAssertSingleBackendCall(spy, member: "deleteBackward()", arguments: [])
        }
    }

    func test_assertSingleBackendCall_failsWhenNoCallIsRecorded() {
        let spy = SpyRichTextInputBackend()
        XCTExpectFailure("zero recorded calls must not satisfy \"exactly one\"") {
            XCTAssertSingleBackendCall(spy, member: "insertText(_:)", arguments: ["a"])
        }
    }

    // MARK: - `XCTAssertRoutesOnly` (added task-23 fix round 1, review Major 4) — the combined
    // reset+snapshot+both-halves wrapper that makes the canvas-side "nothing else" clause unskippable:
    // an author writes one line per witness instead of remembering a separate `before`/assertion pair.

    /// FIX ROUND 2 (review item 5) — renamed from `…_passesForACleanRouterCall`: no witness routes
    /// `canvas` to `inputBackend` yet (Task 20's own audit — the same fact `test_aStubbedPositionCome…`
    /// above is narrowed around), so a literal `canvas.text(in: someRange)`-style call, as
    /// `RouterAssertions.swift`'s own doc comment illustrates for a FUTURE Task-24 caller, cannot reach
    /// the spy and would fail with zero recorded calls — writing one here would be exactly the
    /// pretend-it-routes vacuity Major 3 already removed once. This positive control instead proves the
    /// wrapper's mechanics honestly: the recorded call is made directly on `spy` (the only way to
    /// produce one today), against the SAME real, populated `canvas` (`makeCanvas()`'s paragraphs/frame/
    /// layout) that `RouterStateSnapshot` compares before/after — so the "no work" half is checked
    /// against genuine canvas state, not an unconstructed one. Task 24's own router tests are what
    /// exercise the doc comment's literal shape, once a witness actually reaches the backend through
    /// `canvas`.
    func test_assertRoutesOnly_passesForACleanSpyCall() {
        let (canvas, spy) = makeCanvas()
        let result = XCTAssertRoutesOnly(canvas, spy, member: "insertText(_:)", arguments: ["z"]) {
            spy.insertText("z")
        }
        XCTAssertNotNil(result)
    }

    /// RED IF: `XCTAssertRoutesOnly` stopped asserting the canvas-side half — this is the exact
    /// ergonomics failure the review named (a router that ALSO mutates the canvas on its own, alongside
    /// forwarding correctly to the backend, must still be caught).
    ///
    /// FIX ROUND 2 (review item 3) — the mutation is `canvas.setCaret(global:)`, NOT
    /// `canvas.insertText(_:)` as an earlier round wrote it. `insertText(_:)` is exactly the witness
    /// Task 27 routes: once it does, `canvas.insertText("z")` ALSO appends its own "insertText(_:)"
    /// entry to `spy.calls` (the canvas and the direct `spy.insertText("z")` call above would both
    /// record), so this control would start failing via the COUNT half instead of the STATE half it is
    /// named for — it would still go red, but for the wrong reason, silently losing its power to catch
    /// a REAL "canvas did work of its own" regression once family 3 lands. `setCaret(global:)` is the
    /// same test-only raw selection hook the sibling `test_routerStateSnapshotDetectsASelectionChange`
    /// already uses — it is not, and is never expected to become, a routed witness.
    func test_assertRoutesOnly_failsWhenTheCanvasAlsoDidWorkOfItsOwn() {
        let (canvas, spy) = makeCanvas()
        XCTExpectFailure("a canvas-side mutation alongside a correct backend forward must be caught") {
            XCTAssertRoutesOnly(canvas, spy, member: "insertText(_:)", arguments: ["z"]) {
                spy.insertText("z")
                canvas.setCaret(global: canvas.boxes[0].textStart + 1)   // the "router" did work of its own
            }
        }
    }
}
#endif
