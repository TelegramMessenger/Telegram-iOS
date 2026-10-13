#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 42 — **the backend is the single writable FLOATING-CURSOR authority.** The third suite in the
/// `SelectionAuthorityTests` (Task 35/40b) / `MarkedStateAuthorityTests` (Task 41) family, for the three
/// state properties that used to live on `DocumentCanvasView`: `floatingCursorActive`,
/// `floatingCursorPoint` and `floatingScrollVelocity`.
///
/// **`floatingScrollLink` does NOT move, and that is the load-bearing half of this task.** A
/// `CADisplayLink` is a presentation/timing resource that RETAINS ITS TARGET; `willMove(toWindow: nil)`
/// is the only teardown for it (`WindowDetachCharacterizationTests` is the Task-6 retain-cycle guard),
/// and a link owned by an object with a different lifetime than the view it scrolls is exactly the
/// cycle that guard exists to catch. `test_theDisplayLinkStaysOwnedByTheCanvas` asserts it by name, in
/// both directions.
///
/// # THIS SUITE'S FIRST JOB IS THE HAZARD TASK 32 WROTE DOWN AND DATED TO THIS TASK
///
/// `LegacyRichTextInputBackend+Attachment.swift` has carried, since Task 32, the sentence *"The note
/// above becomes correct at TASK 42, which unifies them; at that point the reset must move to after
/// step 2, or the transient shadow caret survives detach exactly as described."* The mechanism:
///
///   * `performDetachSteps()` step 1's hygiene block cleared `floatingCursorActive` BEFORE step 2;
///   * step 2 (`cancelActiveInteraction(reason:)`) forwards to `DocumentCanvasView.cancelFloatingCursor()`;
///   * that method is `stopFloatingAutoScroll(); guard floatingCursorActive else { return };
///     floatingCursorActive = false; transientCaretView.hide(animated: false)`.
///
/// While the two stores were separate the early reset could not reach that guard. **Unifying them makes
/// it reach**: the guard sees `false`, returns early, and `transientCaretView.hide()` never runs — a
/// stuck BRIGHT caret surviving detach, with the auto-scroll link still correctly torn down (the
/// `stopFloatingAutoScroll()` above the guard is unconditional), so nothing else looks wrong.
///
/// `test_detachHidesTheTransientCaret` is that hazard, and it was built and RUN RED before the reset was
/// moved. The measured failure, with the stores unified and the reset still at step 1:
///
///     FloatingCursorStateAuthorityTests.test_detachHidesTheTransientCaret : XCTAssertTrue failed -
///     detach must hide the transient shadow caret …
///
/// # The un-latching, not just the value (coordinator supplement §2)
///
/// This is a TWO-STORE COLLAPSE, not a move into an empty home: the backend's `floatingCursorActive`
/// has existed since Task 22e and Task 33 gave it six writers, three of which are MIRROR CLEARS whose
/// only job is to stop the flag LATCHING after an interrupted gesture (a latched flag makes the
/// `selectedTextRange` setter drop every OS selection write for the life of the editor, silently).
/// With one store those three clears become redundant with `cancelFloatingCursor()`'s own — they are
/// KEPT. `test_anInterruptedGestureDoesNotLatchTheOneFlag` drives all three paths and asserts the thing
/// that actually matters at each: a `selectedTextRange` write AFTER the interruption is honoured.
///
/// **FIX ROUND 1 (review Major 1) — this header said they are kept "because `legacyCanvas` is optional
/// at every one of them", and that is FALSE for one of the three.** `hostWillResignFirstResponder()`
/// binds `let canvas = legacyCanvas` in its `guard` and returns BEFORE its clear, so on a canvas-less
/// backend it clears nothing; only `cancelActiveInteraction(reason:)` and `hostWillMove(toWindow:)`
/// reach their clears through an optional forward. The per-path table lives at the flag's declaration
/// (`LegacyRichTextInputBackend.swift`); the corrected reason for the resign clear is the other one —
/// the invariant is a property of the MEMBER — and its canvas-less case is unreachable because its one
/// `Sources/` caller is `DocumentCanvasView.resignFirstResponder()` and the canvas IS its own host.
///
/// **And NONE of the three was pinned by anything.** The reviewer deleted all three and ran the full
/// suite: `2303 UIKit / 5 skipped + 383 Core, exit 0`. `cancelFloatingCursor()`'s own clear masks every
/// one of them on the attached path. `test_theMirrorClearsAreTheOnlyClearOnACanvaslessBackend` below is
/// the behavioural pin for the two that are observable at all, and
/// `InputBackendSourceBoundaryTests.test_theFloatingCursorMirrorClearsArePresent_R21` is the
/// source-level MUST-CONTAIN rule that covers all three including the resign one.
@MainActor
@available(iOS 16.0, *)
final class FloatingCursorStateAuthorityTests: XCTestCase {

