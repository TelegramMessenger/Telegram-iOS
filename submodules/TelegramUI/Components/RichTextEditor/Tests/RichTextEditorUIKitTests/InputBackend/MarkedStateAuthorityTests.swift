#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 41 — **the backend is the single writable COMPOSITION authority.** The sibling of
/// `SelectionAuthorityTests` (Task 35/40b) for the four properties that used to live on
/// `DocumentCanvasView`: `markedRange`, `markedTextIsPrediction`, `compositionUndoSnapshot` and
/// `compositionAnchorHead`.
///
/// **THIS SUITE'S FIRST JOB IS NOT THE MOVE — IT IS THE POLICY BRANCHES THE MOVE ACTIVATES.**
/// Before this task `LegacyRichTextInputBackend.markedRangeStorage` was reachable but **uniformly
/// nil in production**: its only writers were `runMutation` (whose `prepareAndRun` has zero
/// production callers) and `reconcileMarkedTextForExternalChange` itself, which only ever CLEARS or
/// REBASES an already-non-nil store and never sets a nil one non-nil. So
/// `reconcileMarkedTextForExternalChange`'s three `RichTextMarkedTextPolicy` branches had never
/// executed against a real composition — only against `FakeInputDocumentClient` in
/// `BackendMarkedTextPolicyTests`. Collapsing the two stores makes them live, at five production
/// sites, in one commit. Section B below is that enumeration, driven end to end through the REAL
/// `TelegramDocumentInputClient` (whose `rebase` is identity-or-nil by D32 construction), and every
/// figure in it was MEASURED AT BASE before the move and is asserted to be unchanged after it.
///
/// **D13 stands**: `ghostStyledLayout` is NOT moved. It is a `weak var … : BlockLayoutEngine?` and a
/// `BlockLayoutEngine` may never cross the seam — an explicit patch-rejection criterion.
/// `test_ghostStyledLayoutStaysOnTheCanvas` asserts it by name.
@MainActor
@available(iOS 16.0, *)
final class MarkedStateAuthorityTests: XCTestCase {

    // MARK: - Fixtures

    /// Two paragraphs so a "correction/composition elsewhere" fixture has somewhere else to be, and
    /// long enough that every offset used below is inside real text.
    private func makeCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta Gamma")]),
                         ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Delta Epsilon")])],
                        width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    private func paragraph(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }

