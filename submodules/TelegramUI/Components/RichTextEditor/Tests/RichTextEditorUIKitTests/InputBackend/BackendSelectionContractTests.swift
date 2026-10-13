#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// Task 22e, the fourth of eight contract suites (22b-22i). Pins the backend's SELECTION-OWNERSHIP
/// contract: endpoint identity (a reversed selection's anchor/head are never reordered — anchor is
/// NOT "the first one set" or "the smaller offset"), the UNORDERED `selectedTextRange` getter (UIKit
/// gets anchor/head verbatim, not `min`/`max`), and floating-cursor suppression of the setter (the
/// load-bearing invariant that a hold-spacebar gesture owns the caret, and the selection-RANGE writes
/// iOS also pushes through this setter during that gesture must be dropped).
///
/// Adjacent suites own the rest of the mutation shape: prepare/notify/commit/publish ordering is
/// 22b's, revision/rebase safety is 22c's, publication counting is 22d's — this suite only owns
/// selection identity/ordering/floating-cursor gating. `LegacyRichTextInputBackend` had no real
/// `selectedTextRange` body and no floating-cursor state at all before this task; both were added
/// here (see `LegacyRichTextInputBackend.swift` and — since Task 33 routed them —
/// `+FloatingCursor.swift`'s `beginFloatingCursor(at:)`/`endFloatingCursor()`; this citation read
/// `+PendingRouting.swift` until Task 34 renamed that file and repaired the pointer).
///
/// `class`, not `final class` — Task 22a's `BackendContractCases` is subclassed again by stage 2,
/// which overrides ONLY `makeBackend()`. The only place this file names a concrete backend type is
/// that override, below.
@MainActor
@available(iOS 16.0, *)
class BackendSelectionContractTests: BackendContractCases {
    /// **TASK 27b — `ReferenceMutationBackend`, not `LegacyRichTextInputBackend`.** This suite drives
    /// `backend.insertText(…)`, and stage 1's legacy conformer no longer owns that mutation: its
    /// witness is now a plain `legacyCanvas` forward (deviation **D35**, ruled by the user
    /// 2026-08-19), so against it those tests would assert a contract this conformer does not meet.
    /// `ReferenceMutationBackend` (`T/Support/`) is the stage-1 conformer that does: a real
    /// `LegacyRichTextInputBackend` for every OTHER member — every non-mutation test in this file
    /// still exercises exactly the production code it did before, one forward away — carrying the
    /// Task-22b transaction body on `insertText(_:)` and running it through the SAME production
    /// `prepareAndRun`/`runMutation` machinery. **No test body in this file changed.** Stage 2
    /// re-overrides this one method with `IDTextEditorBackend()`, for which the mutation contract is a
    /// first-party obligation.
    ///
    /// Only ONE of this suite's 7 tests drives `insertText`
    /// (`test_legacyBackendNeverEmitsUpstreamAffinity`, which needs a real mutation to prove the
    /// affinity survives one). Under the routed legacy backend that assertion would still PASS while
    /// asserting nothing — the fake host's `legacyCanvas` is a separate canvas, so the state it reads
    /// could not move either way. That is the disarmed-test failure mode the post-routing sweep exists
    /// to catch, which is why the suite moves rather than the line being deleted; the other six tests
    /// are unaffected either way.
    override func makeBackend() -> (any RichTextInputBackend)? {
        ReferenceMutationBackend()
    }