    // MARK: - Fixtures

    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    /// A laid-out canvas inside a scroll view inside the key window — the floating-cursor bodies read
    /// `superview as? UIScrollView` for the auto-scroll band (`viewportRect()`), and the resign arm
    /// needs a real window. Same shape as `FloatingCursorRouterTests.laidOut`.
    @discardableResult
    private func laidOut(_ v: DocumentCanvasView) -> DocumentCanvasView {
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Hello world")]))],
                    width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.addSubview(v)
        scroll.contentSize = v.frame.size
        window.addSubview(scroll)
        v.layoutIfNeeded()
        return v
    }

    private func realCanvas() -> (DocumentCanvasView, LegacyRichTextInputBackend) {
        let v = laidOut(DocumentCanvasView())
        return (v, v.inputBackend as! LegacyRichTextInputBackend)
    }

    private func offset(_ v: DocumentCanvasView, _ delta: Int) -> Int { v.boxes[0].textStart + delta }

    /// `RichTextInputContractViolation.report` is an `assertionFailure` in DEBUG unless a reporter is
    /// installed, so an unexpected violation would be a TEST TRAP rather than a readable failure.
    ///
    /// **USED BY ONE TEST, `test_detachHidesTheTransientCaret`, and that is deliberate** (TASK 42 FIX
    /// ROUND 1, review Minor 3 — the task report claimed it wrapped every arm in sections B and C,
    /// which was false and is corrected there). It belongs where a member that REPORTS could plausibly
    /// run: detach drives nine steps including the marked-text and interaction teardown. The section-C
    /// tests drive only members that are documented as SILENT when detached or canvas-less
    /// (`beginFloatingCursor`/`updateFloatingCursor`/`endFloatingCursor` carry Task 31 §6's silent
    /// `guard isAttached`; `cancelActiveInteraction`, `hostWillMove` and `hostWillResignFirstResponder`
    /// report nothing at all), so there is nothing for a reporter to capture and a wrapper would read
    /// as protection it is not providing. A future arm that drives a REPORTING member should use it.
    private func capturingContractViolations(_ body: () -> Void) -> [String] {
        var captured: [String] = []
        let previous = RichTextInputContractViolation.reporter
        RichTextInputContractViolation.reporter = { captured.append($0) }
        defer { RichTextInputContractViolation.reporter = previous }
        body()
        return captured
    }

    // MARK: - Section A — the authority moved

    /// The runtime half of the rule, and the half a text scan structurally cannot do: re-introducing
    /// `var floatingCursorActive = false` on the canvas is a DECLARATION, and
    /// `SwiftSourceScan.inputStateWriteCount` skips declarations on purpose.
    ///
    /// The Mirror is checked against two known-stored canvas properties FIRST — a typo'd name reports
    /// "no stored property" exactly as convincingly as a moved one, which would make every negative
    /// below vacuous.
    func test_floatingCursorActiveIsStoredOnlyInTheBackend() {
        let (v, backend) = realCanvas()
        let canvasLabels = Set(Mirror(reflecting: v).children.compactMap(\.label))

        XCTAssertTrue(canvasLabels.contains("lastLayoutWidth"),
                      "control: the Mirror must see DocumentCanvasView's own stored properties, or "
                      + "every assertion below is vacuous — saw \(canvasLabels.count) labels")
        XCTAssertTrue(canvasLabels.contains("quoteStyle"), "control, second stored property")

        for name in ["floatingCursorActive", "floatingCursorPoint", "floatingScrollVelocity"] {
            XCTAssertFalse(canvasLabels.contains(name),
                           "`\(name)` is STORAGE on the canvas — a second writable floating-cursor "
                           + "authority. Task 42's whole subject is that there is exactly one, and it "
                           + "is the backend.")
        }

        let backendLabels = Set(Mirror(reflecting: backend).children.compactMap(\.label))
        XCTAssertTrue(backendLabels.contains("isAttached"),
                      "control: the Mirror must see the backend's own stored properties — saw "
                      + "\(backendLabels.count) labels")
        for name in ["floatingCursorActive", "floatingCursorPoint", "floatingScrollVelocity"] {
            XCTAssertTrue(backendLabels.contains(name),
                          "`\(name)` must be STORAGE on the backend — it is the one authority")
        }
    }

