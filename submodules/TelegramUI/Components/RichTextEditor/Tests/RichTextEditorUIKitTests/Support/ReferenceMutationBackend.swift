#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

/// TASK 27b — the test-only **reference conformer** for the document-mutation contract.
///
/// # Why this type exists
///
/// The eight `BackendContractCases` suites pin a MUTATION CONTRACT: a mutation entry point prepares
/// against the document client, brackets the four `UITextInputDelegate` notifications, commits, adopts
/// the result, and publishes exactly once. **Stage 1's `LegacyRichTextInputBackend` does not satisfy
/// that contract and cannot be made to** — Task 27 measured both halves (deviation **D35**): routing
/// `DocumentCanvasView.insertText(_:)` onto a `prepareAndRun` body makes typing a silent no-op (the
/// backend's `documentRevision`/`canonicalSelectionStorage` lagged the canvas until Task 35 — which
/// collapsed the SELECTION half of that lag but not the revision half, so the measurement stands),
/// and even
/// with that repaired, `runMutation`'s FIXED four-notification bracket cannot reproduce the witness's
/// PER-BRANCH one. The user ruled Option A on 2026-08-19: the legacy witness becomes a plain
/// `legacyCanvas` forward, and **the mutation contract as written describes stage 2.**
///
/// So the contract needs a stage-1 conformer that DOES own its mutations. This is that conformer. It
/// is not a second backend: it is a `LegacyRichTextInputBackend` **plus four members** — `insertText(_:)`
/// and `deleteBackward()` (Tasks 27b/28) plus `setMarkedText(_:selectedRange:)` and `markedTextRange`
/// (Task 29). The count said "two" until Task 30's stale-reference sweep found it: Task 29 added its two
/// and updated the paragraphs below without updating this sentence. R18's `referenceConformerNonForwards`
/// allow-list is the authoritative list; keep this number in step with it.
///
/// # The shape, and why it is not a strawman validating itself
///
/// Every member below except those four is a **pure forward to `inner`**,
/// a real `LegacyRichTextInputBackend`. So a suite pointed at this conformer still exercises the
/// production backend for attach/detach, selection, publication, marked text, transactions, reentrancy
/// and the delegate emitters — nothing about those tests changes except one hop of indirection.
///
/// Neither mutation member is re-implemented either. Each body is the one Task 22b wrote, moved
/// verbatim from `LegacyRichTextInputBackend+Mutation.swift` (Task 27b moved `insertText(_:)`, TASK 28
/// moved `deleteBackward()`), and each runs through **production** machinery:
/// `inner.prepareAndRun(document:host:build:)` → the reentrancy guard, the edit-policy gate,
/// `ensureCanonicalSelectionIsCurrent`, `runMutation`'s prepare/notify/commit/adopt/notify/publish
/// bracket. The only code this file owns is the two mutation BUILDERS. Everything the mutation
/// suites assert — ordering, exactly-one-commit, revision adoption, rejection channels, publication —
/// is therefore still an assertion about `LegacyRichTextInputBackend`'s own machinery, not about a
/// fixture that agrees with itself by construction.
///
/// What legitimately moved with the bodies is the small part that was never the legacy conformer's:
/// deciding that a keystroke becomes a `.insertText` mutation carrying the caret's typing attributes,
/// and that a Backspace becomes a `.deleteBackward` mutation carrying the current selection as its own
/// proposed range. That is what a mutation-owning backend does, and stage 1's does not.
///
/// # How a suite gets one, and what stage 2 does
///
/// A `BackendContractCases` subclass returns `ReferenceMutationBackend()` from `makeBackend()` — the
/// one place rule **R10** permits naming a concrete conformer. **No test body changed**: the suites
/// still drive `backend.insertText(…)` through `any RichTextInputBackend`. In stage 2 those same
/// `makeBackend()` overrides are re-overridden to return `IDTextEditorBackend()`, for which the
/// mutation contract is a genuine, first-party obligation — at which point this conformer stops being
/// consulted for that backend's run of the suite. Nothing about this type is inherited by stage 2, so
/// it is `final` (unlike the suites themselves, which must never be).
///
/// # Scope
///
/// **`insertText(_:)` and `deleteBackward()`** — the whole of `RichTextKeyInputBackend` except
/// `hasText`, a pure read that stays a forward. TASK 28 added the second, and it needed no factory
/// change and no test-body change at all: its only two drive points
/// (`BackendMutationContractTests.test_deleteBackwardWithProposedRange_forwardsTheProposedRangeVerbatim`
/// and `BackendSelectionContractTests.test_normalizedRange_doesNotDestroyEndpointIdentity`) already sat
/// in suites Task 27b had moved here for `insertText`.
///
/// **TASK 29 added `setMarkedText(_:selectedRange:)` and `markedTextRange`, and it DID need a factory
/// change** — the open question above, measured and answered. Those two are not mutation builders: they
/// are the STORAGE-ONLY bodies Task 22f wrote on `LegacyRichTextInputBackend` ahead of schedule, moved
/// here verbatim when Task 29 replaced them with the real `legacyCanvas` forward. They read and write
/// **`inner.markedRangeStorage`** rather than a field of this conformer's own, and that is
/// load-bearing, not incidental: the policy this suite actually tests is
/// `reconcileMarkedTextForExternalChange`, which is `private` on `LegacyRichTextInputBackend` and reads
/// `markedRangeStorage`. A conformer that kept marked state of its own would have the test writing one
/// store while the policy read another — every "after" assertion green for the wrong reason, or red.
/// `synchronizeAfterExternalChange` therefore stays a plain forward to `inner`, reaching that private
/// policy from inside the class, which is exactly what is wanted.
///
/// Exactly ONE suite moved: `BackendMarkedTextPolicyTests` (11 tests, 12 `backend.setMarkedText` and 14
/// `backend.markedTextRange` drive points), whose `makeBackend()` now returns this type. Measured, not
/// assumed — the other two suites still on a bare `LegacyRichTextInputBackend()` do not drive either
/// member (`FakeClientSelfTests`' five `unmarkText` hits are the mutation ENUM CASE passed to
/// `doc.prepareMutation`; `BackendAttachDetachTests`' single `setMarkedText` hit is inside a doc
/// comment), and the two suites that DO drive `backend.setMarkedText`
/// (`BackendReentrancyTests.test_detachFromInsideAPreserveIfRebasableRebaseCallout_stillLatchesToTheBoundary`,
/// plus `BackendEditPolicyTests`' prose) were already here for `insertText`. **No test body changed**,
/// exactly as 27b's precedent predicted.
///
/// `@available(iOS 13.0, *)`, matching `LegacyRichTextInputBackend` itself rather than the iOS-16
/// fakes/spy — it adds no API of its own, and `BackendAttachmentTests` (a 13.0 suite) constructs one.
@MainActor
@available(iOS 13.0, *)
final class ReferenceMutationBackend: RichTextInputBackend {

