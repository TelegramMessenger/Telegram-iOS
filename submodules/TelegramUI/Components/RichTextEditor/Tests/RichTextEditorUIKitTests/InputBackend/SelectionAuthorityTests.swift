#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 35 — PHASE 5 OPENS. `DocumentCanvasView.anchor`/`.head` are no longer storage: they are
/// computed forwarders over `LegacyRichTextInputBackend.canonicalSelectionStorage`, which is now the
/// ONE stored copy of the canonical selection (spec hard invariant 3: the backend is the only
/// input-state authority).
///
/// **What this suite pins, and what it deliberately does not.** The backend-side selection contract
/// — reversal survival, `normalizedRange` endpoint identity, "one publish per `setSelection`", the
/// reason reaching publication unchanged — is already pinned by `BackendSelectionContractTests` and
/// `BackendPublicationContractTests` against every conformer. This suite pins only what Task 35
/// itself creates: that the two CANVAS properties read and write that one store, that nothing stale
/// remains on the canvas, and — the divergence recorded below — that a single-endpoint forwarder
/// write is TRANSPARENT (it publishes nothing).
///
/// **TASK 40a NARROWED THE FIRST OF THOSE THREE, because Phase 5 ended.** The forwarder SETTERS are
/// `@available(*, unavailable)` as of Task 40a and deleted by Task 40b, so "the canvas properties
/// WRITE that one store" is a fact with a scheduled end date; this suite can no longer assert it and
/// no longer tries. The half that outlives Phase 5 — the canvas properties READ that one store, with
/// no second copy anywhere — is asserted by every test below, now through `v.anchor`/`v.head` reads
/// rather than writes. See `writeAnchor`/`writeHead` for the language constraint that forced this.
///
/// **DIVERGENCE FROM THE TASK BRIEF, disclosed at the site that proves it.** The brief's Step 3 says
/// `setCanonicalAnchor(_:)`/`setCanonicalHead(_:)` should "build the whole selection and route
/// through the existing `setSelection(_:reason: .programmatic)`, so there is exactly one publication
/// path" — the shape those two members carried since Task 20, when nothing called them. Task 35 is
/// the commit that gives them 117 source callers, and routing them through `setSelection` would have
/// changed behaviour at every one of those sites at once, which Global Constraint 1 (and the whole
/// point of the forwarder strategy) forbids. Two concrete consequences, either of which is decisive:
///   1. **A half-updated selection would be published.** Every one of the ~90 `anchor = x; head = y`
///      pairs writes its endpoints one at a time, so the first write would publish the pair
///      `(new anchor, OLD head)` — a range that exists in no version of this editor — to
///      `presentationClient.apply` and `lifecycleClient.backendDidPublishState`.
///   2. **`setCaret(global:reportSelectionChange: false)` would start reporting.** That parameter
///      exists so a tap does NOT ask the host to scroll the caret into view; a publishing forwarder
///      routes `onSelectionChange?()` through the lifecycle client twice per call regardless of it.
/// Publication arrives at these sites later and deliberately, one cluster at a time, as Tasks
/// 36a-39 convert each raw pair into a single `inputBackend.setSelection(_:reason:)` call with its
/// own gate suites. `test_aSingleEndpointWriteIsTransparentAndPublishesNothing` below is the pin.
///
/// **TASK 40b CLOSED PHASE 5, and this suite is its gate.** The setters are DELETED; `anchor`/`head`
/// are get-only computed projections, so "a write through the canvas" is no longer a thing that
/// exists to test — it does not compile. Task 40a's prediction that "Task 40b inherits this shape and
/// needs no further edit here" held exactly: the deletion required no change to any existing test in
/// this file or anywhere else in the package. Two tests were ADDED at the bottom
/// (`test_theCanvasHasNoWritableSelectionSurface`, `test_everySelectionChangePassesThroughTheBackend`)
/// as the runtime half of R7's `test_exactlyOneWritableSelectionAuthority`.
///
/// **TASK 36a CORRECTION, recorded here because this header is where the prediction was written.**
/// 36a-36c convert `+Editing.swift`'s 34 sites onto the caret-outcome return path, and that path
/// applies its claim through this SAME raw pair rather than through `setSelection` — so those 34
/// sites gain no publication, they merely stop being 34 separate writes. The measurement that chose
/// that shape (a measured red set for the publishing alternative, with a green control) is at
/// `applyCaretOutcome` in `DocumentCanvasView+Editing.swift`, and `CaretOutcomeTests` carries the
/// pins. The forwarders' own transparency, which is all this suite asserts, is unaffected.
@available(iOS 16.0, *)
@MainActor
final class SelectionAuthorityTests: XCTestCase {

