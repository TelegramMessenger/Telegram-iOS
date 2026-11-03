#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 29 — Family 6 (marked text and prediction): four witnesses, `markedTextRange`,
/// `markedTextStyle`, `setMarkedText(_:selectedRange:)` and `unmarkText()`.
///
/// All four are PLAIN `legacyCanvas` forwards, per the user's D35 ruling and exactly the shape Task 27b
/// gave `insertText(_:)` and Task 28 gave `deleteBackward()`. The storage-only bodies Task 22f had
/// written for `markedTextRange`/`setMarkedText` did not disappear — they moved to the test-only
/// `ReferenceMutationBackend`, which `BackendMarkedTextPolicyTests` now runs against.
///
/// **The two `…ProducesExactlyOneDocumentCommit` tests the task brief named are re-based, not written
/// as described** — the brief's own SUPERSEDED banner says so, and `DeletionRouterTests` set the
/// precedent. Under a plain forward the backend member never calls `prepareAndRun`, so it never reaches
/// `prepareMutation`/`commitPreparedMutation` and both counts would be trivially zero: an unfalsifiable
/// pair. What a plain forward CAN observe is the revision, and the recursion the guards existed for is
/// pinned directly instead, at the dispatcher, in section 3.
///
/// **Which backend each test runs against, decided before any of them were written** (the handoff's
/// rule 3):
///
///   * **Spy** for the five routing-shape tests. The spy performs no work, so `XCTAssertRoutesOnly`'s
///     "and the canvas did nothing of its own" half is exactly right — and it is genuinely non-inert:
///     under the real backend `setMarkedText` moves `revision`, `layoutGeneration`, `anchor`, `head`
///     and `markedRange`, five of the seven fields `RouterStateSnapshot` watches. A router that kept a
///     copy of the old body beside the forward fails there.
///   * **Real legacy backend** for the behavioural tests. A correctly-routed `setMarkedText`
///     legitimately moves those same fields, so `XCTAssertRouterDidNoWork` would fail FOR CORRECT CODE;
///     they assert the expected DELTA instead, which is the stronger assertion anyway.
///
/// The detached-drop characterizations live in `BackendAttachmentTests`, not here: rule R14 forbids this
/// directory from naming the canvas's backend property, and detaching requires exactly it — the same
/// reason `hasText`'s, `insertText`'s and `deleteBackward`'s detached fallbacks live there.
///
/// Every test reads through a real `DocumentCanvasView` member, never the canvas's backend property —
/// the vacuity trap R14 mechanically forbids in this directory.
@MainActor
@available(iOS 16.0, *)
final class MarkedTextRouterTests: XCTestCase {

    // MARK: - Section 1: the spy backend — "one call, exact arguments, nothing else"

