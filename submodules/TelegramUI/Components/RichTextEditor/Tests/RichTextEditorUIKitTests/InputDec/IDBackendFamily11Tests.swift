#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Task C14 — Family 11 (spellchecking and annotations), the LAST of the 47 `incomingCallbacks`
/// manifest rows and the gate-opening task: once this family lands, `incomingCallbacks` should
/// resolve for the first time in the whole programme, and `isSupported()` should flip to `true` —
/// see this task's own report (`task-C14-report.md`) for the before/after measurements.
///
/// **Testing shape, decided by this task (recorded here and in DIVERGENCES.md entry 14):** the
/// seven annotation callbacks and the two spellchecking thunks are backed by UNDECLARED,
/// kernel/OS-driven-only private selectors (`TGRichTextInputDecLayoutController.m` /
/// `TGRichTextInputDecCanvasCallbacks.m`) with NO Swift-visible entry point that could trigger a
/// genuine private-controller call deterministically in a unit test — the real native-checking
/// machinery that would drive `annotatedSubstringForRange:` etc. is async and OS-scheduled (the
/// package CLAUDE.md's own admission: grammar checking "did NOT fire in the unit-test host").
/// `IDBackendFamily4Tests` (Task C7) already set the precedent for a multi-arg undeclared thunk:
/// it drives `storageFacadeForTesting` directly rather than the private selector that sets its
/// latch. This suite follows the identical shape via the new `IDTextEditorBackend
/// .bridgeForTesting` hook — driving the BRIDGE's own forwarding logic, which is the layer this
/// task actually writes new behavior in; the layout controller's one-line casts above it add
/// nothing beyond ABI matching, which the manifest resolver already certifies structurally (see
/// this task's report for the mismatch-count measurement).
///
/// Gated exactly like every other `.inputDec` suite in this stage.
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily11Tests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// A table-driven pass over the seven annotation callbacks: each bridge method forwards to
    /// EXACTLY the matching `RichTextInputAnnotationClient` member, exactly once, with no cross-
    /// talk between rows. `FakeInputAnnotationClient`'s own counters/log (via the shared
    /// `RichTextInputEventLog`) are the seam plan's default per-client call-count instrument.
    func test_theSevenAnnotationCallbacksMapOneToOneOntoTheAnnotationClient() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        guard let bridge = h.idBackend.bridgeForTesting else {
            return XCTFail("bridgeForTesting must be non-nil once attached")
        }
        let range = NSRange(location: 1, length: 3)

        _ = bridge.annotatedSubstring(forRange: range, revision: 0)
        XCTAssertEqual(h.annotation.annotatedSubstringReadCount, 1,
                       "annotatedSubstring(forRange:revision:) must reach the client exactly once")

        _ = bridge.annotationValue(forKey: "k", atPosition: 2, revision: 0)
        XCTAssertEqual(h.annotation.annotationValueReadCount, 1,
                       "annotationValue(forKey:atPosition:revision:) must reach the client exactly once")

        XCTAssertTrue(bridge.addAnnotationKey("k", value: "v", range: range, revision: 0))
        XCTAssertEqual(h.log.count("annotationAdd"), 1,
                       "addAnnotationKey(_:value:range:revision:) must reach the client exactly once")

        XCTAssertTrue(bridge.removeAnnotationKey("k", range: range, revision: 0))
        XCTAssertEqual(h.log.count("annotationRemove"), 1,
                       "removeAnnotationKey(_:range:revision:) must reach the client exactly once")

        XCTAssertTrue(bridge.addRenderingAttributes([:], range: range, revision: 0))
        XCTAssertEqual(h.annotation.addRenderingAttributesCallCount, 1,
                       "addRenderingAttributes(_:range:revision:) must reach the client exactly once")

        XCTAssertTrue(bridge.removeRenderingAttributes([], range: range, revision: 0))
        XCTAssertEqual(h.annotation.removeRenderingAttributesCallCount, 1,
                       "removeRenderingAttributes(_:range:revision:) must reach the client exactly once")

        bridge.invalidateTemporaryAttributes(inRange: range, revision: 0)
        XCTAssertEqual(h.annotation.invalidateTemporaryAttributesCallCount, 1,
                       "invalidateTemporaryAttributes(inRange:revision:) must reach the client exactly once")
        XCTAssertEqual(h.annotation.lastInvalidatedRange, range)
    }

    /// The `revision` value crosses the bridge UNCHANGED — a distinguishing, non-zero, non-default
    /// value round-trips exactly, proving no site accidentally substitutes the bridge's own
    /// `documentRevision()` (which would defeat `TelegramAnnotationInputClient`'s staleness gate —
    /// see DIVERGENCES.md entry 14).
    func test_annotationWritesCarryTheDocumentRevision() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        guard let bridge = h.idBackend.bridgeForTesting else {
            return XCTFail("bridgeForTesting must be non-nil once attached")
        }
        let range = NSRange(location: 0, length: 1)
        let distinguishingRevision: UInt64 = 424_242

        _ = bridge.addAnnotationKey("k", value: "v", range: range, revision: distinguishingRevision)
        guard case .annotationAdd(_, let addRevision)? = h.log.events.last else {
            return XCTFail("expected an annotationAdd event")
        }
        XCTAssertEqual(addRevision, distinguishingRevision)

        _ = bridge.removeAnnotationKey("k", range: range, revision: distinguishingRevision)
        guard case .annotationRemove(_, let removeRevision)? = h.log.events.last else {
            return XCTFail("expected an annotationRemove event")
        }
        XCTAssertEqual(removeRevision, distinguishingRevision)
    }

    /// `setContinuousSpellCheckingEnabled:` -> `canvas.isSpellCheckingEnabled`. Drives the SETTER
    /// thunk's own bridge method both ways (true -> false and back) so the assertion cannot pass
    /// merely because the property already held the target value.
    func test_spellCheckingToggleReachesTheCanvasState() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        guard let bridge = h.idBackend.bridgeForTesting else {
            return XCTFail("bridgeForTesting must be non-nil once attached")
        }
        XCTAssertTrue(h.canvas.isSpellCheckingEnabled, "precondition: the default")

        bridge.setNativeContinuousSpellCheckingEnabled(false)
        XCTAssertFalse(h.canvas.isSpellCheckingEnabled,
                       "setContinuousSpellCheckingEnabled: must reach canvas.isSpellCheckingEnabled")
        XCTAssertFalse(bridge.isNativeContinuousSpellCheckingEnabled())

        bridge.setNativeContinuousSpellCheckingEnabled(true)
        XCTAssertTrue(h.canvas.isSpellCheckingEnabled)
        XCTAssertTrue(bridge.isNativeContinuousSpellCheckingEnabled())
    }

    /// Pins the *existing* Telegram behavior at `DocumentCanvasView.swift`'s `spellResults`
    /// declaration (the brief's cited "486-488" is stale — this task's own report records the
    /// current line numbers, ~1008-1010, and DIVERGENCES.md entry 14 records the drift): annotation
    /// ranges deliberately do NOT shift across a document edit. The spec wants explicit
    /// rebase-or-clear; repairing that would be a behavior change forbidden during this extraction
    /// (D17, `TelegramAnnotationInputClient`'s own header). Uses the LEGACY backend deliberately —
    /// the mechanism under test is Telegram's pre-existing `spellResults` side table, shared
    /// verbatim by both backends, and the legacy `insertText` path is the well-trodden one; this
    /// test still lives in this (`.inputDec`-gated) suite because the brief places it here.
    func test_annotationRangesAreNotRebasedAcrossAnEdit_documentedDivergence() {
        let h = makeBackendHarness(backend: .legacy)
        defer { h.tearDown() }
        h.setParagraphs(["Hello wrold today"], width: 300)
        // The annotation client's `range` is on the GLOBAL axis, which is 1-based (the first
        // paragraph's text starts at global position 1 — see this package's own "global position
        // axis is 1-based" note); `spellResults` stores REGION-LOCAL (0-based) offsets. "wrold"
        // sits at local index 6, i.e. global position 7.
        let globalRange = NSRange(location: 7, length: 5)   // "wrold", global axis
        let storedRange = NSRange(location: 6, length: 5)   // "wrold", region-local axis
        let revision = h.canvas.documentRevision
        XCTAssertTrue(h.canvas.annotationClient.addAnnotation(
            key: "spelling", value: DocumentCanvasView.SpellStyle.spelling,
            range: globalRange, revision: revision))
        XCTAssertEqual(h.canvas.spellResults[BlockID("p0")]?.ranges.first?.range, storedRange,
                       "precondition: the flag landed at the expected offsets")

        // A genuine mid-document edit BEFORE the flagged word, one undo step (matches every other
        // direct-canvas edit in this suite, e.g. `CanvasEditingTests`).
        h.canvas.setSelectionForTesting(anchor: 0, head: 0)
        h.undoManager.beginUndoGrouping()
        h.canvas.insertText("X")
        h.undoManager.endUndoGrouping()

        // DOCUMENTED DIVERGENCE: the side table's stored range does NOT shift with the edit, so it
        // still reads the SAME stale offsets — which now cover "Xwrol", not "wrold".
        XCTAssertEqual(h.canvas.spellResults[BlockID("p0")]?.ranges.first?.range, storedRange,
                       "existing Telegram behavior (DIVERGENCES.md entry 14): annotation ranges are " +
                       "not rebased across an edit")
    }
}
#endif
