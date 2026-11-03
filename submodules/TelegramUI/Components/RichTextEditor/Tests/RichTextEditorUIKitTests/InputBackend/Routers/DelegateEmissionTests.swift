#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 26 — Family 3, the EMISSION half: the backend is now the package's only sender of
/// `UITextInputDelegate` notifications, and `suppressesSelectionNotifications` is the one flag
/// gating them.
///
/// Two independent angles, deliberately:
///   * `InputBackendSourceBoundaryTests.test_onlyTheBackendSendsInputDelegateNotifications` (rule
///     R16) is the STATIC angle — no file under `Sources/` outside
///     `LegacyRichTextInputBackend+Notifications.swift` may even contain a send.
///   * this suite is the DYNAMIC angle — with a backend that emits nothing, a real edit produces no
///     delegate traffic at all, which is only true if the canvas has no emitter left of its own.
///
/// Backend choice per test, and therefore the assertion shape (see `SelectionRouterTests`' header for
/// the general rule): the "only emitter" test runs BOTH backends and compares; the flag-ownership test
/// runs against the SPY (whose `suppressesSelectionNotifications` is inert storage, so a read-through
/// failure is unambiguous); the asymmetry tests run against the REAL backend, because the asymmetry
/// they pin IS the real backend's behavior.
@MainActor
@available(iOS 16.0, *)
final class DelegateEmissionTests: XCTestCase {

