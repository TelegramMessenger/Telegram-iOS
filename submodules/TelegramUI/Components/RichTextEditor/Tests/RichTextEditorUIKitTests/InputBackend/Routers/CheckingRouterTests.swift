#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 34 — Family 11 (spellchecking and annotations), the LAST Phase-4 family.
///
/// # TWO routed members, and this family had to widen the contract to get them
///
/// `installCheckingIfNeeded()` and `checkOnSelectionChange()` (deviation **D37**). Every earlier family
/// routed a `UITextInput`/`UIResponder` witness; **this one has none.** Its entry points are
/// canvas-INTERNAL — the `isSpellCheckingEnabled` `didSet`, `legacyFinishBecomingFirstResponder()`,
/// `refreshSelectionUI()` and `endCoalescedSelectionDrag()` — and `DocumentCanvasView.inputBackend` is
/// typed `any RichTextInputBackend`, so a backend-internal member (which is what the task brief asked
/// for, in the same breath as asking the canvas call sites to reach it) is unreachable from three of
/// the four. D37 adds `RichTextInputCheckingBackend` on D33's own rationale; D36 does NOT transfer,
/// because Task 32's four stayed off the contract under Global Constraint 12's ban on `@available`
/// gates above iOS 13, and neither member here takes a parameter at all.
///
/// **Consequence for the sibling rules, stated because a reader will look for it:**
/// `RouterWitnessBodyTests.enabledWitnesses` gains NOTHING from this family (it requires a witness whose
/// body is exactly one `inputBackend.…` statement; none of the four call sites is one), and R17 gains two
/// `.statements` entries rather than `.canvasForward` ones, because both callees are ALREADY narrowly
/// named and keep their names under D24's Task-29 amendment.
///
/// # The brief's third member is deliberately absent
///
/// `driveCheck(style:_:)` was not written. It is a bracket over canvas-owned `inFlightCheckStyle` (read
/// synchronously by the `@objc` `removeAnnotation:forRange:` from inside the closure), all three of its
/// call sites are inside canvas bodies, and routing it would send a canvas-captured closure out and
/// straight back with no decision taken in between. `+Checking.swift`'s header carries the full
/// reasoning. Also corrected there: the coordinator supplement claimed two of those call sites were
/// inside `@objc` selectors — measured, both are inside `nativeCheckOnSelectionChange()`, and no `@objc`
/// selector calls it at all.
///
/// # DEVIATION D11 is the boundary, and Section 2 pins it
///
/// The five `@objc` private-controller client selectors and the XOR-obfuscated class/selector strings
/// stay exactly where they are (`DocumentCanvasView+NativeTextCheckingClient.swift`,
/// `NativeTextChecking.swift`); carving them into an Objective-C module is stage-2 work. The
/// `NativeTextChecker` handle stays canvas-owned so `deinit` keeps invalidating it, **the teardown half
/// of the `isSpellCheckingEnabled` `didSet` stays canvas-side and unrouted** (only the ENABLE branch
/// routes — `test_disablingSpellCheckingRoutesNothing` is the pin), and annotation STORAGE stays on the
/// canvas behind `TelegramAnnotationInputClient` (Task 17), including D17's non-rebasing.
///
/// **The brief describes the five selectors as forwarding "to `annotationClient`". Measured, the
/// direction is the OTHER WAY ROUND**, and `test_theAnnotationClientForwardsToTheCanvasNotTheReverse`
/// is the pin: the `@objc` methods call canvas-internal translation
/// (`applyNativeAnnotations` / `clearNativeAnnotations` / `spellResults`), and it is
/// `TelegramAnnotationInputClient` that delegates INTO them ("Delegates verbatim to the existing
/// controller-facing callback", its own doc comment). A reader who inverts that will look for a
/// forwarding layer that does not exist.
@MainActor
@available(iOS 16.0, *)   // `SpyRichTextInputBackend` and the `XCTAssertRoutesOnly` family are iOS 16+
final class CheckingRouterTests: XCTestCase {

