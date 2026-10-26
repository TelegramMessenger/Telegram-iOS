#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 36a — `RichTextInputCaretOutcome` and `DocumentCanvasView.editing(coalescing:_:)`.
///
/// The type exists so Tasks 36b/36c could convert `DocumentCanvasView+Editing.swift`'s 34
/// `anchor = …; head = …` write sites into RETURN VALUES one cluster at a time. Changing
/// `editing(coalescing:_:)`'s own closure type in ONE commit would have broken every one of its call
/// sites plus ~20 primitive signatures together, leaving no intermediate state in which the package
/// compiles — so 36a added the outcome-returning closure as a second overload
/// (`editingApplyingOutcome`), 36b converted the primitives against it, and **Task 36c flipped every
/// call site, deleted the `Void` overload and the eight transitional wrappers, and renamed the
/// survivor back to `editing`. There is one entry point again.**
///
/// **THE CALL-SITE COUNT IS NOT STATED HERE, and this comment used to be why it needed to be.** The
/// plan's "Why three tasks" paragraph is its normative home; it carries the raw figure, the
/// non-comment-line figure, the true invocation figure, the commands and counter that produce each,
/// the Rule-21 re-run note, and the history of every value that has rotted. **Task 36c's fix round
/// deleted the copy that stood here** — three of its four numbers had gone stale within the same
/// task, one of them (`105`) because it subtracted a declaration the counter never counted, and two
/// of them because a LATER commit of that same task added prose the pattern matches. A number
/// restated in a second place is a number that will disagree with the first; the whole point of the
/// home is that there is one.
///
/// **AS OF TASK 36a NOTHING IN `Sources/` CALLED THE NEW FORM**, because the `Void` form passed
/// `.unchanged` and the application branch was dormant on arrival. That is why this suite constructs
/// its claims itself: a dormant branch cannot be exercised by the existing suite, and every fact
/// above the Task-36b MARK would have been vacuous if it were only asserted against the `Void` form
/// (Rule 19 — a negative or equivalence claim is proven only by constructing the thing it forbids).
/// The branch is no longer dormant, but the construction stays: it is still the only thing that
/// separates "the primitive returns the caret" from "the primitive writes it".
///
/// **TASK 36b ENDED THAT.** `+Editing.swift`'s fifteen Kind-B primitives drive
/// `editing` for real, and its eleven Kind-A primitives return a
/// `RichTextInputCaretOutcome` their callers apply. The tests under this file's Task-36b MARK assert
/// the two facts that conversion depends on and that nothing else in the package checks: that an
/// `*Outcome` form RETURNS the caret without writing it, and that a refused edit claims nothing.
///
/// # THE DIVERGENCE FROM THE BRIEF, and the measurement behind it
///
/// The brief's Step 4 applies the claim with `inputBackend.setSelection(claimed, reason: .command)`.
/// It is applied through the raw, non-publishing `setCanonicalAnchor`/`setCanonicalHead` pair
/// instead, because `editing`'s own tail already delivers exactly the two host effects a
/// `.selection` publish delivers, so a claim inside its bracket DOUBLES them — the publishing shape
/// makes the trace gain a `canvasSelectionChanged` between `selectionWillChange` and
/// `selectionDidChange`. **The reasoning, the failing-shape numbers and the green control are
/// recorded once, at `applyCaretOutcome` in `DocumentCanvasView+Editing.swift`**; this header does
/// not restate them.
///
/// `test_aClaimReportsExactlyOnce_theSameAsARawWrite` and
/// `test_aReturnedClaimEmitsTheSameTraceAsAnInBodyCaretWrite` below are the pins: **both were run RED
/// against the publishing shape**, and `test_editingAppliesTheOutcomeInsideTheBracket_…` and
/// `test_editingRespectsUndoCoalescingWithAClaimedCaret` were run red against applying the claim one
/// line later (after `openUndoRun` is computed). Neither is a shape anyone can reach accidentally,
/// which is exactly why they were built and run rather than argued (Rule 19). (Both of those two
/// names changed in Task 36c: they said `editingApplyingOutcome`, and that symbol is gone. What they
/// compare did not change — the second arm of the trace test still applies the caret INSIDE the body,
/// which is what the deleted wrapper did, against a first arm that returns the claim.)
@available(iOS 16.0, *)
@MainActor
final class CaretOutcomeTests: XCTestCase {

