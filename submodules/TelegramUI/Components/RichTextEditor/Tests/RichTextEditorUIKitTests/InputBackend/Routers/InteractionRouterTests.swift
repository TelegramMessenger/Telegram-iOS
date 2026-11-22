#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 32 — Family 9 (touch interaction and selection). **FIVE routed backend members, and only ONE of
/// them has a canvas witness.** That asymmetry is what shapes this file, so it is stated before the
/// tests rather than left to be inferred:
///
///   * `viewportDidChange()` is the one witness — `DocumentCanvasView.viewportDidChange()` is now a
///     one-line router, and `RichTextEditorView.scrollViewDidScroll` still calls it. It gets the
///     standard `XCTAssertRoutesOnly` treatment.
///   * `layoutDidChange(generation:)` is a NOTIFICATION raised from inside `layoutContent()`, which is
///     a 40-line layout body, not a router. `XCTAssertRoutesOnly` (whose contract is "exactly ONE
///     backend call and the canvas did no work of its own") would fail for correct code, so its tests
///     assert on the filtered call log instead — the same shape `ResponderRouterTests` uses for
///     `becomeFirstResponder()`.
///   * `installInteractions()`, `removeInteractions()` and `cancelActiveInteraction(reason:)` have NO
///     canvas witness at all. They are called by `attach(to:)` and `performDetachSteps()`, so what
///     needs proving is the OTHER direction — backend to canvas — which only a real backend can show.
///
/// **Which backend each test runs against** (the handoff's rule 3): spy for the two members with a
/// canvas entry point (Section 1) and for the attach-time call count; the real legacy backend for
/// everything that is about what reaches the canvas (Section 2). Every test reads through a real
/// `DocumentCanvasView` member or through the spy, never the canvas's backend property (rule R14).
///
/// # Two tests the task brief asked for that are NOT here, both deliberately
///
/// **1. The source-level half of `test_removeInteractionsIsCalledOnlyFromDetach` lives in the Core
/// source-boundary suite, as rule R19** (`test_detachOnlyTeardownIsNotWiredIntoResignFirstResponder_R19`,
/// `T/…/SourceBoundary/InputBackendSourceBoundaryTests.swift`). It needs `RepoLayout` and
/// `SwiftSourceScan`, which are Core-test-target types; reimplementing package-root resolution here
/// would have been a second, drifting copy of vetted machinery. The BEHAVIOURAL half is here
/// (`test_resignFirstResponder_doesNotRemoveTheCanvasInteractions`), and the two are complementary
/// rather than redundant: the behavioural one cannot see a call added on a path a unit-test resign does
/// not take, and cannot see `cancelActiveInteraction(reason:)` acquiring a new caller at all.
///
/// **2. The `interactionsInstalled` / `interactionsRemoved` event-log balance assertion is NOT written,
/// and that is a decision rather than an omission.** `RichTextInputEventLog.Event` declares both cases
/// and gives both a `description` arm — and **nothing anywhere emits either one**. The routed bodies do
/// not either: they forward to the canvas, and only a FAKE CLIENT writes to that log. So
/// `log.count("interactionsInstalled") == log.count("interactionsRemoved")` is `0 == 0`, green forever,
/// independent of the code — the exact "reads as enforcement, enforces nothing" shape this project has
/// paid for repeatedly, and which Task 22h's own review already dropped once for being vacuous. The
/// alternative was to invent an emitter (a fake client observing attach/detach), which would mean
/// adding logging to a fixture purely so an assertion could be written about it, while the PRODUCTION
/// bodies must not gain logging at all. Recorded here so the next reader finds a decision instead of a
/// gap. **What actually covers install/remove balance is `test_detach_removesExactlyWhatAttachInstalled`
/// below**, which counts the real objects on the real canvas — a stronger claim than a count of events
/// nobody emits.
@MainActor
@available(iOS 16.0, *)
final class InteractionRouterTests: XCTestCase {

    // MARK: - Fixtures

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

    private func realCanvas() -> (DocumentCanvasView, LegacyRichTextInputBackend) {
        let v = laidOut(DocumentCanvasView())
        return (v, v.inputBackend as! LegacyRichTextInputBackend)
    }

