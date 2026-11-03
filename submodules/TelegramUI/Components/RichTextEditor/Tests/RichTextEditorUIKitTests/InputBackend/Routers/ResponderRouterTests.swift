#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 31 — Family 8 (responder lifecycle, edit policy, traits notification). Six canvas witnesses
/// (`canBecomeFirstResponder`, `becomeFirstResponder()`, `resignFirstResponder()`,
/// `willMove(toWindow:)`, the NEW `canResignFirstResponder` override, and `isEditable`) onto twelve
/// backend members, plus two notifications the canvas raises from its own `didSet`s
/// (`editPolicyDidChange()`, `textInputTraitsDidChange()`).
///
/// **This family is the first whose witnesses are NOT one-line routers, and the tests are shaped by
/// that.** `becomeFirstResponder()`/`resignFirstResponder()` keep `super` on the canvas and make
/// **two** backend calls each (a `hostWill…` before `super` and a `hostDid…`/`hostDidFail…` after), so
/// `XCTAssertRoutesOnly` — whose whole point is "exactly ONE backend call" — would fail for correct
/// code. Those tests assert on the filtered host-hook subsequence of `spy.calls` instead, and say so at
/// each site. The four members that ARE one-line routers (`canBecomeFirstResponder`,
/// `canResignFirstResponder`, `isEditable`, `willMove(toWindow:)`) use `XCTAssertRoutesOnly` as usual.
///
/// **Which backend each test runs against** (the handoff's rule 3):
///
///   * **Spy** for the routing-shape tests (Section 1). Note the spy's `stubbedCanBecomeFirstResponder`
///     / `stubbedCanResignFirstResponder` now gate `super` for real: routing
///     `canBecomeFirstResponder` means a spy-backed canvas cannot take focus unless the stub says it
///     may. That is signal, not an obstacle — `test_becomeFirstResponder_stillCallsSuperOnTheCanvas`
///     turns it into the proof that `super` is still consulted.
///   * **Real legacy backend** for the behavioural tests (Section 2) — the genuine-transition rule, the
///     ordering of the native-checking install relative to the host callback, and the unconditional
///     pre-resign teardown. All three are BEHAVIOUR that moved across the seam, so a spy (which
///     performs no work) could not observe them.
///
/// Every test reads through a real `DocumentCanvasView` member, never the canvas's backend property
/// (rule R14).
@MainActor
@available(iOS 16.0, *)
final class ResponderRouterTests: XCTestCase {

    // MARK: - Fixtures

    /// A REAL window, not an off-screen view: `UIResponder.becomeFirstResponder()` fails outright for a
    /// windowless view (`ResponderLifecycleCharacterizationTests
    /// .test_becomeFirstResponder_onAWindowlessView_failsAndFiresNoCallback` pins that), so every test
    /// here that exercises a SUCCESSFUL transition needs one.
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    private func laidOut(_ v: DocumentCanvasView) -> DocumentCanvasView {
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        window.addSubview(v)
        v.layoutIfNeeded()
        return v
    }

    private func spyCanvas() -> (DocumentCanvasView, SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let v = laidOut(DocumentCanvasView(inputBackend: spy))
        spy.reset()
        return (v, spy)
    }

    private func realCanvas() -> DocumentCanvasView {
        laidOut(DocumentCanvasView())
    }

    /// The responder-lifecycle subsequence of the spy's flat call log. `becomeFirstResponder()` and
    /// `resignFirstResponder()` route MORE than their own two hooks — `super` consults the routed
    /// `canBecomeFirstResponder`/`canResignFirstResponder` an unspecified number of times, and UIKit
    /// may read other witnesses while installing the keyboard — so asserting on the raw log would pin
    /// UIKit's internals rather than this seam's contract. Filtering to `host…` names keeps the
    /// assertion on exactly what Task 31 owns: which hooks fired, in which order, how many times.
    private func hostHooks(_ spy: SpyRichTextInputBackend) -> [String] {
        spy.calls.map(\.member).filter { $0.hasPrefix("host") }
    }

    // MARK: - Section 1: the spy backend