    /// One long paragraph, so every offset used below is inside real text (the global axis is
    /// 1-based, so `boxes[0].textStart == 1` and the text spans offsets 1…23).
    private func makeCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"),
                                        runs: [TextRun(text: "Alpha Beta Gamma Delta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    /// Deviation D22: this suite never writes `anchor`/`head`, so it adds nothing to the Phase-5
    /// deprecation worklist and Task 40b's read-only conversion does not touch it. Seeding goes
    /// through the `setSelectionForTesting` seam, which is deliberately silent.
    private func seed(_ v: DocumentCanvasView, anchor: Int, head: Int) {
        v.setSelectionForTesting(anchor: anchor, head: head)
    }

    // MARK: - The type's three cases

    /// **The distinction the type exists for, asserted as a value fact before any canvas is
    /// involved.** "No claim" and "claims offset 0" are different outcomes; an
    /// `Optional<RichTextCanonicalSelection>` return would spell them the same way at any call site
    /// that reached for `?? current`. This is also the only exercise of the `Equatable` conformance
    /// the type declares — a conformance nothing compares is a conformance nothing checks.
    func test_unchangedIsNotAClaimOfOffsetZero() {
        XCTAssertNotEqual(RichTextInputCaretOutcome.unchanged, .caret(at: 0),
                          "`.unchanged` means NO claim; `.caret(at: 0)` claims the document start")
        XCTAssertNil(RichTextInputCaretOutcome.unchanged.selection)
        XCTAssertEqual(RichTextInputCaretOutcome.caret(at: 4), .range(4, 4),
                       "control: two spellings of the SAME claim must compare equal, or the " +
                       "assertion above would pass for the trivial reason that nothing compares equal")
    }

    /// **Rule 16 applies here and is the whole reason for the seed.** The default selection is
    /// `(0, 0)`; asserting "unchanged" from the default cannot fail against an implementation that
    /// always writes `.caret(at: 0)`. The seed is therefore a NON-DEFAULT, REVERSED, non-collapsed
    /// selection, so "left alone" is distinguishable from every plausible wrong answer — including
    /// the one this type exists to keep separable, "claims the CURRENT selection" (which would
    /// normalise nothing but would still route through the application path).
    func test_unchangedOutcomeLeavesTheSelection() {
        let v = makeCanvas()
        seed(v, anchor: 9, head: 4)
        v.editing { .unchanged }
        XCTAssertEqual(v.anchor, 9, "`.unchanged` means NO claim — the store must be untouched")
        XCTAssertEqual(v.head, 4)
    }

    func test_caretOutcomeCollapsesTheSelectionAtTheGivenOffset() {
        let v = makeCanvas()
        seed(v, anchor: 9, head: 4)
        v.editing { .caret(at: 6) }
        XCTAssertEqual(v.anchor, 6, "`.caret(at:)` collapses BOTH endpoints onto the given offset")
        XCTAssertEqual(v.head, 6)
    }

    /// The argument order is `(anchor, head)` and is NOT normalised. `(9, 2)` is chosen so a `min`/
    /// `max` normalisation anywhere in the path reports `(2, 9)` and fails both assertions, rather
    /// than agreeing by coincidence as a forward range would.
    func test_rangeOutcomePreservesDirection() {
        let v = makeCanvas()
        seed(v, anchor: 2, head: 2)
        v.editing { .range(9, 2) }
        XCTAssertEqual(v.anchor, 9, "anchor must stay the LARGER offset — no normalisation")
        XCTAssertEqual(v.head, 2)
        XCTAssertTrue(v.inputBackend.canonicalSelection.isReversed,
                      "the reversal must survive into the backend's canonical store, not just the " +
                      "canvas forwarders' arithmetic")
    }

    // MARK: - Equivalence between an in-body caret write and a returned claim

    /// **The safety argument for the overload, and the half the brief could not state.** The brief
    /// asks for delegate-trace equality; a nested PUBLICATION is a host callback, not a delegate
    /// notification, so two delegate traces can be equal element-for-element while one form
    /// publishes and the other does not.
    ///
    /// This compares the recorder's FULL event stream — which interleaves the four delegate
    /// notifications with the canvas hooks `canvasSelectionChanged` / `canvasContentSizeChanged`,
    /// on ONE shared ordinal — so a publication IS visible: it reaches
    /// `lifecycleClient.backendDidPublishState(.selection)` → `canvas.onSelectionChange?()` and
    /// lands as an extra `canvasSelectionChanged` between `selectionWillChange` and
    /// `selectionDidChange`. `test_aClaimReportsExactlyOnce_theSameAsARawWrite` asserts the same
    /// fact as a bare count, so a future reader does not have to decode a trace diff to see it.
    ///
    /// The two bodies are equivalent by construction: both run the SAME primitive, and the outcome
    /// form additionally claims the very offset that primitive already left the caret at. So any
    /// difference in the two traces is produced by the application MECHANISM and nothing else.
    func test_aReturnedClaimEmitsTheSameTraceAsAnInBodyCaretWrite() {
        func run(_ useOutcomeForm: Bool) -> (events: [RichTextInputRecordedEvent], reports: Int, text: String) {
            let v = makeCanvas()
            let caret = v.boxes[0].textStart + 3
            seed(v, anchor: caret, head: caret)
            var reports = 0
            v.onSelectionChange = { reports += 1 }
            let recorder = RichTextInputEventRecorder()
            recorder.attach(canvas: v)   // chains the counter above, so both channels stay live
            recorder.reset()
            reports = 0
            if useOutcomeForm {
                v.editing {
                    _ = v.applyReplaceOutcome(globalFrom: caret, globalTo: caret, text: "x")
                    return .caret(at: caret + 1)
                }
            } else {
                v.editing {
                    // The PRE-36c shape, reproduced rather than cited: the primitive's caret is
                    // applied INSIDE the body — byte for byte what the deleted `-> Void` wrappers
                    // did on their next instruction — and the transaction itself claims nothing.
                    v.applyCaretOutcome(v.applyReplaceOutcome(globalFrom: caret, globalTo: caret, text: "x"))
                    return .unchanged
                }
            }
            return (recorder.events, reports, (v.boxes[0] as! BlockBox).currentParagraph().text)
        }

        let plain = run(false)
        let outcome = run(true)

        XCTAssertEqual(plain.text, outcome.text, "control: both forms must produce the same document")
        XCTAssertFalse(plain.events.isEmpty, "control: an empty trace would make the equality vacuous")
        XCTAssertEqual(plain.events, outcome.events,
                       "the two forms must emit an IDENTICAL event stream.\nplain:\n\(plain.events)\n" +
                       "outcome:\n\(outcome.events)")
        XCTAssertEqual(plain.reports, outcome.reports,
                       "…including the host-report count, which is where a publication would show up")
    }

    /// The publication assertion as a bare number, stated separately from the trace comparison
    /// above so it cannot be lost in a diff.
    ///
    /// **What this counts.** `onSelectionChange` is the observable end of
    /// `lifecycleClient.backendDidPublishState(_:reason: .selection)`, and `publishState` calls
    /// `presentationClient.apply` and the lifecycle client UNCONDITIONALLY, one after the other —
    /// so with `suppressHostChangeNotification` false (as here), counting host reports counts
    /// publications. The presentation half (`refreshSelectionUI()`) has no separate canvas-level
    /// observable and rides the same call.
    ///
    /// **The expected value is 1, not 0**: `editing`'s own tail reports once, and always has. What
    /// is pinned is that a CLAIM adds nothing to that — exactly as the raw `anchor = …; head = …`
    /// pair it replaces added nothing. Rule 19: the forbidden shape
    /// (`setSelection(_:reason: .command)`) makes the claim arm 2.
    ///
    /// **FIX ROUND 1 — the name now describes the test.** It previously asserted only the claim arm
    /// and left "the same as a raw write" to the reader (a review nit, correctly filed). The raw arm
    /// below is the comparison the name promises, run against the same canvas shape and the same
    /// offset. It writes through `inputBackend.setCanonicalAnchor`/`setCanonicalHead` rather than
    /// `v.anchor`/`v.head` deliberately: those are the exact members `applyCaretOutcome` calls, and
    /// going through the canvas forwarders would add two entries to the Phase-5 deprecation worklist
    /// this suite is careful not to touch (deviation D22).
    func test_aClaimReportsExactlyOnce_theSameAsARawWrite() {
        func reportsForClaimArm() -> Int {
            let v = makeCanvas()
            seed(v, anchor: 9, head: 4)
            var reports = 0
            v.onSelectionChange = { reports += 1 }
            v.editing { .caret(at: 6) }
            XCTAssertEqual(v.inputBackend.canonicalSelection.head.utf16Offset, 6,
                           "the claim itself must have landed in the backend's canonical store")
            XCTAssertEqual(v.inputBackend.canonicalSelection.anchor.utf16Offset, 6)
            return reports
        }
        func reportsForRawArm() -> Int {
            let v = makeCanvas()
            seed(v, anchor: 9, head: 4)
            var reports = 0
            v.onSelectionChange = { reports += 1 }
            v.editing {
                v.inputBackend.setCanonicalAnchor(6)   // what the 30 converted sites did before 36b/36c
                v.inputBackend.setCanonicalHead(6)
                return .unchanged
            }
            XCTAssertEqual(v.inputBackend.canonicalSelection.head.utf16Offset, 6,
                           "control: the raw arm must reach the same state, or the comparison is " +
                           "between two different situations")
            return reports
        }

        let claim = reportsForClaimArm()
        let raw = reportsForRawArm()
        XCTAssertEqual(raw, 1,
                       "control: the pre-36a shape reports exactly once — `editing`'s own tail. If " +
                       "this is not 1 the expectation below is measuring the wrong baseline")
        XCTAssertEqual(claim, raw,
                       "a caret claim must be as transparent as the raw endpoint pair it replaces. " +
                       "The forbidden shape (`setSelection(_:reason: .command)`) makes the claim arm " +
                       "2 while the raw arm stays 1")
    }

    // MARK: - When the claim is applied

    /// The claim lands INSIDE the delegate bracket: after `body()` and before the DID notifications.
    /// Asserting only that `selectionDidChange` carries the new value would also pass if the claim
    /// were applied BEFORE the bracket opened, so the WILL event is asserted too — it must still
    /// carry the OLD selection. The pair is what fixes the application to one position.
    func test_editingAppliesTheOutcomeInsideTheBracket_beforeTheDidNotifications() {
        let v = makeCanvas()
        seed(v, anchor: 2, head: 2)
        let recorder = RichTextInputEventRecorder()
        recorder.attach(canvas: v)
        recorder.reset()

        v.editing { .caret(at: 7) }

        guard let will = recorder.events.first(where: { $0.kind == .selectionWillChange }),
              let did = recorder.events.first(where: { $0.kind == .selectionDidChange }) else {
            return XCTFail("expected one selectionWillChange and one selectionDidChange\n\(recorder.trace())")
        }
        XCTAssertEqual(will.anchor, 2, "the WILL event must observe the PRE-claim selection")
        XCTAssertEqual(will.head, 2)
        XCTAssertEqual(did.anchor, 7, "the DID event must observe the POST-claim selection")
        XCTAssertEqual(did.head, 7)
        XCTAssertLessThan(will.ordinal, did.ordinal, "control: the two events are in bracket order")
    }

    // MARK: - Undo coalescing

    /// `performEditing` opens `openUndoRun` at the POST-body caret, so a claim has to be applied
    /// before that bookkeeping runs or a converted primitive silently stops coalescing.
    ///
    /// **The construction is what makes this discriminating, and my first attempt was not.** A body
    /// that mutates nothing while claiming the caret it already sits at passes whether or not the
    /// claim is applied at all — nothing moves either way. So here the body's OWN raw write and the
    /// claim deliberately disagree: `applyReplaceOutcome` leaves the caret at `c + 1`, the primitive claims
    /// `c + 5`, and the second call starts at `c + 5`. It coalesces only if the run was opened at
    /// the CLAIMED caret. Rule 19: move `applyCaretOutcome` one line later, after `openUndoRun` is
    /// computed, and the run opens at `c + 1`, the second call fails the contiguity test, and the
    /// last assertion reads 2.
    ///
    /// (`continuesRun` reads the caret as it stood BEFORE `body()`, not after — measured, after this
    /// test's sibling below was first written on the opposite assumption and went red.)
    func test_editingRespectsUndoCoalescingWithAClaimedCaret() {
        let v = makeCanvas()
        let c = v.boxes[0].textStart + 3
        seed(v, anchor: c, head: c)
        let um = UndoManager(); um.groupsByEvent = true
        v.undoManagerOverride = um

        v.editing(coalescing: .typing) {
            v.applyCaretOutcome(v.applyReplaceOutcome(globalFrom: c, globalTo: c, text: "x"))   // body parks the caret at c+1…
            return .caret(at: c + 5)                                // …and the primitive claims c+5
        }
        XCTAssertEqual(v.undoRegistrationCount, 1, "the first edit always starts a fresh undo step")
        XCTAssertEqual(v.head, c + 5,
                       "the claim is applied AFTER the body, so it wins over the body's own write")

        v.editing(coalescing: .typing) { .caret(at: c + 5) }
        XCTAssertEqual(v.undoRegistrationCount, 1,
                       "a contiguous same-kind claim must COALESCE — which it can only do if the " +
                       "run was opened at the CLAIMED caret (c+5) rather than at the body's c+1")
    }

    // MARK: - TASK 36b — the primitives' side of the split

    /// **THE FACT THE WHOLE CONVERSION RESTS ON, and the one no other suite can see.** Every
    /// end-to-end suite drives a primitive through its caller, where the caret is applied a moment
    /// later — so all of them pass whether the primitive writes the caret itself or merely returns
    /// it. Calling the `*Outcome` form DIRECTLY, outside any bracket, is the only way to tell those
    /// two apart, and telling them apart was exactly what Task 36c needed to be true before it
    /// deleted the transitional wrappers. It still is: nothing else would notice a primitive that
    /// quietly went back to writing the caret itself.
    ///
    /// Rule 16: the seed is non-default, reversed and non-collapsed, so "left alone" is
    /// distinguishable from a collapse, from a normalisation, and from a write of the claimed value.
    ///
    /// **Its partner fact — that an enclosing primitive which reads the caret BACK must therefore
    /// apply the claim immediately — is already pinned**, by
    /// `CodeBlockEditingTests.test_codeBlock_enterReplacesSelectionWithNewline`: Enter over a
    /// selection inside a code block deletes, re-resolves `activeStack(at: head)`, and inserts, and
    /// its expected `"a\nd"` becomes `"ad\n"` the moment the delete's claim is deferred past the
    /// re-resolve. Not restated as a second test here (Rule 15); `insertCodeBlockNewline` and its
    /// three siblings carry an in-source comment pointing at the same constraint.
    func test_anOutcomeFormReturnsTheCaretWithoutWritingIt() {
        let v = makeCanvas()
        seed(v, anchor: 9, head: 4)
        let c = v.boxes[0].textStart + 3

        let outcome = v.applyReplaceOutcome(globalFrom: c, globalTo: c, text: "x")

        XCTAssertEqual(outcome, .caret(at: c + 1), "the primitive RETURNS the caret it used to assign")
        XCTAssertEqual(v.anchor, 9, "…and writes NOTHING: the store still holds the seeded selection")
        XCTAssertEqual(v.head, 4)
        XCTAssertTrue((v.boxes[0] as! BlockBox).currentParagraph().text.hasPrefix("Alpxha"),
                      "control: the edit itself really happened, so the two assertions above are " +
                      "not passing because the primitive did nothing at all")
    }

    /// The same fact for the router — the primitive Task 36c converted the most call sites of, and
    /// which forwards its delegate's claim rather than producing one.
    func test_theRouterForwardsItsDelegatesClaimWithoutWritingIt() {
        let v = makeCanvas()
        seed(v, anchor: 9, head: 4)
        let c = v.boxes[0].textStart + 3

        let outcome = v.applySelectionReplaceOutcome(globalFrom: c, globalTo: c + 2, text: "")

        XCTAssertEqual(outcome, .caret(at: c), "the delete's caret collapses to the range start")
        XCTAssertEqual(v.anchor, 9, "…and the router writes nothing either")
        XCTAssertEqual(v.head, 4)
        XCTAssertTrue((v.boxes[0] as! BlockBox).currentParagraph().text.hasPrefix("Alp "),
                      "control: \"ha\" really was deleted")
    }

    /// **A REFUSED EDIT CLAIMS NOTHING — which is not the same as claiming the caret it found.**
    /// This is the meaning `.unchanged` carries into every converted primitive's guard, and the one
    /// the task brief got backwards for `applySelectionReplaceOutcome` (it asked for `.unchanged` at five
    /// exits that all claim a real caret; the correction is recorded on that method). Rule 16 again:
    /// against the default `(0, 0)` selection a `.caret(at: 0)` bug would be invisible here.
    func test_aRefusedEditClaimsNothing() {
        let v = makeCanvas()
        seed(v, anchor: 9, head: 4)

        let refused = v.applyMultiRegionClearOutcome(globalFrom: 5, globalTo: 5, text: "")

        XCTAssertEqual(refused, .unchanged, "an empty range is refused by `guard lo < hi`")
        XCTAssertNotEqual(refused, .caret(at: 5), "…and refusing is NOT claiming the range's own offset")
        XCTAssertEqual(v.anchor, 9, "the store is untouched")
        XCTAssertEqual(v.head, 4)

        let accepted = v.applyMultiRegionClearOutcome(globalFrom: 3, globalTo: 6, text: "")
        XCTAssertNotEqual(accepted, .unchanged,
                          "control: the SAME primitive does claim a caret for a real range, so the " +
                          "refusal above is a property of the input and not of the primitive")
    }

    // MARK: - Undo coalescing (continued)

    /// The control for the test above: a coalescing assertion that cannot distinguish "coalesced"
    /// from "the counter never moves" proves nothing. A caret move BETWEEN two claims breaks the run
    /// and the counter does reach 2.
    func test_theCoalescingCounterDoesReachTwoWhenTheRunIsBroken() {
        let v = makeCanvas()
        let um = UndoManager(); um.groupsByEvent = true
        v.undoManagerOverride = um

        seed(v, anchor: 5, head: 5)
        v.editing(coalescing: .typing) { .caret(at: 5) }
        XCTAssertEqual(v.undoRegistrationCount, 1)
        seed(v, anchor: 12, head: 12)   // a caret move outside `editing` — the classic run-breaker
        v.editing(coalescing: .typing) { .caret(at: 12) }
        XCTAssertEqual(v.undoRegistrationCount, 2,
                       "the second claim does not start where the run left off, so it must register " +
                       "a fresh undo step")
    }
}
#endif