    // MARK: - Fixtures

    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.makeKeyAndVisible()
    }

    override func tearDown() { window.isHidden = true; window = nil; super.tearDown() }

    /// A laid-out canvas inside the KEY WINDOW. The window matters: `becomeFirstResponder()` fails
    /// outside one, and the install-on-focus test's whole subject is the focus transition actually
    /// happening rather than being short-circuited.
    private func focusableCanvas(_ text: String = "hello wrold today") -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: text)]))], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        window.addSubview(v)
        v.layoutIfNeeded()
        return v
    }

    /// The five selector names D11 keeps on the canvas. Spelled here, in the TEST target, and NEVER
    /// under `S/InputBackend/**` — Global Constraint 11 bans private selector names there, and rule R1
    /// (`InputBackendSourceBoundaryTests`) enforces it. The private-API inventory rule
    /// (`test_privateRuntimeLookups_areConfinedToTheInventoriedFiles`) scans
    /// `Sources/RichTextEditorUIKit` only, so a test-target `NSSelectorFromString` is outside it by
    /// construction; that is deliberate, not an oversight to be tidied by moving these into the module.
    private static let d11Selectors = [
        "nativeTextRangeForGlobalLocation:length:",
        "annotatedSubstringForRange:",
        "replaceRange:withAnnotatedString:relativeReplacementRange:",
        "removeAnnotation:forRange:",
        "validAnnotations",
    ]

    /// A laid-out spy-backed canvas: the router-spy shape every Phase-4 family uses. `reset()` after
    /// construction, because building and laying out a canvas drives the backend on its own.
    private func spyCanvas() -> (DocumentCanvasView, SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello wrold today")]))],
                    width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        window.addSubview(v)
        v.layoutIfNeeded()
        spy.reset()
        return (v, spy)
    }

    // MARK: - Section 1: the two members route

    /// `legacyFinishBecomingFirstResponder()` — Task 31's THIRD become-first-responder hook, not
    /// `legacyDidBecomeFirstResponder()` (the brief and the coordinator supplement both named the wrong
    /// one; Task 31 split `becomeFirstResponder()` into three hooks precisely because the boundaries
    /// between them are observable).
    ///
    /// **Scope of `XCTAssertRoutesOnly` here, disclosed rather than implied:** this hook is NOT a
    /// one-line router — it is `inputBackend.installCheckingIfNeeded(); nativeChecker?.preheat();
    /// lastCheckedCaret = head`. The assertion proves exactly one BACKEND call and that nothing the
    /// `RouterStateSnapshot` watches moved; the other two statements touch `nativeChecker` (nil on a spy
    /// canvas) and `lastCheckedCaret`, neither of which that snapshot covers. That is why this family
    /// contributes no name to `RouterWitnessBodyTests.enabledWitnesses`.
    func test_finishingBecomeFirstResponderRoutesTheCheckingInstallToTheBackend() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "installCheckingIfNeeded()", arguments: []) {
            v.legacyFinishBecomingFirstResponder()
        }
    }

    /// The `isSpellCheckingEnabled` `didSet`'s ENABLE branch, asserted as an exact SEQUENCE rather than
    /// as membership: the install must run BEFORE the traits notification, which is where it sat
    /// pre-seam (the `didSet` body is install/teardown, then `reloadInputViews()`, then
    /// `inputBackend.textInputTraitsDidChange()`). Membership alone would not catch a reorder.
    func test_enablingSpellCheckingRoutesTheInstallToTheBackend_beforeTheTraitsNotification() {
        let (v, spy) = spyCanvas()
        v.isSpellCheckingEnabled = false
        spy.reset()

        v.isSpellCheckingEnabled = true

        XCTAssertEqual(spy.calls.map(\.member),
                       ["installCheckingIfNeeded()", "textInputTraitsDidChange()"],
                       "the enable branch installs THROUGH the backend, and does so before the traits " +
                       "notification the same didSet ends with")
    }

    /// D11's teardown half, and the reason this file has a negative test at all: **the DISABLE branch
    /// does not route.** It invalidates the driver, nils it and clears `spellResults` inline, because
    /// the `NativeTextChecker` handle is a canvas-owned resource `deinit` must keep invalidating. A
    /// future task that "completes" the symmetry by routing a teardown moves resource ownership across
    /// the seam, which is stage-2 work — this test is what makes that deliberate rather than accidental.
    ///
    /// **The review established this test's value the only way it can be established — faithfully.** It
    /// built a real `tearDownChecking()` requirement, a canvas hook and three conformer implementations
    /// across six files, and confirmed this assertion reddens with exactly the right two entries and
    /// nothing else moving. A trivial mutation would have proved nothing about a negative test.
    ///
    /// **STATED LIMIT (fix round 1, review Minor 5): this reddens because `SpyRichTextInputBackend`
    /// records by CONVENTION, not because anything enforces it.** Every witness there opens with
    /// `note(...)`, but nothing checks that a NEW backend member does — so a future `tearDownChecking()`
    /// that forgot the `note(...)` call would leave this test green while the teardown routed. The
    /// honest claim is therefore: **this catches a routed teardown that records itself, which is every
    /// member in this tree today.** No machinery is built for the gap; the disclosure is the fix, in the
    /// same shape as `test_finishingBecomeFirstResponderRoutesTheCheckingInstallToTheBackend`'s note on
    /// what `XCTAssertRoutesOnly` does and does not cover.
    func test_disablingSpellCheckingRoutesNothing() {
        let (v, spy) = spyCanvas()

        v.isSpellCheckingEnabled = false

        XCTAssertEqual(spy.calls.map(\.member), ["textInputTraitsDidChange()"],
                       "only the trait notification crosses the seam on the disable path — the teardown " +
                       "itself stays canvas-side (D11)")
    }

    /// `refreshSelectionUI()`, the hot selection funnel: one backend call, no canvas work of its own.
    func test_refreshSelectionUIRoutesTheSelectionDrivenCheckToTheBackend() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "checkOnSelectionChange()", arguments: []) {
            v.refreshSelectionUI()
        }
    }

    /// The coalesced-drag funnel, asserted as an ORDER: one resync bracket at the settled selection,
    /// THEN the check. Reversing them would check at a caret the OS has not yet been told about, and
    /// membership-only assertions cannot see that.
    func test_endingACoalescedDragResyncsThenChecks_inThatOrder() {
        let (v, spy) = spyCanvas()
        v.beginCoalescedSelectionDrag()
        spy.reset()

        v.endCoalescedSelectionDrag()

        XCTAssertEqual(spy.calls.map(\.member),
                       ["notifyCoalescedSelectionResync", "checkOnSelectionChange()"],
                       "one resync bracket for the settled selection, then the check at the final caret")
    }

    // MARK: - Section 2: D11 — the five client selectors stay on the canvas

    /// The canvas IS the private controller's client, and stays it. Each of the five must remain
    /// dispatchable BY SELECTOR from the ObjC runtime, because `NativeTextChecker` messages them that
    /// way — a Swift-level rename that kept the method but changed its `@objc(...)` name would compile,
    /// pass every type-checked test, and silently break checking at runtime.
    func test_theFivePrivateClientSelectorsStayOnTheCanvas_D11() {
        let v = focusableCanvas()
        for name in Self.d11Selectors {
            XCTAssertTrue(v.responds(to: NSSelectorFromString(name)),
                          "D11 keeps `\(name)` on the canvas as an @objc client method — the private " +
                          "controller messages it by selector, so losing the selector name breaks " +
                          "checking with no compile error")
        }
    }

    /// The other half of D11, and the one a routing task could plausibly have broken: the five did NOT
    /// move onto the backend. Asked of the RUNTIME (`responds(to:)`), because that is the question the
    /// private controller asks — `objc_msgSend`, not a type check.
    ///
    /// **The first draft of this test asserted something stronger and FALSE, and the correction is
    /// worth keeping.** It claimed `LegacyRichTextInputBackend`, being a pure Swift class rather than
    /// an `NSObject` subclass, could not host an `@objc` client surface "even in principle", and
    /// asserted `backend as? NSObjectProtocol == nil`. That cast SUCCEEDS: Swift's native root class
    /// implements the `NSObject` protocol, so every Swift class answers `responds(to:)` at runtime.
    /// The test caught it (measured, RED) — so the honest claim is the ordinary one, that the five
    /// selectors are not on the backend, and D11's boundary is a decision rather than a law of the
    /// language.
    func test_theFivePrivateClientSelectorsDidNotMoveToTheBackend_D11() {
        guard let backend = LegacyRichTextInputBackend() as AnyObject as? NSObjectProtocol else {
            return XCTFail("every Swift class answers NSObjectProtocol at runtime — if this ever " +
                           "stops being true, the assertions below silently check nothing")
        }
        for name in Self.d11Selectors {
            XCTAssertFalse(backend.responds(to: NSSelectorFromString(name)),
                           "`\(name)` must stay canvas-side (D11): carving the client surface out of " +
                           "the canvas is stage-2 work, not this task's")
        }
        // Vacuity guard: the same probe run against the canvas, which DOES vend all five, proves the
        // selector strings above are real and the probe can answer TRUE. Without it a typo in every
        // name would make this test pass by asking about nothing.
        let canvas = focusableCanvas()
        for name in Self.d11Selectors {
            XCTAssertTrue(canvas.responds(to: NSSelectorFromString(name)),
                          "the same probe must answer TRUE on the canvas, or the names are wrong and " +
                          "the assertions above are vacuous: `\(name)`")
        }
    }

    /// **Corrects the task brief's stated direction.** The `@objc` selectors do not forward to
    /// `annotationClient`; `TelegramAnnotationInputClient` (Task 17) forwards INTO them. Driving the
    /// client and observing the canvas's own translation store is what proves which way the arrow
    /// points: `annotationValue(for:at:revision:)` answers from `spellResults`, which only the canvas's
    /// `applyNativeAnnotations` writes.
    func test_theAnnotationClientForwardsToTheCanvasNotTheReverse() {
        let v = focusableCanvas()
        let base = v.boxes[0].textStart
        v.applyNativeAnnotations(global: NSRange(location: base + 6, length: 5), style: .spelling)

        let style = v.annotationClient.annotationValue(
            for: "any" as AnyHashable,
            at: RichTextInputPosition(utf16Offset: base + 7),
            revision: v.documentRevision) as? DocumentCanvasView.SpellStyle
        XCTAssertEqual(style, .spelling,
                       "the annotation client reads the canvas's own `spellResults` — storage stays " +
                       "on the canvas (D11/Task 17), and the client is the layer that delegates to it")

        let range = v.annotationClient.annotatedSubstring(
            in: NSRange(location: base, length: 5), revision: v.documentRevision)
        XCTAssertEqual(range?.string, "hello",
                       "…and `annotatedSubstring(in:revision:)` delegates verbatim to the canvas's own " +
                       "`@objc` client methods, which is the direction the brief states backwards")
    }

    // MARK: - Section 3: the lifecycle end-to-end, through the REAL backend

    /// Focus installs the checker. This is a CHARACTERIZATION of the current call graph
    /// (`becomeFirstResponder()` -> backend `hostDidBecomeFirstResponder()` ->
    /// `legacyFinishBecomingFirstResponder()` -> `installNativeCheckingIfNeeded()`), and it is the
    /// assertion that would have to be re-pointed — not rewritten — if the referred contract question
    /// is answered by adding a requirement.
    func test_checkingIsInstalledOnFirstResponder() {
        let v = focusableCanvas()
        XCTAssertNil(v.nativeChecker, "precondition: nothing is installed before focus")
        XCTAssertTrue(v.becomeFirstResponder(), "precondition: the canvas must actually focus")
        XCTAssertNotNil(v.nativeChecker,
                        "becoming first responder installs the native checking driver (if the private " +
                        "class is unavailable this is nil and the whole family is inert — see " +
                        "`NativeTextChecking.swift`, no fallback by design)")
    }

    /// `installNativeCheckingIfNeeded()` is idempotent, which is load-bearing: it is called on EVERY
    /// `becomeFirstResponder()`, and the chat composer focuses the editor on every touch-down. A second
    /// install would drop the live controller and its warm `textChecker` on the floor.
    func test_installingCheckingTwiceKeepsTheSameDriver() {
        let v = focusableCanvas()
        v.installNativeCheckingIfNeeded()
        let first = v.nativeChecker
        XCTAssertNotNil(first, "precondition: the driver installed")
        v.installNativeCheckingIfNeeded()
        XCTAssertTrue(first === v.nativeChecker, "a repeat install must be a no-op, not a re-install")
    }

    /// The `isSpellCheckingEnabled` `didSet`, both branches.
    ///
    /// **The name this test does NOT have is the finding.** The task brief asked for
    /// `test_disablingSpellCheckingTearsDownTheCheckerThroughTheBackend`; measured, the teardown is
    /// canvas-side and inline (`nativeChecker?.invalidate(); nativeChecker = nil; spellResults = [:]`
    /// …), the three members the brief proposed routing contain no teardown at all, and the
    /// `NativeTextChecker` handle is deliberately canvas-owned so `deinit` keeps invalidating it. So
    /// "through the backend" would have been false in the name of a passing test, which is the worst
    /// kind. Named for what it checks instead.
    func test_disablingSpellCheckingTearsDownTheChecker_andReEnablingReinstallsIt() {
        let v = focusableCanvas()
        v.installNativeCheckingIfNeeded()
        let base = v.boxes[0].textStart
        v.applyNativeAnnotations(global: NSRange(location: base + 6, length: 5), style: .spelling)
        XCTAssertNotNil(v.nativeChecker, "precondition: a live driver")
        XCTAssertFalse(v.spellResults.isEmpty, "precondition: a flagged range to clear")

        v.isSpellCheckingEnabled = false
        XCTAssertNil(v.nativeChecker, "disabling tears the driver down")
        XCTAssertTrue(v.spellResults.isEmpty, "…and drops every flag it had produced")

        v.isSpellCheckingEnabled = true
        XCTAssertNotNil(v.nativeChecker, "re-enabling installs a fresh driver")
    }

    /// Setting the trait to its CURRENT value must change nothing — the `guard oldValue !=` at the top
    /// of the `didSet` is load-bearing for the trait notification as well as for the install/teardown,
    /// and this is the cheap pin that a routing task cannot accidentally drop.
    func test_settingSpellCheckingToItsCurrentValueDoesNotReinstall() {
        let v = focusableCanvas()
        v.installNativeCheckingIfNeeded()
        let first = v.nativeChecker
        XCTAssertNotNil(first, "precondition: the driver installed")
        v.isSpellCheckingEnabled = true          // already true
        XCTAssertTrue(first === v.nativeChecker, "a no-op trait write must not touch the driver")
    }

    /// The selection funnel reaches the checking driver. Pinned through `lastCheckedCaret`, which
    /// `nativeCheckOnSelectionChange()` records on every selection change and nothing else writes —
    /// so it is evidence the funnel RAN, without depending on the asynchronous checker actually
    /// flagging anything (`SelectionDrivenSpellCheckTests` owns that, with its own run-loop spins).
    func test_aSelectionChangeRunsTheSelectionDrivenCheckingFunnel() {
        let v = focusableCanvas()
        v.installNativeCheckingIfNeeded()
        let base = v.boxes[0].textStart
        v.setCaret(global: base + 8)
        XCTAssertEqual(v.lastCheckedCaret, base + 8,
                       "`refreshSelectionUI()` runs `nativeCheckOnSelectionChange()`, which records the " +
                       "caret it last saw — the observable that the funnel ran at all")
        v.setCaret(global: base + 14)
        XCTAssertEqual(v.lastCheckedCaret, base + 14, "…and again on the next selection change")
    }
}
#endif
