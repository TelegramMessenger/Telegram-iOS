#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// A no-op `UITextInputTokenizer` for `SpyBackend`'s `tokenizer` witness — nothing in this suite reads
/// a real tokenization result, so a full `UITextInputStringTokenizer` (which needs a real `UITextInput`
/// host) would be pure ceremony.
@available(iOS 13.0, *)
private final class NoOpTokenizer: NSObject, UITextInputTokenizer {
    func rangeEnclosingPosition(_ position: UITextPosition, with granularity: UITextGranularity, inDirection direction: UITextDirection) -> UITextRange? { nil }
    func isPosition(_ position: UITextPosition, atBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool { false }
    func position(from position: UITextPosition, toBoundary granularity: UITextGranularity, inDirection direction: UITextDirection) -> UITextPosition? { nil }
    func isPosition(_ position: UITextPosition, withinTextUnit granularity: UITextGranularity, inDirection direction: UITextDirection) -> Bool { false }
}

/// A full, independent `RichTextInputBackend` conformer used ONLY to test the canvas's injection seam
/// (`DocumentCanvasView(inputBackend:)`) and attach atomicity — NOT `LegacyRichTextInputBackend`. It
/// must implement the whole ~50-member contract because the protocol has no default witnesses.
@available(iOS 13.0, *)
@MainActor
private final class SpyBackend: RichTextInputBackend {
    var isAttached = false
    var attachError: Error?
    var didAttachCount = 0
    /// Only ever set on the (never-reached, in these tests) success path — proves a throwing
    /// `attach(to:)` touched nothing on the host before throwing.
    var presentationApplyObserved = false
    weak var capturedHost: (any RichTextInputHost)?

    func attach(to host: any RichTextInputHost) throws {
        if let attachError { throw attachError }
        capturedHost = host
        isAttached = true
        didAttachCount += 1
    }
    func detach() { isAttached = false }
    func synchronizeAfterExternalChange(_ change: RichTextInputExternalChange) {}
    func setSelection(_ selection: RichTextCanonicalSelection, reason: RichTextSelectionChangeReason) {}

    var state: RichTextInputStateSnapshot {
        RichTextInputStateSnapshot(documentRevision: 0, selection: .caret(at: .downstream(0)), markedRange: nil, isComposing: false)
    }
    /// TASK 35 — real storage, for the reason spelled out in full on `SpyRichTextInputBackend`
    /// (`T/Support/`): `DocumentCanvasView.anchor`/`.head` are forwarders onto these members now, and
    /// three tests in this file install this spy in a real canvas.
    var canonicalSelectionStorage: RichTextCanonicalSelection = .caret(at: .downstream(0))
    var canonicalSelection: RichTextCanonicalSelection { canonicalSelectionStorage }
    var canonicalSelectionAnchorOffset: Int { canonicalSelectionStorage.anchor.utf16Offset }
    var canonicalSelectionHeadOffset: Int { canonicalSelectionStorage.head.utf16Offset }
    func setCanonicalAnchor(_ utf16Offset: Int) {
        canonicalSelectionStorage.anchor = .downstream(utf16Offset)
    }
    func setCanonicalHead(_ utf16Offset: Int) {
        canonicalSelectionStorage.head = .downstream(utf16Offset)
    }
    func clearCompositionState() { markedRangeStorage = nil; markedTextIsPredictionStorage = false }
    /// TASK 41 — real storage, same reason as `canonicalSelectionStorage` above: three tests in this
    /// file install this spy in a REAL canvas, whose `markedRange` is now a projection of it.
    var markedRangeStorage: NSRange?
    var markedTextIsPredictionStorage = false
    var compositionSnapshotStorage: RichTextCompositionSnapshot?
    var markedRange: NSRange? { markedRangeStorage }
    var isComposingPrediction: Bool { markedRangeStorage != nil && markedTextIsPredictionStorage }
    var isComposing: Bool { markedRangeStorage != nil }
    var compositionSnapshot: RichTextCompositionSnapshot? { compositionSnapshotStorage }
    func setCompositionMarkedRange(_ range: NSRange?, isPrediction: Bool) {
        if let range, range.length > 0 {
            markedRangeStorage = range; markedTextIsPredictionStorage = isPrediction
        } else {
            markedRangeStorage = nil; markedTextIsPredictionStorage = false
        }
    }
    func setCompositionSnapshot(_ snapshot: RichTextCompositionSnapshot?) {
        compositionSnapshotStorage = snapshot
    }
    /// TASK 42 — real storage, same reason as the two blocks above: this spy is installed in a REAL
    /// canvas whose `floatingCursorActive`/`floatingCursorPoint`/`floatingScrollVelocity` are now
    /// projections of it.
    var floatingCursorActive = false
    var floatingCursorPoint: CGPoint = .zero
    var floatingScrollVelocity: CGFloat = 0
    func setFloatingCursorActive(_ active: Bool) { floatingCursorActive = active }
    func setFloatingCursorPoint(_ point: CGPoint) { floatingCursorPoint = point }
    func setFloatingScrollVelocity(_ velocity: CGFloat) { floatingScrollVelocity = velocity }
    var suppressesSelectionNotifications: Bool = false
    // Task 26's five delegate brackets: run the body, notify nothing (this spy has no delegate).
    func notifyingContentAndSelectionChange(_ body: () -> Void) { body() }
    func notifyingSelectionChange(_ body: () -> Void) { body() }
    func notifyingSelectionChangeIgnoringCoalescing(_ body: () -> Void) { body() }
    func notifyingContentChange(_ body: () -> Void) { body() }
    func notifyCoalescedSelectionResync() {}

    // RichTextInputTextBackend
    var inputDelegate: UITextInputDelegate?
    var tokenizer: UITextInputTokenizer { NoOpTokenizer() }
    var selectedTextRange: UITextRange?
    var markedTextRange: UITextRange? { nil }
    var markedTextStyle: [NSAttributedString.Key: Any]?
    var beginningOfDocument: UITextPosition { DocumentTextPosition(0) }
    var endOfDocument: UITextPosition { DocumentTextPosition(0) }
    func text(in range: UITextRange) -> String? { nil }
    func replace(_ range: UITextRange, withText text: String) {}
    func setMarkedText(_ text: String?, selectedRange: NSRange) {}
    func unmarkText() {}
    func textRange(from: UITextPosition, to: UITextPosition) -> UITextRange? { nil }
    func position(from: UITextPosition, offset: Int) -> UITextPosition? { nil }
    func position(from: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? { nil }
    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult { .orderedSame }
    func offset(from: UITextPosition, to other: UITextPosition) -> Int { 0 }
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? { nil }
    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? { nil }
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection { .natural }
    func setBaseWritingDirection(_ direction: NSWritingDirection, for range: UITextRange) {}
    func firstRect(for range: UITextRange) -> CGRect { .zero }
    func caretRect(for position: UITextPosition) -> CGRect { .zero }
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [] }
    func closestPosition(to point: CGPoint) -> UITextPosition? { nil }
    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? { nil }
    func characterRange(at point: CGPoint) -> UITextRange? { nil }
    func textStyling(at position: UITextPosition, in direction: UITextStorageDirection) -> [NSAttributedString.Key: Any]? { nil }
    func insertDictationResult(_ dictationResult: [UIDictationPhrase]) {}

    // RichTextKeyInputBackend
    var hasText: Bool { false }
    func insertText(_ text: String) {}
    func deleteBackward() {}

    // RichTextInputResponderBackend
    var canBecomeFirstResponder: Bool { false }
    var canResignFirstResponder: Bool { false }
    func hostWillBecomeFirstResponder() {}
    func hostDidBecomeFirstResponder() {}
    func hostDidFailToBecomeFirstResponder() {}
    func hostWillResignFirstResponder() {}
    func hostDidResignFirstResponder() {}
    func hostDidFailToResignFirstResponder() {}
    func hostWillMove(toWindow window: UIWindow?) {}
    func editPolicyDidChange() {}
    func textInputTraitsDidChange() {}
    var isEditableForWritingTools: Bool { false }
    func canPerformCommand(_ command: RichTextInputCommand, sender: Any?) -> Bool { false }
    func performCommand(_ command: RichTextInputCommand, sender: Any?) {}
    var undoManager: UndoManager? { nil }

    // RichTextInputInteractionBackend
    func installInteractions() {}
    func removeInteractions() {}
    func viewportDidChange() {}
    func layoutDidChange(generation: UInt64) {}
    func beginFloatingCursor(at point: CGPoint) {}
    func updateFloatingCursor(at point: CGPoint) {}
    func endFloatingCursor() {}
    func cancelActiveInteraction(reason: RichTextInteractionCancellationReason) {}