    /// The real backend every member but `insertText(_:)`/`deleteBackward()` forwards to. Exposed (not
    /// `private`) for the
    /// one test that has to reach a legacy-only internal on the SUBJECT of its assertion — see
    /// `BackendAttachmentTests`' leaked-transaction-depth test, which simulates the leak on `inner`
    /// and then drives two mutations through this conformer. A `BackendContractCases` subclass may not
    /// reach it: R10 forbids naming this type outside `makeBackend()`, so no contract suite can.
    let inner: LegacyRichTextInputBackend

    /// Every contract suite uses this form: a fresh, unattached backend, exactly what the previous
    /// `makeBackend()` bodies handed back.
    ///
    /// (Two inits rather than one defaulted parameter: a default argument is evaluated in a
    /// non-isolated context, so `= LegacyRichTextInputBackend()` does not compile against the
    /// `@MainActor` class — the compiler catches it, but the two-init shape says why.)
    init() {
        self.inner = LegacyRichTextInputBackend()
    }

    /// `wrapping:` exists for the same single caller as `inner` above — a test that already holds the
    /// canvas's own backend and needs the reference `insertText` on THAT instance rather than a fresh
    /// one, so the assertion's subject stays that canvas's backend.
    init(wrapping inner: LegacyRichTextInputBackend) {
        self.inner = inner
    }

    // MARK: - The four members that are not forwards

