#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 33 — Family 10 (floating cursor and autoscroll). THREE routed backend members
/// (`beginFloatingCursor(at:)`, `updateFloatingCursor(at:)`, `endFloatingCursor()`), each with a canvas
/// witness UIKit dispatches to the first responder, plus the backend's own `floatingCursorActive` flag,
/// of which this task makes the backend the WRITER.
///
/// # There WERE two flags called `floatingCursorActive` — TASK 42 UNIFIED THEM
///
/// When this file was written `DocumentCanvasView.floatingCursorActive` was the canvas's own store (the
/// one its presentation reads — `updateCaretView()`'s dimmed landing caret, `floatingAutoScrollTick`'s
/// guard — and the one `cancelFloatingCursor()` cleared), while
/// `LegacyRichTextInputBackend.floatingCursorActive` was the backend's, and since Task 33 the ONLY flag
/// the `selectedTextRange` setter consults. **Task 42 moved the state: there is one store, on the
/// backend, and `v.floatingCursorActive` is a get-only projection of it.**
///
/// **The `v.` / `backend.` distinction in the assertions below is therefore no longer a distinction
/// between two values, and the spellings are KEPT ANYWAY.** Deliberately: each pair now reads as "the
/// backend's store, and the canvas surface still projects it", which is a real property of the collapse
/// and the thing a future task would break by re-introducing a canvas copy. Rewriting them to one
/// spelling would delete that check for no gain. What a reader must NOT do is treat a `v.`/`backend.`
/// pair as independent evidence — it is one fact asserted twice, on purpose.
///
/// # The interruption-latch tests are the point of this file
///
/// Making the backend a writer created a defect that did not exist before it: `cancelFloatingCursor()`
/// cleared only the CANVAS's flag, so an interrupted gesture (resign first responder, window removal)
/// would have left the backend's `true` forever — and with the setter's guard collapsed onto that one
/// flag, **every subsequent `selectedTextRange` write would be silently dropped for the life of the
/// editor**. No crash, no log, no build error. `+FloatingCursor.swift`'s header records the fix (the
/// three backend members that reach a canvas cancel clear the mirror too); the three
/// `…soLaterSelectionWritesAreHonoured` tests below are what pin it, and each was red without its clear.
///
/// **TASK 42 CLOSED THE HOLE AT ITS SOURCE and left those three clears in place.** With one store,
/// `cancelFloatingCursor()` clears THE flag (through the `setFloatingCursorActive(_:)` contract door), so
/// the three mirror clears are redundant on the attached path — but each is reached through an optional
/// `legacyCanvas?`, so with no canvas attached the mirror is still the only clear there is. **Those three
/// red-checks are therefore historical**: re-running them today would find the cancel's own clear masking
/// two of the three. `FloatingCursorStateAuthorityTests.test_anInterruptedGestureDoesNotLatchTheOneFlag`
/// is the post-collapse pin for the property that actually matters (a later write is honoured).
@MainActor
@available(iOS 16.0, *)
final class FloatingCursorRouterTests: XCTestCase {

    // MARK: - Fixtures

    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    /// A laid-out canvas inside a scroll view inside the key window — the floating-cursor bodies read
    /// `superview as? UIScrollView` for the auto-scroll band, and the resign test needs a real window.
    private func laidOut(_ v: DocumentCanvasView) -> DocumentCanvasView {
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Hello world")]))],
                    width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        scroll.addSubview(v)
        scroll.contentSize = v.frame.size
        window.addSubview(scroll)
        v.layoutIfNeeded()
        return v
    }

    private func spyCanvas() -> (DocumentCanvasView, SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let v = laidOut(DocumentCanvasView(inputBackend: spy))
        spy.reset()
        return (v, spy)
    }

    private func realCanvas() -> (DocumentCanvasView, LegacyRichTextInputBackend) {
        let v = laidOut(DocumentCanvasView())
        return (v, v.inputBackend as! LegacyRichTextInputBackend)
    }