    // RichTextInputCheckingBackend (Task 34, deviation D37)
    func installCheckingIfNeeded() {}
    func checkOnSelectionChange() {}
}

// MARK: - Fakes for a `LegacyRichTextInputHost` that is NOT `DocumentCanvasView`
//
// These exist only to let `test_detachRunsTheNineStepsInOrder` and
// `test_detachRequestedDuringAMutationIsDeferredToTheTransactionBoundary` observe ordering across
// BOTH the backend's own internal stub calls (`cancelActiveInteraction`, `removeInteractions`,
// recorded into the shared `LegacyRichTextInputBackend.pendingRoutingCalls` by `pendingRouting`) and
// the host's client calls (`tearDownPresentation`, `backendWillDetach`, `apply`) — so both fakes below
// append into that SAME shared, module-accessible (`@testable import`) static array, giving one
// single, orderable timeline.

@available(iOS 13.0, *)
private final class FakeDocumentClient: RichTextInputDocumentClient {
    var revision: UInt64 = 0
    var utf16Length: Int = 0
    func plainText(in range: NSRange) -> String? { nil }
    func attributedText(in range: NSRange) -> NSAttributedString? { nil }
    func typingAttributes(at position: RichTextInputPosition) -> [NSAttributedString.Key: Any] { [:] }
    func clamp(_ position: RichTextInputPosition) -> RichTextInputPosition { position }
    func isValidInsertionPosition(_ position: RichTextInputPosition) -> Bool { true }
    func rebase(_ position: RichTextInputPosition, fromRevision: UInt64) -> RichTextInputPosition? { position }
    func prepareMutation(_ mutation: RichTextInputMutation, expectedRevision: UInt64) -> RichTextInputMutationPreparation {
        .terminal(RichTextInputMutationResult(disposition: .noChange, revision: revision,
                                               selection: .caret(at: .downstream(0)), markedRange: nil,
                                               affectedRange: nil, contentChanged: false, selectionChanged: false,
                                               legacyConservativePreparation: true))
    }
    func commitPreparedMutation(_ prepared: RichTextInputPreparedMutation) -> RichTextInputMutationResult {
        RichTextInputMutationResult(disposition: .noChange, revision: revision, selection: .caret(at: .downstream(0)),
                                     markedRange: nil, affectedRange: nil, contentChanged: false,
                                     selectionChanged: false, legacyConservativePreparation: true)
    }
}

@available(iOS 13.0, *)
private final class FakeGeometryClient: RichTextInputGeometryClient {
    var layoutGeneration: UInt64 = 0
    func caretGeometry(at position: RichTextInputPosition, revision: UInt64, purpose: RichTextInputGeometryPurpose) -> RichTextInputCaretGeometry? { nil }
    func closestPosition(to point: CGPoint, within range: NSRange?, revision: UInt64, purpose: RichTextInputGeometryPurpose) -> RichTextInputPosition? { nil }
    func characterRange(at point: CGPoint, revision: UInt64) -> NSRange? { nil }
    func lineRange(enclosing position: RichTextInputPosition, revision: UInt64) -> (range: NSRange, resolvedAffinity: RichTextInputAffinity)? { nil }
    func navigate(from position: RichTextInputPosition, direction: RichTextInputLayoutDirection, offset: Int, anchorPositionOffset: CGFloat?, revision: UInt64) -> RichTextInputNavigationResult? { nil }
    func firstRect(for range: NSRange, revision: UInt64, purpose: RichTextInputGeometryPurpose) -> CGRect? { nil }
    func selectionSegments(for request: RichTextInputSelectionGeometryRequest, revision: UInt64) -> [RichTextInputSelectionSegment]? { nil }
    func baseWritingDirection(at position: RichTextInputPosition, revision: UInt64) -> RichTextInputWritingDirection { .leftToRight }
}

@available(iOS 13.0, *)
private final class FakeAnnotationClient: RichTextInputAnnotationClient {
    func annotatedSubstring(in range: NSRange, revision: UInt64) -> NSAttributedString? { nil }
    func annotationValue(for key: AnyHashable, at position: RichTextInputPosition, revision: UInt64) -> Any? { nil }
    func addAnnotation(key: AnyHashable, value: Any, range: NSRange, revision: UInt64) -> Bool { false }
    func removeAnnotation(key: AnyHashable, range: NSRange, revision: UInt64) -> Bool { false }
    func addRenderingAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange, revision: UInt64) -> Bool { false }
    func removeRenderingAttributes(_ keys: [NSAttributedString.Key], range: NSRange, revision: UInt64) -> Bool { false }
    func invalidateTemporaryAttributes(in range: NSRange, revision: UInt64) {}
}

@available(iOS 13.0, *)
private final class FakePresentationClient: RichTextInputPresentationClient {
    let containerView = UIView()
    var visibleBounds: CGRect = .zero
    func apply(_ snapshot: RichTextInputPresentationSnapshot) {
        LegacyRichTextInputBackend.pendingRoutingCalls.append("presentationApply")
    }
    func invalidate(_ invalidation: RichTextInputPresentationInvalidation) {}
    func requestReveal(_ target: RichTextInputRevealTarget, animated: Bool) {}
    func dismissEditMenu(reason: RichTextInputEditMenuDismissReason) {}
    var interactionContainerView: UIView { containerView }
    func tearDownPresentation() {
        LegacyRichTextInputBackend.pendingRoutingCalls.append("tearDownPresentation")
    }
}

@available(iOS 13.0, *)
private final class FakeLifecycleClient: RichTextInputLifecycleClient {
    var editPolicy: RichTextInputEditPolicy = .legacyUnrestricted
    /// Fires from inside `backendDidPublishState` — lets a test drive a reentrant `detach()` call
    /// from within an in-flight publish, exactly like a real facade callback could.
    var onDidPublishState: (() -> Void)?
    func backendDidAttach() {
        LegacyRichTextInputBackend.pendingRoutingCalls.append("backendDidAttach")
    }
    func backendWillDetach() {
        LegacyRichTextInputBackend.pendingRoutingCalls.append("backendWillDetach")
    }
    func backendWillBeginEditing() -> Bool { true }
    func backendDidBeginEditing() {}
    func backendShouldEndEditing() -> Bool { true }
    func backendDidEndEditing() {}
    func backendDidPublishState(_ state: RichTextInputStateSnapshot, reason: RichTextInputStateChangeReason) {
        LegacyRichTextInputBackend.pendingRoutingCalls.append("lifecyclePublish")
        onDidPublishState?()
    }
    func backendDidRejectMutation(_ mutation: RichTextInputMutation, reason: RichTextInputMutationRejection) {}
    func backendRequiresLayout(for range: NSRange?, reason: RichTextInputLayoutRequestReason) {}
}

/// TASK 30 — a pasteboard double for the command family's detached-drop test. Duplicated rather than
/// shared on this target's standing per-file-isolation convention (four other copies exist), NOT because
/// the siblings are unreachable — **FIX ROUND 1, Min-6: they are internal, and the original wording here
/// claimed otherwise.** See `CommandRouterTests.FakePasteboard`'s note for the full account. This one is
/// `private` because it is genuinely file-local; the others are not.
@available(iOS 13.0, *)
private final class DetachedFakePasteboard: TextPasteboard {
    var items: [String: Any] = [:]
    var string: String? {
        get { items["public.utf8-plain-text"] as? String }
        set { if let v = newValue { items = ["public.utf8-plain-text": v] } else { items = [:] } }
    }
    var hasStrings: Bool { !((string ?? "").isEmpty) }
    func data(forPasteboardType type: String) -> Data? { items[type] as? Data }
    func setItems(_ newItems: [[String: Any]], options: [UIPasteboard.OptionsKey: Any]) {
        items = newItems.first ?? [:]
    }
    func contains(pasteboardTypes: [String]) -> Bool { pasteboardTypes.contains { items[$0] != nil } }
}

@available(iOS 13.0, *)
private final class FakeCommandClient: RichTextInputCommandClient {
    func canPerform(_ command: RichTextInputCommand, sender: Any?) -> Bool { false }
    func prepare(_ command: RichTextInputCommand, sender: Any?) -> RichTextInputCommandPreparation {
        .terminal(RichTextInputCommandResult(performed: false, revision: 0, selection: .caret(at: .downstream(0)), contentChanged: false, selectionChanged: false))
    }
    func commit(_ prepared: RichTextInputPreparedCommand) -> RichTextInputCommandResult {
        RichTextInputCommandResult(performed: false, revision: 0, selection: .caret(at: .downstream(0)), contentChanged: false, selectionChanged: false)
    }
    var undoManager: UndoManager? { nil }   // TASK 30 — nothing in these two tests reads it
}

/// A `LegacyRichTextInputHost` that is NOT a `DocumentCanvasView` — only its `legacyCanvas` accessor
/// needs to vend one (an unrelated, separately-constructed canvas; nothing in these two tests reads
/// it), because the protocol's `legacyCanvas` requirement is non-optional.
@available(iOS 13.0, *)
@MainActor
private final class RecordingHost: LegacyRichTextInputHost {
    let hostView = UIView()
    let dummyCanvas = DocumentCanvasView()
    let fakeDocumentClient = FakeDocumentClient()
    let fakeGeometryClient = FakeGeometryClient()
    let fakeAnnotationClient = FakeAnnotationClient()
    let fakePresentationClient = FakePresentationClient()
    let fakeLifecycleClient = FakeLifecycleClient()
    let fakeCommandClient = FakeCommandClient()

    var hostInputView: UIView { hostView }
    var legacyCanvas: DocumentCanvasView { dummyCanvas }
    var documentClient: any RichTextInputDocumentClient { fakeDocumentClient }
    var geometryClient: any RichTextInputGeometryClient { fakeGeometryClient }
    var annotationClient: any RichTextInputAnnotationClient { fakeAnnotationClient }
    var presentationClient: any RichTextInputPresentationClient { fakePresentationClient }
    var lifecycleClient: any RichTextInputLifecycleClient { fakeLifecycleClient }
    var commandClient: any RichTextInputCommandClient { fakeCommandClient }
}

@available(iOS 13.0, *)
@MainActor
final class BackendAttachmentTests: XCTestCase {
    override func tearDown() {
        RichTextInputContractViolation.reporter = nil
        super.tearDown()
    }

    // MARK: - Construction wires a backend

    func test_canvasConstructsAndAttachesALegacyBackend() {
        let canvas = DocumentCanvasView()
        XCTAssertTrue(canvas.inputBackend is LegacyRichTextInputBackend)
        XCTAssertTrue(canvas.inputBackend.isAttached)
    }

    func test_injectedBackendIsUsedInsteadOfTheDefault() {
        let spy = SpyBackend()
        let canvas = DocumentCanvasView(inputBackend: spy)
        withExtendedLifetime(canvas) {
            XCTAssertTrue((canvas.inputBackend as AnyObject) === (spy as AnyObject))
            XCTAssertTrue(spy.isAttached)
            XCTAssertEqual(spy.didAttachCount, 1)
        }
    }

    // MARK: - attach

    func test_attachTwiceThrowsAlreadyAttached_andPreservesTheFirstAttachment() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        XCTAssertTrue(backend.isAttached)
        let firstHost = backend.host
        XCTAssertNotNil(firstHost)