    /// Needed for `test_programmaticSelection_producesTheSameDelegateOrderAsAKeyboardSelection`, which
    /// compares notification/publish ORDER between two selection-setting paths — bypassing canvas
    /// plumbing exactly like `BackendMutationContractTests`/`BackendPublicationContractTests` (this
    /// suite tests the backend in isolation).
    private var delegate: RecordingInputDelegate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        delegate = RecordingInputDelegate(log: log)
        backend.inputDelegate = delegate
    }

    override func tearDownWithError() throws {
        delegate = nil
        try super.tearDownWithError()
    }

    // MARK: - 1. The worked example: DEVIATION D6, no affinity model anywhere in the package

    /// DEVIATION D6: no affinity model exists anywhere in the package, so the legacy backend must
    /// never invent one. Every position it emits is `.downstream`.
    func test_legacyBackendNeverEmitsUpstreamAffinity() {
        backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(7), head: .downstream(2)),
                             reason: .touch)
        let s = backend.state.selection
        XCTAssertEqual(s.anchor.affinity, .downstream)
        XCTAssertEqual(s.head.affinity, .downstream)
        backend.insertText("x")
        XCTAssertEqual(backend.state.selection.head.affinity, .downstream)
    }

    // MARK: - 2. A reversed selection survives setSelection unchanged — no reordering

    /// A reversed selection (head < anchor — a right-to-left drag) must survive `setSelection`
    /// verbatim: `canonicalSelectionStorage = selection` is a plain assignment, never a `min`/`max`
    /// reorder. Companion to `DirectionalSelectionCharacterizationTests`, the same fact pinned against
    /// the real canvas. Anchor (7) and head (2) are chosen to genuinely differ under normalization —
    /// a symmetric pair (e.g. both 5) would make this assertion vacuous.
    ///
    /// RED IF: `setSelection` ever normalized its argument before storing (e.g. always storing the
    /// smaller offset as `anchor`) — `canonicalSelection.anchor.utf16Offset` would then read 2, not 7.
    func test_reversedSelection_survivesSetSelectionRoundTrip() {
        backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(7), head: .downstream(2)),
                             reason: .touch)
        XCTAssertEqual(backend.canonicalSelection.anchor.utf16Offset, 7)
        XCTAssertEqual(backend.canonicalSelection.head.utf16Offset, 2)
        XCTAssertTrue(backend.canonicalSelection.isReversed)
    }

    // MARK: - 3. The selectedTextRange getter hands UIKit an unordered range

    /// Mirrors `DirectionalSelectionCharacterizationTests
    /// .test_selectedTextRangeGetter_isUnorderedForAReversedSelection` (pinned against the real
    /// canvas) — now on the backend's OWN `selectedTextRange` getter. `.start`/`.end`
    /// (`DocumentTextRange.from`/`.to`) must report anchor/head VERBATIM, never `min`/`max` —
    /// `RichTextCanonicalSelection.normalizedRange`'s own doc comment: "the canvas hands UIKit an
    /// unordered range for a reversed drag and that is load-bearing."
    ///
    /// TASK 26 REBASE — the driver changed from `setSelection` to this member's OWN SETTER, and the
    /// reason is load-bearing rather than cosmetic. Task 26 routed `DocumentCanvasView.selectedTextRange`
    /// onto this member, and at that commit the CANVAS was the live authority for `anchor`/`head`
    /// (every canvas selection funnel wrote it directly and never reached `setSelection`), so this
    /// getter had to read the canvas rather than `canonicalSelectionStorage` — otherwise the canvas
    /// witness would hand UIKit a stale caret after any of them; and `setSelection`, which did not
    /// write the canvas, was therefore not a driver that could seed what this getter read.
    ///
    /// **TASK 35 ENDED BOTH CONDITIONS** (the sentences above are kept in the past tense as the
    /// rebase's actual reason, not deleted): the two stores are one, the getter reads
    /// `canonicalSelectionStorage`, and `setSelection` WOULD work as a driver again. The rebase is
    /// kept anyway, and now on stronger ground than staleness — round-tripping through the member's
    /// own setter is: it is backend-agnostic (a stage-2 conformer's setter seeds whatever its own getter
    /// reads), and it strengthens the test — it now covers BOTH halves of the endpoint-identity
    /// property rather than only the read half.
    ///
    /// The offsets stay 7/2 for the same reason as before: a symmetric pair would be vacuous under
    /// normalization. They are within `FakeInputHost.seededTextLength`, so the setter's clamp is
    /// inert here (this test's subject is ordering, not clamping — see test 7's own note).
    ///
    /// RED IF: the getter built its `UITextRange` from `normalizedRange` (or any `min`/`max`) instead
    /// of the two endpoints directly — `.from.offset` would then read 2 (the min), not 7. Equally red
    /// if the SETTER reordered them on the way in.
    func test_selectedTextRangeGetter_handsUIKitAnUnorderedRange_forAReversedSelection() {
        backend.selectedTextRange = DocumentTextRange(DocumentTextPosition(7), DocumentTextPosition(2))
        guard let range = backend.selectedTextRange as? DocumentTextRange else {
            XCTFail("expected a DocumentTextRange"); return
        }
        XCTAssertEqual(range.from.offset, 7, "from must be the ANCHOR, not min()")
        XCTAssertEqual(range.to.offset, 2, "to must be the HEAD, not max()")
        XCTAssertEqual(backend.canonicalSelection.anchor.utf16Offset, 7,
                       "the same write must record the applied ANCHOR in the backend's own canonical " +
                       "store — without this the assertions above could pass on a getter that read a " +
                       "store the setter never touched (Task 26 decision C2: the routed setter has TWO " +
                       "destinations and both must happen)")
        XCTAssertEqual(backend.canonicalSelection.head.utf16Offset, 2)
        XCTAssertTrue(backend.canonicalSelection.isReversed)
    }

    // MARK: - 4. normalizedRange orders the RANGE without destroying the selection's own endpoint identity

    /// `RichTextCanonicalSelection.normalizedRange`'s own doc comment: "MUST NOT be used to reorder
    /// anchor/head." Drives a REAL mutation (`deleteBackward()`, whose `.deleteBackward` case forwards
    /// both the raw `selection` AND a `proposedRange` derived from `normalizedRange` —
    /// `BackendMutationContractTests.test_deleteBackwardWithProposedRange_forwardsTheProposedRangeVerbatim`
    /// pins the non-reversed case) with a REVERSED selection already set, so both fields are visible
    /// at once: `proposedRange` must be ORDERED (`location: 2, length: 5`) while the `selection` field
    /// carries the ORIGINAL, unordered anchor(7)/head(2) — proving the ordering used for the range
    /// shape never leaks back into (or is derived FROM a corrupted) the canonical endpoints.
    ///
    /// RED IF: `deleteBackward()`'s `selection` field ever reflected the ordered range instead of the
    /// raw stored anchor/head (e.g. `RichTextCanonicalSelection(anchor: .downstream(2), head:
    /// .downstream(7))`, silently un-reversing it), or `proposedRange` were left unordered
    /// (`location: 7, length: -5`, which no real `NSRange` can even express without crashing/undefined
    /// behavior downstream).
    func test_normalizedRange_doesNotDestroyEndpointIdentity() {
        backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(7), head: .downstream(2)),
                             reason: .touch)
        log.reset()   // clear setSelection's own publish noise — irrelevant to this test

        backend.deleteBackward()

        guard case .deleteBackward(let selection, let proposedRange) =
            fakeHost!.fakeDocumentClient.receivedMutations.last else {
            XCTFail("expected the last received mutation to be .deleteBackward"); return
        }
        XCTAssertEqual(selection, RichTextCanonicalSelection(anchor: .downstream(7), head: .downstream(2)),
                       "the reversed selection's own anchor/head identity must reach the document " +
                       "client unchanged")
        XCTAssertEqual(proposedRange, NSRange(location: 2, length: 5),
                       "normalizedRange must ORDER the proposedRange without perturbing the selection above")
    }

    // MARK: - 5. Every RichTextSelectionChangeReason reaches publication unchanged

    /// `setSelection`'s `reason: RichTextSelectionChangeReason` (touch/keyboard/floatingCursor/command/
    /// programmatic/externalSynchronization) is accepted UNIFORMLY today — stage 1 has no per-reason
    /// branching, so every one of them reaches the exact SAME publication: one `presentationApply` +
    /// one `lifecyclePublish`, tagged `.selection`. Driven across SEVERAL distinct reasons (not just
    /// one) so a reason-specific special case anywhere couldn't slip through by chance.
    ///
    /// RED IF: a future `setSelection` special-cased any one `RichTextSelectionChangeReason` (e.g.
    /// skipping publication for `.floatingCursor` samples, or tagging `.command` with a different
    /// publish reason) — the per-reason assertions below would then disagree across the loop.
    func test_selectionChangeReason_reachesPublicationUnchanged() {
        let reasons: [RichTextSelectionChangeReason] = [
            .touch, .keyboard, .command, .programmatic, .floatingCursor, .externalSynchronization,
        ]
        for (i, reason) in reasons.enumerated() {
            log.reset()
            backend.setSelection(.caret(at: .downstream(i + 1)), reason: reason)
            XCTAssertEqual(log.kinds, ["presentationApply", "lifecyclePublish"],
                           "reason \(reason) must publish exactly once, unconditionally")
            let publishedReasons = log.events.compactMap { event -> String? in
                if case .lifecyclePublish(_, let r) = event { return r }
                return nil
            }
            XCTAssertEqual(publishedReasons, ["selection"],
                           "reason \(reason) must still tag the publication .selection")
        }
    }

    // MARK: - 6. selectedTextRange's setter is a thin forwarder onto setSelection — same order either way

    /// The `selectedTextRange` SETTER (the OS's keyboard-driven path — cursor-drag/autocorrect) and a
    /// direct `setSelection(_:reason:.programmatic)` call must produce the IDENTICAL notification/
    /// publish ORDER, because the setter (added by this task) is a thin forwarder onto the ONE
    /// whole-selection write — not a second, independently-implemented publish path.
    ///
    /// RED IF: the `selectedTextRange` setter published/notified through any path other than
    /// `setSelection(_:reason:)` — the two recorded orders would then disagree (an extra or missing
    /// `presentationApply`/`lifecyclePublish`, or a delegate call one path has and the other doesn't).
    ///
    /// FIX ROUND 1 (review Minor 8): this equivalence is a STAGE-1 property of today's pure-forwarder
    /// setter, not a contract to defend going forward. Task 26 carries the canvas's OWN setter body in
    /// verbatim (`imageObjectDeletePending`, `finalizeMarkedText()`, `clearStructuralSelections()`,
    /// `dismissEditMenuForSelectionOrTextChange()`, `onSelectionChange?()`) — real side effects a plain
    /// `setSelection(_:reason:.programmatic)` call does not trigger — while `setSelection`'s own
    /// selection-funnel bracket (rows 8-10) still fires and the setter itself must stay delegate-silent
    /// (row 21; see `LegacyRichTextInputBackend.swift`'s Major 1 fix). So the two paths are DESIGNED to
    /// diverge once Task 26 lands; a future reader must not treat this test's equality as something
    /// that should still hold afterward — it is expected to need editing (or retiring) then.
    func test_programmaticSelection_producesTheSameDelegateOrderAsAKeyboardSelection() {
        backend.setSelection(.caret(at: .downstream(4)), reason: .programmatic)
        let programmaticOrder = log.kinds
        log.reset()

        backend.selectedTextRange = DocumentTextRange(DocumentTextPosition(6), DocumentTextPosition(6))
        let keyboardOrder = log.kinds

        XCTAssertEqual(programmaticOrder, keyboardOrder)
        XCTAssertEqual(programmaticOrder, ["presentationApply", "lifecyclePublish"])
    }

    // MARK: - 7. The selectedTextRange setter is ignored while the floating cursor is active

    /// The load-bearing floating-cursor invariant (`DocumentCanvasView+FloatingCursor.swift`'s own
    /// header comment, mirrored onto this backend by this task): during the hold-spacebar gesture, iOS
    /// ALSO pushes selection RANGES (anchored at the gesture-start position) through
    /// `selectedTextRange`'s SETTER; applying them would turn a cursor MOVE into a text SELECTION. So
    /// the setter must ignore writes while `beginFloatingCursor(at:)` is active, and resume accepting
    /// them once `endFloatingCursor()` clears it — contrasted directly (the SAME write, before/after)
    /// so "ignores the write" isn't vacuous.
    ///
    /// Final part pins the new state's teardown (hard-won rule: "if you add state, say what tears it
    /// down and pin that too"): a floating-cursor session left active must not survive
    /// `detach()`/a fresh `attach()` — mirrors `BackendPublicationContractTests`' pending-coalesced-
    /// latch pair for `suppressesSelectionNotifications`, using the fixture's `makeHost(log:)` factory
    /// (R11) rather than constructing `FakeInputHost` directly.
    ///
    /// RED IF: the setter applied a write while the floating cursor was active (the canonical selection
    /// would move to the ignored offset), failed to resume accepting writes after `endFloatingCursor()`
    /// (the contrasting write would ALSO be dropped), or a session left active survived detach/reattach
    /// (the post-reattach write would still be dropped).
    func test_selectedTextRangeSetter_isIgnoredWhileFloatingCursorIsActive() throws {
        backend.setSelection(.caret(at: .downstream(3)), reason: .programmatic)
        let settled = backend.canonicalSelection

        // FIX ROUND 1 (review Minor 6): an in-range offset (5), not a large out-of-range one (the
        // original 50) — this test's subject is floating-cursor SUPPRESSION, not the canvas's own
        // `clamp()` (which this backend's setter does not yet apply — see Task 26's own note on
        // `LegacyRichTextInputBackend.swift`'s `selectedTextRange`). An out-of-range value would pin
        // the ABSENCE of clamping as if it were a guarantee, forcing Task 26 to edit this test when it
        // moves the canvas's clamping body in; an in-range value asserts only what this test means to.
        backend.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        backend.selectedTextRange = DocumentTextRange(DocumentTextPosition(5), DocumentTextPosition(5))
        XCTAssertEqual(backend.canonicalSelection, settled,
                       "a write while the floating cursor owns the caret must be ignored")

        backend.endFloatingCursor()
        backend.selectedTextRange = DocumentTextRange(DocumentTextPosition(5), DocumentTextPosition(5))
        XCTAssertEqual(backend.canonicalSelection.head.utf16Offset, 5,
                       "the SAME write must be accepted once the floating cursor has ended — the " +
                       "contrast that makes the ignored write above non-vacuous")

        backend.beginFloatingCursor(at: CGPoint(x: 1, y: 1))
        backend.detach()

        let freshHost = makeHost(log: log)
        try backend.attach(to: freshHost)
        withExtendedLifetime(freshHost) {
            log.reset()   // discard this attach's own lifecycleDidAttach noise
            backend.selectedTextRange = DocumentTextRange(DocumentTextPosition(9), DocumentTextPosition(9))
            XCTAssertEqual(backend.canonicalSelection.head.utf16Offset, 9,
                           "a fresh attach must not inherit a stuck floating-cursor session from the " +
                           "previous one — the write above would otherwise still be dropped")
        }
    }
}
#endif