    /// One long paragraph, so every offset used below is inside real text and the publication path
    /// (`refreshSelectionUI()` → caret/handle geometry) has something to resolve.
    private func makeCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"),
                                        runs: [TextRun(text: "Alpha Beta Gamma Delta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    /// **TASK 40a REWROTE THESE TWO, and the reason is a language constraint, not a preference.**
    /// They used to be `v.anchor = value` / `v.head = value` — the last two forwarder WRITES in the
    /// package, deliberately kept because this suite's subject was the forwarders themselves.
    /// Task 40a's Step-4 gate flips both setters to `@available(*, unavailable)` so the COMPILER
    /// enumerates any surviving write (an expected-zero scrape has failed four distinct ways on this
    /// branch). Swift offers no way to keep these: an `unavailable` accessor cannot be referenced
    /// from a normal function NOR from an `@available(*, unavailable)` one — measured, both forms
    /// error, and the "an unavailable context may reference an unavailable decl" rule turns out to be
    /// PLATFORM-scoped (`@available(macOS, unavailable)` compiles; `*` does not). An
    /// `@available(*, unavailable)` test also would not run, so suppression could not have saved the
    /// coverage even if it existed.
    ///
    /// **What survives the rewrite, and what does not.** "Writing `v.anchor` reaches the backend" is
    /// on death row regardless — Task 40b DELETES the setters, so that fact stops existing. The
    /// invariant that outlives Phase 5 is the other direction: **a write through the backend is
    /// visible through the canvas GETTERS**, which stay. These helpers now write the backend's D33
    /// pair directly and every assertion below reads back through `v.anchor`/`v.head`, so the suite
    /// still fails if the getters are ever given a second, stale copy of the selection — which is
    /// what "one authority" actually means. Task 40b inherits this shape and needs no further edit
    /// here.
    private func writeAnchor(_ v: DocumentCanvasView, _ value: Int) {
        v.inputBackend.setCanonicalAnchor(value)
    }
    private func writeHead(_ v: DocumentCanvasView, _ value: Int) {
        v.inputBackend.setCanonicalHead(value)
    }

    // MARK: - The store moved

    /// TASK 40a: reads back through the canvas GETTERS as well as the backend, because the helpers
    /// now write the backend directly — a backend-only assertion here would be tautological.
    func test_aCanonicalEndpointWriteIsVisibleThroughTheCanvasGetters() {
        let v = makeCanvas()
        writeAnchor(v, 7)
        XCTAssertEqual(v.inputBackend.canonicalSelection.anchor.utf16Offset, 7,
                       "the D33 pair must write the backend's canonical store")
        XCTAssertEqual(v.inputBackend.canonicalSelectionAnchorOffset, 7)
        XCTAssertEqual(v.anchor, 7,
                       "…and the canvas getter must project it, with no second stored copy")
        // The OTHER endpoint must be untouched — a single-endpoint setter that rebuilt both would
        // silently collapse every `anchor = a; head = b` pair to a caret.
        let headBefore = v.inputBackend.canonicalSelectionHeadOffset
        writeHead(v, 3)
        XCTAssertEqual(v.inputBackend.canonicalSelectionHeadOffset, 3)
        XCTAssertEqual(v.head, 3)
        XCTAssertEqual(v.inputBackend.canonicalSelectionAnchorOffset, 7,
                       "writing head must not disturb anchor (headBefore was \(headBefore))")
        XCTAssertEqual(v.anchor, 7)
    }

    func test_writingTheBackendSelectionIsVisibleThroughTheCanvasForwarders() {
        let v = makeCanvas()
        v.inputBackend.setSelection(
            RichTextCanonicalSelection(anchor: .downstream(9), head: .downstream(4)),
            reason: .programmatic)
        XCTAssertEqual(v.anchor, 9, "the canvas must READ the backend store, not a stale copy")
        XCTAssertEqual(v.head, 4)
    }

    func test_selFromAndSelToDeriveFromTheBackendSelection() {
        let v = makeCanvas()
        v.inputBackend.setSelection(
            RichTextCanonicalSelection(anchor: .downstream(9), head: .downstream(4)),
            reason: .programmatic)
        XCTAssertEqual(v.selFrom, 4, "selFrom is min(anchor, head) over the BACKEND's endpoints")
        XCTAssertEqual(v.selTo, 9)
        // Derived, never cached: a second backend write must move them again with no canvas-side
        // invalidation step in between.
        v.inputBackend.setSelection(
            RichTextCanonicalSelection(anchor: .downstream(2), head: .downstream(6)),
            reason: .programmatic)
        XCTAssertEqual(v.selFrom, 2)
        XCTAssertEqual(v.selTo, 6)
    }

    /// REVERSED means `anchor > head` and STAYS that way. The values are picked so a `min`/`max`
    /// normalisation anywhere in the round trip is visible: a normalising implementation reports
    /// `(4, 9)` and fails both assertions, rather than agreeing by coincidence as `(4, 4)` would.
    func test_reversedSelectionIsPreservedThroughTheCanvasGetters() {
        let v = makeCanvas()
        writeAnchor(v, 9)
        writeHead(v, 4)
        XCTAssertEqual(v.anchor, 9, "anchor must stay the LARGER offset — no normalisation")
        XCTAssertEqual(v.head, 4)
        XCTAssertTrue(v.inputBackend.canonicalSelection.isReversed)
        XCTAssertEqual(v.selFrom, 4)
        XCTAssertEqual(v.selTo, 9)
    }

    // MARK: - Publication

    /// The CANVAS-side half of publication: one whole-selection write through the backend delivers
    /// exactly one host-visible selection report. (The backend-side obligations — publishing exactly
    /// once, with `.selection`, and carrying the caller's `RichTextSelectionChangeReason` through
    /// unchanged — are pinned for every conformer by
    /// `BackendPublicationContractTests.test_selectionOnlyChange_publishesReasonSelection_andEmitsNoTextNotifications`
    /// and `BackendSelectionContractTests.test_selectionChangeReason_reachesPublicationUnchanged`;
    /// this does not restate them.)
    ///
    /// **WHAT THIS DOES NOT PIN, said plainly so a later reader does not credit it with coverage it
    /// lacks** (Task 35 review, m3). Its `reports == 1` line is green on the PRE-Task-35 tree as well
    /// as after — `setSelection` published exactly once before the storage moved too — so the only
    /// assertion that was red before this task is `XCTAssertEqual(v.head, 5)`, i.e. the forwarder READ
    /// that three sibling tests already cover. It is a genuine regression guard and it is kept, but
    /// the new publication fact this task establishes is the NEGATIVE one immediately below: that a
    /// single-endpoint forwarder write publishes NOTHING. This test's name comes from the brief's
    /// Step-1 list; the work its name implies is done by the two contract suites named above.
    func test_setSelectionPublishesOnceWithTheGivenReason() {
        let v = makeCanvas()
        var reports = 0
        v.onSelectionChange = { reports += 1 }
        v.inputBackend.setSelection(
            RichTextCanonicalSelection(anchor: .downstream(5), head: .downstream(5)),
            reason: .keyboard)
        XCTAssertEqual(reports, 1, "one whole-selection write ⇒ exactly one selection report")
        XCTAssertEqual(v.head, 5)
    }

    /// TASK 35's DIVERGENCE, pinned rather than merely documented (see the suite header for why the
    /// brief's "route through `setSelection`" shape was rejected). A single-endpoint forwarder write
    /// updates the store and reports NOTHING — exactly what a raw `anchor = …` did before this task,
    /// which is what makes the forwarder transparent at all 117 source write sites. Rule 19: the
    /// assertion is constructed so the forbidden shape fails it — routing `setCanonicalAnchor`
    /// through `setSelection` makes `reports` 2, not 0.
    func test_aSingleEndpointWriteIsTransparentAndPublishesNothing() {
        let v = makeCanvas()
        var reports = 0
        v.onSelectionChange = { reports += 1 }
        writeAnchor(v, 9)
        writeHead(v, 4)
        XCTAssertEqual(reports, 0,
                       "a single-endpoint write published nothing before Task 35 and must publish " +
                       "nothing after it; publication arrives per cluster in Tasks 36a-39 — see " +
                       "the suite header's Task-36a correction for which of those tasks it is not. " +
                       "TASK 40a: this is now the D33 pair directly, and it is load-bearing for " +
                       "`setSelectionForTesting`, whose body is these same two calls")
        XCTAssertEqual(v.anchor, 9, "…but the write itself must still have landed")
        XCTAssertEqual(v.head, 4)
    }

    // MARK: - One store

    /// The Mirror is the point of this test, so the Mirror itself is checked first: a typo'd property
    /// name reports "no stored property" exactly as convincingly as a converted one, which would make
    /// the whole assertion vacuous. `lastLayoutWidth` and `quoteStyle` are two stored properties
    /// declared alongside `anchor`/`head` on `DocumentCanvasView`; seeing them proves the reflection
    /// is looking at the right object and at the right layer of it (a class Mirror lists only that
    /// class's own stored properties, not `UIView`'s).
    func test_thereIsExactlyOneStoredCopyOfTheSelection() {
        let v = makeCanvas()
        let labels = Set(Mirror(reflecting: v).children.compactMap(\.label))

        XCTAssertTrue(labels.contains("lastLayoutWidth"),
                      "control: the Mirror must see DocumentCanvasView's own stored properties, or " +
                      "the two assertions below prove nothing — saw \(labels.count) labels")
        XCTAssertTrue(labels.contains("quoteStyle"), "control, second stored property")

        XCTAssertFalse(labels.contains("anchor"),
                       "`anchor` is still STORAGE on the canvas — a second selection authority")
        XCTAssertFalse(labels.contains("head"),
                       "`head` is still STORAGE on the canvas — a second selection authority")

        // And the behavioural half of "one copy": a mutation made entirely through the backend is
        // visible through the canvas with no synchronisation step of any kind.
        v.inputBackend.setSelection(
            RichTextCanonicalSelection(anchor: .downstream(11), head: .downstream(3)),
            reason: .programmatic)
        XCTAssertEqual(v.anchor, 11)
        XCTAssertEqual(v.head, 3)
    }

    // MARK: - TASK 40b — the gate

    /// TASK 40b's headline fact: **the canvas has no writable selection surface at all.** The setters
    /// deleted in this task took the last one with them, so this is the runtime half of R7's
    /// `test_exactlyOneWritableSelectionAuthority` (`InputBackendSourceBoundaryTests`) — the half a
    /// text scan structurally cannot do, since re-introducing `var anchor = 0` is a DECLARATION and
    /// that scan skips declarations on purpose.
    ///
    /// It overlaps `test_thereIsExactlyOneStoredCopyOfTheSelection` above by design and the overlap
    /// is not redundancy: that test's subject is "the STORE moved to the backend" (Task 35), this
    /// one's is "no canvas-side writable surface exists" (Task 40b), and they would be deleted for
    /// different reasons. What is genuinely new here is `selFrom`/`selTo`: they are `min`/`max` of the
    /// two projections and a cached copy of EITHER is the same second authority under another name.
    ///
    /// The compile-time half needs no test and cannot have one: `v.anchor = 0` does not build, and a
    /// test asserting that would itself not build. `SourceBoundary`'s scan and this Mirror are what
    /// remain once the compiler has taken its share.
    func test_theCanvasHasNoWritableSelectionSurface() {
        let v = makeCanvas()
        let labels = Set(Mirror(reflecting: v).children.compactMap(\.label))

        // Control first — a Mirror that sees nothing "proves" every negative below (see the sibling
        // test's note; this is the same trap, restated because a reader may run only this one).
        XCTAssertTrue(labels.contains("lastLayoutWidth"),
                      "control: the Mirror must see DocumentCanvasView's own stored properties, or "
                      + "every assertion below is vacuous — saw \(labels.count) labels")

        for name in ["anchor", "head", "selFrom", "selTo"] {
            XCTAssertFalse(labels.contains(name),
                           "`\(name)` is STORAGE on the canvas — a second writable selection authority. "
                           + "Phase 5's whole subject is that there is exactly one, and it is the backend.")
        }

        // …and the projections are LIVE, not a snapshot taken at construction: a backend write with no
        // canvas-side notification of any kind must be visible immediately through all four.
        v.inputBackend.setSelection(
            RichTextCanonicalSelection(anchor: .downstream(13), head: .downstream(2)),
            reason: .programmatic)
        XCTAssertEqual([v.anchor, v.head, v.selFrom, v.selTo], [13, 2, 2, 13])
    }

    /// The other half of the gate: **every canvas-level selection entry point lands in the backend's
    /// one store.** Rule 19 — each leg is armed by seeding the backend to a sentinel the operation
    /// cannot produce, so a canvas that had quietly kept its own copy would report the sentinel and
    /// fail, rather than agreeing by coincidence with an assertion on the expected value alone.
    ///
    /// The four legs are the canvas's real user-facing funnels, deliberately not `setSelection` calls
    /// dressed up: `setCaret(global:)` (tap), `setSelectionHead(global:)` (drag / shift-arrow),
    /// `selectWord(at:)` (double tap) and `selectAllText()` (⌘A). Note what Task 39 measured and
    /// recorded at `setCaret`: the three `set…` funnels do NOT route through
    /// `inputBackend.setSelection(_:reason:)` — they write the raw D33 pair — so this test asserts
    /// where the state LANDS, which is the invariant, and says nothing about which door it used,
    /// which is not.
    func test_everySelectionChangePassesThroughTheBackend() {
        // "Alpha Beta Gamma Delta" is 22 UTF-16 units, but the canvas's GLOBAL axis is not the
        // string's: a paragraph box's text starts at `textStart == 1` and the document carries a
        // trailing position, so `documentSize` is 24 and "Beta" lives at 7..<11. Every literal below
        // is on that axis and the control assertion at the end pins it — measured, not assumed (the
        // first draft of this test used string offsets and failed by exactly one).
        let v = makeCanvas()
        let sentinel = 21

        func seedSentinel() {
            v.inputBackend.setSelection(
                RichTextCanonicalSelection(anchor: .downstream(sentinel), head: .downstream(sentinel)),
                reason: .programmatic)
            XCTAssertEqual(v.anchor, sentinel, "control: the sentinel must be readable before each leg")
        }
        func assertBackendCarries(_ anchor: Int, _ head: Int, _ leg: String) {
            XCTAssertEqual(v.inputBackend.canonicalSelectionAnchorOffset, anchor, "\(leg): backend anchor")
            XCTAssertEqual(v.inputBackend.canonicalSelectionHeadOffset, head, "\(leg): backend head")
            // The projections are the SAME state, not a parallel one that happens to agree.
            XCTAssertEqual(v.anchor, anchor, "\(leg): canvas projection of anchor")
            XCTAssertEqual(v.head, head, "\(leg): canvas projection of head")
        }

        seedSentinel()
        v.setCaret(global: 6)
        assertBackendCarries(6, 6, "setCaret(global:)")

        seedSentinel()
        v.setCaret(global: 6)
        v.setSelectionHead(global: 10)
        assertBackendCarries(6, 10, "setSelectionHead(global:)")

        seedSentinel()
        v.selectWord(at: 9)           // inside "Beta" (global 7..<11)
        assertBackendCarries(7, 11, "selectWord(at:)")

        seedSentinel()
        v.selectAllText()             // RENDERABLE bounds, so 1..<23 rather than 0..<documentSize
        assertBackendCarries(1, 23, "selectAllText()")
        XCTAssertEqual(v.documentSize, 24,
                       "control: the fixture and its global axis are what every literal above assumes")
    }
}
#endif