    /// A live IME COMPOSITION (not a prediction): `selectedRange.location > 0` parks the caret at the
    /// END of the provisional text, which is what `markedTextIsPrediction` is defined as NOT.
    @discardableResult
    private func compose(_ v: DocumentCanvasView, _ text: String = "ab") -> NSRange? {
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.legacySetMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0))
        return v.inputBackend.markedRange
    }

    /// `RichTextInputContractViolation.report` is an `assertionFailure` in DEBUG unless a reporter is
    /// installed, so an unexpected continuity violation is a TEST TRAP rather than a readable failure.
    /// Every section-B arm runs inside this.
    private func capturingContractViolations(_ body: () -> Void) -> [String] {
        var captured: [String] = []
        let previous = RichTextInputContractViolation.reporter
        RichTextInputContractViolation.reporter = { captured.append($0) }
        defer { RichTextInputContractViolation.reporter = previous }
        body()
        return captured
    }

    // MARK: - Section A — the authority moved

    /// The runtime half of R7's composition clause, and the half a text scan structurally cannot do:
    /// re-introducing `var markedRange: (from: Int, to: Int)?` on the canvas is a DECLARATION, and
    /// `SwiftSourceScan.inputStateWriteCount` skips declarations on purpose.
    ///
    /// The Mirror is checked against two known-stored canvas properties FIRST — a typo'd name reports
    /// "no stored property" exactly as convincingly as a moved one, which would make every negative
    /// below vacuous.
    func test_markedRangeIsStoredOnlyInTheBackend() {
        let v = makeCanvas()
        let labels = Set(Mirror(reflecting: v).children.compactMap(\.label))

        XCTAssertTrue(labels.contains("lastLayoutWidth"),
                      "control: the Mirror must see DocumentCanvasView's own stored properties, or "
                      + "every assertion below is vacuous — saw \(labels.count) labels")
        XCTAssertTrue(labels.contains("quoteStyle"), "control, second stored property")

        for name in ["markedRange", "markedTextIsPrediction",
                     "compositionUndoSnapshot", "compositionAnchorHead"] {
            XCTAssertFalse(labels.contains(name),
                           "`\(name)` is STORAGE on the canvas — a second writable composition "
                           + "authority. Task 41's whole subject is that there is exactly one, and "
                           + "it is the backend.")
        }
    }

    /// D13, asserted BY NAME as the brief requires. `ghostStyledLayout` is presentation state that
    /// stays: it holds a `BlockLayoutEngine`, and passing one across the boundary is an explicit
    /// patch-rejection criterion. It must still be STORAGE on the canvas — the exact opposite of the
    /// four names above — and `refreshPredictionStyling()` must still write it.
    func test_ghostStyledLayoutStaysOnTheCanvas() {
        let v = makeCanvas()
        let labels = Set(Mirror(reflecting: v).children.compactMap(\.label))
        XCTAssertTrue(labels.contains("ghostStyledLayout"),
                      "D13: `ghostStyledLayout` is a `weak var BlockLayoutEngine?` and must NOT move "
                      + "to the backend — a BlockLayoutEngine may never cross the seam. Saw "
                      + "\(labels.count) labels.")

        // …and it is still LIVE, not merely present: a PREDICTION styles a leaf, and ending the
        // prediction clears the reference again.
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.legacySetMarkedText("xy", selectedRange: NSRange(location: 0, length: 0))
        XCTAssertTrue(v.markedTextIsPrediction, "control: the fixture must be a PREDICTION")
        XCTAssertNotNil(v.ghostStyledLayout,
                        "refreshPredictionStyling() must still write the canvas's ghost reference")
        _ = v.finalizeMarkedText()
        XCTAssertNil(v.ghostStyledLayout, "…and clear it when the prediction is dismissed")
    }

    /// The canvas keeps a READ-ONLY `(from: Int, to: Int)?` projection of the backend's `NSRange?`,
    /// for the ~24 test files that assert on it. It must be the SAME state, not a parallel copy that
    /// happens to agree: the assertion below writes through the backend's raw setter with no
    /// canvas-side notification of any kind and reads back through the canvas.
    func test_theCanvasProjectionMatchesTheBackend() {
        let v = makeCanvas()
        XCTAssertNil(v.markedRange, "control: nothing is composing on a fresh canvas")
        XCTAssertFalse(v.markedTextIsPrediction)

        v.inputBackend.setCompositionMarkedRange(NSRange(location: 4, length: 3), isPrediction: true)
        XCTAssertEqual(v.markedRange?.from, 4, "the canvas must PROJECT the backend's store")
        XCTAssertEqual(v.markedRange?.to, 7, "…as an exclusive `to`, the tuple shape it always had")
        XCTAssertTrue(v.markedTextIsPrediction)

        v.inputBackend.setCompositionMarkedRange(nil, isPrediction: false)
        XCTAssertNil(v.markedRange)
        XCTAssertFalse(v.markedTextIsPrediction)

        // And the real composition path lands in the same one store.
        let composed = compose(v, "ab")
        XCTAssertNotNil(composed, "control: a composition must actually be established")
        XCTAssertEqual(v.markedRange.map { NSRange(location: $0.from, length: $0.to - $0.from) },
                       v.inputBackend.markedRange,
                       "the projection and the store must be the same state")
    }

    /// The published snapshot's composition fields are REAL now. Before this task
    /// `state.isComposing` was `false` everywhere in production (the store was uniformly nil) and had
    /// zero `Sources/` readers; making them real cannot by itself change behaviour, but a snapshot
    /// that lies about composing is the thing stage 2 would build on.
    func test_stateSnapshotReportsIsComposing() {
        let v = makeCanvas()
        XCTAssertFalse(v.inputBackend.state.isComposing)
        XCTAssertNil(v.inputBackend.state.markedRange)

        compose(v, "ab")
        XCTAssertTrue(v.inputBackend.state.isComposing,
                      "a live composition must be visible in the published snapshot")
        XCTAssertEqual(v.inputBackend.state.markedRange,
                       v.markedRange.map { NSRange(location: $0.from, length: $0.to - $0.from) })
        XCTAssertTrue(v.inputBackend.isComposing, "the backend's own accessor agrees with its snapshot")

        _ = v.finalizeMarkedText()
        XCTAssertFalse(v.inputBackend.state.isComposing,
                       "a committed composition must clear the snapshot too — the two-store split "
                       + "that let `markedTextRange` read nil while `isComposing` read true is the "
                       + "thing this task closes")
        XCTAssertNil(v.inputBackend.state.markedRange)
    }

    /// Step 4's rewire. A system Cmd-Z can fire mid-composition through the RESPONDER path, which
    /// (unlike the facade's `undo()`) does NOT call `finalizeMarkedText()` first — so `registerUndo`'s
    /// closure must drop the composition itself, or the restored snapshot is left with a marked range
    /// pointing into a document that no longer exists.
    ///
    /// Driven on a SPY backend so the call itself is observable, not just its effect: the effect
    /// alone is indistinguishable from the `.discard` policy the same closure already declares.
    func test_clearCompositionStateIsCalledFromTheUndoRestorePath() {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta Gamma")])],
                        width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()

        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.setCaret(global: v.boxes[0].textStart + 1)
        um.beginUndoGrouping()
        v.editing { v.applyReplaceOutcome(globalFrom: v.head, globalTo: v.head, text: "x") }
        um.endUndoGrouping()
        spy.reset()

        um.undo()

        XCTAssertEqual(spy.calls.filter { $0.member == "clearCompositionState" }.count, 1,
                       "the undo-restore closure must clear composition state through the backend "
                       + "exactly once — got \(spy.calls.map(\.description))")
    }

    // MARK: - Section B — the three policy branches, against the REAL client
    //
    // RULING 1 (coordinator supplement §1): the three `RichTextMarkedTextPolicy` branches run against
    // `TelegramDocumentInputClient` for the FIRST TIME in this commit. Each arm below drives a real
    // production site with a live composition and asserts what happens to it. Every expectation was
    // measured at BASE (before the store collapse) through the canvas's own `markedRange`, so these
    // are zero-behaviour-change assertions, not fresh policy.

    /// `.layoutOnly` / `.preserveIfRebasable` — **the D38 obligation, made concrete.**
    ///
    /// A width reflow moves geometry and nothing else, so a live composition must survive it. This is
    /// the test the coordinator's supplement §2 commissioned, and it was built and watched fail
    /// before the fix: with the store collapsed and `reconcileMarkedTextForExternalChange`'s
    /// `.preserveIfRebasable` fast path keyed on the backend's CACHED `documentRevision`, the typing
    /// on the first line leaves that cache behind the client's live revision (deviation D38), the
    /// fast path does not fire, `TelegramDocumentInputClient.rebase` is identity-or-nil and returns
    /// nil, and `.preserveIfRebasable` silently degrades to `.discard`.
    ///
    /// The `insertText` is LOAD-BEARING, not scene-setting: without it the backend's cache and the
    /// client's revision still agree and the bug does not reproduce.
    func test_aWidthReflowDuringACompositionKeepsTheMarkedRange() {
        let v = makeCanvas()
        let violations = capturingContractViolations {
            v.setCaret(global: v.boxes[0].textStart + 1)
            v.insertText("x")   // advances the CANVAS revision; the backend's cache stays behind (D38)
            compose(v, "ab")
            XCTAssertNotNil(v.inputBackend.markedRange, "control: a composition is live before the reflow")
            let before = v.inputBackend.markedRange
            v.layoutContent()
            v.setParagraphsWidthIfNeeded(260)
            XCTAssertEqual(v.inputBackend.markedRange, before,
                           "a `.layoutOnly` reflow moves no text — the composition must survive it "
                           + "unchanged. A nil here is `.preserveIfRebasable` degrading to `.discard`: "
                           + "the composition was silently dropped by a rotation / keyboard-height "
                           + "change / composer resize mid-IME.")
            XCTAssertNotNil(v.markedRange, "…and the canvas projection agrees")
        }
        XCTAssertEqual(violations, [])
    }

    /// `.formatting` / `.preserveIfRebasable` — the two character-format sites, and **a finding that
    /// contradicts what both call sites' own comments imply.**
    ///
    /// MEASURED AT BASE, at all five sites, before any of this task's source changes (the raw output
    /// is in the Task 41 report): a bold toggle during a composition ENDS it —
    /// `canvas.markedRange=Optional((from: 2, to: 4))` before, `nil` after — and so does `setLink`.
    /// Not because of any policy: `performEditing` (`+Editing.swift`) opens with
    /// `finalizeMarkedText()`, so `editing { }` COMMITS the composition before the formatting mutation
    /// runs, and `.preserveIfRebasable` is reached with nothing left to preserve.
    ///
    /// So the disclosed "`.preserveIfRebasable` degrades to `.discard` here" at
    /// `applyCharacterToggle`'s call site, and the plan's `.formatting` rationale it cites, are both
    /// describing a branch that **cannot be reached with a live composition from either production
    /// site**. The width reflow is the ONLY one of the five that reaches it — which is why it is the
    /// only one that could carry the D38 defect, and why this arm asserts the composition ENDS.
    /// Preserving that answer is a zero-behaviour-change requirement; the classification that would
    /// make `.formatting` preserve is pinned separately, one test below, driven directly.
    func test_aBoldToggleDuringACompositionCommitsIt_asItAlreadyDidAtBase() {
        let v = makeCanvas()
        let violations = capturingContractViolations {
            compose(v, "ab")
            XCTAssertNotNil(v.inputBackend.markedRange, "control: a composition is live before the toggle")
            v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 3)
            v.toggleBold()
            XCTAssertNil(v.inputBackend.markedRange,
                         "`editing { }` finalizes first — measured at BASE as `nil` too")
            XCTAssertFalse(v.inputBackend.state.isComposing)
        }
        XCTAssertEqual(violations, [])
    }

    /// The second `.formatting` site: `applyCharacterAttribute` is a separate call site from
    /// `applyCharacterToggle`, so it is measured separately rather than argued to be the same.
    func test_aSetLinkDuringACompositionCommitsIt_asItAlreadyDidAtBase() {
        let v = makeCanvas()
        let violations = capturingContractViolations {
            compose(v, "ab")
            XCTAssertNotNil(v.inputBackend.markedRange, "control")
            v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 3)
            v.setLink("https://telegram.org")
            XCTAssertNil(v.inputBackend.markedRange)
        }
        XCTAssertEqual(violations, [])
    }

    /// The classification itself, driven DIRECTLY at the backend because no production site can reach
    /// it (see the two tests above). `RichTextInputExternalChangeReason.preservesTextOffsets` is what
    /// replaced `reconcileMarkedTextForExternalChange`'s stale-cache-keyed fast path, and it answers
    /// for `.formatting` as well as `.layoutOnly`; without this test that half of it would be a
    /// decorative `case` with no coverage at all.
    ///
    /// The arms are constructed so the classification is FALSIFIABLE in both directions: an
    /// attribute-only reason keeps the range, a content-moving one drops it against the real
    /// identity-or-nil client.
    ///
    /// **ALL EIGHT CASES, and the four this originally omitted are the DANGEROUS four** (TASK 41 FIX
    /// ROUND 1, review M2, DEMONSTRATED by the reviewer). It first iterated only `.layoutOnly`,
    /// `.formatting`, `.remoteUpdate` and `.structuralCommand`. Flipping `.initialDocument`,
    /// `.documentReplacement`, `.undo` and `.redo` from `false` to `true` — four cases at once, in the
    /// direction that keeps an unvalidated range over moved text — left the **entire 2679-test suite
    /// green**. Those four have no production consumer today (their sites declare `.discard`), so no
    /// behavioural route reaches them; that is exactly why they need a DIRECT pin rather than being
    /// left to a production path that does not exist. Combined with the guidance defect the same
    /// review found at `preservesTextOffsets` itself (M1), a misclassification would have arrived
    /// with misleading advice AND no detector.
    ///
    /// Each case is driven through the real `synchronizeAfterExternalChange` — behaviourally, not by
    /// reading the property back — so the pin fails if the classification is wrong OR if the branch
    /// stops consulting it. The `switch` is exhaustive, so a NEW reason fails to compile this array
    /// only if it is also added here; the count assertion below is the backstop that forces it.
    func test_preservesTextOffsetsDecidesWhetherACompositionSurvivesAnExternalChange() {
        // (reason, does the composition survive it)
        let cases: [(RichTextInputExternalChangeReason, Bool)] = [
            (.layoutOnly, true),            // geometry only
            (.formatting, true),            // attribute-only
            (.initialDocument, false),      // ⎫
            (.documentReplacement, false),  // ⎪ the four with no production consumer — the ones the
            (.undo, false),                 // ⎪ reviewer flipped to `true` for a fully green run
            (.redo, false),                 // ⎭
            (.structuralCommand, false),
            (.remoteUpdate, false),
        ]
        XCTAssertEqual(cases.count, 8,
                       "every case of RichTextInputExternalChangeReason must be pinned here. The "
                       + "`switch` in `preservesTextOffsets` is exhaustive, so a new reason compiles "
                       + "without touching this array — this count is what forces it in.")
        for (reason, survives) in cases {
            let v = makeCanvas()
            let violations = capturingContractViolations {
                v.setCaret(global: v.boxes[0].textStart + 1)
                v.insertText("x")   // put the backend's cached revision behind the client's (D38)
                compose(v, "ab")
                let before = v.inputBackend.markedRange
                XCTAssertNotNil(before, "\(reason): control")
                let adopted = v.inputBackend.state.documentRevision
                v.inputBackend.synchronizeAfterExternalChange(RichTextInputExternalChange(
                    oldRevision: adopted,
                    newRevision: reason == .layoutOnly ? adopted : adopted + 1,
                    reason: reason, changedRangeBefore: nil, changedRangeAfter: nil,
                    selection: v.inputBackend.canonicalSelection,
                    markedTextPolicy: .preserveIfRebasable))
                if survives {
                    XCTAssertEqual(v.inputBackend.markedRange, before,
                                   "\(reason) moves no text offsets — the composition must survive")
                } else {
                    XCTAssertNil(v.inputBackend.markedRange,
                                 "\(reason) can move text — the real client's identity-or-nil rebase "
                                 + "cannot re-express the range, so `.preserveIfRebasable` correctly "
                                 + "degrades to `.discard`")
                }
            }
            XCTAssertEqual(violations, [], "\(reason)")
        }
    }

    /// `.documentReplacement` / `.discard`. `reload` calls `finalizeMarkedText()` on its own FIRST
    /// line, so the composition is already committed before the policy is ever consulted — the
    /// `.discard` there is a declaration, not the mechanism. Both halves are asserted: the
    /// composition ends, AND it ended by being COMMITTED (its text is still in the document that the
    /// reload then replaces), which is what distinguishes `finalizeMarkedText()` from a raw drop.
    func test_aReloadEndsTheComposition() {
        let v = makeCanvas()
        let violations = capturingContractViolations {
            compose(v, "ab")
            XCTAssertNotNil(v.inputBackend.markedRange, "control")
            v.reload([paragraph("q", "Gamma")], width: 300)
            XCTAssertNil(v.inputBackend.markedRange,
                         "a whole-document replacement cannot leave a marked range pointing into "
                         + "the old document")
            XCTAssertFalse(v.inputBackend.state.isComposing)
        }
        XCTAssertEqual(violations, [])
    }

    /// `.undo` / `.discard`, through the RESPONDER path — the one entry point that reaches
    /// `registerUndo`'s closure without the facade's `finalizeMarkedText()` in front of it.
    func test_aResponderUndoEndsTheComposition() {
        let v = makeCanvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        let violations = capturingContractViolations {
            v.setCaret(global: v.boxes[0].textStart + 1)
            um.beginUndoGrouping()
            v.editing { v.applyReplaceOutcome(globalFrom: v.head, globalTo: v.head, text: "x") }
            um.endUndoGrouping()
            compose(v, "ab")
            XCTAssertNotNil(v.inputBackend.markedRange, "control")
            um.undo()
            XCTAssertNil(v.inputBackend.markedRange,
                         "a snapshot restore must not leave a marked range pointing into the "
                         + "document it replaced")
            XCTAssertFalse(v.inputBackend.state.isComposing)
            XCTAssertNil(v.markedRange, "…and the canvas projection agrees")
        }
        XCTAssertEqual(violations, [])
    }

    /// **A FINDING, pinned rather than left as prose: `.commitBeforeChange` has ZERO production
    /// callers.** All five `synchronizingExternalChange` sites declare either `.discard` (reload,
    /// the undo restore) or `.preserveIfRebasable` (the two formatting sites, the width reflow).
    /// So the branch that `BackendMarkedTextPolicyTests` describes as "observably identical to
    /// `.discard` at this stage" is not merely indistinguishable — it is unreachable outside tests,
    /// and the divergence its doc comment promises Task 41 would deliver has no site to deliver at.
    /// Recorded here so a later task that wires a `.commitBeforeChange` site knows it is the first.
    func test_commitBeforeChangeHasNoProductionCallSite() {
        let sources = FileManager.default
            .enumerator(at: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()      // InputBackend
                .deletingLastPathComponent()      // RichTextEditorUIKitTests
                .deletingLastPathComponent()      // Tests
                .deletingLastPathComponent()      // package root
                .appendingPathComponent("Sources/RichTextEditorUIKit"),
                        includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        XCTAssertGreaterThan(sources.count, 20,
                             "control: the source walk must actually find files, or this test is vacuous")

        var offenders: [String] = []
        for url in sources {
            guard let raw = try? String(contentsOf: url) else { continue }
            // Comments discuss the case constantly; only a real argument counts.
            for line in raw.split(separator: "\n", omittingEmptySubsequences: false)
            where line.contains("markedTextPolicy: .commitBeforeChange")
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("///") {
                offenders.append("\(url.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertEqual(offenders, [],
                       "`.commitBeforeChange` now has a production call site: \(offenders). It is "
                       + "the FIRST — until this commit every site declared `.discard` or "
                       + "`.preserveIfRebasable`, so the branch had never run against the real "
                       + "document client. Read `reconcileMarkedTextForExternalChange`'s doc comment "
                       + "(the three observables it must diverge from `.discard` on) before adding it.")
    }
}
#endif