    /// MOVED VERBATIM from `LegacyRichTextInputBackend+Mutation.swift` by Task 27b, including its
    /// deviation note. Nothing about the body changed; only its home did.
    ///
    /// Deviation D25: reads `document.typingAttributes(at:)` FRESH on every call (no backend-side
    /// cache) so freshly-typed plain text picks up the caret's current inline formatting, exactly
    /// like a real text view's typing attributes.
    func insertText(_ text: String) {
        guard inner.isAttached, let host = inner.host, let document = inner.document else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        inner.prepareAndRun(document: document, host: host) {
            let typingAttributes = document.typingAttributes(at: inner.canonicalSelectionStorage.head)
            let attributedText = NSAttributedString(string: text, attributes: typingAttributes)
            return RichTextInputMutation.insertText(
                text: attributedText, replacing: inner.canonicalSelectionStorage,
                origin: .softwareKeyboard)
        }
    }

    /// MOVED VERBATIM from `LegacyRichTextInputBackend+Mutation.swift` by Task 28, including its
    /// deviation note. Nothing about the body changed; only its home did — and with it, the
    /// `"operation on a detached backend"` report, which now belongs to this conformer rather than to
    /// the routed legacy member (which drops silently, like every other OS-driven witness).
    ///
    /// The member carries no explicit range, so the "proposed range" the document client's
    /// `.deleteBackward` case wants is synthesized from the backend's OWN current selection —
    /// forwarded verbatim as both `selection` and `proposedRange` (not independently derived).
    func deleteBackward() {
        guard inner.isAttached, let host = inner.host, let document = inner.document else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        inner.prepareAndRun(document: document, host: host) {
            RichTextInputMutation.deleteBackward(
                selection: inner.canonicalSelectionStorage,
                proposedRange: inner.canonicalSelectionStorage.normalizedRange)
        }
    }

    // MARK: - RichTextInputBackend composite surface — pure forwards, all the way down

    var state: RichTextInputStateSnapshot { inner.state }
    var isAttached: Bool { inner.isAttached }

    func attach(to host: any RichTextInputHost) throws { try inner.attach(to: host) }
    func detach() { inner.detach() }

    func synchronizeAfterExternalChange(_ change: RichTextInputExternalChange) {
        inner.synchronizeAfterExternalChange(change)
    }

    func setSelection(_ selection: RichTextCanonicalSelection, reason: RichTextSelectionChangeReason) {
        inner.setSelection(selection, reason: reason)
    }

    var canonicalSelection: RichTextCanonicalSelection { inner.canonicalSelection }
    var canonicalSelectionAnchorOffset: Int { inner.canonicalSelectionAnchorOffset }
    var canonicalSelectionHeadOffset: Int { inner.canonicalSelectionHeadOffset }
    func setCanonicalAnchor(_ utf16Offset: Int) { inner.setCanonicalAnchor(utf16Offset) }
    func setCanonicalHead(_ utf16Offset: Int) { inner.setCanonicalHead(utf16Offset) }
    func clearCompositionState() { inner.clearCompositionState() }

    // TASK 41 — composition state. Plain `inner.…` forwards, as R18 requires of every member not on
    // its allow-list: the bodies under test are `LegacyRichTextInputBackend`'s.
    var markedRange: NSRange? { inner.markedRange }
    var isComposingPrediction: Bool { inner.isComposingPrediction }
    var isComposing: Bool { inner.isComposing }
    var compositionSnapshot: RichTextCompositionSnapshot? { inner.compositionSnapshot }
    func setCompositionMarkedRange(_ range: NSRange?, isPrediction: Bool) {
        inner.setCompositionMarkedRange(range, isPrediction: isPrediction)
    }
    func setCompositionSnapshot(_ snapshot: RichTextCompositionSnapshot?) {
        inner.setCompositionSnapshot(snapshot)
    }

    var suppressesSelectionNotifications: Bool {
        get { inner.suppressesSelectionNotifications }
        set { inner.suppressesSelectionNotifications = newValue }
    }

    func notifyingContentAndSelectionChange(_ body: () -> Void) {
        inner.notifyingContentAndSelectionChange(body)
    }
    func notifyingSelectionChange(_ body: () -> Void) { inner.notifyingSelectionChange(body) }
    func notifyingSelectionChangeIgnoringCoalescing(_ body: () -> Void) {
        inner.notifyingSelectionChangeIgnoringCoalescing(body)
    }
    func notifyingContentChange(_ body: () -> Void) { inner.notifyingContentChange(body) }
    func notifyCoalescedSelectionResync() { inner.notifyCoalescedSelectionResync() }