    /// The brief's explicit non-move, asserted in BOTH directions. `floatingScrollLink` retains its
    /// target; `willMove(toWindow: nil)` must keep being able to invalidate it from the canvas, and the
    /// backend must not hold one at all (a link whose lifetime is the backend's, not the view's, is the
    /// retain cycle Task 6 pinned, re-homed).
    func test_theDisplayLinkStaysOwnedByTheCanvas() {
        let (v, backend) = realCanvas()
        let canvasLabels = Set(Mirror(reflecting: v).children.compactMap(\.label))
        XCTAssertTrue(canvasLabels.contains("floatingScrollLink"),
                      "the CADisplayLink is a presentation/timing resource and must STAY canvas "
                      + "storage — `willMove(toWindow:)` is its only teardown. Saw "
                      + "\(canvasLabels.count) labels.")

        for child in Mirror(reflecting: backend).children {
            XCTAssertFalse(child.value is CADisplayLink,
                           "the backend holds a CADisplayLink (`\(child.label ?? "?")`) — a display "
                           + "link retains its target, and one owned by the backend outlives the view "
                           + "it scrolls. The backend owns the STATE; the canvas owns the link.")
        }
        XCTAssertFalse(Set(Mirror(reflecting: backend).children.compactMap(\.label))
                        .contains("floatingScrollLink"),
                       "`floatingScrollLink` must not exist on the backend by name either")
    }

    /// The canvas keeps READ-ONLY projections of the three moved properties, for the ~6 test files and
    /// the ~9 canvas read sites that name them. They must be the SAME state, not a parallel copy that
    /// happens to agree: the writes below go through the backend's raw doors with no canvas-side
    /// notification of any kind, and are read back through the canvas.
    func test_theCanvasProjectionMatchesTheBackend() {
        let (v, backend) = realCanvas()
        XCTAssertFalse(v.floatingCursorActive, "control: nothing is floating on a fresh canvas")
        XCTAssertEqual(v.floatingCursorPoint, .zero)
        XCTAssertEqual(v.floatingScrollVelocity, 0, accuracy: 0.0001)

        backend.setFloatingCursorActive(true)
        backend.setFloatingCursorPoint(CGPoint(x: 12, y: 34))
        backend.setFloatingScrollVelocity(-7.5)
        XCTAssertTrue(v.floatingCursorActive, "the canvas must PROJECT the backend's store")
        XCTAssertEqual(v.floatingCursorPoint, CGPoint(x: 12, y: 34))
        XCTAssertEqual(v.floatingScrollVelocity, -7.5, accuracy: 0.0001)

        backend.setFloatingCursorActive(false)
        backend.setFloatingCursorPoint(.zero)
        backend.setFloatingScrollVelocity(0)
        XCTAssertFalse(v.floatingCursorActive)

        // …and the REAL gesture lands in the same one store.
        v.setCaret(global: offset(v, 2))
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        XCTAssertTrue(backend.floatingCursorActive, "control: the gesture is live")
        XCTAssertEqual(v.floatingCursorActive, backend.floatingCursorActive)
        XCTAssertEqual(v.floatingCursorPoint, backend.floatingCursorPoint,
                       "the projection and the store must be the same state")
        v.updateFloatingCursor(at: CGPoint(x: 150, y: 5))   // into the top auto-scroll band
        XCTAssertEqual(v.floatingCursorPoint, backend.floatingCursorPoint)
        XCTAssertEqual(v.floatingScrollVelocity, backend.floatingScrollVelocity, accuracy: 0.0001)
        v.endFloatingCursor()
    }

    // MARK: - Section B — the hazard Task 32 dated to this task