    /// The three recognizers `installSelectionInteractions()` adds, as identities.
    ///
    /// **Counting `gestureRecognizers` is NOT a substitute, and the numbers are the reason.** A canvas
    /// holds more than our three: `UIEditMenuInteraction` (installed by the same method's iOS-16 tail)
    /// attaches its own, and the first-responder machinery attaches more again — measured on this
    /// fixture, a freshly attached canvas reports **6** and a focused one **8**, and a resign takes it
    /// back to 6. Every assertion in this file is therefore about WHICH recognizers are installed, never
    /// how many.
    private func ourRecognizers(_ v: DocumentCanvasView) -> [UIGestureRecognizer] {
        [v.selectionTap as UIGestureRecognizer?, v.loupeLongPress, v.selectionHandlePan].compactMap { $0 }
    }

    private func installedOnCanvas(_ recognizers: [UIGestureRecognizer],
                                   _ v: DocumentCanvasView) -> Bool {
        let live = v.gestureRecognizers ?? []
        return recognizers.allSatisfy { r in live.contains { $0 === r } }
    }

    /// The Family-9 subsequence of the spy's flat log. `layoutContent()` and window hosting reach other
    /// witnesses (geometry reads, `canBecomeFirstResponder`, …), so asserting on the raw log would pin
    /// UIKit's and the layout engine's internals rather than this seam's contract.
    private func interactionCalls(_ spy: SpyRichTextInputBackend) -> [SpyRichTextInputBackend.Call] {
        let family: Set<String> = ["installInteractions()", "removeInteractions()", "viewportDidChange()",
                                   "layoutDidChange(generation:)", "cancelActiveInteraction(reason:)"]
        return spy.calls.filter { family.contains($0.member) }
    }

    // MARK: - Section 1: the spy backend — the canvas entry points route