    // MARK: - RichTextInputTextBackend

    var inputDelegate: UITextInputDelegate? {
        get { inner.inputDelegate }
        set { inner.inputDelegate = newValue }
    }

    var tokenizer: UITextInputTokenizer { inner.tokenizer }

    var selectedTextRange: UITextRange? {
        get { inner.selectedTextRange }
        set { inner.selectedTextRange = newValue }
    }

    /// MOVED VERBATIM from `LegacyRichTextInputBackend.swift`'s "Marked text (TASK 22f…)" section by
    /// TASK 29, when the real member became a `legacyCanvas` forward that reads the CANVAS's
    /// `markedRange`. Reads `inner.markedRangeStorage` — see this type's Scope section for why the
    /// store matters.
    var markedTextRange: UITextRange? {
        guard let m = inner.markedRangeStorage else { return nil }
        return DocumentTextRange(DocumentTextPosition(m.location), DocumentTextPosition(m.location + m.length))
    }

    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get { inner.markedTextStyle }
        set { inner.markedTextStyle = newValue }
    }

    var beginningOfDocument: UITextPosition { inner.beginningOfDocument }
    var endOfDocument: UITextPosition { inner.endOfDocument }

    func text(in range: UITextRange) -> String? { inner.text(in: range) }

    func replace(_ range: UITextRange, withText text: String) {
        inner.replace(range, withText: text)
    }

    /// MOVED VERBATIM from `LegacyRichTextInputBackend.swift`'s "Marked text (TASK 22f…)" section by
    /// TASK 29, including its `guard transactionPhase == .idle` member-level reentrancy guard (Task 26)
    /// and its `.markedText`-reasoned publish (22f fix round 1). Nothing about the body changed; only
    /// its home did — and with it the `"operation on a detached backend"` report, which now belongs to
    /// this conformer rather than to the routed legacy member (which drops silently, like every other
    /// routed witness).
    ///
    /// Storage-only and DELIBERATELY MINIMAL, as 22f's own header said: it mirrors the ONE fact the
    /// marked-text policy suite needs from the real canvas — the marked range replaces the prior
    /// composition (or the current selection, on the first keystroke of a run) and grows/shrinks with
    /// the composing text's length. It inserts no provisional text, brackets no delegate notification,
    /// registers no undo, applies no body-paragraph guard and draws no prediction-vs-composition
    /// distinction. **That is what the real forward does now** (`LegacyRichTextInputBackend+MarkedText.swift`
    /// → `DocumentCanvasView.legacySetMarkedText`); this is the fixture the contract is pinned against.
    func setMarkedText(_ text: String?, selectedRange: NSRange) {
        guard inner.isAttached else {
            RichTextInputContractViolation.report("operation on a detached backend: \(#function)")
            return
        }
        // Mirrors `DocumentCanvasView.legacySetMarkedText`'s own `lo` derivation: the range being
        // replaced is an existing composition's START, else the live (collapsed-or-not) selection's
        // start.
        let base = inner.markedRangeStorage?.location ?? inner.canonicalSelectionStorage.normalizedRange.location
        let newLength = (text ?? "").utf16.count
        inner.markedRangeStorage = newLength == 0 ? nil : NSRange(location: base, length: newLength)
        // TASK 26 — member-level reentrancy, the same shape as `setSelection`: the storage write
        // happens, the bracket is skipped, the outer publish carries it.
        guard inner.transactionPhase == .idle else { return }
        inner.withTransaction {
            inner.transactionPhase = .publishingState
            inner.publishState(reason: .markedText)
        }
    }

    func unmarkText() { inner.unmarkText() }

    func textRange(from: UITextPosition, to: UITextPosition) -> UITextRange? {
        inner.textRange(from: from, to: to)
    }

    func position(from: UITextPosition, offset: Int) -> UITextPosition? {
        inner.position(from: from, offset: offset)
    }

    func position(from: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        inner.position(from: from, in: direction, offset: offset)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        inner.compare(position, to: other)
    }

    func offset(from: UITextPosition, to other: UITextPosition) -> Int {
        inner.offset(from: from, to: other)
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        inner.position(within: range, farthestIn: direction)
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        inner.characterRange(byExtending: position, in: direction)
    }

    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        inner.baseWritingDirection(for: position, in: direction)
    }

    func setBaseWritingDirection(_ direction: NSWritingDirection, for range: UITextRange) {
        inner.setBaseWritingDirection(direction, for: range)
    }

    func firstRect(for range: UITextRange) -> CGRect { inner.firstRect(for: range) }
    func caretRect(for position: UITextPosition) -> CGRect { inner.caretRect(for: position) }
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { inner.selectionRects(for: range) }
    func closestPosition(to point: CGPoint) -> UITextPosition? { inner.closestPosition(to: point) }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        inner.closestPosition(to: point, within: range)
    }

    func characterRange(at point: CGPoint) -> UITextRange? { inner.characterRange(at: point) }

    func textStyling(at position: UITextPosition, in direction: UITextStorageDirection) -> [NSAttributedString.Key: Any]? {
        inner.textStyling(at: position, in: direction)
    }

    func insertDictationResult(_ dictationResult: [UIDictationPhrase]) {
        inner.insertDictationResult(dictationResult)
    }

    // MARK: - RichTextKeyInputBackend (`insertText(_:)`/`deleteBackward()` are above)

    var hasText: Bool { inner.hasText }

    // MARK: - RichTextInputResponderBackend

    var canBecomeFirstResponder: Bool { inner.canBecomeFirstResponder }
    var canResignFirstResponder: Bool { inner.canResignFirstResponder }

    func hostWillBecomeFirstResponder() { inner.hostWillBecomeFirstResponder() }
    func hostDidBecomeFirstResponder() { inner.hostDidBecomeFirstResponder() }
    func hostDidFailToBecomeFirstResponder() { inner.hostDidFailToBecomeFirstResponder() }
    func hostWillResignFirstResponder() { inner.hostWillResignFirstResponder() }
    func hostDidResignFirstResponder() { inner.hostDidResignFirstResponder() }
    func hostDidFailToResignFirstResponder() { inner.hostDidFailToResignFirstResponder() }

    func hostWillMove(toWindow window: UIWindow?) { inner.hostWillMove(toWindow: window) }
    func editPolicyDidChange() { inner.editPolicyDidChange() }
    func textInputTraitsDidChange() { inner.textInputTraitsDidChange() }

    var isEditableForWritingTools: Bool { inner.isEditableForWritingTools }

    func canPerformCommand(_ command: RichTextInputCommand, sender: Any?) -> Bool {
        inner.canPerformCommand(command, sender: sender)
    }

    func performCommand(_ command: RichTextInputCommand, sender: Any?) {
        inner.performCommand(command, sender: sender)
    }
    var undoManager: UndoManager? { inner.undoManager }

    // MARK: - RichTextInputInteractionBackend

    func installInteractions() { inner.installInteractions() }
    func removeInteractions() { inner.removeInteractions() }
    func viewportDidChange() { inner.viewportDidChange() }
    func layoutDidChange(generation: UInt64) { inner.layoutDidChange(generation: generation) }
    var floatingCursorActive: Bool { inner.floatingCursorActive }
    var floatingCursorPoint: CGPoint { inner.floatingCursorPoint }
    var floatingScrollVelocity: CGFloat { inner.floatingScrollVelocity }
    func setFloatingCursorActive(_ active: Bool) { inner.setFloatingCursorActive(active) }
    func setFloatingCursorPoint(_ point: CGPoint) { inner.setFloatingCursorPoint(point) }
    func setFloatingScrollVelocity(_ velocity: CGFloat) { inner.setFloatingScrollVelocity(velocity) }
    func beginFloatingCursor(at point: CGPoint) { inner.beginFloatingCursor(at: point) }
    func updateFloatingCursor(at point: CGPoint) { inner.updateFloatingCursor(at: point) }
    func endFloatingCursor() { inner.endFloatingCursor() }

    func cancelActiveInteraction(reason: RichTextInteractionCancellationReason) {
        inner.cancelActiveInteraction(reason: reason)
    }

    // MARK: - RichTextInputCheckingBackend (Task 34, deviation D37)
    //
    // Plain delegation, like every other non-mutation member: this conformer diverges from
    // `LegacyRichTextInputBackend` ONLY on the members whose Task-22b/22f bodies it carries.

    func installCheckingIfNeeded() { inner.installCheckingIfNeeded() }
    func checkOnSelectionChange() { inner.checkOnSelectionChange() }
}
#endif