    /// **THE §1 TEST. Built and RUN RED before `performDetachSteps()`'s reset was moved.**
    ///
    /// See this suite's header for the mechanism. The assertion is on the TRANSIENT caret — the bright
    /// gliding shadow — because that is the only observable the early reset destroys: the auto-scroll
    /// link is torn down either way (`stopFloatingAutoScroll()` sits ABOVE `cancelFloatingCursor()`'s
    /// guard), and the flag itself reads `false` either way (step 1 set it). A test that asserted only
    /// the flag would have stayed green through the whole defect.
    func test_detachHidesTheTransientCaret() {
        let (v, backend) = realCanvas()
        let violations = capturingContractViolations {
            v.setCaret(global: offset(v, 2))
            v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
            XCTAssertTrue(backend.floatingCursorActive, "precondition: the gesture is live")
            XCTAssertFalse(v.transientCaretView.isHidden,
                           "precondition: the bright shadow caret is on screen, or hiding it below "
                           + "proves nothing")

            backend.detach()

            XCTAssertTrue(v.transientCaretView.isHidden,
                          "detach must hide the transient shadow caret. RED when "
                          + "`performDetachSteps()`'s `floatingCursorActive = false` hygiene reset "
                          + "runs BEFORE step 2: with one store, the early reset makes "
                          + "`cancelFloatingCursor()`'s `guard floatingCursorActive` return early and "
                          + "the caret is never hidden — a stuck bright caret surviving detach.")
            XCTAssertEqual(v.transientCaretView.alpha, 0, accuracy: 0.0001,
                           "…and `hide(animated: false)` zeroes the alpha in the same breath")
            XCTAssertFalse(backend.floatingCursorActive, "detach still clears the one flag")
        }
        XCTAssertEqual(violations, [])
    }

    // MARK: - Section C — the invariants that now straddle (or deliberately do not) the seam

    /// **Coordinator supplement §3.** `stopFloatingAutoScroll()` writes the link and the velocity
    /// together — "no link ⇒ no velocity" — and after this task those two writes live on opposite
    /// sides of the seam (the link is canvas storage, the velocity is a backend door call). **The
    /// decision: both writes STAY in that one canvas body**, so the invariant is still enforced in a
    /// single place rather than by an argument spanning two objects. This is the pin for it: a velocity
    /// left non-zero with no link is a silent stuck-autoscroll state that nothing else in the suite
    /// would notice.
    func test_stoppingTheAutoScrollClearsTheLinkAndTheVelocityTogether() {
        let (v, backend) = realCanvas()
        v.setCaret(global: offset(v, 2))
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        v.updateFloatingCursor(at: CGPoint(x: 150, y: 5))   // top band → starts the link, sets a velocity

        XCTAssertNotNil(v.floatingScrollLink, "precondition: the auto-scroll link actually started")
        XCTAssertNotEqual(backend.floatingScrollVelocity, 0,
                          "precondition: …with a non-zero velocity, or the assertion below is vacuous")

        v.stopFloatingAutoScroll()

        XCTAssertNil(v.floatingScrollLink, "the link half")
        XCTAssertEqual(backend.floatingScrollVelocity, 0, accuracy: 0.0001,
                       "the VELOCITY half, which now lives on the backend. `stopFloatingAutoScroll()` "
                       + "must clear both or the editor holds a stuck auto-scroll velocity with no "
                       + "link to consume it.")
        XCTAssertEqual(v.floatingScrollVelocity, 0, accuracy: 0.0001, "…and the projection agrees")
        v.endFloatingCursor()
    }

    /// The Task-6 retain-cycle guard, restated at this task's boundary. It duplicates
    /// `WindowDetachCharacterizationTests.test_removalFromWindow_tearsDownTheFloatingScrollLink`
    /// deliberately: that suite is a FROZEN characterization file (its diff must stay empty), so the
    /// assertion that this task did not break the link teardown belongs here, where it can carry this
    /// task's reasoning.
    func test_windowDetachStillInvalidatesTheLink() {
        let (v, backend) = realCanvas()
        v.setCaret(global: offset(v, 2))
        v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
        v.updateFloatingCursor(at: CGPoint(x: 150, y: 5))
        XCTAssertNotNil(v.floatingScrollLink, "precondition: the link actually started")

        v.removeFromSuperview()   // willMove(toWindow: nil)

        XCTAssertNil(v.floatingScrollLink,
                     "`willMove(toWindow: nil)` -> `cancelFloatingCursor()` -> "
                     + "`stopFloatingAutoScroll()` is the ONLY teardown for this link; the backend "
                     + "owns the STATE and must never own the link, or this path stops reaching it")
        XCTAssertFalse(backend.floatingCursorActive, "…and the one flag is cleared with it")
        XCTAssertTrue(v.transientCaretView.isHidden, "…and the bright shadow caret is hidden")
        // FIX ROUND 1 (review Minor 6): the velocity half, asserted on the path a USER actually hits
        // rather than only on the direct `stopFloatingAutoScroll()` call two tests up. Structurally
        // implied (every teardown funnels through that one body) — asserted anyway, because "implied by
        // a funnel" is a claim about the funnel, and this is the composition the funnel exists to serve.
        XCTAssertEqual(backend.floatingScrollVelocity, 0, accuracy: 0.0001,
                       "window removal must leave no auto-scroll velocity behind either")
    }

