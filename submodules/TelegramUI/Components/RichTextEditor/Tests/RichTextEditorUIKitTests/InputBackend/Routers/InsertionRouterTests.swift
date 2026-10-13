#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// A `UITextRange` that is deliberately NOT a `DocumentTextRange`. UIKit can hand a witness a range
/// object it did not mint (a stale one from a previous document, or one from another text input), and
/// the pre-seam `replace(_:withText:)` answered that with a bare `guard … as? … else { return }`.
/// Where that cast lives after routing is a real decision, so both halves of it are pinned below.
/// Nothing reads this object's `start`/`end`; it exists only to fail the cast.
@available(iOS 13.0, *)
private final class ForeignTextRange: UITextRange {}

/// TASK 27a — Family 4's routable half (`replace(_:withText:)`, `hasText`); **TASK 27b — its third
/// witness, `insertText(_:)`** (section 3 below).
///
/// `insertText(_:)` is a PLAIN `legacyCanvas` forward, per the user's D35 ruling: Task 27 measured
/// that routing it into the document-client transaction makes typing a silent no-op, and that no
/// repair reconciles `runMutation`'s fixed four-notification bracket with the witness's per-branch
/// one. The transaction body that used to sit on `LegacyRichTextInputBackend.insertText(_:)` now lives
/// on the test-only `ReferenceMutationBackend`, which the mutation contract suites run against.
///
/// **Which backend each test runs against, decided before any of them were written** (the handoff's
/// rule 3 — deciding this mid-task is how it gets discovered as a red):
///
///   * **Spy** for the three routing-shape tests. The spy performs no work, so `RouterStateSnapshot`'s
///     seven fields cannot move and `XCTAssertRoutesOnly`'s "and the canvas did nothing of its own"
///     half is exactly right — and it is genuinely non-inert for `replace`, which under the real
///     backend moves `revision`, `anchor`, `head`, `undoRegistrationCount` and
///     `dismissEditMenuCountForTesting`. A router that kept a copy of the old inline body beside the
///     forward would fail there.
///   * **Real legacy backend** for the four behavioural tests. A correctly-routed `replace` legitimately
///     moves those same fields, so `XCTAssertRouterDidNoWork` would fail FOR CORRECT CODE; those tests
///     assert the expected DELTA instead, which is the stronger assertion anyway since it pins the body
///     the routing moved rather than its absence.
///
/// `hasText`'s DETACHED fallback is pinned in `BackendAttachmentTests`, not here: rule R14 forbids this
/// directory from naming the canvas's backend property, so there is no legal way to detach from inside
/// this file — and the fallback is a characterization of THIS conformer, not a contract obligation, so
/// a `final class … XCTestCase` that already constructs the concrete backend is its correct home.
///
/// Every test reads through a real `DocumentCanvasView` member, never the canvas's backend property —
/// the vacuity trap R14 mechanically forbids in this directory.
@MainActor
@available(iOS 16.0, *)
final class InsertionRouterTests: XCTestCase {

    // MARK: - Section 1: the spy backend — "one call, exact arguments, exact return, nothing else"

    private func spyCanvas() -> (DocumentCanvasView, SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        spy.reset()
        return (v, spy)
    }

    /// The spy's `stubbedHasText` default is `false`, and this canvas is SEEDED — so the pre-seam,
    /// non-routing answer (`documentSize > 0`) is `true`. The `false` read below is therefore real
    /// signal, not a value a broken router could produce by accident.
    ///
    /// RED IF: the witness kept answering `documentSize > 0` itself (it would read `true`, and the spy
    /// would record zero calls).
    func test_hasText_callsTheBackendOnceAndReturnsItsExactValue() {
        let (v, spy) = spyCanvas()
        XCTAssertGreaterThan(v.documentSizeValue, 0,
                             "precondition: the non-routing answer must be `true`, or the assertion " +
                             "below could pass for a router that never forwarded")
        let result = XCTAssertRoutesOnly(v, spy, member: "hasText", arguments: []) {
            v.hasText
        }
        XCTAssertFalse(result, "the router must return the backend's answer, not the canvas's own")
    }

    func test_replaceWithText_callsTheBackendOnceWithTheRangeObjectAndText() {
        let (v, spy) = spyCanvas()
        let range = DocumentTextRange(DocumentTextPosition(3), DocumentTextPosition(5))
        XCTAssertRoutesOnly(v, spy, member: "replace(_:withText:)",
                            arguments: [ObjectIdentifier(range).debugDescription, "Zed"]) {
            v.replace(range, withText: "Zed")
        }
    }