    private func focused(_ v: DocumentCanvasView) -> Bool { v.becomeFirstResponder() }

    private func offset(_ v: DocumentCanvasView, _ delta: Int) -> Int { v.boxes[0].textStart + delta }

    // MARK: - Section 1: the three witnesses route, exactly once, and do no work of their own

    /// The non-routing answer is not a coincidental pass: the pre-seam body collapsed a ranged
    /// selection, dismissed the edit menu and repositioned the caret, and `RouterStateSnapshot` watches
    /// `anchor`, `head` and `dismissEditMenuCountForTesting`. A canvas that kept ANY of that fails the
    /// "did no work of its own" half even if it also forwarded.
    func test_beginFloatingCursor_routesToTheBackend() {
        let (v, spy) = spyCanvas()
        let point = CGPoint(x: 10, y: 12)
        XCTAssertRoutesOnly(v, spy, member: "beginFloatingCursor(at:)",
                            arguments: [String(describing: point)]) {
            v.beginFloatingCursor(at: point)
        }
    }

    func test_updateFloatingCursor_routesToTheBackend() {
        let (v, spy) = spyCanvas()
        let point = CGPoint(x: 44, y: 12)
        XCTAssertRoutesOnly(v, spy, member: "updateFloatingCursor(at:)",
                            arguments: [String(describing: point)]) {
            v.updateFloatingCursor(at: point)
        }
    }