    /// **Coordinator supplement §2 — the un-latching, preserved through the collapse.** Three of the
    /// backend's six writers are Task-33 MIRROR CLEARS that exist so an interrupted gesture cannot
    /// leave the suppression flag `true` forever; with one store they are redundant with
    /// `cancelFloatingCursor()`'s own clear, and they are kept anyway (see the header). What is
    /// asserted here is not the flag but its consequence — a `selectedTextRange` write after the
    /// interruption is HONOURED — because the flag reading `false` is worth nothing on its own.
    func test_anInterruptedGestureDoesNotLatchTheOneFlag() {
        // Arm 1 — resign first responder.
        do {
            let (v, backend) = realCanvas()
            guard v.becomeFirstResponder() else { return XCTFail("canvas must become first responder") }
            v.setCaret(global: offset(v, 2))
            v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
            XCTAssertTrue(backend.floatingCursorActive, "resign arm: precondition")

            _ = v.resignFirstResponder()

            XCTAssertFalse(backend.floatingCursorActive, "resign arm: the one flag")
            v.selectedTextRange = DocumentTextRange(DocumentTextPosition(offset(v, 0)),
                                                    DocumentTextPosition(offset(v, 3)))
            XCTAssertEqual(v.selFrom, offset(v, 0), "resign arm: a later selection write is honoured")
            XCTAssertEqual(v.selTo, offset(v, 3))
        }
        // Arm 2 — removal from the window.
        do {
            let (v, backend) = realCanvas()
            v.setCaret(global: offset(v, 2))
            v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
            XCTAssertTrue(backend.floatingCursorActive, "window arm: precondition")

            v.removeFromSuperview()

            XCTAssertFalse(backend.floatingCursorActive, "window arm: the one flag")
            v.selectedTextRange = DocumentTextRange(DocumentTextPosition(offset(v, 0)),
                                                    DocumentTextPosition(offset(v, 3)))
            XCTAssertEqual(v.selFrom, offset(v, 0), "window arm: a later selection write is honoured")
            XCTAssertEqual(v.selTo, offset(v, 3))
        }
        // Arm 3 — the backend member detach step 2 calls, driven DIRECTLY (so detach's own hygiene
        // reset cannot mask it), exactly as `FloatingCursorRouterTests` does. NOTE (fix round 1): with
        // one store the canvas's own `cancelFloatingCursor()` clear satisfies this arm whether or not
        // the member's mirror clear exists — see
        // `test_theMirrorClearsAreTheOnlyClearOnACanvaslessBackend` for the arm that isolates it.
        do {
            let (v, backend) = realCanvas()
            v.setCaret(global: offset(v, 2))
            v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
            XCTAssertTrue(backend.floatingCursorActive, "cancel arm: precondition")

            backend.cancelActiveInteraction(reason: .backendDetach)

            XCTAssertFalse(backend.floatingCursorActive, "cancel arm: the one flag")
            v.selectedTextRange = DocumentTextRange(DocumentTextPosition(offset(v, 0)),
                                                    DocumentTextPosition(offset(v, 3)))
            XCTAssertEqual(v.selFrom, offset(v, 0), "cancel arm: a later selection write is honoured")
            XCTAssertEqual(v.selTo, offset(v, 3))
        }
    }