    /// The cast is the BACKEND's decision, exactly as the floating-cursor drop is for `selectedTextRange`
    /// (Task 26). A foreign range must still REACH the backend; only the backend may drop it.
    ///
    /// RED IF: the router re-grew the pre-seam `guard let r = range as? DocumentTextRange else { return }`
    /// — the spy would then record zero calls.
    func test_replaceWithText_forwardsAForeignRangeTypeRatherThanDroppingItAtTheRouter() {
        let (v, spy) = spyCanvas()
        let foreign = ForeignTextRange()
        XCTAssertRoutesOnly(v, spy, member: "replace(_:withText:)",
                            arguments: [ObjectIdentifier(foreign).debugDescription, "Zed"]) {
            v.replace(foreign, withText: "Zed")
        }
    }

    // MARK: - Section 2: the real legacy backend — the canvas body the routing moved

    private func realCanvas(_ text: String = "teh cat") -> (DocumentCanvasView, RichTextInputEventRecorder) {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: text)])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        // No `undoManagerOverride`: `replace(_:withText:)` runs through `editing { }`, which registers
        // undo on the canvas's default manager (`groupsByEvent == true`), so no explicit group bracket
        // is needed — matching `AutocorrectOriginCharacterizationTests`' own fixture note.
        let recorder = RichTextInputEventRecorder(); recorder.attach(canvas: v); recorder.reset()
        return (v, recorder)
    }

    /// The whole moved body, end to end: the edit lands, the revision moves once, and the
    /// autocorrection heuristic still runs and still records its flag.
    ///
    /// RED IF: the backend dropped the `legacyReplace` forward (nothing changes), or the moved body lost
    /// `detectAutocorrection`/`applyCorrectionFlag` (`spellResults` stays empty).
    func test_replaceWithText_runsTheWholeCanvasBodyThroughTheBackend() {
        let (v, _) = realCanvas()
        let s = v.boxes[0].textStart
        let before = v.documentRevision

        v.replace(DocumentTextRange(DocumentTextPosition(s), DocumentTextPosition(s + 3)), withText: "the")

        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "the cat")
        XCTAssertEqual(v.documentRevision, before + 1)
        XCTAssertFalse(v.spellResults.isEmpty,
                       "the autocorrection heuristic and its correction flag moved with the body")
    }

    /// **The load-bearing test of this task.** The routed member must add NO bracket of its own: the
    /// canvas body already runs one `editing { }`, so the observable trace of one `replace` is exactly
    /// the six events below. Wrapping the forward in `notifyingContentAndSelectionChange` — which the
    /// task brief's Step 5 asked for — makes it eight, and `AutocorrectOriginCharacterizationTests`
    /// pins the same array by exact equality in three separate tests.
    ///
    /// RED IF: the backend member gained a bracket. Verified red against exactly that (see the task
    /// report's red-check section).
    func test_replaceWithText_emitsExactlyThePlainEditingBracket_theBackendAddsNoneOfItsOwn() {
        let (v, recorder) = realCanvas()
        let s = v.boxes[0].textStart

        v.replace(DocumentTextRange(DocumentTextPosition(s), DocumentTextPosition(s + 3)), withText: "the")

        XCTAssertEqual(recorder.kinds, [.textWillChange, .selectionWillChange, .selectionDidChange,
                                        .textDidChange, .canvasContentSizeChanged, .canvasSelectionChanged])
    }

    /// The other half of the cast decision (its spy half is in section 1): the backend DROPS a foreign
    /// range, silently and completely, exactly as the pre-seam witness's `guard` did.
    ///
    /// RED IF: the backend forwarded a foreign range to `legacyReplace` with fabricated offsets — the
    /// document would change.
    func test_replaceWithText_ignoresAForeignRangeTypeWithoutTouchingTheDocument() {
        let (v, recorder) = realCanvas()
        let before = v.documentRevision

        v.replace(ForeignTextRange(), withText: "Zed")

        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "teh cat")
        XCTAssertEqual(v.documentRevision, before, "a dropped write must not open an editing transaction")
        XCTAssertEqual(recorder.kinds, [], "…and must not emit a delegate bracket either")
    }

    /// Axis 3 of the divergence audit, pinned rather than merely disclosed. The pre-seam body read the
    /// original word via `text(in:)`, which is a CLAMPING projection (`legacyPlainText`); the document
    /// client's `plainText(in:)` REJECTS an out-of-bounds range instead. With a range that runs past the
    /// end of the document, the clamping read still yields `"teh"` — a single word, so the heuristic
    /// classifies the edit as an autocorrection and records the flag.
    ///
    /// RED IF: `legacyReplace` re-derived `oldText` through the document client (or through any
    /// rejecting projection) — `oldText` would be `nil`, `detectAutocorrection` would return `nil`, and
    /// `spellResults` would stay empty while the edit itself still landed. Verified red against exactly
    /// that (see the task report's red-check section).
    func test_replaceWithText_readsTheOriginalThroughTheClampingProjection_notARejectingOne() {
        let (v, _) = realCanvas("teh")
        let s = v.boxes[0].textStart
        let pastTheEnd = v.documentSizeValue + 4

        v.replace(DocumentTextRange(DocumentTextPosition(s), DocumentTextPosition(pastTheEnd)), withText: "the")

        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "the",
                       "precondition: the edit itself lands either way — this test is about the READ")
        XCTAssertFalse(v.spellResults.isEmpty,
                       "the clamped read yields \"teh\", so the correction flag is still recorded")
    }

    /// `hasText` against the real backend, both polarities from one member.
    ///
    /// RED IF: the backend answered from something other than the document length (a hardcoded `true`
    /// would fail the empty case; a hardcoded `false` would fail the seeded one).
    func test_hasText_tracksTheDocumentLength() {
        let (v, _) = realCanvas()
        XCTAssertTrue(v.hasText)

        let empty = DocumentCanvasView()
        XCTAssertEqual(empty.documentSizeValue, 0, "precondition: an unseeded canvas has no content")
        XCTAssertFalse(empty.hasText)
    }

    // MARK: - Section 3: `insertText(_:)` (TASK 27b)

    /// The spy records the call and performs NO edit, so `XCTAssertRoutesOnly`'s "and the canvas did
    /// nothing of its own" half is exactly right here — and it is genuinely non-inert: under the real
    /// backend this same call moves `revision`, `anchor`, `head` and `undoRegistrationCount`, all seven
    /// of which `RouterStateSnapshot` watches.
    ///
    /// RED IF: the witness kept its own body (the canvas would type, moving the snapshot, and the spy
    /// would record zero calls) — or forwarded a transformed string.
    func test_insertText_callsTheBackendOnceWithTheExactString() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "insertText(_:)", arguments: ["x"]) {
            v.insertText("x")
        }
    }

    /// The whole moved body, end to end, through the real backend: the character lands at the caret,
    /// the caret advances, and the revision moves exactly once.
    ///
    /// RED IF: the backend dropped the `legacyInsertText` forward (nothing changes), or the dispatcher
    /// repoint went to the wrong body.
    func test_insertText_runsTheWholeCanvasBodyThroughTheBackend() {
        let (v, _) = realCanvas("Alpha")
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 1)
        let before = v.documentRevision

        v.insertText("x")

        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Axlpha")
        XCTAssertEqual(v.head, s + 2, "the caret advances past the inserted character")
        XCTAssertEqual(v.documentRevision, before + 1)
    }

    /// **The load-bearing test of this task.** `legacyInsertText` brackets itself — per branch — so the
    /// routed member must add NO bracket of its own. One ordinary keystroke is exactly the six events
    /// below; wrapping the forward in `notifyingContentAndSelectionChange` (the shape the Phase-4
    /// preamble's snippet used to prescribe, corrected by Task 27a) makes it ten, and the marked-commit
    /// branch's TEXT-ONLY bracket would become a four-notification one.
    ///
    /// `DelegateTraceCharacterizationTests` pins the same traces from the canvas side, including the
    /// marked-commit asymmetry this test cannot see from a plain caret — the two together are what
    /// prove the per-branch shape survived the routing.
    ///
    /// RED IF: the backend member gained a bracket. Verified red against exactly that (see the task
    /// report's red-check section).
    func test_insertText_emitsExactlyTheWitnessesOwnBracket_theBackendAddsNoneOfItsOwn() {
        let (v, recorder) = realCanvas("Alpha")
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 1)
        recorder.reset()

        v.insertText("x")

        XCTAssertEqual(recorder.kinds, [.textWillChange, .selectionWillChange, .selectionDidChange,
                                        .textDidChange, .canvasContentSizeChanged, .canvasSelectionChanged])
    }
}
#endif