    /// An EMPTY first paragraph, because that is the composable branch: `legacySetMarkedText`'s
    /// body-paragraph guard falls back to `commitMarkedText()` + `insertText(text)` anywhere else, and
    /// `insertText` has itself been a router into the backend since Task 27b — so on the fallback branch
    /// a backend sees `setMarkedText` AND `insertText`. It cannot happen against a SPY (the spy's
    /// `setMarkedText` records and returns; the canvas body never runs), but the fixture drives the
    /// composable branch anyway so the same canvas is reusable by section 2, where it does happen.
    private func spyCanvas() -> (DocumentCanvasView, SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "")]),
                         ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        v.setCaret(global: v.boxes[0].textStart)
        spy.reset()
        return (v, spy)
    }

    /// The spy returns its own `sentinelRange`, which is NOT what a non-routing canvas would return
    /// (with no composition the canvas's own answer is `nil`), so the identity check below is real
    /// signal rather than a value a broken router could produce by accident.
    ///
    /// RED IF: the witness kept its own `guard let m = markedRange … DocumentTextRange(…)` body — the
    /// spy would record zero calls and the result would be `nil`.
    func test_markedTextRange_callsTheBackendOnceAndReturnsItsExactValue() {
        let (v, spy) = spyCanvas()
        XCTAssertNil(v.markedRange, "precondition: the non-routing answer here is nil")
        let result = XCTAssertRoutesOnly(v, spy, member: "markedTextRange", arguments: []) {
            v.markedTextRange
        }
        XCTAssertTrue(result === spy.sentinelRange,
                      "the router must return the backend's object identically, not rebuild a range")
    }

    /// `markedTextStyle` is a `{ get set }` accessor pair, which `RouterWitnessBodyTests` cannot express
    /// (its own SCOPE LIMIT note names this member by name and predicted this). This test and its
    /// behavioural sibling below are the cover: per-accessor routing here, per-accessor VALUE there.
    ///
    /// The setter's expected argument is the spy's deterministic `describeSorted` encoding
    /// (`"[<key.rawValue>=<value>]"`). A single-entry, integer-valued style keeps that string stable —
    /// the spy's own doc comment warns Task 29 not to assert a MULTI-entry `markedTextStyle` argument,
    /// because `String(describing:)` over a `Dictionary` has unspecified element order.
    ///
    /// RED IF: either accessor kept its own body (`get { nil }` / `set { }` do no canvas work at all, so
    /// `XCTAssertRouterDidNoWork` cannot catch them — the CALL COUNT is the only thing that can, which
    /// is precisely why this test exists rather than relying on the behavioural sibling alone).
    func test_markedTextStyle_routesEachAccessorToTheBackendExactlyOnce() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "markedTextStyle.get", arguments: []) {
            _ = v.markedTextStyle
        }
        XCTAssertRoutesOnly(v, spy, member: "markedTextStyle.set", arguments: ["[NSUnderline=1]"]) {
            v.markedTextStyle = [.underlineStyle: 1]
        }
    }

    /// RED IF: the witness kept its own body (the canvas would insert provisional text and set
    /// `markedRange`, moving five of the seven watched fields, and the spy would record zero calls) —
    /// or forwarded a transformed string / a re-derived `selectedRange`.
    func test_setMarkedText_callsTheBackendOnceWithTheExactArguments() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "setMarkedText(_:selectedRange:)",
                            arguments: ["ni", String(describing: NSRange(location: 2, length: 0))]) {
            v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        }
    }

    /// A `nil` `markedText` must REACH the backend, not be dropped at the router: the canvas body
    /// collapses it to `""`, which is the composition-CANCEL path, so a router that swallowed it would
    /// strand a live composition. (`SpyRichTextInputBackend` logs a nil as the literal `"nil"`.)
    ///
    /// RED IF: the router grew a `guard let markedText else { return }`.
    func test_setMarkedText_forwardsANilMarkedTextRatherThanDroppingItAtTheRouter() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "setMarkedText(_:selectedRange:)",
                            arguments: ["nil", String(describing: NSRange(location: 0, length: 0))]) {
            v.setMarkedText(nil, selectedRange: NSRange(location: 0, length: 0))
        }
    }

    /// RED IF: the witness kept its own `commitMarkedText()` body — the spy would record zero calls, and
    /// with a live composition the canvas would also move `markedRange` and `undoRegistrationCount`.
    func test_unmarkText_callsTheBackendExactlyOnce() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "unmarkText()", arguments: []) {
            v.unmarkText()
        }
    }

    // MARK: - Section 2: the real legacy backend — the canvas bodies the routing moved

    private func realCanvas() -> (DocumentCanvasView, RichTextInputEventRecorder) {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "")]),
                         ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        v.setCaret(global: v.boxes[0].textStart)
        // No `undoManagerOverride`: the canvas's default manager has `groupsByEvent == true`, so
        // `commitMarkedText`'s direct `registerUndo` needs no explicit group bracket — the same fixture
        // note `InsertionRouterTests` and `MarkedTextTests` carry.
        let recorder = RichTextInputEventRecorder(); recorder.attach(canvas: v); recorder.reset()
        return (v, recorder)
    }

    /// The whole moved body, end to end, through the real backend: the provisional text lands, the
    /// marked range is established, the caret is placed inside it, and the revision moves EXACTLY once.
    ///
    /// The revision assertion is the re-based form of the brief's
    /// `test_oneSetMarkedTextProducesExactlyOneDocumentCommit`. It is the observation that survives
    /// Option A: a plain forward never reaches `commitPreparedMutation`, but a witness that dispatched
    /// back into itself would move the revision more than once. `documentCommit` could not see that
    /// anyway — Task 27a measured that `prepareAndRun`'s idle guard rejects the re-entrant call, leaving
    /// the commit count at 1.
    ///
    /// RED IF: the backend dropped the `legacySetMarkedText` forward (nothing changes), or the forward
    /// reached the wrong body.
    func test_setMarkedText_runsTheWholeCanvasBodyThroughTheBackend() {
        let (v, _) = realCanvas()
        let s = v.boxes[0].textStart
        let before = v.documentRevision

        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))

        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "ni")
        XCTAssertEqual(v.markedRange.map { NSRange(location: $0.from, length: $0.to - $0.from) },
                       NSRange(location: s, length: 2))
        XCTAssertEqual(v.head, s + 2, "the caret is placed inside the composition, per selectedRange")
        XCTAssertEqual(v.documentRevision, before + 1, "exactly one revision for one composition update")
    }

    /// **The load-bearing test of this task.** `legacySetMarkedText` brackets itself TWICE and
    /// ASYMMETRICALLY — a `notifyingContentChange` text bracket for the provisional edit, then a
    /// SEPARATE `notifyingSelectionChangeIgnoringCoalescing` bracket for the caret placement, then the
    /// `notifyContentSizeChanged()` / `onSelectionChange?()` tail — so the routed member must add NO
    /// bracket of its own. One composition begin is exactly the six events below; wrapping the forward
    /// in `notifyingContentAndSelectionChange` makes it ten (measured on the sibling witnesses).
    ///
    /// `MarkedTextTraceCharacterizationTests.test_compositionBeginUpdateCommit_traceAndRevisions` pins
    /// the same six by exact equality WITH their per-event `(anchor, head, revision, markedRange)`
    /// states, and `DelegateTraceCharacterizationTests
    /// .test_setMarkedText_emitsATextBracketThenASeparateSelectionBracket` pins the delegate half; this
    /// test's distinct job is to pin it in the file a future editor of the ROUTER reads.
    ///
    /// RED IF: the backend member gained a bracket. **Verified red** against exactly
    /// `notifyingContentAndSelectionChange { legacyCanvas?.legacySetMarkedText(…) }` — six recorded
    /// events became TEN, in the order `textWillChange, selectionWillChange, textWillChange,
    /// textDidChange, selectionWillChange, selectionDidChange, canvasContentSizeChanged,
    /// canvasSelectionChanged, selectionDidChange, textDidChange` (the added bracket wraps BOTH of the
    /// body's own).
    ///
    /// **The same run measured which OTHER suites catch it, and this family differs from Family 5's
    /// finding** — worth recording, because Task 28's report is what a reader would otherwise
    /// generalise from: `MarkedTextTraceCharacterizationTests` goes red with **14** failures and
    /// `DelegateTraceCharacterizationTests` with **1**, because both pin marked-text traces by exact
    /// equality. `EditingInputDelegateBracketTests` stays **green** (its assertions are monotone
    /// `> 0`), exactly as the coordinator's supplement predicted. So this member is not the sole guard
    /// its Family-5 sibling was — but it is the guard a reader of the ROUTER finds.
    func test_setMarkedText_emitsExactlyTheWitnessesOwnTwoBrackets_theBackendAddsNoneOfItsOwn() {
        let (v, recorder) = realCanvas()

        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))

        XCTAssertEqual(recorder.kinds, [.textWillChange, .textDidChange,
                                        .selectionWillChange, .selectionDidChange,
                                        .canvasContentSizeChanged, .canvasSelectionChanged])
    }

    /// `unmarkText`'s half of the same property, and it is SHARPER than its sibling's: `commitMarkedText`
    /// emits NO delegate notification and NO canvas-hook event at all, so a bracket added at the backend
    /// would not double an existing one — it would be the ONLY one, fabricated out of nothing. The
    /// revision assertion is the re-based form of the brief's
    /// `test_oneUnmarkTextProducesExactlyOneDocumentCommit`: a commit mutates no text, so the honest
    /// "exactly one" here is exactly ZERO revisions, plus one undo step becoming available.
    ///
    /// RED IF: the backend member gained a bracket (the trace would stop being empty), or the forward
    /// reached a body that mutates text (the revision would move).
    func test_unmarkText_commitsThroughTheBackend_movingNoRevisionAndEmittingNothing() {
        let (v, recorder) = realCanvas()
        v.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertNotNil(v.markedRange, "precondition: a composition is live")
        let before = v.documentRevision
        recorder.reset()

        v.unmarkText()

        XCTAssertNil(v.markedRange, "the composition is committed, not left dangling")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "ni",
                       "committed, not deleted — the provisional characters stay")
        XCTAssertEqual(v.documentRevision, before, "commitMarkedText mutates no text")
        XCTAssertEqual(recorder.kinds, [], "…and emits no delegate or canvas-hook event at all")
        XCTAssertTrue(v.effectiveUndoManager?.canUndo ?? false,
                      "the composition became one undo step")
    }

    /// `markedTextStyle`'s behavioural half. BOTH halves are deliberate and must survive relocation: the
    /// getter is `nil` because we draw our own underline decoration (`drawMarkedTextUnderline`) and vend
    /// no system styling, and the setter is a no-op because there is nothing to remember.
    ///
    /// This is the test the coordinator's pre-flight flagged as load-bearing: the backend used to hold
    /// `markedTextStyle` as a plain STORED property, and routing the witness onto that storage would
    /// have been a silent behaviour change — after a set, the getter would start answering the stored
    /// dictionary. Task 29 replaced the storage with `get { nil } set { }`.
    ///
    /// RED IF: the backend's member is a stored property. **Verified red** against exactly that (a
    /// backing store added to `+MarkedText.swift`'s accessor pair): the second assertion read
    /// `"[__C.NSAttributedStringKey(_rawValue: NSUnderline): 1]"` where it must read nil. Nothing else
    /// in the package goes red on that mutation — before Task 29 this member had NO test coverage at
    /// all, which is why the coordinator's pre-flight flagged it.
    func test_markedTextStyleGetterIsNilAndSetterIsANoOp() {
        let (v, _) = realCanvas()
        XCTAssertNil(v.markedTextStyle, "the getter vends no system styling")

        v.markedTextStyle = [.underlineStyle: 1]

        XCTAssertNil(v.markedTextStyle, "…and the setter remembered nothing")
    }

    /// The family's own semantic axis, pinned rather than merely disclosed: `unmarkText`/`commitMarkedText`
    /// is the KEYBOARD-DRIVEN accept path and COMMITS a prediction, while `finalizeMarkedText()` is the
    /// interruption path and DISMISSES one — removing the ghost, because committing it would desync the
    /// keyboard's shadow document and duplicate the word on its accept-`replace` (the on-device bug Task
    /// 18 fixed). A genuine COMPOSITION is committed by both.
    ///
    /// A prediction is distinguished from a composition ONLY by the `{0, 0}` shape of `selectedRange`
    /// (the ghost trails the caret), which is why both halves below differ in exactly that argument.
    ///
    /// RED IF: `finalizeMarkedText()` were collapsed to `commitMarkedText()` — the prediction's ghost
    /// text would survive as "nihao" instead of being removed, and no dismissed range would be returned.
    func test_finalizeMarkedTextDismissesAPredictionButCommitsAComposition() {
        let (composing, _) = realCanvas()
        composing.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))   // composition
        XCTAssertNil(composing.finalizeMarkedText(),
                     "a committed composition reports no dismissed range")
        XCTAssertNil(composing.markedRange)
        XCTAssertEqual((composing.boxes[0] as! BlockBox).currentParagraph().text, "ni",
                       "a composition is COMMITTED — its text stays")

        let (predicting, _) = realCanvas()
        let s = predicting.boxes[0].textStart
        predicting.setMarkedText("ing", selectedRange: NSRange(location: 0, length: 0))   // prediction
        XCTAssertEqual((predicting.boxes[0] as! BlockBox).currentParagraph().text, "ing",
                       "precondition: the ghost is really in the document before the dismissal")
        let dismissed = predicting.finalizeMarkedText()
        XCTAssertEqual(dismissed.map { NSRange(location: $0.from, length: $0.to - $0.from) },
                       NSRange(location: s, length: 3),
                       "a prediction reports the range it removed, so a caller can shift a later caret")
        XCTAssertNil(predicting.markedRange)
        XCTAssertEqual((predicting.boxes[0] as! BlockBox).currentParagraph().text, "",
                       "a prediction is DISMISSED — its ghost text is removed")
    }

    // MARK: - Section 3: the dispatcher repoint (Step 4), the recursion guard itself

    /// `legacyApplyMutation`'s own rule is "every case must dispatch to the LEGACY BODY, never to the
    /// UIKit witness of the same name". With a SPY backend that rule is directly observable: the legacy
    /// bodies run on the canvas and reach the spy only through the bracket helpers, so the spy must
    /// never see `setMarkedText(_:selectedRange:)` or `unmarkText()` at all. A case still pointed at its
    /// witness would bounce out through the backend, and against a spy the mutation would silently
    /// vanish entirely.
    ///
    /// This is the re-based form of the brief's two recursion guards, and it is strictly sharper than a
    /// commit COUNT: Task 27a measured that `prepareAndRun`'s idle guard rejects the re-entrant call, so
    /// a commit count stays at 1 whether or not the repoint was made.
    ///
    /// RED IF: either case in `legacyApplyMutation` were left pointing at its witness — the spy would
    /// record `setMarkedText(_:selectedRange:)` / `unmarkText()`, and the document would not change.
    /// **Verified red** against exactly that (both cases reverted at once): four assertions failed,
    /// with the spy log reading `["unmarkText()"]` where it must be empty.
    ///
    /// **And this test is the ONLY thing that catches it — measured, not assumed.** The task brief's
    /// Step 6 named `TelegramDocumentInputClientMutationTests` as "the direct check that
    /// `legacyApplyMutation`'s `.setMarkedText`/`.unmarkText` cases still reach a real body"; under the
    /// same mutation that suite stays **green, 18/18**. It cannot see the defect, because with an
    /// ATTACHED canvas a case pointed at its witness still reaches the same legacy body — one useless
    /// round trip out through the backend and back. The bounce only becomes visible when the backend is
    /// something other than the canvas's own (a spy) or when `legacyCanvas` is nil.
    func test_theMutationDispatcherReachesTheLegacyBodies_notTheRoutedWitnesses() {
        let (v, spy) = spyCanvas()
        let s = v.boxes[0].textStart

        _ = v.legacyApplyMutation(.setMarkedText(text: NSAttributedString(string: "ni"),
                                                 replacing: NSRange(location: s, length: 0),
                                                 selectedRangeInMarkedText: NSRange(location: 2, length: 0)))

        XCTAssertFalse(spy.calls.map(\.member).contains("setMarkedText(_:selectedRange:)"),
                       "the .setMarkedText case must reach legacySetMarkedText directly, never the witness")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "ni",
                       "…and the legacy body really ran, so the assertion above is not vacuous")
        XCTAssertNotNil(v.markedRange)

        spy.reset()
        _ = v.legacyApplyMutation(.unmarkText)

        XCTAssertEqual(spy.calls.map(\.member), [],
                       "the .unmarkText case must reach legacyUnmarkText directly, never the witness — " +
                       "and commitMarkedText emits nothing, so the whole log stays empty")
        XCTAssertNil(v.markedRange, "…and the composition really was committed")
    }
}
#endif