        var thrown: Error?
        XCTAssertThrowsError(try backend.attach(to: canvas)) { thrown = $0 }
        if case .alreadyAttached = thrown as? RichTextInputBackendAttachmentError {
            // expected
        } else {
            XCTFail("expected .alreadyAttached, got \(String(describing: thrown))")
        }
        XCTAssertTrue(backend.isAttached, "the first attachment must survive a rejected second attach")
        XCTAssertTrue((backend.host as AnyObject?) === (firstHost as AnyObject?),
                     "the host must be unchanged by the rejected second attach")
    }

    /// Red if: the throwing branch of `attach(to:)` ever set `isAttached = true`, incremented
    /// `didAttachCount`, or let control reach the (never-installed) success path that would have
    /// touched `presentationApplyObserved` or the canvas's gesture recognizers.
    ///
    /// **TASK 32 RE-BASED THE RECOGNIZER ASSERTION, and the reason is the whole point of keeping it.**
    /// It used to read `canvas.gestureRecognizers?.count == baseline.gestureRecognizers?.count`, where
    /// `baseline` is "an ordinarily-constructed canvas, for comparison". Until Task 32 both sides were
    /// **0**, because `installInteractions()` was a no-op stub — the claim "a failed attach installed
    /// nothing" was trivially true and would have held for a build that installed nothing EVER. Now
    /// `attach(to:)` really does install (three recognizers, from inside `DocumentCanvasView.init`), so
    /// `baseline` is 3 while the failed canvas is still 0 — its attach throws inside
    /// `installInitialState(from:)`, which runs BEFORE `installInteractions()` — and the old spelling
    /// would assert `0 == 3`.
    ///
    /// The intent is unchanged and is now a STRONGER claim than it was, so it is written as the
    /// presence-then-absence pair this suite's siblings use (`BackendAttachDetachTests`' fix-round
    /// Major 1): the failed canvas must be at zero, and the ordinary one must NOT be, or the zero would
    /// again be vacuous. Both halves go red under the mutation the test names — a `DocumentCanvasView`
    /// that reached the install path despite the throw fails the first, and a build where
    /// `installInteractions()` silently stopped installing fails the second.
    func test_attachIsAtomic_aThrowingAttachLeavesNothingInstalled() {
        let spy = SpyBackend()
        spy.attachError = RichTextInputBackendAttachmentError.missingCapability("test")
        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }

        let canvas = DocumentCanvasView(inputBackend: spy)
        let baseline = DocumentCanvasView()   // an ordinarily-constructed canvas, for comparison

        XCTAssertFalse(canvas.inputBackend.isAttached)
        XCTAssertEqual(spy.didAttachCount, 0)
        XCTAssertFalse(spy.presentationApplyObserved)
        XCTAssertEqual(canvas.gestureRecognizers?.count ?? 0, 0,
                       "a failed attach must not have installed any gesture recognizer")
        XCTAssertNotNil(baseline.selectionTap,
                        "CONTROL (Task 32): a SUCCESSFUL attach does install them, so the zero above " +
                        "is a fact about the failure and not about the build")
        XCTAssertTrue(reported.contains { $0.contains("backend attach failed") })
    }

    /// Red if the `do/catch` around `try self.inputBackend.attach(to: self)` in
    /// `DocumentCanvasView.init` ever regressed to `try?` — that would leave `reported` empty while
    /// still producing a silently-detached, inert editor.
    func test_aFailingAttachIsReportedNotSwallowed() {
        let spy = SpyBackend()
        spy.attachError = RichTextInputBackendAttachmentError.missingCapability("test")
        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }

        _ = DocumentCanvasView(inputBackend: spy)

        XCTAssertTrue(reported.contains { $0.contains("backend attach failed") && $0.contains("missingCapability") },
                     "expected a report naming both the failure and the error case; got \(reported)")
    }

    // MARK: - detach

    /// Red if a second `detach()` re-ran any teardown step, or if `detach()`'s `guard isAttached` were
    /// deleted.
    ///
    /// **TASK 32 CHANGED WHICH OBSERVABLE MAKES THIS DISCRIMINATING, and FIX ROUND 1 (review Major 2)
    /// changed it again — the second change is the one that matters, so read it first.**
    ///
    /// *What Task 32 broke.* The `pendingRoutingCalls` count used to be the observable: steps 2 and 4
    /// (`cancelActiveInteraction(reason:)`, `removeInteractions()`) were stubs that logged
    /// unconditionally, so a second `performDetachSteps()` grew the log by two.
    /// `BackendAttachDetachTests.test_detachTwice_isIdempotent` records the red-check that confirmed it
    /// ("`5` is not equal to `3`"). Task 32 gave both steps real bodies that reach the canvas through
    /// `legacyCanvas` — i.e. through `host`, which step 9 has already released — so a second pass became
    /// an optional-chained no-op for those two, exactly as it already was for steps 7 and 8. **Every
    /// step that produced an observable now routes through `host`**, so with the guard deleted the
    /// counter sees nothing. The reviewer measured this end-to-end: all 41 tests across this suite and
    /// `BackendAttachDetachTests` stayed GREEN with `guard isAttached else { return }` removed.
    ///
    /// *What fix round 1 restored, and why it was NOT out of scope.* Task 32's report called restoring
    /// the pin out of scope for an extraction commit. **The coordinator overruled that, correctly.** The
    /// decisive argument is not "more coverage": it is that retiring the property while KEEPING a
    /// counter assertion whose own comment conceded it "is kept only as a cheap regression net" is the
    /// project's own worst pattern — "reads as enforcement, enforces nothing" — in its loudest form, a
    /// test whose comment admits its own vacuity under a name that still promises the claim. **That
    /// counter assertion is now DELETED.** In its place: an observable that does NOT route through
    /// `host` — `performDetachSteps()`'s own hygiene resets, which are unconditional value assignments
    /// on the backend itself (`floatingCursorActive = false`, `activeTransactionDepth = 0`). Poison both
    /// AFTER the first detach and they survive a second one iff the guard is doing its job.
    ///
    /// **RED-CHECK (re-run at fix round 1, not inherited):** with `detach()`'s `guard isAttached else
    /// { return }` deleted, BOTH new assertions fail; restored, both pass. That is the pin the counter
    /// could not carry.
    ///
    /// **This restoration is available HERE and not in `BackendAttachDetachTests`.** That suite is a
    /// `BackendContractCases` descendant and rule R10 forbids it from naming a concrete backend at all
    /// outside `makeBackend()` — it types its subject as `any RichTextInputBackend`, which has neither
    /// `floatingCursorActive` nor `activeTransactionDepth` on its surface. Its own corrected note
    /// therefore stands as written: for an inherited contract suite the loss is permanent, because the
    /// only remaining observable is legacy-internal by construction.
    ///
    /// The first-detach control (added by Task 32) stays: it asserts the first `detach()` actually tore
    /// the canvas's interactions down, which is the precondition the idempotence claim rests on. Same
    /// construction, and same reason, as `BackendAttachDetachTests.test_detachTwice_isIdempotent`'s "the
    /// first detach() must have done something observable" line, whose own fix round records why a
    /// sibling's assertion is not a substitute for carrying your own control.
    ///
    /// (Writing `activeTransactionDepth` from a test is outside rule R12's scope — R12 walks
    /// `S/InputBackend/` only, and its subject is production mutation sites.)
    func test_detachIsIdempotent() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        XCTAssertNotNil(canvas.selectionTap,
                        "precondition: attach installed the canvas's gesture recognizers")

        backend.detach()

        XCTAssertFalse(backend.isAttached)
        XCTAssertNil(backend.host)
        XCTAssertNil(canvas.selectionTap,
                     "the FIRST detach() must have done something observable — step 4 removed them")

        // Poison two of `performDetachSteps()`'s own hygiene resets. Unlike every other observable in
        // the nine steps these do not route through `host`, so a second pass that actually RAN would
        // clear them regardless of the released host — which is precisely what makes them the pin.
        backend.floatingCursorActive = true
        backend.activeTransactionDepth = 7

        backend.detach()   // second call — must be a pure no-op

        XCTAssertFalse(backend.isAttached)
        XCTAssertNil(backend.host)
        XCTAssertTrue(backend.floatingCursorActive,
                      "a second detach() must not re-run the hygiene resets — `guard isAttached` is " +
                      "what stops it, and this assertion is that guard's only remaining pin")
        XCTAssertEqual(backend.activeTransactionDepth, 7,
                       "…and the same for the transaction-depth reset")
    }

    /// Red if any operational member skipped its `guard isAttached` violation report, or if it
    /// mutated state despite being detached (the canonical selection would move off its post-attach
    /// seed value).
    func test_operationAfterDetachIsRejectedAndPublishesNothing() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        let seeded = backend.canonicalSelection
        backend.detach()

        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }
        var selectionChangeFired = 0
        canvas.onSelectionChange = { selectionChangeFired += 1 }

        backend.setSelection(.caret(at: .downstream(3)), reason: .programmatic)

        XCTAssertTrue(reported.contains { $0.contains("operation on a detached backend") })
        XCTAssertEqual(backend.canonicalSelection, seeded, "a detached backend must not adopt the new selection")
        XCTAssertEqual(selectionChangeFired, 0, "a detached backend must publish nothing")
    }

    // MARK: - Published state

    func test_stateReflectsRevisionSelectionMarkedRangeAndComposing() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend

        XCTAssertEqual(backend.state.documentRevision, 0)
        XCTAssertEqual(backend.state.selection, .caret(at: .downstream(0)))
        XCTAssertNil(backend.state.markedRange)
        XCTAssertFalse(backend.state.isComposing)

        backend.setSelection(.caret(at: .downstream(0)), reason: .programmatic)
        XCTAssertEqual(backend.state.selection, .caret(at: .downstream(0)))
    }

    /// FIX ROUND 1 — `clearCompositionState()` must publish. It mutates `markedRange` and (via it)
    /// `isComposing` — two of the four published snapshot fields — and `backendDidPublishState` is
    /// the spec's ONLY publication channel. (This used to add "symmetric with `setCanonicalAnchor`/
    /// `setCanonicalHead`, which both publish unconditionally through `setSelection`" — TASK 35 broke
    /// that symmetry deliberately: those two are now raw, non-publishing writes backing the canvas
    /// `anchor`/`head` forwarders. The assertion below is unaffected; only the analogy was.)
    /// `.markedText` routes through the
    /// content-size channel (`TelegramLifecycleInputClient.backendDidPublishState`), same as
    /// `.content`. Red if `clearCompositionState` ever went back to a bare guarded mutate with no
    /// publish call.
    func test_clearCompositionStatePublishesExactlyOnceWithMarkedTextReason() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        var contentFired = 0
        var selectionFired = 0
        canvas.onContentSizeChange = { contentFired += 1 }
        canvas.onSelectionChange = { selectionFired += 1 }

        backend.clearCompositionState()

        XCTAssertEqual(contentFired, 1, ".markedText routes through the content-size channel")
        XCTAssertEqual(selectionFired, 0, ".markedText must not also fire the selection channel")
        XCTAssertNil(backend.state.markedRange)
        XCTAssertFalse(backend.state.isComposing)
    }

    func test_setSelectionUpdatesStateAndPublishesOnce() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        var fired = 0
        canvas.onSelectionChange = { fired += 1 }

        let newSelection = RichTextCanonicalSelection(anchor: .downstream(0), head: .downstream(0))
        backend.setSelection(newSelection, reason: .programmatic)

        XCTAssertEqual(backend.state.selection, newSelection)
        XCTAssertEqual(fired, 1)
    }

    /// Red if `setSelection` ever grew a change-detecting early return — the spec requires a
    /// publication for every call, equal value or not.
    func test_setSelectionWithAnEqualSelectionPublishesOnce() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        let same = backend.canonicalSelection
        var fired = 0
        canvas.onSelectionChange = { fired += 1 }

        backend.setSelection(same, reason: .programmatic)

        XCTAssertEqual(fired, 1, "an equal selection must still publish exactly once")
    }

    // MARK: - synchronizeAfterExternalChange

    func test_synchronizeAfterExternalChangeAdoptsTheNewRevision() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        let newSelection = RichTextCanonicalSelection.caret(at: .downstream(0))
        let change = RichTextInputExternalChange(
            oldRevision: 0, newRevision: 5, reason: .documentReplacement,
            changedRangeBefore: nil, changedRangeAfter: nil, selection: newSelection,
            markedTextPolicy: .discard)

        backend.synchronizeAfterExternalChange(change)

        XCTAssertEqual(backend.state.documentRevision, 5)
        XCTAssertEqual(backend.state.selection, newSelection)
    }

    /// Red if `.layoutOnly` ever bumped `documentRevision` — that would let a later genuine content
    /// change be silently mistaken for a no-op against a revision that moved for free.
    func test_synchronizeWithLayoutOnlyKeepsTheDocumentRevision() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        XCTAssertEqual(backend.state.documentRevision, 0)
        let change = RichTextInputExternalChange(
            oldRevision: 0, newRevision: 5, reason: .layoutOnly,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: .caret(at: .downstream(0)), markedTextPolicy: .preserveIfRebasable)

        backend.synchronizeAfterExternalChange(change)

        XCTAssertEqual(backend.state.documentRevision, 0, "a layout-only change must not move the document revision")
    }

    /// Red if a stale/out-of-order external change were ever silently adopted instead of rejected.
    func test_synchronizeWithADecreasingRevisionIsAContractViolationAndIsNotAdopted() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        // Adopt revision 5 first.
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: 0, newRevision: 5, reason: .documentReplacement,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: .caret(at: .downstream(0)), markedTextPolicy: .discard))
        XCTAssertEqual(backend.state.documentRevision, 5)

        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }
        let staleSelection = RichTextCanonicalSelection.caret(at: .downstream(9))
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: 5, newRevision: 2, reason: .documentReplacement,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: staleSelection, markedTextPolicy: .discard))

        XCTAssertEqual(backend.state.documentRevision, 5, "a decreasing revision must not be adopted")
        XCTAssertNotEqual(backend.state.selection, staleSelection)
        XCTAssertTrue(reported.contains { $0.contains("continuity") })
    }

    /// FIX ROUND 1 — the missed case. A plain `newRevision >= documentRevision` guard (the
    /// pre-fix rule) prevents REGRESSION but not DISAGREEMENT: this change's `oldRevision` (3)
    /// does not match what the backend actually adopted (5), even though its `newRevision` (6)
    /// does not regress — exactly the stale-diff race the continuity check exists to catch (a
    /// `changedRangeBefore`/`changedRangeAfter` computed against a baseline of 3 applied to a
    /// backend at 5). Confirmed RED against the pre-fix `>= documentRevision`-only guard (that
    /// guard passes `6 >= 5` and adopts the stale change) and GREEN against the tightened
    /// `oldRevision == documentRevision && newRevision >= documentRevision` rule.
    func test_synchronizeWithAMismatchedOldRevisionIsRejectedEvenIfNewRevisionDoesNotRegress() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        // Adopt revision 5 first (oldRevision 0 correctly matches the freshly-attached backend).
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: 0, newRevision: 5, reason: .documentReplacement,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: .caret(at: .downstream(0)), markedTextPolicy: .discard))
        XCTAssertEqual(backend.state.documentRevision, 5)

        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }
        let staleSelection = RichTextCanonicalSelection.caret(at: .downstream(9))
        // oldRevision (3) disagrees with the backend's adopted revision (5); newRevision (6) does
        // NOT regress (6 >= 5) — the case a plain `>=` guard lets through.
        backend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: 3, newRevision: 6, reason: .documentReplacement,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: staleSelection, markedTextPolicy: .discard))

        XCTAssertEqual(backend.state.documentRevision, 5,
                       "a change whose oldRevision disagrees with the adopted revision must not be " +
                       "adopted, even when its newRevision does not regress")
        XCTAssertNotEqual(backend.state.selection, staleSelection)
        XCTAssertTrue(reported.contains { $0.contains("continuity") })
    }

    // MARK: - Host retention

    /// Red if `host` were ever changed from `weak` to a strong reference — the canvas would then
    /// leak for the lifetime of the backend.
    func test_theBackendRetainsTheHostWeakly() {
        weak var probe: DocumentCanvasView?
        var backend: LegacyRichTextInputBackend!
        autoreleasepool {
            let canvas = DocumentCanvasView()
            probe = canvas
            backend = (canvas.inputBackend as! LegacyRichTextInputBackend)
            XCTAssertNotNil(backend.host)
        }
        XCTAssertNil(probe, "the canvas must be deallocatable while the backend is still held strongly elsewhere")
        XCTAssertNotNil(backend, "the backend itself must still be alive")
        XCTAssertNil(backend.host, "and its weak host reference must now read nil")
    }

    /// TASK 24 FIX ROUND 1 (Critical, reviewer Focal Point 1) — the concrete reachability proof for
    /// the review's "state 2": the contract-sanctioned "host deallocated while the backend is still
    /// (nominally) attached" state this SAME suite's own test above asserts is possible. Before this
    /// fix round, EVERY Family-1 read witness force-unwrapped `legacyCanvas`/`document` on the theory
    /// that this state cannot reach a read — this test proves it CAN, and that the fix turns a crash
    /// into the documented, non-crashing degradation `DocumentCanvasView.init`'s own comment describes
    /// ("alive but inert"). Red if any of the eleven Family-1 witnesses ever reintroduces a force
    /// unwrap of `legacyCanvas`/`document` on this exact path.
    func test_readingAWitnessAfterTheHostDeallocates_doesNotCrash_returnsTheDocumentedFallback() {
        var violations: [String] = []
        RichTextInputContractViolation.reporter = { violations.append($0) }

        weak var probe: DocumentCanvasView?
        var backend: LegacyRichTextInputBackend!
        autoreleasepool {
            let canvas = DocumentCanvasView()
            probe = canvas
            backend = (canvas.inputBackend as! LegacyRichTextInputBackend)
        }
        XCTAssertNil(probe, "precondition: the canvas must actually be gone")
        XCTAssertNil(backend.host, "precondition: the weak host reference must read nil")

        // None of these may crash. Each returns the SAME fallback its own pre-Task-24 stub returned.
        XCTAssertNil(backend.text(in: DocumentTextRange(DocumentTextPosition(0), DocumentTextPosition(1))))
        XCTAssertTrue(backend.beginningOfDocument is DocumentTextPosition)
        XCTAssertEqual((backend.beginningOfDocument as! DocumentTextPosition).offset, 0)
        XCTAssertEqual((backend.endOfDocument as! DocumentTextPosition).offset, 0)
        XCTAssertNil(backend.position(from: DocumentTextPosition(0), offset: 1))
        XCTAssertNil(backend.position(from: DocumentTextPosition(0), in: .right, offset: 1))
        _ = backend.tokenizer   // must not crash; identity/type covered by the tokenizer-cache tests

        XCTAssertFalse(violations.isEmpty,
                       "at least the non-per-keystroke members (tokenizer/beginningOfDocument/" +
                       "endOfDocument) must report a contract violation on this path")
    }

    // MARK: - TASK 35: which store `selectedTextRange`'s getter answers from

    /// **TASK 35 RETIRED THIS TEST'S SUBJECT, and did so by name.** It was written at Task 26 (fix
    /// round 1, review m4) to pin the getter's TWO branches — the attached one reading the canvas's
    /// live `anchor`/`head`, the detached one falling back to `canonicalSelectionStorage` — and its own
    /// RED-IF clause said it would be "equally red if the fallback were widened to always answer from
    /// canonical". That is exactly what Task 35 does, because there is no longer a second store to
    /// disagree with: `DocumentCanvasView.anchor`/`.head` became forwarders over
    /// `canonicalSelectionStorage`, so the old attached branch would have been a round trip out to the
    /// canvas and straight back. The `guard let legacyCanvas else { … }` and both
    /// `legacyCanvas.anchor`/`.head` reads (the last two in the tree) are gone with it, along with
    /// their D24 clause-(b) entries.
    ///
    /// What survives, and is what this test now pins, is everything the fallback branch was protecting:
    /// the getter answers from this backend's own state in EVERY host state, including the five
    /// documented ones that reach `host == nil` while a caller still holds the backend (a swallowed
    /// `attach` throw, a host deallocated while attached, the detach→re-attach window,
    /// `DocumentCanvasView.deinit` after Swift has zeroed the weak `host`, and a `DocumentTokenizer`
    /// outliving its canvas — `+TextReads.swift`'s Task-24 fix note). In every one of them UIKit may
    /// still read `selectedTextRange`, and the answer must be state rather than a trap or a nil.
    ///
    /// **The non-vacuity control changed shape with the subject.** It used to be "the two stores
    /// disagree"; it is now `host.dummyCanvas`, which is a DIFFERENT `DocumentCanvasView` with its OWN
    /// `LegacyRichTextInputBackend` (constructed in its `init`) and therefore its own canonical store,
    /// still reading `(0, 0)`. That asserts the thing worth asserting after the collapse: "one stored
    /// copy" is per-backend, and this getter reads the backend it belongs to — not whatever canvas the
    /// host happens to vend.
    ///
    /// Lives here — `final class … XCTestCase`, legacy-only, already licensed to name
    /// `LegacyRichTextInputBackend` — and NOT in a `BackendContractCases` suite: the host-vends-a-canvas
    /// shape is a D24 concept stage 2's backend does not have.
    ///
    /// RED IF: the getter reinstated a `legacyCanvas.anchor`/`.head` read (the attached assertions
    /// would report the dummy canvas's `(0, 0)`), or trapped/returned nil with no host (the detached
    /// read would fail or crash — R15 separately forbids the `legacyCanvas!` spelling), or normalized
    /// the endpoints (the reversed `(7, 2)` would come back as `(2, 7)`).
    func test_selectedTextRangeGetter_answersFromTheCanonicalStore_attachedOrNot() {
        let host = RecordingHost()
        let backend = LegacyRichTextInputBackend()
        try! backend.attach(to: host)
        backend.setSelection(RichTextCanonicalSelection(anchor: .downstream(7), head: .downstream(2)),
                             reason: .programmatic)

        guard let attachedRange = backend.selectedTextRange as? DocumentTextRange else {
            XCTFail("expected a DocumentTextRange while attached"); return
        }
        XCTAssertEqual(attachedRange.from.offset, 7,
                       "while attached the getter answers from this backend's canonical store")
        XCTAssertEqual(attachedRange.to.offset, 2)
        XCTAssertEqual(host.dummyCanvas.anchor, 0,
                       "control: the host's canvas has its OWN backend and its own store, untouched " +
                       "by this backend's setSelection — so the reads above cannot be coming from it")
        XCTAssertEqual(host.dummyCanvas.head, 0)

        backend.detach()

        guard let detachedRange = backend.selectedTextRange as? DocumentTextRange else {
            XCTFail("expected a DocumentTextRange after detach"); return
        }
        XCTAssertEqual(detachedRange.from.offset, 7,
                       "and the same store answers with no host at all — the state that made the old " +
                       "fallback branch load-bearing is unchanged, only the branch is gone")
        XCTAssertEqual(detachedRange.to.offset, 2,
                       "and it stays UNORDERED — the getter must never normalize a reversed selection")
        withExtendedLifetime(host) {}
    }

    // MARK: - `hasText`'s detached fallback (TASK 27a)

    /// TASK 27a routed `hasText` through `RichTextInputDocumentClient.utf16Length`. With no attached
    /// client there is no length to read, so it answers `false` — where the pre-seam canvas witness
    /// (`documentSize > 0`) kept answering from canvas state that is still alive during the documented
    /// "attached but host gone" / detach→re-attach windows. That is a real, disclosed divergence
    /// (`+Insertion.swift`'s own doc comment), so it is pinned rather than left to prose.
    ///
    /// **Both polarities come from ONE backend and ONE store**, which is what makes this non-vacuous:
    /// attached, it reports the client's `utf16Length = 12`; detached, the SAME backend reports `false`.
    ///
    /// Lives here — `final class … XCTestCase`, legacy-only, already licensed to name
    /// `LegacyRichTextInputBackend` — and NOT in a `BackendContractCases` suite: this is a
    /// characterization of THIS conformer's fallback, not a contract obligation stage 2 must inherit.
    /// It also cannot live in `InsertionRouterTests` beside its siblings, because rule R14 forbids that
    /// directory from naming the canvas's backend property, and detaching requires exactly that.
    ///
    /// RED IF: the `guard let document = self.document else { return false }` fallback were removed
    /// (the detached read would trap, which R15 separately forbids), or if the member answered from
    /// anything other than the document client (the attached read would not track `utf16Length`).
    func test_hasTextAnswersFromTheDocumentClient_andIsFalseWhenDetached() {
        let host = RecordingHost()
        let backend = LegacyRichTextInputBackend()
        try! backend.attach(to: host)

        XCTAssertFalse(backend.hasText, "control: an empty document reads false while ATTACHED too")
        host.fakeDocumentClient.utf16Length = 12
        XCTAssertTrue(backend.hasText, "attached, the answer is the document client's length")

        backend.detach()

        XCTAssertFalse(backend.hasText,
                       "detached there is no client to read; false is the documented fallback — and " +
                       "the client still reports 12, so this is the fallback branch, not a stale read")
        XCTAssertEqual(host.fakeDocumentClient.utf16Length, 12)
        withExtendedLifetime(host) {}
    }

    // MARK: - `insertText(_:)`'s detached drop (TASK 27b)

    /// TASK 27b routed `insertText(_:)` as a plain `legacyCanvas` forward. With no host there is no
    /// canvas to forward to, so the keystroke is **dropped silently** — where the pre-seam witness ran
    /// entirely on canvas state and typed even in the documented "attached but host gone" /
    /// detach→re-attach windows. That is a real, disclosed axis-2 divergence (`+Insertion.swift`'s own
    /// doc comment), and the SILENCE is a deliberate policy choice, not an omission: `insertText` is
    /// the OS's per-keystroke entry point, so a `RichTextInputContractViolation` report here would turn
    /// a documented teardown window into a DEBUG trap on the hottest path in the editor (the precedent
    /// `text(in:)` and `replace(_:withText:)` set). A policy this task chose is a policy this task
    /// pins.
    ///
    /// The control matters as much as the assertion: the SAME canvas, the SAME call, ATTACHED, types.
    /// Without it the "document did not change" half would pass just as well for a member that never
    /// worked at all.
    ///
    /// Lives here rather than in `InsertionRouterTests` for the same reason `hasText`'s fallback does:
    /// R14 forbids that directory from naming the canvas's backend property, and detaching requires it.
    ///
    /// RED IF: the forward gained a `RichTextInputContractViolation.report` on the nil-canvas path
    /// (`reported` would be non-empty), or the member force-unwrapped `legacyCanvas` (a crash, which
    /// R15 separately forbids).
    func test_insertTextOnADetachedBackend_isDroppedSilently_ratherThanReported() {
        let canvas = DocumentCanvasView()
        canvas.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])], width: 300)
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 300); canvas.layoutIfNeeded()
        canvas.setCaret(global: canvas.boxes[0].textStart)
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }

        backend.insertText("x")
        XCTAssertEqual((canvas.boxes[0] as! BlockBox).currentParagraph().text, "xAlpha",
                       "control: attached, the forward reaches the canvas body and types")
        let revisionAfterControl = canvas.documentRevision

        backend.detach()
        backend.insertText("y")

        XCTAssertEqual((canvas.boxes[0] as! BlockBox).currentParagraph().text, "xAlpha",
                       "detached there is no canvas to forward to, so the keystroke is dropped")
        XCTAssertEqual(canvas.documentRevision, revisionAfterControl)
        XCTAssertEqual(reported, [], "and the drop is SILENT — following the precedent `text(in:)` and " +
                                     "`replace(_:withText:)` set, the same one this test's two siblings " +
                                     "cite. TASK 29 CORRECTION: this message used to say \"on an " +
                                     "OS-driven path\", which Task 28's review showed is not the " +
                                     "criterion — `RichTextEditorView.insertText(_:)` is a programmatic " +
                                     "caller, so OS-drivenness alone does not settle this member either")
    }

    /// TASK 28's sibling of the test above, and the one place the divergence is sharper than
    /// `insertText`'s: `LegacyRichTextInputBackend.deleteBackward()` USED TO REPORT on exactly this
    /// path — its Task-22b body opened with
    /// `guard isAttached, let host, let document else { RichTextInputContractViolation.report(…) }`.
    /// Task 28 routed the member as a plain `legacyCanvas` forward, and that report moved WITH the
    /// transaction body to `ReferenceMutationBackend.deleteBackward()`, where it still fires; the routed
    /// member drops silently instead. **The reason is PRECEDENT, not OS-drivenness** (corrected at Task
    /// 28's review): the Phase-4 preamble's clause is "report only where a *programmatic* caller could
    /// reach the member", and `RichTextEditorView.deleteBackward()` is one — so that clause does not
    /// settle this member. What settles it is that `insertText(_:)` has the IDENTICAL shape (UIKit entry
    /// point + public facade forwarder) and Task 27b ruled it silent; the sibling test above is that
    /// ruling. Giving the two halves of one keystroke pair opposite detached behaviour would need a
    /// reason nobody has. The cost still favours silence — a report is a DEBUG `assertionFailure` with
    /// no reporter installed, and UIKit reaches this member far more often than the facade does.
    /// **This is a policy choice this task made, so this task pins it.**
    ///
    /// The control matters as much as the assertion: the SAME canvas, the SAME call, ATTACHED, deletes.
    /// Without it the "document did not change" half would pass just as well for a member that never
    /// worked at all.
    ///
    /// Lives here rather than in `DeletionRouterTests` for the same reason `insertText`'s does: R14
    /// forbids that directory from naming the canvas's backend property, and detaching requires it.
    ///
    /// RED IF: the forward kept (or re-grew) a `RichTextInputContractViolation.report` on the nil-canvas
    /// path (`reported` would be non-empty), or the member force-unwrapped `legacyCanvas` (a crash,
    /// which R15 separately forbids).
    func test_deleteBackwardOnADetachedBackend_isDroppedSilently_ratherThanReported() {
        let canvas = DocumentCanvasView()
        canvas.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])], width: 300)
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 300); canvas.layoutIfNeeded()
        canvas.setCaret(global: canvas.boxes[0].textStart + 1)
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }

        backend.deleteBackward()
        XCTAssertEqual((canvas.boxes[0] as! BlockBox).currentParagraph().text, "lpha",
                       "control: attached, the forward reaches the canvas body and deletes")
        let revisionAfterControl = canvas.documentRevision

        backend.detach()
        backend.deleteBackward()

        XCTAssertEqual((canvas.boxes[0] as! BlockBox).currentParagraph().text, "lpha",
                       "detached there is no canvas to forward to, so the Backspace is dropped")
        XCTAssertEqual(canvas.documentRevision, revisionAfterControl)
        XCTAssertEqual(reported, [], "and the drop is SILENT — matching insertText's identical-shape ruling")
    }

    /// TASK 29's member of the same family: `setMarkedText(_:selectedRange:)` is a plain `legacyCanvas`
    /// forward, so an IME composition update arriving with no host is **dropped silently**, where the
    /// pre-seam witness ran entirely on canvas state and composed even in the documented "attached but
    /// host gone" / detach→re-attach windows. A real, disclosed axis-2 divergence
    /// (`+MarkedText.swift`'s own doc comment).
    ///
    /// Silence is easier to justify here than for either sibling above, and the reason is worth stating
    /// because the two criteria finally AGREE: `setMarkedText` has **no public-facade forwarder at all**
    /// (measured — `RichTextEditorView` exposes `insertText(_:)` and `deleteBackward()` but nothing that
    /// reaches this member), so the Phase-4 preamble's "report only where a PROGRAMMATIC caller could
    /// reach the member" clause settles it directly, AND the `insertText`/`deleteBackward` precedent
    /// points the same way. There is no trade-off to record.
    ///
    /// The control matters as much as the assertion: the SAME canvas, the SAME call, ATTACHED, composes.
    ///
    /// Lives here rather than in `MarkedTextRouterTests` for the same reason its two siblings do: R14
    /// forbids that directory from naming the canvas's backend property, and detaching requires it.
    ///
    /// RED IF: the forward gained a `RichTextInputContractViolation.report` on the nil-canvas path
    /// (`reported` would be non-empty) — which is exactly what the Task-22f body it REPLACED did — or
    /// the member force-unwrapped `legacyCanvas` (a crash, which R15 separately forbids).
    func test_setMarkedTextOnADetachedBackend_isDroppedSilently_ratherThanReported() {
        let canvas = DocumentCanvasView()
        canvas.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "")])], width: 300)
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 300); canvas.layoutIfNeeded()
        canvas.setCaret(global: canvas.boxes[0].textStart)
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }

        backend.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertEqual((canvas.boxes[0] as! BlockBox).currentParagraph().text, "ni",
                       "control: attached, the forward reaches the canvas body and composes")
        XCTAssertNotNil(canvas.markedRange)
        let revisionAfterControl = canvas.documentRevision

        backend.detach()
        backend.setMarkedText("nihao", selectedRange: NSRange(location: 5, length: 0))

        XCTAssertEqual((canvas.boxes[0] as! BlockBox).currentParagraph().text, "ni",
                       "detached there is no canvas to forward to, so the composition update is dropped")
        XCTAssertEqual(canvas.documentRevision, revisionAfterControl)
        XCTAssertEqual(reported, [], "and the drop is SILENT — the report the Task-22f storage-only body " +
                                     "used to make moved to ReferenceMutationBackend with that body")
    }

    /// TASK 28 fix round — **the third leg of the pair above, added because the record claimed it and
    /// nothing checked it.** Both detached-drop tests say the `"operation on a detached backend"` report
    /// *moved* to `ReferenceMutationBackend` rather than being deleted, and D27's axis-2 entry says the
    /// same; that was an unpinned assertion in two documents. It is a real assertion about the
    /// conformer's own guard, not a tautology — the guard is the thing that stops a contract suite
    /// running a `prepareAndRun` transaction against a detached backend, and the conformer is the
    /// artifact TASK 29 edited next (it added two more members to that file, one of which — the
    /// re-homed `setMarkedText` — this test now covers).
    ///
    /// Covers the conformer's non-forward members that HAVE a guard, in one test, since they share one
    /// guard shape. TASK 29 added two more non-forward members (`setMarkedText(_:selectedRange:)` and
    /// its paired read `markedTextRange`) and extended this test with the first: it carries the same
    /// `guard inner.isAttached else { report }` opener, moved with the body. `markedTextRange` is a pure
    /// READ with no guard at all (it answers `nil` when nothing is composing, detached or not), so it is
    /// deliberately absent rather than silently missing.
    ///
    /// RED IF: either member lost its `guard inner.isAttached, let host, let document else { report }`
    /// opener while being moved — the arrays would be empty and the transaction would silently not run.
    func test_theReferenceConformersMutationMembersStillReportWhenDetached() {
        let reference = ReferenceMutationBackend()   // fresh and UNATTACHED
        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }

        reference.deleteBackward()
        reference.insertText("x")
        reference.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))

        XCTAssertEqual(reported, ["operation on a detached backend: deleteBackward()",
                                  "operation on a detached backend: insertText(_:)",
                                  "operation on a detached backend: setMarkedText(_:selectedRange:)"],
                       "the report the routed legacy members gave up moved HERE with their transaction " +
                       "and storage bodies — it was not deleted")
    }

    /// TASK 30's members of the same family, in ONE test because all three share one detached shape and
    /// one ruling. `performCommand(_:sender:)` is a plain `legacyCanvas` forward, so a Copy/Cut/Paste/
    /// Select arriving with no host is **dropped silently**; `canPerformCommand(_:sender:)` answers
    /// `false` for every command; `undoManager` answers `nil`. All three are real, disclosed axis-2
    /// divergences (`+Commands.swift`'s per-member audits) — the pre-seam witnesses ran entirely on
    /// canvas state and had no host dependency at all.
    ///
    /// Silence: `performCommand` matches `insertText`/`deleteBackward` exactly (a UIKit responder entry
    /// point PLUS a public-facade forwarder — `RichTextEditorView.pasteFromPasteboard()` reaches
    /// `paste(_:)`), so the precedent Task 28 settled applies verbatim. `canPerformCommand` and
    /// `undoManager` follow `hasText`'s precedent instead: UIKit polls both on menu/responder
    /// evaluation paths this code does not choose, where a report would flood.
    ///
    /// The CONTROLS matter as much as the assertions: the same canvas, the same calls, ATTACHED, work.
    ///
    /// Lives here rather than in `CommandRouterTests` for the same reason its three siblings above do:
    /// R14 forbids that directory from naming the canvas's backend property, and detaching requires it.
    ///
    /// RED IF: any of the three grew a `RichTextInputContractViolation.report` on its detached path, or
    /// stopped being reachable at all while attached (the controls catch the second).
    func test_theCommandFamilyOnADetachedBackend_isDroppedSilently_ratherThanReported() {
        let canvas = DocumentCanvasView()
        canvas.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])], width: 300)
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 300); canvas.layoutIfNeeded()
        canvas.setSelectionForTesting(anchor: canvas.boxes[0].textStart, head: canvas.boxes[0].textStart + 5)
        let pasteboard = DetachedFakePasteboard(); canvas.pasteboard = pasteboard
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }

        // Controls, attached.
        XCTAssertTrue(backend.canPerformCommand(.copy, sender: nil),
                      "control: attached, availability is answered from the live selection")
        XCTAssertTrue(backend.undoManager === canvas.effectiveUndoManager,
                      "control: attached, the manager is the canvas's own")
        backend.performCommand(.copy, sender: nil)
        XCTAssertEqual(pasteboard.string, "Alpha", "control: attached, the forward reaches the canvas body")
        pasteboard.items = [:]

        backend.detach()

        XCTAssertFalse(backend.canPerformCommand(.copy, sender: nil),
                       "detached there is no client to ask, so availability collapses to false")
        XCTAssertNil(backend.undoManager,
                     "detached there is no client to ask, so the responder chain sees no manager")
        backend.performCommand(.copy, sender: nil)
        XCTAssertTrue(pasteboard.items.isEmpty,
                      "detached there is no canvas to forward to, so the Copy is dropped")
        XCTAssertEqual(reported, [],
                       "and every one of the three drops is SILENT — matching the insertText/" +
                       "deleteBackward ruling for the forward and hasText's for the two reads")
    }

    // MARK: - detach ordering (spec's nine steps)

    /// Red if the nine-step order in `performDetachSteps()` were reordered, or if `removeInteractions`
    /// / `cancelActiveInteraction` were dropped from the path.
    ///
    /// **TASK 32 RE-BASED THIS TEST. It went RED as written, and its intent is preserved rather than
    /// its spelling.** The asserted sequence had four entries; the first two
    /// (`"cancelActiveInteraction(reason:)"`, `"removeInteractions()"`) were written into
    /// `pendingRoutingCalls` by the two members' STUB bodies. Task 32 replaced those stubs with real
    /// canvas forwards, which log nothing, so the shared timeline now carries only the two CLIENT calls.
    ///
    /// The two halves of the original claim are therefore now checked separately, and both are
    /// STRONGER than the log entry they replace — a logged stub proved only that a no-op ran:
    ///
    ///   * **"…were dropped from the path"** is now checked by EFFECT on the host's canvas, with a
    ///     precondition on each so neither can pass vacuously: step 2 must clear a floating-cursor
    ///     session that was active going in, and step 4 must remove the recognizers `attach` installed.
    ///   * **"the order were reordered"** survives only for the client-facing tail. Stated plainly
    ///     rather than faked: **the relative order of steps 2 and 4 is no longer observable at all**
    ///     through this host. The two touch disjoint canvas state (display links + floating-cursor
    ///     flag vs the recognizer list), so running 4 before 2 produces the identical end state, and
    ///     nothing either one does is visible to the other. `+Attachment.swift`'s source is the only
    ///     authority on that pair now. What IS still pinned here is that step 7 precedes step 8, which
    ///     `BackendAttachDetachTests.test_detachOrder_matchesTheSpecifiedSequence` red-checked by
    ///     swapping those two lines.
    func test_detachRunsTheNineStepsInOrder() {
        let host = RecordingHost()
        let backend = LegacyRichTextInputBackend()
        try! backend.attach(to: host)
        // Step 2's target: an in-flight floating-cursor session on the host's canvas. `cancelFloatingCursor()`
        // guards on this flag, so without the precondition the post-assertion would hold for a build where
        // step 2 never ran at all.
        host.dummyCanvas.beginFloatingCursor(at: CGPoint(x: 1, y: 1))
        XCTAssertTrue(host.dummyCanvas.floatingCursorActive, "precondition for step 2")
        // Step 4's target: the recognizers the canvas's OWN attach installed. Asserted by IDENTITY, never
        // by count — a canvas also holds the `UIEditMenuInteraction`'s own recognizers, which step 4
        // deliberately leaves alone (see `legacyRemoveSelectionInteractions()`'s disclosed asymmetry).
        XCTAssertNotNil(host.dummyCanvas.selectionTap, "precondition for step 4")
        let baseline = LegacyRichTextInputBackend.pendingRoutingCalls.count

        backend.detach()

        let observed = Array(LegacyRichTextInputBackend.pendingRoutingCalls[baseline...])
        XCTAssertEqual(observed, [
            "tearDownPresentation",
            "backendWillDetach",
        ], "the client-facing tail, in the spec's order — steps 2 and 4 no longer log, see this test's note")
        XCTAssertFalse(host.dummyCanvas.floatingCursorActive,
                       "step 2 (cancelActiveInteraction) must still be on the path")
        XCTAssertNil(host.dummyCanvas.selectionTap,
                     "step 4 (removeInteractions) must still be on the path")
        XCTAssertNil(host.dummyCanvas.loupeLongPress)
        XCTAssertNil(host.dummyCanvas.selectionHandlePan)
    }

    /// This is the real-backend counterpart of
    /// `BackendReentrancyTests.test_detachDuringMutation_runsAtTheTransactionBoundary` (Task 22g).
    ///
    /// FIX ROUND 2 (review Minor 1/5(a)) — CORRECTED, this comment was stale in two ways. First,
    /// `BackendReentrancyTests` now exists and IS the properly-discriminating pin for this invariant —
    /// this is no longer "the only test covering this behavior". Second, the original `Red if` framing
    /// ("Red if a `detach()` called reentrantly … ever tore presentation down mid-mutation instead of
    /// latching") is now KNOWN FALSE for this test's own hook site: `onDidPublishState`
    /// (`FakeLifecycleClient.backendDidPublishState` below) records `"lifecyclePublish"` and only THEN
    /// invokes the hook, and nothing here logs anything further between the outer publish and the
    /// detach steps in EITHER world — exactly the non-discriminating shape
    /// `BackendReentrancyTests.test_detachDuringMutation_runsAtTheTransactionBoundary`'s own doc
    /// comment documents fixing (by rehooking onto `onApply` instead, which fires BEFORE
    /// `lifecyclePublish` is logged). An unconditional `performDetachSteps()` here would produce the
    /// SAME `observed` array asserted below, byte-for-byte — this test does not actually catch that
    /// regression. Left AS-IS rather than rehooked: `BackendReentrancyTests` already covers the
    /// invariant correctly and exhaustively (including this exact real-host ordering, via the fakes),
    /// and this test still exercises ground that suite doesn't — the REAL `LegacyRichTextInputBackend`
    /// attached to a non-`DocumentCanvasView` `LegacyRichTextInputHost` (`RecordingHost`), and
    /// `pendingRoutingCalls` ordering across the interaction stubs. Kept as a characterization of that
    /// shape, not as the regression pin for the latch itself.
    func test_detachRequestedDuringAMutationIsDeferredToTheTransactionBoundary() {
        let host = RecordingHost()
        let backend = LegacyRichTextInputBackend()
        try! backend.attach(to: host)
        let baseline = LegacyRichTextInputBackend.pendingRoutingCalls.count
        var violations: [String] = []
        RichTextInputContractViolation.reporter = { violations.append($0) }

        host.fakeLifecycleClient.onDidPublishState = { [weak backend] in
            backend?.detach()
        }

        backend.setSelection(.caret(at: .downstream(0)), reason: .programmatic)

        let observed = Array(LegacyRichTextInputBackend.pendingRoutingCalls[baseline...])
        // The mutation's own publish (presentationApply, lifecyclePublish) completes FIRST; only
        // once `setSelection` reaches `endTransaction()` does the latched detach's teardown run.
        // TASK 32: the two interaction entries left this sequence when their stubs became real canvas
        // forwards (they log nothing now) — see `test_detachRunsTheNineStepsInOrder`'s note. What this
        // test is ABOUT is untouched: the mutation's own publish still completes before any teardown
        // step runs, which is the whole latch invariant, and it is still visible here because
        // `presentationApply`/`lifecyclePublish` precede `tearDownPresentation`.
        XCTAssertEqual(observed, [
            "presentationApply",
            "lifecyclePublish",
            "tearDownPresentation",
            "backendWillDetach",
        ])
        XCTAssertFalse(backend.isAttached)
        XCTAssertTrue(violations.isEmpty, "a well-ordered reentrant detach must not report a contract violation")
    }

    // MARK: - Transaction phase

    func test_transactionPhaseIsIdleOutsideAnOperation() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        XCTAssertEqual(backend.transactionPhase, .idle)

        backend.setSelection(.caret(at: .downstream(0)), reason: .programmatic)

        XCTAssertEqual(backend.transactionPhase, .idle, "endTransaction must always return the phase to idle")
    }

    // MARK: - `activeTransactionDepth` (Task 22g fix round 2, review Major)
    //
    // These two live HERE, not in `BackendReentrancyTests` (which types `backend` as `any
    // RichTextInputBackend` and is barred by R10/R11 from naming the concrete type outside
    // `makeBackend()`): both scenarios below require directly manipulating
    // `activeTransactionDepth`/calling `endTransaction()` — internal implementation details with no
    // path to construct through the public protocol surface. This file already downcasts to the
    // concrete `LegacyRichTextInputBackend` for exactly this reason (see
    // `test_transactionPhaseIsIdleOutsideAnOperation` immediately above).

    /// The entry/exit pair's OVER-DECREMENT direction: `endTransaction()` reached with no matching
    /// entry bump (the shape a caller that bypasses `withTransaction(_:)` — `+Attachment.swift` —
    /// would produce) must be a REPORTED contract violation, not a silently-clamped no-op that
    /// masquerades as a legitimate outermost exit.
    ///
    /// RED IF: `endTransaction()`'s `guard activeTransactionDepth > 0 else { report; return }`
    /// (`+Attachment.swift`) were reverted to the OLD `activeTransactionDepth = max(0,
    /// activeTransactionDepth - 1)` clamp — no violation would be reported, and the call would
    /// silently fall through to the guarded real work below (harmless here, since nothing else is
    /// pending, but exactly the "silently reinstates the defect" shape the review named). Confirmed
    /// red against exactly that reversion, then reverted.
    func test_endTransactionWithNoMatchingBump_reportsAViolation_insteadOfSilentlyClamping() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        XCTAssertEqual(backend.activeTransactionDepth, 0)
        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }

        backend.endTransaction()

        XCTAssertTrue(reported.contains { $0.contains("activeTransactionDepth already 0") },
                     "expected a reported violation naming the unmatched exit; got \(reported)")
        XCTAssertEqual(backend.activeTransactionDepth, 0, "an unmatched exit must not go negative")
        XCTAssertEqual(backend.transactionPhase, .idle, "an unmatched exit must not disturb an already-idle backend")
    }

    /// The entry/exit pair's UNDER-DECREMENT direction: a bump that never reaches its own
    /// `endTransaction()` (simulating a hypothetical future bug that increments the counter without
    /// going through `withTransaction(_:)`) must not survive detach into a fresh re-attach — the same
    /// hygiene treatment `deferredExternalChange` already gets in `performDetachSteps()`.
    ///
    /// RED IF: `performDetachSteps()`'s `activeTransactionDepth = 0` reset (`+Attachment.swift`) were
    /// deleted — the leaked bump would survive detach and re-attach. Confirmed red (see below), then
    /// reverted.
    ///
    /// FIX ROUND 3 (review item 3) — PINS THE CONSEQUENCE, NOT THE VARIABLE. The original version of
    /// this test asserted `transactionPhase == .idle` after a single follow-up `setSelection` — a
    /// direct read of the internal phase variable, not an observable effect. The FIRST mutation after
    /// a leak is NOT itself discriminating: `withTransaction`'s `body()` call is unconditional
    /// regardless of the counter's value, so it still runs and still publishes even with the leak
    /// present — the leak's effect is that this first call's OWN `endTransaction()` then returns
    /// WITHOUT resetting `transactionPhase` to `.idle` (depth decrements to a still-nonzero value),
    /// wedging it. That wedge is only OBSERVABLE on a SECOND, subsequent mutation:
    /// `prepareAndRun`'s reentrancy guard (`+Mutation.swift`) checks `transactionPhase == .idle` and
    /// would wrongly reject that second call as if it were still reentrant. So this test now performs
    /// TWO ordinary `insertText` calls and asserts the document client is reached (`onContentSizeChange`
    /// fires) for BOTH — the second call is the one that actually exercises the wedge.
    ///
    /// TASK 27b — **the DRIVER changed, the SUBJECT did not.** `backend.insertText` is now a plain
    /// `legacyCanvas` forward (deviation D35), so it no longer opens a transaction at all and could not
    /// exercise the wedge: it would edit the canvas without ever moving `backend.state.documentRevision`
    /// — a test that fails for correct code. The two mutations are therefore driven through
    /// `ReferenceMutationBackend`, the test-only conformer that carries the Task-22b transaction body,
    /// **wrapping this very backend** (`wrapping:`), so the leak simulated below, the reset under test,
    /// and the `prepareAndRun` reentrancy guard that makes the wedge observable are all still this
    /// canvas's own `LegacyRichTextInputBackend`.
    func test_aLeakedTransactionDepthBump_doesNotSurviveDetachIntoAFreshAttach() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        let reference = ReferenceMutationBackend(wrapping: backend)
        // Simulate a leaked bump directly — `withTransaction(_:)` itself cannot leak (that is the
        // whole point of the chokepoint), so this constructs the scenario by bypassing it, the same
        // way a hypothetical future bug would.
        backend.activeTransactionDepth += 1

        backend.detach()
        try! backend.attach(to: canvas)

        XCTAssertEqual(backend.activeTransactionDepth, 0,
                       "performDetachSteps must reset the counter — the same hygiene treatment " +
                       "deferredExternalChange already gets — or the leak survives into re-attach")

        // A rejected second mutation (the wedge, if the reset were missing) reports via
        // `RichTextInputContractViolation.report`, which traps in DEBUG with no reporter installed —
        // installed here so the wedge is OBSERVED, not crashed on, matching this file's own established
        // pattern (`test_operationAfterDetachIsRejectedAndPublishesNothing`).
        var reported: [String] = []
        RichTextInputContractViolation.reporter = { reported.append($0) }

        // FIX ROUND 3 follow-up: `canvas.onContentSizeChange` turned out to be an unreliable signal
        // here — the REAL canvas's own layout machinery can fire it from more than one internal path,
        // so it does not cleanly count "how many mutations actually committed". `documentRevision` is
        // the backend's OWN adopted value, moved ONLY by `runMutation`'s commit branch — a precise,
        // first-party signal that a mutation actually reached and committed through the document
        // client, not merely that some UI notification happened to fire.
        let initialRevision = backend.state.documentRevision
        reference.insertText("z")
        let revisionAfterFirst = backend.state.documentRevision
        XCTAssertGreaterThan(revisionAfterFirst, initialRevision, "the first ordinary mutation must succeed")

        reference.insertText("w")
        let revisionAfterSecond = backend.state.documentRevision

        XCTAssertGreaterThan(revisionAfterSecond, revisionAfterFirst,
                             "a SECOND, ordinary mutation must ALSO succeed and move the revision " +
                             "forward — a leaked, unreset depth would leave transactionPhase wedged " +
                             "non-idle after the FIRST mutation, and prepareAndRun's own reentrancy " +
                             "guard would then reject the second one as if it were still reentrant, " +
                             "leaving the revision unchanged")
        XCTAssertTrue(reported.isEmpty, "neither mutation should be treated as reentrant misuse; got \(reported)")
        XCTAssertEqual(backend.transactionPhase, .idle, "kept alongside the consequence above")
    }

    // MARK: - Host conformance (D23 / D24)

    /// D23: `hostInputView` is distinct from the pre-existing `UIResponder.inputView` override
    /// (`DocumentCanvasView`'s custom-keyboard hook, deliberately un-routed per D5) — both happen to
    /// vend `self`/`nil` respectively, but they answer different questions. D24: `legacyCanvas` is the
    /// one declared path from the backend to the canvas's `legacy…` hooks.
    func test_theCanvasVendsItselfAsBothHostViewAndLegacyCanvas() {
        let canvas = DocumentCanvasView()
        XCTAssertTrue(canvas.hostInputView === canvas)
        XCTAssertTrue(canvas.legacyCanvas === canvas)
        XCTAssertNil(canvas.inputView, "the UIResponder custom-keyboard hook must stay untouched by D23/D24")
    }

    // MARK: - Tokenizer cache (TASK 24 FIX ROUND 1, Major 1/2)
    //
    // The tokenizer cache moved from the canvas's own `inputTokenizer` (one canvas, one tokenizer, by
    // construction — never a reattach risk) to `LegacyRichTextInputBackend.tokenizerStorage`, which CAN
    // be reattached to a DIFFERENT canvas. (TASK 43 deleted `inputTokenizer`, which had sat dead since
    // this move, and brought the CONSTRUCTION over too — see the mutation note below.) Neither test can be satisfied through `SpyRichTextInputBackend`
    // (its `tokenizer` returns `stubbedTokenizer` unconditionally, so identity holds whether or not the
    // REAL backend caches) — both exercise the real `LegacyRichTextInputBackend` directly, which is why
    // they live here rather than in the router-spy suite.

    /// Red if `attach(to:)` ever stopped building `tokenizerStorage` eagerly (the fallback tokenizer is
    /// itself a single shared instance, so a naive identity-only check would still pass against that
    /// mutation) — the `is DocumentTokenizer` check catches it: the fallback's dynamic type is
    /// `NoOpTextInputTokenizer`, never `DocumentTokenizer`.
    ///
    /// TASK 24 RE-REVIEW (Minor, reviewer) — the previous rationale here was stale. Deleting
    /// `tokenizerStorage = built` from `attach(to:)` does NOT yield "a fresh `DocumentTokenizer`": the
    /// getter has no construction in it at all, so the read falls through to the shared
    /// `NoOpTextInputTokenizer` (caught by the `is DocumentTokenizer` check, and by this test installing
    /// no reporter so the fallback's `report` hits DEBUG's `assertionFailure`). Deleting the
    /// `if let existing = tokenizerStorage` short-circuit would not even compile. After the fix there is
    /// exactly ONE construction site for a backend-reachable tokenizer (`+Attachment.swift`), so
    /// "mint twice" is no longer expressible — the property is enforced by SHAPE, not by this assertion.
    /// If the caching clause is ever wanted in isolation from the eager-build clause, the mutation is
    /// `legacyCanvas.map { DocumentTokenizer(canvas: $0) } ?? Self.detachedFallbackTokenizer` in the
    /// getter: then `first === second` fails while `first is DocumentTokenizer` still passes.
    ///
    /// **TASK 43 FIX ROUND 1 (review Major 1) — THE SPELLING OF THAT MUTATION IS LOAD-BEARING, WHICH IS
    /// NOT A SENTENCE ANYONE EXPECTS TO WRITE.** Task 43 first wrote this note as
    /// `legacyCanvas.map(DocumentTokenizer.init(canvas:))`, and in the same commit added
    /// `InputBackendSourceBoundaryTests.test_theTokenizerHasExactlyOneConstructionSite` on a scan that
    /// could not see `Name.init(` — so the note pointed the next reader at the one construction form
    /// the new rule was blind to. The rule now catches both parenthesised spellings, and an exact
    /// mention allowance catches the three unparenthesised ones; the note is spelled the plain way
    /// regardless, because a doc comment recommending a mutation should recommend the ordinary form.
    ///
    /// EXPECT TWO REDS when you apply it, not one: it is a genuine SECOND construction site, so
    /// `test_theTokenizerHasExactlyOneConstructionSite` reddens alongside this test. That is the rule
    /// working, not collateral damage — revert both together.
    func test_tokenizerIsCachedAcrossReads() {
        let canvas = DocumentCanvasView()
        let backend = canvas.inputBackend as! LegacyRichTextInputBackend
        let first = backend.tokenizer
        let second = backend.tokenizer
        XCTAssertTrue(first is DocumentTokenizer, "the attached read path must vend the real tokenizer, not the detached fallback")
        XCTAssertTrue(first === second, "tokenizer must be cached, not rebuilt on every read")
    }

    /// Red if `performDetachSteps()` ever stopped resetting `tokenizerStorage` (Major 1): a read taken
    /// WHILE DETACHED (before any reattach) would still find the OLD cached `DocumentTokenizer` — still
    /// holding `unowned` the canvas this backend just relinquished — and return it directly, silently
    /// skipping BOTH the "no canvas attached" contract-violation report AND the safe fallback. This is
    /// the precise Major-1 hazard: `attach(to:)` REBUILDS `tokenizerStorage` unconditionally on every
    /// call, so a detach→reattach round trip alone cannot discriminate whether the reset ran (attach's
    /// own rebuild would paper over a missing reset) — the DETACHED window itself is the only place
    /// that can observe it.
    func test_tokenizerIsClearedWhileDetached_notStaleFromThePreviousAttach() {
        // A detached `tokenizer` read reports a `RichTextInputContractViolation` (per the fix's own
        // doc comment) — install a reporter, like every other test here that deliberately exercises a
        // violation path, or the default (DEBUG `assertionFailure`) crashes the test process instead
        // of letting this test observe and assert on the fallback value.
        var violations: [String] = []
        RichTextInputContractViolation.reporter = { violations.append($0) }

        let host = RecordingHost()
        let backend = LegacyRichTextInputBackend()
        try! backend.attach(to: host)
        let attachedTokenizer = backend.tokenizer
        XCTAssertTrue(attachedTokenizer is DocumentTokenizer)

        backend.detach()
        let detachedTokenizer = backend.tokenizer
        XCTAssertFalse(detachedTokenizer is DocumentTokenizer,
                       "a detached read must not vend the stale tokenizer bound to the relinquished canvas")
        XCTAssertFalse(detachedTokenizer === attachedTokenizer)
        XCTAssertEqual(violations.count, 1, "the detached read must report exactly one contract violation")
    }

    /// End-to-end companion to the test above: after a full detach → reattach (to a DIFFERENT canvas)
    /// cycle, `tokenizer` is a genuinely fresh instance bound to the NEW canvas, not the one it was
    /// attached to before.
    func test_tokenizerIsRebuiltAfterDetachAndReattachToADifferentCanvas() {
        let host1 = RecordingHost()
        let host2 = RecordingHost()
        let backend = LegacyRichTextInputBackend()
        try! backend.attach(to: host1)
        let firstTokenizer = backend.tokenizer
        XCTAssertTrue(firstTokenizer is DocumentTokenizer)

        backend.detach()
        try! backend.attach(to: host2)
        let secondTokenizer = backend.tokenizer
        XCTAssertTrue(secondTokenizer is DocumentTokenizer)

        XCTAssertFalse(firstTokenizer === secondTokenizer,
                       "reattaching to a different canvas must vend a FRESH tokenizer, not one still " +
                       "holding the previous (relinquished) canvas")
    }

    // MARK: - Pending-routing stub hygiene — RETIRED BY TASK 34
    //
    // THREE members stood here and are DELETED together, not one by one:
    //   * `test_everyPendingRoutingStubNamesTheTaskThatDeletesIt` — the vacuity rule. It asserted that
    //     the `pendingRouting(_:)` funnel DECLARATION was still present in
    //     `+PendingRouting.swift` (renamed `+Unwitnessed.swift`) as its own anti-vacuity anchor. Task
    //     34 deleted the funnel, so this rule would have failed on CORRECT source. Its own doc comment
    //     said exactly that ("TASK 34 DELETES THIS TEST … the XCTFail on an unreadable file is the
    //     signal"), and it carried the generalisation this project paid twice for, preserved verbatim
    //     at R20 (Core source-boundary suite), which is its successor:
    //
    //       "a vacuity guard anchored on a quantity a schedule is deliberately driving to zero will
    //        fire on the correct source, one step before the thing it was protecting is gone — and if
    //        the count is interesting enough to guard once, expect it to be guarded twice."
    //
    //     It was, in fact, guarded twice — rule R13 in the Core suite was the other, and neither knew
    //     about the other. R20 is deliberately ONE rule in ONE place, and that place is the CORE suite
    //     so it also runs under a bare `swift test`: this UIKit twin only ever surfaced in a full
    //     `Scripts/iostest.sh` run, which is how it went eleven tasks without being re-read.
    //   * `isLivePendingRoutingCallSite(_:)` — its line predicate, whose only consumer was that rule.
    //   * `test_isLivePendingRoutingCallSitePredicate_skipsCommentedLines` — the predicate's own
    //     self-test. **Its subject was carried forward rather than dropped**: R20's
    //     `test_thePendingRoutingResidueScanActuallyDetects_R20` pins the same "a doc comment merely
    //     MENTIONING the literal must not trip the scan" case, and covers strictly more, because R20
    //     scans `SwiftSourceScan.stripCommentsAndStringLiterals`'d text instead of a `//`-prefix
    //     heuristic — block comments included, which this predicate explicitly could not see.
}
#endif