    func test_endFloatingCursor_routesToTheBackend() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "endFloatingCursor()", arguments: []) {
            v.endFloatingCursor()
        }
    }

    /// **DEVIATION D2, pinned at COMPILE time.** The plan's Interfaces block spells this member
    /// `updateFloatingCursor(at:animated:)`; UIKit's real `UITextInput` requirement has no `animated:`,
    /// and both the witness and the backend member carry UIKit's spelling. The direct calls below —
    /// one on the canvas, one on the backend — do not compile against an `(at:animated:)` signature, so
    /// this test's VALUE is that it builds. The runtime assertions are incidental.
    func test_updateFloatingCursorHasNoAnimatedParameter() {
        let (v, backend) = realCanvas()
        v.setCaret(global: offset(v, 1))
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 12))
        v.updateFloatingCursor(at: .zero)
        backend.updateFloatingCursor(at: .zero)
        v.endFloatingCursor()
        XCTAssertFalse(backend.floatingCursorActive, "the gesture ended")
    }

    // MARK: - Section 2: the backend is the flag's writer

    /// The core of this task: the REAL hold-spacebar gesture (which arrives at the canvas witness) now
    /// moves the BACKEND's flag, where before Task 33 it moved only the canvas's. Both are asserted from
    /// the same drive, because the two stores must agree until Task 42 merges them.
    func test_theBackendWritesTheFloatingCursorActiveFlag() {
        let (v, backend) = realCanvas()
        v.setCaret(global: offset(v, 2))
        XCTAssertFalse(backend.floatingCursorActive, "precondition")

        v.beginFloatingCursor(at: CGPoint(x: 20, y: 12))
        XCTAssertTrue(backend.floatingCursorActive, "the backend is the writer now")
        XCTAssertTrue(v.floatingCursorActive, "and the canvas's own store still tracks it")

        v.endFloatingCursor()
        XCTAssertFalse(backend.floatingCursorActive)
        XCTAssertFalse(v.floatingCursorActive)
    }

    /// §2's collapse, exercised through the ROUTED path rather than by writing a flag directly. Before
    /// this task the `selectedTextRange` setter consulted `backendFlag || canvasFlag`, because the real
    /// gesture wrote only the canvas's; it now consults the backend's alone, and this is the test that
    /// certifies the collapse against the gesture a user actually performs.
    func test_theRoutedGestureStillSuppressesTheSelectedTextRangeSetter() {
        let (v, backend) = realCanvas()
        v.setCaret(global: offset(v, 2))
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        XCTAssertTrue(backend.floatingCursorActive, "precondition: the routed gesture set the backend's flag")
        let headBefore = v.head

        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(offset(v, 0)),
                                                DocumentTextPosition(offset(v, 4)))

        XCTAssertEqual(v.anchor, v.head, "the OS range write is dropped while the gesture owns the caret")
        XCTAssertEqual(v.head, headBefore)
        v.endFloatingCursor()
    }

    // MARK: - Section 3: the interruption latch — the defect this task had to avoid creating

    /// **THE test for §1's fix, resign arm.** Losing first responder mid-gesture reaches
    /// `cancelFloatingCursor()`, which clears the CANVAS's flag only. Without
    /// `hostWillResignFirstResponder()`'s mirror clear the backend's stays `true`, the collapsed setter
    /// guard is true forever, and this assertion fails on the *second* half: the write is silently
    /// dropped.
    func test_resignFirstResponderClearsTheBackendsFlag_soLaterSelectionWritesAreHonoured() {
        let (v, backend) = realCanvas()
        guard focused(v) else { return XCTFail("canvas must become first responder") }
        v.setCaret(global: offset(v, 2))
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        XCTAssertTrue(backend.floatingCursorActive, "precondition")

        _ = v.resignFirstResponder()

        XCTAssertFalse(v.floatingCursorActive, "the canvas's flag — cancelFloatingCursor() clears this one")
        XCTAssertFalse(backend.floatingCursorActive,
                       "the backend's mirror must be cleared too, or the setter guard latches forever")

        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(offset(v, 0)),
                                                DocumentTextPosition(offset(v, 3)))
        XCTAssertEqual(v.selFrom, offset(v, 0), "a selection write after an INTERRUPTED gesture is honoured")
        XCTAssertEqual(v.selTo, offset(v, 3))
    }

    /// **THE test for §1's fix, window-removal arm.** `willMove(toWindow: nil)` is the only teardown for
    /// the two `CADisplayLink`s and likewise reaches `cancelFloatingCursor()`.
    func test_windowRemovalClearsTheBackendsFlag_soLaterSelectionWritesAreHonoured() {
        let (v, backend) = realCanvas()
        v.setCaret(global: offset(v, 2))
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        XCTAssertTrue(backend.floatingCursorActive, "precondition")

        v.removeFromSuperview()   // willMove(toWindow: nil)

        XCTAssertFalse(v.floatingCursorActive, "the canvas's flag")
        XCTAssertFalse(backend.floatingCursorActive, "the backend's mirror")

        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(offset(v, 0)),
                                                DocumentTextPosition(offset(v, 3)))
        XCTAssertEqual(v.selFrom, offset(v, 0), "a selection write after an INTERRUPTED gesture is honoured")
        XCTAssertEqual(v.selTo, offset(v, 3))
    }

    /// The window witness carries a BRANCH (`newWindow == nil`), and the backend's mirror clear mirrors
    /// it rather than firing unconditionally: entering a window mid-gesture must NOT clear the flag, or
    /// the suppression this whole family exists for is lost while the finger is still down. Red if
    /// `hostWillMove(toWindow:)` drops the branch — MEASURED, by making that clear unconditional.
    ///
    /// **The obvious drive for this is VACUOUS, and finding that out is why the measurement matters.**
    /// The first version of this test re-parented an already-windowed canvas under a sibling view and
    /// asserted the flag survived. It passed under the mutation: **UIKit does not call
    /// `willMove(toWindow:)` at all when the view's window does not change**, so the member under test
    /// never ran and the assertion was about nothing. The canvas must therefore start OUTSIDE a window
    /// and be added to one — the same drive `ResponderRouterTests.test_willMoveToWindow_routesTheAdditionToo`
    /// uses for the same reason.
    func test_enteringAWindowMidGestureDoesNotClearTheBackendsFlag() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Hello world")]))],
                    width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        v.layoutIfNeeded()
        let backend = v.inputBackend as! LegacyRichTextInputBackend
        v.setCaret(global: offset(v, 2))
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        XCTAssertNil(v.window, "precondition: the canvas is not in a window, so the addSubview below " +
                               "really does change its window and really does reach willMove(toWindow:)")
        XCTAssertTrue(backend.floatingCursorActive, "precondition")

        window.addSubview(v)   // willMove(toWindow: non-nil)

        XCTAssertTrue(v.floatingCursorActive, "the canvas's flag — the canvas hook only cancels for a nil window")
        XCTAssertTrue(backend.floatingCursorActive, "so the backend's mirror must not clear either")
        v.endFloatingCursor()
    }

    /// The third backend member that reaches a canvas cancel. In production it is called only from
    /// `performDetachSteps()` step 2, whose hygiene reset has already cleared the backend's flag — so
    /// this clear is redundant THERE, and is present so the invariant is a property of the member rather
    /// than of its caller's ordering.
    func test_cancelActiveInteractionClearsTheBackendsFlag() {
        let (v, backend) = realCanvas()
        v.setCaret(global: offset(v, 2))
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        XCTAssertTrue(backend.floatingCursorActive, "precondition")

        backend.cancelActiveInteraction(reason: .backendDetach)

        XCTAssertFalse(v.floatingCursorActive, "the canvas's flag")
        XCTAssertFalse(backend.floatingCursorActive, "the backend's mirror")
    }

    /// The fourth cancel path, and the one that needed no new code: detach's own hygiene reset
    /// (`performDetachSteps()`) has cleared this flag since Task 22e. Asserted here so the enumeration
    /// of cancel paths in `+FloatingCursor.swift`'s header is covered end to end rather than three
    /// quarters of the way.
    func test_detachClearsTheBackendsFlag() {
        let (v, backend) = realCanvas()
        v.setCaret(global: offset(v, 2))
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        XCTAssertTrue(backend.floatingCursorActive, "precondition")

        backend.detach()

        XCTAssertFalse(backend.floatingCursorActive)
        XCTAssertFalse(v.floatingCursorActive, "detach step 2 cancels the canvas half")
    }

    // MARK: - Section 4: the detached guard (§3)

    /// All three members carry a SILENT `guard isAttached` — Task 31's settled class for OS-driven
    /// entry points (a report would be a DEBUG `assertionFailure` on a documented teardown window).
    /// The guard wraps BOTH the forward and the flag write, which is what keeps the two stores in
    /// lockstep while detached: a `begin` that reached neither cannot leave a latched mirror behind.
    ///
    /// **The MIRROR is the only half the FINAL assertion can pin, and the name says so.** An earlier
    /// version also asserted the canvas's flag there, under the name `…TouchesNeitherStore`: that
    /// assertion cannot fail either way, because `legacyCanvas` is `host?.legacyCanvas` and
    /// `performDetachSteps()` step 9 releases the weak `host`, so the forward's optional chain is `nil`
    /// for a detached backend whether or not the guard exists. **Two mechanisms, one effect, and only
    /// one of them is observable** — so the assertion promising both is gone.
    ///
    /// ┌─ **A DEAD ASSERTION WAS REPLACED WITH A DEAD ASSERTION, and that is the note worth keeping.** ─
    /// │
    /// │  The repair above shipped with a new precondition — `XCTAssertFalse(v.floatingCursorActive,
    /// │  "precondition: detach cleared the canvas half too")` — placed before any `beginFloatingCursor`
    /// │  call. `DocumentCanvasView.floatingCursorActive` defaults to `false`, so it asserted
    /// │  `false == false` about a value nothing had set, while its message claimed detach had cleared
    /// │  it. Confirmed dead by mutation: deleting the `floatingCursorActive = false` line from
    /// │  `cancelFloatingCursor()` left it **GREEN**.
    /// │
    /// │  Rule 13 says a correction is a claim and gets the same test as the sentence it corrects.
    /// │  **The test-shaped corollary: a replacement for a dead assertion must be RED-CHECKED before it
    /// │  ships** — the discipline this project already demands of every new rule, owed equally to every
    /// │  repaired test. The mutation result is the argument; there is nothing to add to it.
    /// │
    /// │  **The mechanical form to look for is "is this assertion's subject at its default value when
    /// │  the assertion runs?"** — cheap to check, and it is what the priming below fixes. It is not by
    /// │  itself a verdict: a starting-state precondition that stops a LATER assertion from passing
    /// │  spuriously is doing real work even when no mutation of the code under test reddens it (this
    /// │  file has two, at `test_theBackendWritesTheFloatingCursorActiveFlag` and
    /// │  `test_enteringAWindowMidGestureDoesNotClearTheBackendsFlag`, both kept). What was dead here was
    /// │  narrower and worse: an assertion claiming the code under test had CHANGED a value it never
    /// │  touched.
    /// └───────────────────────────────────────────────────────────────────────────────────────────────
    func test_beginFloatingCursorOnADetachedBackendDoesNotLatchTheMirror() {
        let (v, backend) = realCanvas()
        // Prime BOTH stores first, exactly as every sibling in this section does, so the post-detach
        // precondition is about what detach DID rather than about a flag nothing ever set.
        v.setCaret(global: offset(v, 2))
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        XCTAssertTrue(v.floatingCursorActive, "precondition: the gesture is live on the canvas store")
        XCTAssertTrue(backend.floatingCursorActive, "precondition: and on the backend's mirror")

        backend.detach()
        // RED-CHECKED: deleting `floatingCursorActive = false` from `cancelFloatingCursor()`
        // (`DocumentCanvasView+FloatingCursor.swift`) turns THIS line red. It was green under the same
        // mutation before the priming above was added.
        XCTAssertFalse(v.floatingCursorActive, "detach step 2 cleared the canvas half")

        backend.beginFloatingCursor(at: CGPoint(x: 30, y: 12))

        XCTAssertFalse(backend.floatingCursorActive, "a detached begin must not latch the mirror")
    }

    // MARK: - Section 5: the family's stubs are gone — TEST DELETED BY TASK 34, BOTH HALVES DEAD
    //
    // `test_noPendingRoutingStubsRemainForThisFamily` stood here. **Both of its halves were dead, and
    // they died for two DIFFERENT reasons — which is the finding worth keeping.**
    //
    //   * The first half asserted `!LegacyRichTextInputBackend.pendingRoutingInventory.contains(member)`
    //     for the family's three members. That Set was EMPTIED by this very task's own predecessor
    //     (Task 33 routed the last stubbed family), so `contains` answered `false` for every possible
    //     argument and **the assertion could not fail**. It was LIVE WHEN WRITTEN and was killed by a
    //     later, correct change SOMEWHERE ELSE. Rule 16's mechanical form — "is the subject at its
    //     default value when the assertion runs?" — does not catch that, and a red-check at authoring
    //     time would have passed. **The trigger for finding it is the EMPTYING, not the assertion:
    //     when a collection a suite asserts membership against becomes empty, every such assertion in
    //     the tree dies at once, in every file, silently.** Task 34 swept for the shape and found
    //     exactly two (the other is in `CommandRouterTests`).
    //   * The second half — drive each member, assert `pendingRoutingCalls` stayed empty — was the
    //     LIVE one, and this task killed it too: Task 34 deleted the `pendingRouting(_:)` funnel, so
    //     "no member records a call to it" is now true by construction rather than by test.
    //
    // The successor is rule R20 in the Core source-boundary suite
    // (`test_noPendingRoutingResidueRemains_R20`), which asserts the same property of
    // the SOURCE, for every file under `S/InputBackend/` at once rather than per family.
    //
    // What is NOT lost with it: this family's actual routing is pinned by Sections 1-4 above, which
    // assert through `SpyRichTextInputBackend` that each witness routes exactly once and that the
    // canvas does no work of its own — strictly more than a "no stub ran" probe ever proved.
}
#endif