    /// The non-routing answer is NOT a coincidental pass here, which is why this uses the full
    /// `XCTAssertRoutesOnly`: the pre-seam witness's very first statement was `bumpLayoutGeneration()`,
    /// and `RouterStateSnapshot` watches `layoutGeneration`. So a canvas that kept ANY of the old body
    /// fails the "did no work of its own" half even if it also forwarded.
    func test_viewportDidChange_routesToTheBackend() {
        let (v, spy) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "viewportDidChange()", arguments: []) {
            v.viewportDidChange()
        }
    }

    /// The host's real entry point, one hop further out than the witness — `RichTextEditorView`'s
    /// `scrollViewDidScroll` calls `canvas.viewportDidChange()`, so this pins that the ROUTING did not
    /// change which method the facade must call.
    func test_viewportDidChange_isStillTheCanvasEntryPointTheFacadeCalls() {
        let (v, spy) = spyCanvas()
        v.viewportDidChange()
        XCTAssertEqual(interactionCalls(spy).map(\.member), ["viewportDidChange()"])
    }

    /// `layoutContent()` announces the generation it just laid out at. Exactly once, with the canvas's
    /// CURRENT value — not a stale one and not a fabricated constant.
    func test_layoutContent_notifiesTheBackendOfTheLayoutGenerationExactlyOnce() {
        let (v, spy) = spyCanvas()

        v.layoutContent()

        XCTAssertEqual(interactionCalls(spy),
                       [.init(member: "layoutDidChange(generation:)",
                              arguments: [String(v.layoutGeneration)])],
                       "exactly one notification, carrying the generation the canvas now reports")
    }

    /// The notification is the LAST statement of `layoutContent()`, not the first — so the value the
    /// backend is told already includes that pass's own `bumpLayoutGeneration()`. Red if the call were
    /// hoisted to the top (it would report the PREVIOUS generation, one less).
    func test_layoutContent_announcesTheGenerationAfterItsOwnBump_notBefore() {
        let (v, spy) = spyCanvas()
        let before = v.layoutGeneration

        v.layoutContent()

        XCTAssertEqual(v.layoutGeneration, before + 1, "precondition: the pass bumped the counter once")
        XCTAssertEqual(interactionCalls(spy).first?.arguments, [String(before + 1)],
                       "the announced generation is the post-bump one; a call hoisted to the top of " +
                       "layoutContent() would announce \(before)")
    }

    /// **The BACKEND decides that a canvas gets interactions; `DocumentCanvasView.init` does not.** A
    /// spy-backed canvas installs nothing, because the spy's own `attach(to:)` is the spy's — nothing in
    /// the canvas's construction sequence installs on its own initiative.
    ///
    /// **Why there is no "installInteractions() is called exactly once" test here, stated rather than
    /// left as a gap:** the natural spy-based version cannot exist. `installInteractions()` is called
    /// from inside `LegacyRichTextInputBackend.attach(to:)`, so a canvas whose backend IS the spy never
    /// reaches that call at all (the spy's `attach` is its own three-line implementation), and a canvas
    /// whose backend is real does not record anything. The call count is also not a fact worth pinning:
    /// `installSelectionInteractions()` is idempotent by construction (`…_isIdempotent_…` below), so a
    /// second call is a no-op rather than a defect. What DOES matter — that the interactions exist after
    /// construction, and only because the backend put them there — is what this test and
    /// `…_installsTheCanvasSelectionInteractionsAtAttachTime` cover between them.
    func test_aCanvasInstallsNoInteractionsOfItsOwnAccord_onlyItsBackendDoes() {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        withExtendedLifetime(v) {
            XCTAssertNil(v.selectionTap)
            XCTAssertNil(v.loupeLongPress)
            XCTAssertNil(v.selectionHandlePan)
            XCTAssertEqual(v.gestureRecognizers?.count ?? 0, 0,
                           "no recognizers at all — not even the UIEditMenuInteraction's, since that " +
                           "too rides on installSelectionInteractions()")
        }
    }

    // MARK: - Section 2: the real legacy backend — what reaches the canvas

    /// `attach(to:)` runs inside `DocumentCanvasView.init`, so a real canvas is interaction-ready the
    /// moment it exists — this is the timing change Task 32 introduces, asserted rather than assumed.
    /// The recognizers are the tap, the loupe long-press and the selection-handle pan; the
    /// `UIEditMenuInteraction` comes from `installSelectionInteractions()`'s iOS-16 tail.
    func test_installInteractions_installsTheCanvasSelectionInteractionsAtAttachTime() {
        let (v, _) = realCanvas()
        XCTAssertEqual(ourRecognizers(v).count, 3, "the tap, the loupe long-press and the handle pan")
        XCTAssertTrue(installedOnCanvas(ourRecognizers(v), v))
        XCTAssertTrue(v.interactions.contains { $0 is UIEditMenuInteraction })
    }

    /// Ground 1 of the routed member's zero-behaviour-change argument (`+Interaction.swift`'s header):
    /// the facade's own `canvas.installSelectionInteractions()` call, which now runs SECOND, must be a
    /// complete no-op — otherwise the end state of the init sequence would differ from the pre-seam one.
    func test_installInteractions_isIdempotent_soTheFacadesOwnCallChangesNothing() {
        let (v, backend) = realCanvas()
        let recognizers = v.gestureRecognizers ?? []
        let interactionCount = v.interactions.count

        v.installSelectionInteractions()   // what RichTextEditorView does after adding the canvas
        backend.installInteractions()      // and the routed member, a third time, for good measure

        XCTAssertEqual(v.gestureRecognizers ?? [], recognizers, "same recognizers, same identities")
        XCTAssertEqual(v.interactions.count, interactionCount, "no second UIEditMenuInteraction")
    }

    /// `removeInteractions()` is the inverse of install's recognizer half. The two stored references are
    /// cleared too — `gestureRecognizerShouldBegin(_:)` arbitrates by comparing against them, so leaving
    /// them dangling would be a gate pointing at recognizers that can never fire again.
    ///
    /// **EXACTLY those, and nothing else** — the second half of the assertion is the one that matters,
    /// and it is here because the first implementation of the hook failed it: removing every entry of
    /// `gestureRecognizers` also tore out the ones `UIEditMenuInteraction` had attached. The
    /// edit-menu interaction is the disclosed asymmetry (install adds it, remove does not take it away),
    /// so its recognizers must still be there afterwards.
    func test_removeInteractions_removesExactlyTheRecognizersInstallAdded() {
        let (v, backend) = realCanvas()
        let ours = ourRecognizers(v)
        let othersBefore = (v.gestureRecognizers ?? []).filter { r in !ours.contains { $0 === r } }
        XCTAssertEqual(ours.count, 3, "precondition")
        XCTAssertFalse(othersBefore.isEmpty,
                       "precondition: UIKit's own recognizers are present, so 'exactly ours' is a real claim")

        backend.removeInteractions()

        XCTAssertNil(v.selectionTap)
        XCTAssertNil(v.loupeLongPress)
        XCTAssertNil(v.selectionHandlePan)
        let after = v.gestureRecognizers ?? []
        XCTAssertFalse(after.contains { r in ours.contains { $0 === r } }, "all three of ours are gone")
        XCTAssertTrue(othersBefore.allSatisfy { r in after.contains { $0 === r } },
                      "and UIKit's own — the UIEditMenuInteraction's — are untouched")
    }

    /// The balance claim, made against the real objects rather than against an event counter nobody
    /// emits (see this file's header for why the brief's log-balance assertion was not written).
    func test_detach_removesExactlyWhatAttachInstalled() {
        let (v, backend) = realCanvas()
        let ours = ourRecognizers(v)
        XCTAssertEqual(ours.count, 3, "precondition: attach installed them")

        backend.detach()

        let after = v.gestureRecognizers ?? []
        XCTAssertFalse(after.contains { r in ours.contains { $0 === r } }, "step 4 removed them")
        XCTAssertNil(v.selectionTap)
    }

    /// **DEVIATION D18, the behavioural half.** `resignFirstResponder()` keeps its documented teardown
    /// gaps: it must NOT remove the recognizers, because doing so would fix a leak
    /// `ResponderLifecycleCharacterizationTests` pins as present-day behaviour. The source-level half is
    /// rule R19 (see this file's header).
    func test_resignFirstResponder_doesNotRemoveTheCanvasInteractions() {
        let (v, _) = realCanvas()
        let ours = ourRecognizers(v)
        XCTAssertEqual(ours.count, 3, "precondition")
        XCTAssertTrue(v.becomeFirstResponder())

        _ = v.resignFirstResponder()

        XCTAssertEqual(ourRecognizers(v).count, 3,
                       "D18: resignFirstResponder must not gain the detach-only teardown")
        XCTAssertTrue(installedOnCanvas(ours, v), "the same three, still on the canvas")
    }

    /// Step 2 of detach. **Both statements are exercised**, which is why this test builds its own
    /// scroll-view host instead of using `realCanvas()`: `updateDragAutoScroll` only starts its display
    /// link when the canvas's superview IS a `UIScrollView` and the touch is inside the viewport's
    /// edge band (`SelectionInteractionTests.tallCanvasInScroll` is the shape this borrows). Each half
    /// carries a precondition, because each teardown call is a no-op against the state it clears —
    /// `cancelFloatingCursor()` guards on `floatingCursorActive`, and `stopDragAutoScroll()` on a nil
    /// link is silent — so without them the assertions would hold for a body that did nothing.
    func test_cancelActiveInteraction_tearsDownTheFloatingCursorAndTheDragAutoScroll() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let v = DocumentCanvasView()
        let backend = v.inputBackend as! LegacyRichTextInputBackend
        v.setBlocks((0..<40).map {
            .paragraph(ParagraphBlock(id: BlockID("p\($0)"), runs: [TextRun(text: "Line \($0)")]))
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 1600)
        scroll.addSubview(v); scroll.contentSize = v.frame.size; v.layoutIfNeeded()

        v.beginFloatingCursor(at: CGPoint(x: 5, y: 5))
        v.updateDragAutoScroll(point: CGPoint(x: 40, y: scroll.contentOffset.y + 190), headInTable: false)
        XCTAssertTrue(v.floatingCursorActive, "precondition for the cancelFloatingCursor half")
        XCTAssertNotNil(v.dragAutoScrollLink, "precondition for the stopDragAutoScroll half")

        backend.cancelActiveInteraction(reason: .backendDetach)

        XCTAssertFalse(v.floatingCursorActive)
        XCTAssertNil(v.dragAutoScrollLink)
    }

    /// `layoutDidChange(generation:)` is notification-only. **It must never trigger a relayout** — the
    /// canvas has already laid out by the time it calls this, so a relayout here is an unbounded
    /// notify → layout → notify loop, not merely redundant work. `layoutContent()`'s first statement is
    /// `bumpLayoutGeneration()`, so the counter staying put is exactly "no additional layout pass ran".
    func test_layoutDidChangeIsNotificationOnlyAndDoesNotRelayout() {
        let (v, backend) = realCanvas()
        let generationBefore = v.layoutGeneration
        let revisionBefore = v.documentRevision

        backend.layoutDidChange(generation: 9_009)

        XCTAssertEqual(backend.lastObservedLayoutGeneration, 9_009, "it stored the announced value")
        XCTAssertEqual(v.layoutGeneration, generationBefore,
                       "no additional layout pass ran — layoutContent() would have bumped this")
        XCTAssertEqual(v.documentRevision, revisionBefore)
    }

    /// The stored value tracks the LAST LAYOUT PASS, which is not the same thing as the canvas's last
    /// generation — `viewportDidChange()` bumps the counter without notifying. **This pins the
    /// divergence `lastObservedLayoutGeneration`'s own doc comment discloses**, so that whoever gives
    /// the field a reader meets the lag as a failing expectation rather than as a surprise.
    func test_lastObservedLayoutGenerationLagsAfterAViewportScroll_theDisclosedDivergence() {
        let (v, backend) = realCanvas()
        v.layoutContent()
        XCTAssertEqual(backend.lastObservedLayoutGeneration, v.layoutGeneration, "in step after a layout")

        v.viewportDidChange()

        XCTAssertEqual(backend.lastObservedLayoutGeneration, v.layoutGeneration - 1,
                       "the canvas advanced and the backend was not told — the documented lag")
    }

    /// **FIX ROUND 1 (review Minor 1): the SECOND class of lag, and the surprising one.** The viewport
    /// case above is the one a reader expects from the member's name; this one is not. `layoutGeneration`
    /// is also advanced by all five members of `TelegramAnnotationInputClient`, so **every
    /// spell-annotation and rendering-attribute write** desynchronises the backend's copy — on a path
    /// that has nothing to do with layout at all. Pinned through the real client, not by calling
    /// `bumpLayoutGeneration()` directly, so it is a fact about a live production path rather than about
    /// the counter.
    func test_lastObservedLayoutGenerationLagsAfterAnAnnotationWrite_theOtherDisclosedDivergence() {
        let (v, backend) = realCanvas()
        v.layoutContent()
        XCTAssertEqual(backend.lastObservedLayoutGeneration, v.layoutGeneration, "in step after a layout")

        v.annotationClient.invalidateTemporaryAttributes(in: NSRange(location: 0, length: 1),
                                                         revision: v.documentRevision)

        XCTAssertEqual(backend.lastObservedLayoutGeneration, v.layoutGeneration - 1,
                       "an annotation write advances the canvas counter and notifies nobody")
    }

    /// **RECORDED FOLLOW-UP, task-22h-review.md Major 5 — DISCHARGED HERE, with its premise corrected.**
    /// The obligation read: "once `installInteractions()` gets a real body that actually reads
    /// `host.presentationClient.interactionContainerView` (to hand it to real gesture recognizers), add a
    /// genuine backend-level counterpart". **`installInteractions()` does not read it, and must not** —
    /// it forwards to `installSelectionInteractions()`, which installs the recognizers on the canvas
    /// itself, and `TelegramPresentationInputClient`'s own doc comment states the design outright:
    /// "`interactionContainerView` is the drawing plane only — it grants no interaction authority", the
    /// container is `isUserInteractionEnabled = false`, and the recognizers "stay exactly where they
    /// are". Building an install path that handed the container to recognizers would be a behaviour
    /// change and an architectural reversal.
    ///
    /// What Major 5 was PROTECTING is delivered instead: the test it retired could only pin
    /// `FakeInputPresentationClient`'s own stored `let containerView` — zero real coverage. This one runs
    /// against the REAL `TelegramPresentationInputClient` on a real canvas, exercises operations across
    /// the backend's lifetime, and asserts the identity never moves. The invariant under test is
    /// `prepareInteractionContainer()`'s ("`selectionChromeContainer` … must have a container identity
    /// that is STABLE for the whole backend lifetime"), which is why forcing the lazy container into
    /// existence at attach time exists at all.
    func test_interactionContainerViewIdentity_isStableAcrossTheBackendLifetime() {
        let (v, backend) = realCanvas()
        let client = v.presentationClient
        let atAttach = client.interactionContainerView

        // Operations spanning the things that historically re-created chrome: a layout pass, a viewport
        // scroll, a selection change, a document mutation, and a focus transition.
        v.layoutContent()
        v.viewportDidChange()
        v.setSelectionForTesting(anchor: 0, head: 3)
        v.insertText("x")
        XCTAssertTrue(v.becomeFirstResponder())
        _ = v.resignFirstResponder()

        XCTAssertTrue(client.interactionContainerView === atAttach,
                      "the interaction container identity must not move while the backend is attached")
        XCTAssertTrue(client.interactionContainerView === v.selectionChromeContainer,
                      "…and it is the canvas's own chrome container, not a fresh view")
        withExtendedLifetime(backend) {}
    }
}
#endif