    /// `false` is deliberately NOT the non-routing answer: the canvas's own override was a literal
    /// `true`, so a router that never forwarded would read back `true` here and this assertion would be
    /// a coincidental pass (the reasoning `SpyRichTextInputBackend.stubbedCanBecomeFirstResponder`'s own
    /// comment records).
    func test_canBecomeFirstResponder_routesToTheBackend() {
        let (v, spy) = spyCanvas()
        let answer = XCTAssertRoutesOnly(v, spy, member: "canBecomeFirstResponder", arguments: []) {
            v.canBecomeFirstResponder
        }
        XCTAssertFalse(answer, "the stub is `false`, which the pre-seam literal `true` never was")
    }

    /// A **NEW** override — the canvas had none, so `UIResponder`'s own `true` applied. Same polarity
    /// argument as above: `false` cannot be the non-routing answer.
    func test_canResignFirstResponder_routesToTheBackend() {
        let (v, spy) = spyCanvas()
        let answer = XCTAssertRoutesOnly(v, spy, member: "canResignFirstResponder", arguments: []) {
            v.canResignFirstResponder
        }
        XCTAssertFalse(answer, "the stub is `false`, which `UIResponder`'s inherited `true` never was")
    }

    /// DEVIATION D3: the canvas keeps `@available(iOS 18.0, *) var isEditable` as the router; the backend
    /// member it forwards to is `isEditableForWritingTools`, deliberately UN-GATED (the iOS 13 floor —
    /// hard invariant 12). The witness is availability-gated, so the drive point here must be too.
    func test_isEditable_routesToTheBackendsUnGatedWritingToolsMember() throws {
        guard #available(iOS 18.0, *) else {
            throw XCTSkip("`isEditable` is an iOS 18+ optional `UITextInput` member")
        }
        let (v, spy) = spyCanvas()
        let answer = XCTAssertRoutesOnly(v, spy, member: "isEditableForWritingTools", arguments: []) {
            v.isEditable
        }
        XCTAssertFalse(answer, "the stub is `false`, which the pre-seam literal `true` never was")
    }

    /// The failure path. The spy's `stubbedCanBecomeFirstResponder` defaults to `false`, so `super`
    /// refuses — which is exactly the arrangement this test wants, and is itself evidence that `super`
    /// consults the ROUTED value.
    func test_becomeFirstResponder_whenSuperRefuses_firesWillThenDidFail() {
        let (v, spy) = spyCanvas()
        XCTAssertFalse(v.becomeFirstResponder())
        XCTAssertEqual(hostHooks(spy),
                       ["hostWillBecomeFirstResponder()", "hostDidFailToBecomeFirstResponder()"],
                       "a failed transition fires the will-hook and the FAIL hook, and neither the " +
                       "did-hook nor any begin-editing callback")
    }

    func test_becomeFirstResponder_whenSuperAccepts_firesWillThenDid() {
        let (v, spy) = spyCanvas()
        spy.stubbedCanBecomeFirstResponder = true
        spy.reset()
        XCTAssertTrue(v.becomeFirstResponder())
        XCTAssertEqual(hostHooks(spy),
                       ["hostWillBecomeFirstResponder()", "hostDidBecomeFirstResponder()"])
    }

    /// The brief's Step-1 requirement: **the canvas remains responsible for `super.becomeFirstResponder()`;
    /// the backend owns only the ordering AROUND it.** Both directions are asserted, because only the pair
    /// is proof: the spy performs no work at all, so the only thing that can make this view the first
    /// responder is `super`, and the only thing that can stop it is `super` honouring the routed
    /// `canBecomeFirstResponder`. A router that had swallowed `super` would answer `false`/not-focused in
    /// BOTH halves; one that ignored the routed gate would answer focused in both.
    func test_becomeFirstResponder_stillCallsSuperOnTheCanvas() {
        let (refused, refusedSpy) = spyCanvas()
        XCTAssertFalse(refusedSpy.stubbedCanBecomeFirstResponder, "precondition")
        XCTAssertFalse(refused.becomeFirstResponder())
        XCTAssertFalse(refused.isFirstResponder, "super refused, so nothing else may have granted focus")

        let (accepted, acceptedSpy) = spyCanvas()
        acceptedSpy.stubbedCanBecomeFirstResponder = true
        XCTAssertTrue(accepted.becomeFirstResponder())
        XCTAssertTrue(accepted.isFirstResponder,
                      "the spy performs no work — only `super.becomeFirstResponder()` can grant focus")
    }

    func test_resignFirstResponder_whenSuperRefuses_firesWillThenDidFail() {
        let (v, spy) = spyCanvas()
        // Never focused, so `super.resignFirstResponder()` answers false (the observed behaviour
        // `ResponderLifecycleCharacterizationTests` records at its own resign tests).
        XCTAssertFalse(v.resignFirstResponder())
        XCTAssertEqual(hostHooks(spy),
                       ["hostWillResignFirstResponder()", "hostDidFailToResignFirstResponder()"])
    }

    func test_resignFirstResponder_whenSuperAccepts_firesWillThenDid() {
        let (v, spy) = spyCanvas()
        spy.stubbedCanBecomeFirstResponder = true
        spy.stubbedCanResignFirstResponder = true
        XCTAssertTrue(v.becomeFirstResponder())
        spy.reset()
        XCTAssertTrue(v.resignFirstResponder())
        XCTAssertEqual(hostHooks(spy),
                       ["hostWillResignFirstResponder()", "hostDidResignFirstResponder()"])
    }

    /// The teardown branch — `willMove(toWindow: nil)`, which
    /// `WindowDetachCharacterizationTests` calls "the ONLY teardown for the two CADisplayLinks".
    /// `super.willMove(toWindow:)` stays on the canvas; only the `newWindow == nil` body routes.
    func test_willMoveToWindow_routesTheRemovalToTheBackend() {
        let (v, spy) = spyCanvas()
        v.removeFromSuperview()
        XCTAssertEqual(spy.calls.filter { $0.member == "hostWillMove(toWindow:)" }.map(\.description),
                       ["hostWillMove(toWindow:)(nil)"],
                       "exactly one routed call, carrying the nil window the teardown branch keys on")
    }

    /// The non-nil half, so the router is proved to forward the ARGUMENT rather than to fire only on
    /// removal — a router that hard-coded `nil`, or that only called the backend inside its own
    /// `if newWindow == nil`, would read identically to a correct one on the test above alone.
    func test_willMoveToWindow_routesTheAdditionToo() {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        spy.reset()
        window.addSubview(v)
        XCTAssertEqual(spy.calls.filter { $0.member == "hostWillMove(toWindow:)" }.map(\.description),
                       ["hostWillMove(toWindow:)(non-nil)"])
    }

    /// DEVIATION D5: the canvas notifies the backend from its `isSpellCheckingEnabled` `didSet` rather
    /// than routing the six trait witnesses. This is the spy-side half of that contract — it asserts the
    /// canvas CALLS the member, and is unaffected by the member's body being deliberately empty today.
    func test_traitsDidChangeFiresWhenSpellCheckingIsToggled() {
        let (v, spy) = spyCanvas()
        XCTAssertTrue(v.isSpellCheckingEnabled, "precondition: the default")
        v.isSpellCheckingEnabled = false
        XCTAssertEqual(spy.calls.filter { $0.member == "textInputTraitsDidChange()" }.count, 1)
    }

    /// The `didSet`'s own `guard oldValue != isSpellCheckingEnabled` is load-bearing and stays: setting
    /// the SAME value must fire nothing, or every keyboard re-read would notify the backend.
    func test_traitsDidChangeDoesNotFireWhenSpellCheckingIsSetToItsCurrentValue() {
        let (v, spy) = spyCanvas()
        v.isSpellCheckingEnabled = true   // already true
        XCTAssertEqual(spy.calls.filter { $0.member == "textInputTraitsDidChange()" }.count, 0)
    }

    /// DEVIATION D4 — the six `UITextInputTraits` witnesses deliberately do NOT route. `spellCheckingType`
    /// is the one that makes D4 load-bearing rather than cosmetic: it reads canvas state
    /// (`isSpellCheckingEnabled ? .yes : .no`), so a naive extraction onto the backend would break the
    /// spellcheck toggle. `textInputMode` (D5) is deliberately NOT read here — it is single-shot
    /// side-effecting (it consumes `initialPrimaryLanguage` on its first query) and the canvas's own
    /// doc comment bans adding a non-side-effecting read path for it, so a test that touched it would
    /// change the very state it was meant to observe.
    func test_theSixTraitWitnessesDoNotRoute() {
        let (v, spy) = spyCanvas()
        _ = v.autocorrectionType
        _ = v.spellCheckingType
        if #available(iOS 17.0, *) { _ = v.inlinePredictionType }
        _ = v.smartDashesType
        _ = v.smartQuotesType
        _ = v.smartInsertDeleteType
        XCTAssertEqual(spy.calls.map(\.description), [],
                       "D4: the six traits answer from the canvas; none of them may reach the backend")
    }

    /// `spellCheckingType`'s value half, so D4's "reads canvas state" claim is pinned and not merely
    /// asserted in a comment.
    func test_spellCheckingTypeStillTracksTheCanvasToggle() {
        let v = realCanvas()
        XCTAssertEqual(v.spellCheckingType, .yes)
        v.isSpellCheckingEnabled = false
        XCTAssertEqual(v.spellCheckingType, .no)
    }

    /// The `editPolicy` `didSet` has called this since Task 20; Task 31 only moves the member's body
    /// out of the file Task 34 renamed `+Unwitnessed.swift`. Asserted here so the family's routing
    /// table is complete in one place. The `didSet`'s inequality guard is asserted in the same test,
    /// for the same reason as the traits one above.
    func test_editPolicyDidChangeFiresOnceWhenThePolicyActuallyChanges() {
        let (v, spy) = spyCanvas()
        v.editPolicy = RichTextInputEditPolicy(
            isEditable: false, isSelectable: true, allowsRichText: true,
            allowsPaste: true, allowsDictation: true, allowsWritingTools: true)
        XCTAssertEqual(spy.calls.filter { $0.member == "editPolicyDidChange()" }.count, 1)
        let unchanged = v.editPolicy
        v.editPolicy = unchanged   // the same value again
        XCTAssertEqual(spy.calls.filter { $0.member == "editPolicyDidChange()" }.count, 1,
                       "the didSet's `guard editPolicy != oldValue` still gates the notification")
    }

    // MARK: - Section 2: the real legacy backend — behaviour that moved across the seam

    /// The two Bool getters answer TODAY's values, not the stub's `false`. `canBecomeFirstResponder` was
    /// a literal `true` on the canvas; `canResignFirstResponder` had no override at all, so
    /// `UIResponder`'s documented `true` applied and the new override must reproduce it.
    func test_theRoutedResponderGettersStillAnswerTrue() {
        let v = realCanvas()
        XCTAssertTrue(v.canBecomeFirstResponder, "there is no edit policy gate today")
        XCTAssertTrue(v.canResignFirstResponder, "the NEW override must match UIResponder's default")
    }

    func test_isEditableStillAnswersTrue() throws {
        guard #available(iOS 18.0, *) else {
            throw XCTSkip("`isEditable` is an iOS 18+ optional `UITextInput` member")
        }
        XCTAssertTrue(realCanvas().isEditable, "Writing Tools must still see an editable view")
    }

    /// **The genuine-transition rule, which is the half of this family that MOVED.** `wasFirstResponder`
    /// used to be a local captured before `super` inside `becomeFirstResponder()`; it is now backend
    /// state captured in `hostWillBecomeFirstResponder()` at the same instant. A repeat call must still
    /// fire no host hook.
    func test_theGenuineTransitionRuleMovesIntoTheBackendUnchanged() {
        let v = realCanvas()
        var became = 0
        v.onBecameFirstResponder = { became += 1 }
        XCTAssertTrue(v.becomeFirstResponder())
        XCTAssertEqual(became, 1)
        XCTAssertTrue(v.becomeFirstResponder(), "a repeat call still succeeds")
        XCTAssertEqual(became, 1, "…but it is not a transition, so the host hook must not fire again")

        var resigned = 0
        v.onResignedFirstResponder = { resigned += 1 }
        XCTAssertTrue(v.resignFirstResponder())
        XCTAssertEqual(resigned, 1)
        XCTAssertFalse(v.resignFirstResponder(), "already not focused")
        XCTAssertEqual(resigned, 1, "…and that is not a transition either")
    }

    /// **The repeat-become assertion the suite did not have** — the defect the brief's own
    /// decomposition would have introduced, and the reason `didJustBecomeFirstResponder = true` must
    /// stay INSIDE the transition gate rather than moving into the unconditional post-hook.
    ///
    /// It is not hypothetical. The chat composer focuses the editor on touch-DOWN
    /// (`ChatTextInputPanelNode`'s `TouchDownGestureRecognizer` → `ensureFocusedOnTap()` →
    /// `RichTextEditorChatInputNode.makeInputFirstResponder()` → `RichTextEditorView.becomeFirstResponder()`
    /// → this canvas), and not one of those hops tests `isFirstResponder` first — the panel's touch-down
    /// handler branches on `isInputFirstResponder == true` and calls `ensureFocusedOnTap()` ANYWAY, just
    /// deferred. So every touch on an already-focused composer is a repeat `becomeFirstResponder()`.
    /// `performSingleTap` then reads this flag and computes
    /// `wasFirstResponder = wasFirstResponderAtEntry && !justFocused`; with the flag wrongly `true`
    /// every such tap is classified as FOCUSING and the edit menu stops toggling.
    ///
    /// The three pre-existing assertions on this flag (`ResponderLifecycleCharacterizationTests` at
    /// first-become, post-resign and windowless-failure) do not cover a repeat become.
    func test_aRepeatBecomeFirstResponderDoesNotSetTheFocusingTapFlag() {
        let v = realCanvas()
        XCTAssertTrue(v.becomeFirstResponder())
        XCTAssertTrue(v.didJustBecomeFirstResponder, "precondition: the genuine transition sets it")
        v.didJustBecomeFirstResponder = false   // consumed, exactly as `performSingleTap` consumes it
        XCTAssertTrue(v.isFirstResponder, "precondition: still focused, so the next call is a REPEAT")
        XCTAssertTrue(v.becomeFirstResponder())
        XCTAssertFalse(v.didJustBecomeFirstResponder,
                       "a repeat become is not a focus transition: setting the flag here would make " +
                       "every tap in a focused chat composer read as a focusing tap, and the edit " +
                       "menu would stop toggling")
    }

    /// **The ordering half.** In the pre-seam body the native-checking install segment
    /// (`installNativeCheckingIfNeeded()`, `nativeChecker?.preheat()`, `lastCheckedCaret = head`) runs
    /// AFTER `onBecameFirstResponder?()`, and `onBecameFirstResponder` is a public host callback the
    /// chat composer sets and drives on every touch-down, so it can do arbitrary synchronous work. That
    /// makes the order observable in principle, which under a zero-behaviour-change phase is enough to
    /// preserve it rather than argue it inert.
    ///
    /// `lastCheckedCaret` is the observable: it starts `nil` and is written only by that last segment.
    func test_becomeFirstResponder_runsTheNativeCheckingInstallAfterTheHostCallback() {
        let v = realCanvas()
        XCTAssertNil(v.lastCheckedCaret, "precondition: nothing has seeded it yet")
        var callbackRan = false
        var lastCheckedCaretAtCallback: Int?
        v.onBecameFirstResponder = { [unowned v] in
            callbackRan = true
            lastCheckedCaretAtCallback = v.lastCheckedCaret
        }
        XCTAssertTrue(v.becomeFirstResponder())
        XCTAssertTrue(callbackRan, "precondition: the host callback fired at all")
        XCTAssertNil(lastCheckedCaretAtCallback,
                     "the install segment must still run AFTER the host callback, not before it")
        XCTAssertEqual(v.lastCheckedCaret, v.head, "…and it must still run")
    }

    /// The resign side is ASYMMETRIC to the become side and that is the interesting part: the pre-resign
    /// work (`finalizeMarkedText`, `breakUndoCoalescing`, `cancelFloatingCursor`) runs BEFORE the
    /// `wasFirstResponder` capture and before `super`, and is therefore NOT gated on the resign
    /// succeeding. Pinned here because the routing had to preserve it and nothing else asserts the
    /// unconditional half.
    func test_resignFirstResponder_whenNeverFocused_stillRunsThePreResignTeardown() {
        let v = realCanvas()
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        XCTAssertTrue(v.floatingCursorActive, "precondition")
        XCTAssertFalse(v.resignFirstResponder(), "never focused, so super refuses")
        XCTAssertFalse(v.floatingCursorActive,
                       "the pre-resign teardown runs before super and is not gated on its result")
    }

    /// The resign post-hook's flag write is UN-gated where become's is gated — the asymmetry stated as a
    /// test rather than only in a comment. `didJustBecomeFirstResponder = false` must happen on any
    /// successful resign.
    func test_resignFirstResponder_clearsTheFocusingTapFlagOnEverySuccessfulResign() {
        let v = realCanvas()
        XCTAssertTrue(v.becomeFirstResponder())
        XCTAssertTrue(v.didJustBecomeFirstResponder, "precondition")
        XCTAssertTrue(v.resignFirstResponder())
        XCTAssertFalse(v.didJustBecomeFirstResponder)
    }
}
#endif