    /// **FIX ROUND 1 (review Major 1) — the three Task-33 MIRROR CLEARS were unpinned, all three of
    /// them, and this is the arm that isolates the two that can be isolated at all.**
    ///
    /// The reviewer deleted every mirror clear and the whole suite stayed green
    /// (`2303 UIKit / 5 skipped + 383 Core, exit 0`), because since the store collapse
    /// `cancelFloatingCursor()` clears the same flag on every attached path. **The only configuration
    /// in which a mirror clear is observable is a backend that is still `isAttached` but whose weak
    /// `host` has gone** — then `legacyCanvas?` is nil, the forward is a no-op, and whatever the flag
    /// does is the member's own doing. Releasing the host is spelled directly (`backend.host = nil`)
    /// rather than staged through an `autoreleasepool`, because the fact under test is "the forward
    /// found no canvas", not ARC's timing.
    ///
    /// **The third clear, `hostWillResignFirstResponder()`'s, cannot be reached this way and the last
    /// arm asserts exactly that** — its `guard` binds `let canvas = legacyCanvas` and returns first.
    /// That is the corrected per-path fact from review Major 1, pinned here rather than only written
    /// down; the clear itself is covered by the source-level
    /// `InputBackendSourceBoundaryTests.test_theFloatingCursorMirrorClearsArePresent_R21`.
    ///
    /// RED-CHECKED, per clear: deleting `floatingCursorActive = false` from
    /// `cancelActiveInteraction(reason:)` reddens arm 1; deleting it from `hostWillMove(toWindow:)`
    /// reddens arm 2. (Deleting the resign one reddens R21, not this test — which is the point of the
    /// third arm.)
    func test_theMirrorClearsAreTheOnlyClearOnACanvaslessBackend() {
        // Arm 1 — `cancelActiveInteraction(reason:)`.
        do {
            let (v, backend) = realCanvas()
            v.setCaret(global: offset(v, 2))
            v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
            XCTAssertTrue(backend.floatingCursorActive, "cancelActiveInteraction arm: precondition")
            backend.host = nil                       // still attached; the forward now finds no canvas
            XCTAssertNil(backend.legacyCanvas, "precondition: the forward must be a no-op")
            XCTAssertTrue(backend.isAttached, "precondition: this is NOT a detached backend")

            backend.cancelActiveInteraction(reason: .backendDetach)

            XCTAssertFalse(backend.floatingCursorActive,
                           "with no canvas, `cancelActiveInteraction`'s own mirror clear is the ONLY "
                           + "thing that can clear this flag — deleting it latches the "
                           + "`selectedTextRange` setter for the life of the editor")
            withExtendedLifetime(v) {}
        }
        // Arm 2 — `hostWillMove(toWindow:)`, whose clear carries the `window == nil` branch.
        do {
            let (v, backend) = realCanvas()
            v.setCaret(global: offset(v, 2))
            v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
            XCTAssertTrue(backend.floatingCursorActive, "hostWillMove arm: precondition")
            backend.host = nil
            XCTAssertNil(backend.legacyCanvas, "precondition: the forward must be a no-op")

            backend.hostWillMove(toWindow: nil)

            XCTAssertFalse(backend.floatingCursorActive,
                           "with no canvas, `hostWillMove(toWindow:)`'s own mirror clear is the ONLY "
                           + "thing that can clear this flag")
            withExtendedLifetime(v) {}
        }
        // Arm 2b — the branch is still load-bearing in this configuration: a NON-nil window must not
        // clear, or the suppression dies mid-gesture on any announced window change.
        do {
            let (v, backend) = realCanvas()
            v.setCaret(global: offset(v, 2))
            v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
            backend.host = nil

            backend.hostWillMove(toWindow: window)

            XCTAssertTrue(backend.floatingCursorActive,
                          "entering a window must not clear the flag, canvas or no canvas")
            withExtendedLifetime(v) {}
        }
        // Arm 3 — the corrected fact: `hostWillResignFirstResponder()` clears NOTHING here, because its
        // guard binds `let canvas = legacyCanvas` and returns first. Asserted rather than assumed.
        do {
            let (v, backend) = realCanvas()
            v.setCaret(global: offset(v, 2))
            v.beginFloatingCursor(at: CGPoint(x: 30, y: 12))
            XCTAssertTrue(backend.floatingCursorActive, "resign arm: precondition")
            backend.host = nil

            backend.hostWillResignFirstResponder()

            XCTAssertTrue(backend.floatingCursorActive,
                          "`hostWillResignFirstResponder()` returns at its `guard let canvas = "
                          + "legacyCanvas` before reaching its mirror clear, so on a canvas-less "
                          + "backend it clears nothing. This is the fact review Major 1 corrected; it "
                          + "is not a gap, because the member's only `Sources/` caller is "
                          + "`DocumentCanvasView.resignFirstResponder()` and the canvas IS its own "
                          + "host, so this configuration cannot dispatch it in production. If this "
                          + "assertion ever flips, the guard changed shape and the per-path table at "
                          + "the flag's declaration needs re-measuring.")
            withExtendedLifetime(v) {}
        }
    }
}
#endif