    private func makeCanvas(_ backend: (any RichTextInputBackend)? = nil) -> DocumentCanvasView {
        let v = DocumentCanvasView(inputBackend: backend)
        v.setParagraphs([
            ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Beta")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    private func delegateKinds(_ recorder: RichTextInputEventRecorder) -> [RichTextInputRecordedEventKind] {
        recorder.kinds.filter {
            $0 == .textWillChange || $0 == .selectionWillChange
                || $0 == .selectionDidChange || $0 == .textDidChange
        }
    }

    // MARK: - 1. The backend is the only emitter

    /// The brief asks for "the backend's own emission counter equals the delegate's received count".
    /// There is no such counter, and adding one to production code purely to be counted would be a
    /// weaker test than this: a backend that emits NOTHING is substituted for the real one, and the
    /// SAME edit through the SAME canvas then produces zero delegate events. If any emitter survived
    /// on the canvas, the spy arm would still see its notifications. The spy's own bracket log is the
    /// non-vacuity control — it proves the edit really did reach a bracket rather than being skipped.
    ///
    /// RED IF: any one of the 44 converted sites were restored to an inline
    /// `inputDelegate?.…Change(self)` — the spy arm's `delegateKinds` would stop being empty.
    /// Verified red against exactly that mutation, on `+Editing.swift`'s `editing` bracket.
    func test_theBackendIsTheOnlyDelegateEmitter() {
        // Arm A: a backend that emits nothing.
        let spy = SpyRichTextInputBackend()
        let spyCanvas = makeCanvas(spy)
        let spyRecorder = RichTextInputEventRecorder()
        spyRecorder.attach(canvas: spyCanvas)
        spyCanvas.setCaret(global: spyCanvas.boxes[0].textStart + 1)
        spy.reset(); spyRecorder.reset()
        spyCanvas.editing { spyCanvas.applyReplaceOutcome(globalFrom: spyCanvas.head, globalTo: spyCanvas.head, text: "x") }

        XCTAssertEqual(delegateKinds(spyRecorder), [],
                       "with a non-emitting backend installed, one full edit must produce NO delegate " +
                       "traffic — any event here is an emitter still living on the canvas")
        XCTAssertTrue(spy.calls.contains { $0.member == "notifyingContentAndSelectionChange" },
                      "control: the edit must actually have reached a backend bracket, or the empty " +
                      "assertion above is vacuous")

        // Arm B: the real backend, same canvas shape, same edit.
        let realCanvas = makeCanvas()
        let realRecorder = RichTextInputEventRecorder()
        realRecorder.attach(canvas: realCanvas)
        realCanvas.setCaret(global: realCanvas.boxes[0].textStart + 1)
        realRecorder.reset()
        realCanvas.editing { realCanvas.applyReplaceOutcome(globalFrom: realCanvas.head, globalTo: realCanvas.head, text: "x") }

        XCTAssertEqual(delegateKinds(realRecorder),
                       [.textWillChange, .selectionWillChange, .selectionDidChange, .textDidChange],
                       "the real backend emits the full bracket for the same edit — the contrast that " +
                       "makes arm A's emptiness mean 'the canvas has no emitter', not 'nothing ran'")
    }

    /// The delegate itself has no canvas-side storage left: installing it through `canvas.inputDelegate`
    /// reaches the backend, and clearing it there silences the emitters.
    func test_theDelegateIsStoredOnTheBackendAndClearingItSilencesEveryBracket() {
        let v = makeCanvas()
        let spy = InputDelegateSpy()
        v.inputDelegate = spy
        v.setCaret(global: v.boxes[1].textStart)
        XCTAssertEqual(spy.selectionWillChangeCount, 1)

        v.inputDelegate = nil
        v.setCaret(global: v.boxes[0].textStart)
        XCTAssertEqual(spy.selectionWillChangeCount, 1,
                       "a cleared delegate must receive nothing more — proving the emitters read the " +
                       "backend's storage, not a canvas-side copy taken at install time")
    }

    // MARK: - 2. `suppressesSelectionNotifications` is the backend's flag

    /// **TASK 43 — the forwarder this test was written for is GONE.** It read
    /// `DocumentCanvasView.coalescingSelectionNotifications` (a Task-26 computed forwarder) in both
    /// directions. Task 43 deleted that property from `Sources/`, so the canvas's gesture entry points
    /// name `inputBackend.suppressesSelectionNotifications` directly and there is no canvas-side
    /// spelling left to read through. The assertions are re-pointed at the backend rather than at the
    /// (test-target-only) shim in `Support/CanvasCoalescingTestAccess.swift` — leaning on the shim
    /// here would make this suite assert a fact about the TEST target. The test is RENAMED, because
    /// what it can still prove is narrower than what it used to.
    ///
    /// **FIX ROUND 1 (review Minor 1) — WHAT THIS TEST IS FOR, now that it can no longer be what it
    /// was.** The first re-point kept a RED-IF sentence claiming this pins "must READ THROUGH, not
    /// shadow" — a fact the body no longer asserted, because the canvas-side spelling it read through
    /// is deleted. Worse, the two surviving assertions were verbatim what
    /// `DelegateOwnershipTests.test_coalescingFlagIsStoredOnlyInTheBackend` already asserts. A
    /// duplicated body under a comment describing coverage it does not provide is worse than either
    /// problem alone.
    ///
    /// **The fact this suite uniquely owns is ROUTING, not storage.** It builds the canvas around an
    /// INJECTED `SpyRichTextInputBackend`, so it proves the gesture entry points write *whatever
    /// backend is installed* — reached through the `inputBackend` existential, not a concrete or
    /// captured one. `DelegateOwnershipTests` runs against the REAL `LegacyRichTextInputBackend` and
    /// proves the opposite half: where the flag is STORED (`Mirror`). Neither subsumes the other, and
    /// the assertion below is now written to fail for the routing reason: a spy that never sees the
    /// write is a canvas that stopped routing.
    ///
    /// **The no-shadow fact moved to a source rule, which is where it belongs.** A canvas-side
    /// computed shadow is invisible to a `Mirror` and, now that no canvas property forwards, invisible
    /// to any runtime read too. `InputBackendSourceBoundaryTests`
    /// `.test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` catches it in BOTH directions
    /// because its allowance is an EXACT dictionary: a shadow that caches the backend value adds a
    /// 5th `suppressesSelectionNotifications` mention, and a pure shadow that never consults the
    /// backend at all drops `DocumentCanvasView.swift` from 3 to 2. Either way it reddens.
    ///
    /// RED IF: `beginCoalescedSelectionDrag()`/`endCoalescedSelectionDrag()` stop routing to the
    /// installed backend — a hard-coded backend, a captured one, or a canvas-side copy written
    /// instead. NOT red if the flag merely moves storage: that is the other test's job.
    func test_suppressesSelectionNotificationsIsRoutedToTheInstalledBackend() {
        let spy = SpyRichTextInputBackend()
        let v = makeCanvas(spy)

        v.beginCoalescedSelectionDrag()
        XCTAssertTrue(spy.suppressesSelectionNotifications,
                      "beginCoalescedSelectionDrag must write THE INSTALLED backend's flag — this "
                      + "canvas was built around an injected spy, so a green here proves the write "
                      + "went through the `inputBackend` existential and not to some other instance")

        v.endCoalescedSelectionDrag()
        XCTAssertFalse(spy.suppressesSelectionNotifications,
                       "and so must the clear; its own `guard` reads the same flag on the same "
                       + "installed backend, so a write that reached a different instance would leave "
                       + "the drag permanently open")
    }

    // MARK: - 3. The three asymmetries, re-asserted at the level Task 26 moved them to

    /// `moveFloatingCaret` brackets even while a coalesced drag suppresses the three selection funnels.
    /// The golden trace pins each half separately; this pins the CONTRAST in one run, so a change that
    /// made both behave the same way (either way) fails here even if someone re-recorded one trace.
    func test_moveFloatingCaretIgnoresSuppression() {
        let v = makeCanvas()
        let spy = InputDelegateSpy()
        v.inputDelegate = spy
        v.beginCoalescedSelectionDrag()

        v.setSelectionHead(global: v.boxes[0].textStart + 2)
        XCTAssertEqual(spy.selectionWillChangeCount, 0,
                       "the funnel is suppressed while coalescing")

        v.moveFloatingCaret(toGlobal: v.boxes[0].textStart + 3)
        XCTAssertEqual(spy.selectionWillChangeCount, 1,
                       "moveFloatingCaret brackets anyway — the documented asymmetry")
        XCTAssertEqual(spy.selectionDidChangeCount, 1)

        v.endCoalescedSelectionDrag()
    }

    /// SELF-DISCLOSED POLICY, PINNED (Task 26 replaced one of the brief's five brackets with this one):
    /// `notifyingSelectionChangeIgnoringCoalescing`. NINE canvas sites emit an unconditional selection
    /// bracket today; routing them through the SUPPRESSED bracket would have changed their behavior
    /// during a coalesced drag. The brief's name for the unsuppressed bracket — `notifyingFloatingCaretMove`
    /// — fitted exactly one of the nine, so FIX ROUND 1 (review m2, coordinator ruling) dropped that
    /// name from the contract and moved its rationale to `moveFloatingCaret`'s own call site.
    /// `applySelection` and `selectImage` stand in for the eight non-floating sites here — one that
    /// never touches a structural selection and one that does; `test_moveFloatingCaretIgnoresSuppression`
    /// above covers the ninth.
    ///
    /// RED IF: either site were routed through `notifyingSelectionChange` — both counts would read 0.
    /// Verified red against exactly that mutation on `applySelection`.
    func test_theUnsuppressedSelectionBracketIsNotSuppressedByCoalescing() {
        let v = makeCanvas()
        let spy = InputDelegateSpy()
        v.inputDelegate = spy
        v.beginCoalescedSelectionDrag()

        v.applySelection(from: v.boxes[0].textStart, to: v.boxes[0].textStart + 3)
        XCTAssertEqual(spy.selectionWillChangeCount, 1,
                       "applySelection never consulted the coalescing flag before Task 26 and must not now")
        XCTAssertEqual(spy.selectionDidChangeCount, 1)

        v.endCoalescedSelectionDrag()
    }

    // MARK: - 4. Hazard C3: the coalescing flag's didSet flush vs endCoalescedSelectionDrag's bracket

    /// `endCoalescedSelectionDrag` clears the flag BEFORE firing its one bracket, and the flag is now
    /// the backend's — whose `didSet` flushes a publish that `setSelection` deferred during the
    /// suppressed run. That flush is reachable for the first time in this task, because the routed
    /// `selectedTextRange` setter is exactly what calls `setSelection` while suppressed.
    ///
    /// The resulting ORDER is pinned here rather than left to chance: the deferred publish's
    /// `onSelectionChange` lands BEFORE the resync bracket. Nothing is invented — the publish is the
    /// one the setter deferred, not a new event; a suppressed run simply moves it from the setter to
    /// the drag's end, which is what "coalesced" means.
    ///
    /// `RichTextInputEventRecorder` (not `InputDelegateSpy`) is deliberate: it is the only observer in
    /// this tree that gives delegate events and canvas hooks ONE shared ordinal, which is what makes
    /// the relative order observable at all. An earlier version of this test used separate counters and
    /// could NOT discriminate — the mutation below passed against it.
    ///
    /// RED IF: `endCoalescedSelectionDrag` fired its bracket before clearing the flag — the flush would
    /// land after the bracket instead of before. Verified red against exactly that reordering; the
    /// observed order became [selectionWillChange, selectionDidChange, canvasSelectionChanged].
    func test_endCoalescedSelectionDrag_flushesTheDeferredPublishBeforeItsResyncBracket() {
        let v = makeCanvas()
        let recorder = RichTextInputEventRecorder()
        recorder.attach(canvas: v)

        v.beginCoalescedSelectionDrag()
        recorder.reset()
        let target = v.boxes[1].textStart
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(target), DocumentTextPosition(target))
        XCTAssertEqual(recorder.kinds, [],
                       "the setter emits no delegate notifications (golden trace row 21) and its own " +
                       "publish is DEFERRED during the suppressed run — that deferral is the " +
                       "precondition this test exists to exercise")

        v.endCoalescedSelectionDrag()
        XCTAssertEqual(recorder.kinds,
                       [.canvasSelectionChanged, .selectionWillChange, .selectionDidChange],
                       "clearing the flag flushes the one deferred publish FIRST, then the single " +
                       "resync bracket fires")
    }
}
#endif
