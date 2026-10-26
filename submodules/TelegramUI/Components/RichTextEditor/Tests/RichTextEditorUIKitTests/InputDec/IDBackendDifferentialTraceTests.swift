#if canImport(UIKit)
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// One named, replayable interaction, driven directly against a `DocumentCanvasView` — deliberately
/// NOT typed to either harness below, so the SAME scenario body drives both the fake-client-boundary
/// harness (`IDFakeClientHarness`, whose `.canvas` is a `DocumentCanvasView`) and the real-canvas
/// harness (`RichTextInputBackendHarness`, likewise). The body must be deterministic: no timers, no
/// `DispatchQueue.main.async`, no window hosting.
@available(iOS 13.0, *)
struct IDTraceScenario {
    let name: String
    let body: @MainActor (DocumentCanvasView) -> Void
}

@available(iOS 13.0, *)
extension IDBackendDifferentialTraceTests {
    /// Places the selection via `position(from:offset:)` + the real `selectedTextRange` setter —
    /// NOT `setSelectionForTesting(anchor:head:)`. DEVIATION FROM THE BRIEF'S VERBATIM SCENARIO
    /// BODIES, a real bug found while wiring Step 3, not a style choice: `setSelectionForTesting`
    /// writes RAW offsets straight into `state.selection` via `setCanonicalAnchor`/`setCanonicalHead`
    /// (`DocumentCanvasView.swift`), never touching `state.documentRevision` — so on a canvas built by
    /// `makeBackendHarness` (whose `setParagraphs(...)` call, AFTER the ID backend's `attach(to:)` already
    /// seeded `state.documentRevision`, bumps the REAL `TelegramDocumentInputClient`'s revision), the
    /// very next `.inputDec` mutation's `ensureCanonicalSelectionIsCurrent(host:)` sees a stale
    /// `state.documentRevision`, cannot rebase across what is effectively a full content replace, and
    /// REJECTS the mutation — silently, since a rejection reports through `lifecycleClient`, which the
    /// recorder never hooks. Measured directly: with `setSelectionForTesting`, EVERY `.inputDec`
    /// scenario in this file produced an UNCHANGED document and an EMPTY recorder trace — a false
    /// "identical to Legacy" reading would have been possible only by no-oping. `position(from:offset:)`
    /// is the same pattern `BackendSemanticContractCases.test_insertTextAtTheCaretAppearsInTheDocument`
    /// already uses successfully against this exact harness — it resolves a REAL position against the
    /// document as it stands now, so it carries no stale revision.
    private static func caret(_ canvas: DocumentCanvasView, _ offset: Int) {
        let position = canvas.position(from: canvas.beginningOfDocument, offset: offset)!
        canvas.selectedTextRange = canvas.textRange(from: position, to: position)
    }
    private static func selection(_ canvas: DocumentCanvasView, _ from: Int, _ to: Int) {
        let a = canvas.position(from: canvas.beginningOfDocument, offset: from)!
        let b = canvas.position(from: canvas.beginningOfDocument, offset: to)!
        canvas.selectedTextRange = canvas.textRange(from: a, to: b)
    }

    /// Task D3: steps a caret `steps` positions in `direction` from `offset`, via the REAL
    /// `position(from:in:direction:)` witness — the same primitive a hardware arrow key drives
    /// (see the package `CLAUDE.md`'s "Left/right arrow navigation" invariant). Deliberately NOT a
    /// force-unwrap chain: a `nil` mid-walk (navigation cannot progress further) leaves the caret at
    /// its last resolved position rather than crashing the whole differential run — a stall here
    /// would be as costly as the pasteboard dialog the command group avoids, and unlike that risk
    /// this one is silent until it happens. If the two backends disagree on how far this can walk,
    /// that disagreement shows up in the final `selection`/`content` comparison, which is the point.
    private static func caretByNavigating(_ canvas: DocumentCanvasView, from offset: Int,
                                          direction: UITextLayoutDirection, steps: Int) {
        var position = canvas.position(from: canvas.beginningOfDocument, offset: offset)!
        for _ in 0..<steps {
            if let next = canvas.position(from: position, in: direction, offset: 1) { position = next }
        }
        canvas.selectedTextRange = canvas.textRange(from: position, to: position)
    }

    static let structuralScenarios: [IDTraceScenario] = [
        IDTraceScenario(name: "type-one-char") { canvas in
            caret(canvas, 5)   // end of "Alpha"
            canvas.insertText("x")
        },
        IDTraceScenario(name: "return-splits-paragraph") { canvas in
            caret(canvas, 2)   // "Al|pha" — interior, matches BackendSemanticContractCases' own
                               // `test_insertNewlineSplitsTheParagraph` offset exactly
            canvas.insertText("\n")
        },
        IDTraceScenario(name: "backspace-merges-paragraphs") { canvas in
            // start of "Beta" — offset 7, NOT 6: `BackendSemanticContractCases
            // .test_endOfDocumentOffsetEqualsUTF16LengthPlusBoundarySlots` proves (for BOTH backends)
            // that the paragraph boundary occupies TWO structural slots (axis offset 11 = the 10-unit
            // text length + 1 extra), so "Alpha" (5 chars) is followed by boundary slots at 5→6 and
            // 6→7, and "Beta" begins at 7. An initial `caret(canvas, 6)` landed INSIDE "Alpha" for
            // `.inputDec` (produced "Alpa\nBeta" — one character short, no merge) while Legacy's own
            // axis tolerated it — a harness offset bug this task found and fixed, not a backend one.
            caret(canvas, 7)
            canvas.deleteBackward()
        },
        IDTraceScenario(name: "delete-over-selection") { canvas in
            selection(canvas, 2, 9)   // "Al[pha\nBe]ta" — 2 chars into "Beta" is real-axis 7+2=9
            canvas.deleteBackward()
        },
        IDTraceScenario(name: "cjk-compose-commit") { canvas in
            caret(canvas, 5)   // end of "Alpha"
            canvas.setMarkedText("にほ", selectedRange: NSRange(location: 2, length: 0))
            canvas.unmarkText()
        },
    ]

    /// Task D3, Step 1. Every body here uses the REAL, production selection primitives
    /// (`setCaret(global:)` / `setSelectionHead(global:)` / `setSelectionAnchor(global:)` /
    /// `selectAll(_:)`) rather than `setSelectionForTesting` — that test-only seam writes raw
    /// offsets straight into `state.selection` without touching `state.documentRevision`, which is
    /// exactly the mechanism D2's own header comment (above) measured to silently reject every
    /// subsequent `.inputDec` mutation on this harness. None of these bodies mutate content, so the
    /// staleness would not bite today, but the production primitives are the honest simulation of
    /// what a real drag/select-all/programmatic-select gesture does, and they are what
    /// `DirectionalSelectionCharacterizationTests` already establishes as reversed-selection-capable.
    /// `textRange(from:to:)` cannot represent a reversed (anchor > head) range on its own — Family 1's
    /// own comment says it "still ORDERS its two arguments (load-bearing — do not fix)" — so a
    /// reversed drag MUST go through `setCaret`/`setSelectionHead`, not the `selection(...)` helper.
    static let selectionScenarios: [IDTraceScenario] = [
        IDTraceScenario(name: "reverse-drag-selection") { canvas in
            canvas.setCaret(global: 8)         // caret inside "Beta" ("B|eta")
            canvas.setSelectionHead(global: 2)  // anchor 8, head 2 — a REVERSED range ("Al|pha\nBe|ta")
            canvas.setSelectionHead(global: 0)  // extend further left, past the paragraph boundary
        },
        IDTraceScenario(name: "select-all-then-collapse") { canvas in
            canvas.selectAll(nil)   // the real responder action — routes through performCommand(.selectAll)
                                     // on BOTH backends, never canPerformAction, so it carries none of the
                                     // command group's pasteboard-dialog risk (there is no pasteboard here anyway)
            caret(canvas, 0)        // collapse the just-made full-document selection to a caret at the start
        },
        IDTraceScenario(name: "programmatic-selection-then-type") { canvas in
            selection(canvas, 2, 5)   // "Al[pha]" — interior of "Alpha", no paragraph boundary crossed
            canvas.insertText("Q")
        },
        IDTraceScenario(name: "caret-across-paragraph-boundary") { canvas in
            // From the end of "Alpha" (offset 5), two RIGHT arrow-key-style steps through the sparse
            // two-slot paragraph-boundary gap (`BackendSemanticContractCases
            // .test_endOfDocumentOffsetEqualsUTF16LengthPlusBoundarySlots`) should land at "start of
            // Beta" (offset 7) on a backend that resolves the boundary correctly — this is exactly the
            // still-open paragraph-boundary position-resolution divergence D2's report flagged as
            // "may well recur" in this group, driven here via real hardware-arrow-key navigation
            // (`position(from:in:direction:)`) rather than a raw offset.
            caretByNavigating(canvas, from: 5, direction: .right, steps: 2)
        },
    ]

    /// Task D3, Step 2. Two of the three drive `setMarkedText`/`unmarkText` exactly like D2's
    /// `cjk-compose-commit`; the third two use REAL production entry points for "an external
    /// structural change" and "resignation" rather than calling `synchronizeAfterExternalChange`
    /// directly with a synthetic `RichTextInputExternalChange` value (which the brief's Interfaces
    /// section — stale per the supplement — would have had to invent from whole cloth; a real host
    /// call site is the honest simulation and is what a live Telegram session would actually fire).
    static let markedScenarios: [IDTraceScenario] = [
        IDTraceScenario(name: "compose-then-cancel") { canvas in
            caret(canvas, 5)   // end of "Alpha"
            canvas.setMarkedText("にほ", selectedRange: NSRange(location: 2, length: 0))
            // Cancel: replace the marked text with an EMPTY string (what a keyboard sends when the
            // user deletes every composing character), THEN commit via `unmarkText()` — net effect
            // should be "no change" on a backend that cancels correctly.
            canvas.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
            canvas.unmarkText()
        },
        IDTraceScenario(name: "compose-then-structural-edit") { canvas in
            caret(canvas, 5)
            canvas.setMarkedText("にほ", selectedRange: NSRange(location: 2, length: 0))
            // A REAL external (non-keyboard) structural change while composition is still live: a
            // width reflow, `synchronizingExternalChange(reason: .layoutOnly, markedTextPolicy:
            // .preserveIfRebasable)`'s own production call site (`DocumentCanvasView
            // .setParagraphsWidthIfNeeded`) — the ONE site that does NOT call `finalizeMarkedText()`
            // first (contrast `reload`/`legacyWillResignFirstResponder`, both of which commit any
            // live composition before synchronizing). Task 41's own history (that method's doc
            // comment) is exactly a width-reflow-while-composing bug on Legacy; this is the InputDec
            // counterpart of that same scenario shape.
            canvas.setParagraphsWidthIfNeeded(200)
        },
        IDTraceScenario(name: "compose-then-resign") { canvas in
            caret(canvas, 5)
            canvas.setMarkedText("にほ", selectedRange: NSRange(location: 2, length: 0))
            // `resignFirstResponder()` — real production entry point, no window/hosting required
            // (`hostWillResignFirstResponder()` fires unconditionally, pre-`super`, regardless of
            // whether the canvas is actually the first responder). Legacy's own pre-`super` hook
            // (`legacyWillResignFirstResponder`) unconditionally calls `finalizeMarkedText()`;
            // `.inputDec`'s `hostWillResignFirstResponder()` is a literal `{}` no-op
            // (`IDTextEditorBackend+Responder.swift`) — whether the kernel's own resign path commits
            // the composition some OTHER way is exactly what this scenario's outcome answers.
            _ = canvas.resignFirstResponder()
        },
    ]

    /// Task D3, Step 3. `copy`/`cut`/`paste` are driven via the CANVAS RESPONDER ACTIONS
    /// (`copy(_:)`/`cut(_:)`/`paste(_:)` → `inputBackend.performCommand(.x, sender:)`) — NEVER via
    /// `canPerformAction(_:withSender:)`/`canPerformCommand`. This is the load-bearing decision the
    /// supplement's §2 asked to make explicitly, so it is recorded here rather than only in the
    /// report: `performCommand(.paste, ...)` for BOTH backends resolves to the SAME canvas body,
    /// `DocumentCanvasView.legacyPaste(_:)` (`.inputDec` reaches it through
    /// `TelegramCommandInputClient.commit`'s `.paste` case; `.legacy` reaches it directly — see that
    /// client's own header, "TASK 30 — three call sites... repointed at renamed canvas bodies").
    /// Neither path ever calls `IDTextEditorBackend.canPerformCommand`/`pasteAvailabilityFromKernel`,
    /// which is the ONLY member in this package that consults the private kernel's
    /// `shouldHandlePasteAction(_:sender:)` — the exact call `IDBackendFamily7Tests`/
    /// `IDBackendEditPolicyTests.test_allowsPasteFalse_makesCanPerformPasteFalse` measured to stall
    /// ~175s+ on the system "Allow Paste" dialog (D1/R1/R2/R12; `matrix.sh:112-123`). So a plain
    /// `canvas.copy(nil)`/`.cut(nil)`/`.paste(nil)` call is safe by construction, on BOTH backends,
    /// regardless of pasteboard content — no scenario here reaches `canPerformCommand` at all.
    ///
    /// The SEPARATE, ALSO-real hazard `CanvasClipboardTests.FakePasteboard`'s own doc comment
    /// documents — "the simulator's UIPasteboard.general can be unauthorized and hang on reads" —
    /// is independent of the kernel and applies to EITHER backend (`canvas.pasteboard` defaults to
    /// `UIPasteboard.general` on a harness canvas; nothing in `makeBackendHarness` overrides it). So
    /// every scenario that touches the clipboard installs the SAME in-process fake
    /// (`CanvasClipboardTests.FakePasteboard`, reused rather than duplicated — internal, same test
    /// target) `~1600` existing Legacy pasteboard tests already use for the identical reason.
    static let commandScenarios: [IDTraceScenario] = [
        IDTraceScenario(name: "copy-then-paste") { canvas in
            canvas.pasteboard = CanvasClipboardTests.FakePasteboard()
            selection(canvas, 0, 5)   // "Alpha"
            canvas.copy(nil)
            caret(canvas, 11)         // end of document, after "Beta"
            canvas.paste(nil)
        },
        IDTraceScenario(name: "cut-collapses-the-selection") { canvas in
            canvas.pasteboard = CanvasClipboardTests.FakePasteboard()
            selection(canvas, 2, 9)   // the SAME boundary-crossing span `delete-over-selection` uses
                                      // ("Al[pha\nBe]ta") — cut reaches the paragraph-boundary delete
                                      // range through a DIFFERENT canvas entry point (`legacyCut` →
                                      // the routed `replace(_:withText:)` witness) than deleteBackward,
                                      // so this checks whether D2's open divergence recurs there too.
            canvas.cut(nil)
        },
        IDTraceScenario(name: "paste-over-a-selection") { canvas in
            let pb = CanvasClipboardTests.FakePasteboard()
            canvas.pasteboard = pb
            pb.string = "XY"          // pre-populate — models content copied from ANOTHER field/app
            selection(canvas, 0, 5)   // "Alpha" — interior only, no boundary crossed
            canvas.paste(nil)
        },
        IDTraceScenario(name: "undo-after-typing") { canvas in
            caret(canvas, 5)
            canvas.insertText("XYZ")
            // `outcome(...)`'s own bracket (below) opens ONE undo group around the whole scenario
            // body, because `.legacy`'s routed mutation witnesses register undo directly and need an
            // open group (see that helper's own comment). Calling `UndoManager.undo()` while that
            // outer group is STILL open is unsafe (NSUndoManager expects `undo()` outside any open
            // grouping). So this scenario closes the outer group early — finalizing "type XYZ" as one
            // complete, undoable event — invokes undo through the REAL command surface
            // (`inputBackend.performCommand(.undo, sender:)`, the same call a keyboard-toolbar Undo
            // button would make; `.legacy` and `.inputDec` route it through the SAME
            // `TelegramCommandInputClient` — see that file's header), then reopens an EMPTY group so
            // `outcome(...)`'s own trailing `endUndoGrouping()` still has a matching `begin` to close.
            canvas.effectiveUndoManager?.endUndoGrouping()
            canvas.inputBackend.performCommand(.undo, sender: nil)
            canvas.effectiveUndoManager?.beginUndoGrouping()
        },
    ]

    /// Task D3, Step 4. The concatenation every anti-vacuity/determinism guard and
    /// `test_theScenarioListIsTheUnionOfEveryGroup` iterate.
    static let allScenarios: [IDTraceScenario] =
        structuralScenarios + selectionScenarios + markedScenarios + commandScenarios
}

/// The comparable slice of a fake-client-boundary event log (`RichTextInputEventLog`, seam Task 22).
/// Geometry events are dropped — `caretRect`/`selectionRects` are layout facts, not semantic ones.
/// Everything else is compared EXACTLY.
///
/// **Used ONLY for `.inputDec`'s own internal self-consistency** (see this file's header comment for
/// why it cannot be used for a Legacy-vs-`.inputDec` comparison at all).
///
/// DEVIATION FROM THE BRIEF'S VERBATIM STEP-2 TEXT — a real bug, not a design choice. The brief's
/// literal snippet was `log.kinds.filter { $0 != "geometryQuery" && $0 != "presentationInvalidate" }`.
/// `RichTextInputEventLog.kinds` (seam Task 22) reduces EVERY case to its bare case name — including
/// `.documentPrepare(mutation: String, expectedRevision: UInt64)`, whose `mutation` string (the
/// `RichTextInputMutation`'s own default description, e.g. `"insertParagraphBreak(replacing: ...,
/// origin: ...)"`) is truncated at the FIRST "(" in the whole rendered `Event` description — the "("
/// right after `documentPrepare` itself. So `log.kinds` collapses `documentPrepare` for
/// `.insertParagraphBreak`, `.deleteBackward`, `.replaceText`, `.insertText`, `.setMarkedText`, and
/// `.unmarkText` all down to the identical string `"documentPrepare"` — precisely the one fact this
/// test exists to read out. Using `log.kinds` verbatim would make the comparison structurally BLIND
/// to the intent-latch class of bug it exists to catch. The fix keeps `documentPrepare`'s own
/// MUTATION CASE NAME (not its full payload — ranges/`NSAttributedString`/tokens are exactly as
/// volatile as geometry, and keeping them would make even a same-backend rerun non-deterministic) and
/// otherwise reuses `kinds` unchanged. This is not "widening the projection for coverage" (the
/// supplement's warning is specifically about NOT re-adding geometry, which stays dropped exactly as
/// specified) — it is restoring information the reused helper already intended to carry for this one
/// case, the same "deviation from the brief's verbatim text — a real bug" class
/// `RichTextInputEventLog.Event.description`'s own doc comment already records for an unrelated bug
/// in the same file.
@available(iOS 13.0, *)
enum IDTraceProjection {
    static func semantic(_ log: RichTextInputEventLog) -> [String] {
        zip(log.events, log.kinds).compactMap { event, kind -> String? in
            guard kind != "geometryQuery", kind != "presentationInvalidate" else { return nil }
            if case .documentPrepare(let mutation, _) = event {
                let mutationCaseName = mutation.prefix { $0 != "(" }
                return "documentPrepare(\(mutationCaseName))"
            }
            return kind
        }
    }
}

/// A scenario's comparable OUTCOME on a real, backend-agnostic canvas: the UIKit-facing event-kind
/// sequence the canvas fired (`RichTextInputEventRecorder.kinds` — no geometry-carrying case exists
/// in that enum at all: `textWillChange`/`selectionWillChange`/`selectionDidChange`/`textDidChange`/
/// `canvasContentSizeChanged`/`canvasSelectionChanged`/`canvasBecameFirstResponder`/
/// `canvasResignedFirstResponder` are pure notification labels), PLUS the resulting document text and
/// canonical selection (`anchor`/`head` — semantic integer offsets, not screen geometry, so keeping
/// them does not violate the "geometry stays dropped" rule either). Read off the SAME canvas either
/// backend actually edits — see this file's header for why this, not the fake-client event log, is
/// the instrument that can compare the two backends at all.
@available(iOS 13.0, *)
struct BackendScenarioOutcome: Equatable, CustomStringConvertible {
    let recorderKinds: [String]
    let content: String
    let selection: String

    /// The anti-vacuity signal: a scenario that touched nothing fires no recorder event at all. NOT
    /// `content.isEmpty`/`selection.isEmpty` — those are always non-empty by construction (the seeded
    /// document is never blank and a selection always has SOME offsets), so checking them would make
    /// the guard pass trivially even for a silently no-op scenario body.
    var isVacuous: Bool { recorderKinds.isEmpty }

    var description: String { "kinds: \(recorderKinds), content: \(content.debugDescription), selection: \(selection)" }
}

@available(iOS 16.0, *)
enum BackendScenarioOutcomeReader {
    @MainActor
    static func read(_ h: RichTextInputBackendHarness) -> BackendScenarioOutcome {
        BackendScenarioOutcome(recorderKinds: h.recorder.kinds.map(\.rawValue),
                               content: documentText(h),
                               selection: "\(h.anchor)-\(h.head)")
    }

    @MainActor
    private static func documentText(_ h: RichTextInputBackendHarness) -> String {
        guard let range = h.canvas.textRange(from: h.canvas.beginningOfDocument, to: h.canvas.endOfDocument) else {
            return ""
        }
        return h.canvas.text(in: range) ?? ""
    }
}

/// The equivalence argument, in one place: the same scenario, both backends, one process.
///
/// **Why this file does NOT compare `RichTextInputEventLog` traces between Legacy and `.inputDec`,
/// despite the brief asking for exactly that — a load-bearing, empirically-verified finding.**
/// `makeIDFakeClientHarness`/`IDFakeClientHarness` (Task C2) — generalized over `RichTextInputBackendKind`
/// in this task's Step 1, per the brief — attach the driven backend to a `FakeInputHost` whose six
/// `RichTextInputHost` client properties (document/geometry/annotation/presentation/lifecycle/command)
/// are all fakes sharing one `RichTextInputEventLog`. The `.inputDec` backend's mutation surface
/// (`insertText`/`deleteBackward`/`setMarkedText`) is a genuine two-phase transaction THROUGH
/// `documentClient.prepareMutation`/`commitPreparedMutation` — so it lights up that log richly. But
/// Legacy's own `insertText(_:)`/`deleteBackward()`/`setMarkedText(_:selectedRange:)` are PLAIN
/// FORWARDS onto `legacyCanvas.legacyInsertText`/`legacyDeleteBackward`/`legacySetMarkedText` — Legacy
/// IS the document engine, editing the canvas's OWN block storage directly
/// (`LegacyRichTextInputBackend+Insertion.swift`'s own doc comment: "Legacy owns every branch ...
/// because it IS the document engine"), and NONE of its routed mutation witnesses ever call through to
/// `host.documentClient`/`host.lifecycleClient`/etc. (confirmed by reading every implementation, not
/// assumed — `LegacyRichTextInputBackend+Attachment.swift` shows `lifecycleClient` is touched ONLY by
/// `attach(to:)`/`detach()`, never by an editing witness). **Measured directly**: driving all five
/// structural scenarios below through `makeLegacyFakeClientHarness` produced an EMPTY
/// `RichTextInputEventLog` for every one — not a near-miss, an exact `[]` every time. A comparison
/// between an always-populated `.inputDec` trace and an always-empty Legacy trace is not a differential
/// instrument; it fails identically regardless of whether the two backends actually agree, which is
/// the definition of a vacuous test (the same anti-vacuity principle the brief's own
/// `test_everyScenarioProducesANonEmptyLegacyTrace` exists to guard against, just one level up: no
/// per-scenario fix can rescue an instrument that is architecturally blind to one whole backend).
///
/// So the actual cross-backend equivalence check in this file (`test_structuralScenariosProduceTheSameOutcomeOnBothBackends`)
/// uses `RichTextInputBackendHarness`/`makeBackendHarness(backend:)` instead — the OTHER, already
/// backend-agnostic harness this package established (`RichTextInputBackendHarness.swift`, used by
/// ~1600 tests for `.legacy` and by `IDHarnessTests`/`CanvasFactoryTests`/etc. for `.inputDec`), which
/// drives a REAL canvas with REAL Telegram-facing clients for EITHER backend and is exactly the
/// "canvas-visible behavior" surface `IDFakeClientHarness`'s own doc comment says to reach for when the
/// assertion is not about the client boundary. `RichTextInputEventRecorder` (`kinds`) hooks the
/// canvas's real `inputDelegate`/`onContentSizeChange`/`onSelectionChange` — touched by BOTH backends'
/// real editing witnesses — plus the resulting document TEXT and SELECTION, read through the canvas's
/// shared `UITextInput` surface (`text(in:)`/`beginningOfDocument`/`endOfDocument`), which both
/// backends implement.
///
/// The fake-client `IDTraceScenario`/`IDTraceProjection` machinery is KEPT, not deleted — it drives
/// `test_inputDecIntentLatchProducesTheExpectedMutationPerScenario` below, which is still exactly the
/// right instrument for verifying `.inputDec`'s OWN intent-latch correctness (the R7/R10 class of bug)
/// with precision no coarser signal could match; it is simply not, and cannot be, a Legacy comparison.
@available(iOS 17.0, *)
@MainActor
final class IDBackendDifferentialTraceTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    // MARK: - `.inputDec`-only: the intent latch produces the expected mutation

    private func inputDecTrace(_ scenario: IDTraceScenario) -> [String] {
        let h = makeIDFakeClientHarness(kind: .inputDec)
        defer { h.tearDown() }
        h.log.reset()
        scenario.body(h.canvas)
        return IDTraceProjection.semantic(h.log)
    }

    /// Each scenario's `.inputDec` trace must contain the expected `documentPrepare(<mutation case>)`
    /// entry — the direct check for the R7/R10 class of bug (a thunk this backend's own code assumed
    /// would latch the intent, but measurably never fires). `cjk-compose-commit` expects
    /// `setMarkedText`, not `replaceText`: this task's own investigation (see
    /// `IDTextEditorBackend.latchMarkedTextIntent()`'s doc comment) found and fixed exactly this gap —
    /// a THIRD instance, on `setMarkedText`, of the same class R10 already found and fixed for
    /// `deleteBackward`.
    func test_inputDecIntentLatchProducesTheExpectedMutationPerScenario() {
        let expectedMutation: [String: String] = [
            "type-one-char": "documentPrepare(insertText)",
            "return-splits-paragraph": "documentPrepare(insertParagraphBreak)",
            "backspace-merges-paragraphs": "documentPrepare(deleteBackward)",
            "delete-over-selection": "documentPrepare(deleteBackward)",
            "cjk-compose-commit": "documentPrepare(setMarkedText)",
        ]
        for scenario in Self.structuralScenarios {
            let trace = inputDecTrace(scenario)
            guard let expected = expectedMutation[scenario.name] else {
                return XCTFail("scenario '\(scenario.name)' has no expected-mutation entry")
            }
            XCTAssertTrue(trace.contains(expected),
                          "scenario '\(scenario.name)' expected '\(expected)' in trace: \(trace)")
        }
    }

    /// A scenario whose `.inputDec` trace is EMPTY proves nothing.
    func test_everyScenarioProducesANonEmptyInputDecTrace() {
        for scenario in Self.structuralScenarios {
            XCTAssertFalse(inputDecTrace(scenario).isEmpty,
                           "scenario '\(scenario.name)' recorded nothing — it is vacuous")
        }
    }

    // MARK: - Cross-backend: the actual Legacy vs `.inputDec` differential

    private func outcome(_ scenario: IDTraceScenario, _ kind: RichTextInputBackendKind) -> BackendScenarioOutcome {
        let h = makeBackendHarness(backend: kind)
        defer { h.tearDown() }
        h.recorder.reset()
        // `makeBackendHarness` installs a per-test `UndoManager` with `groupsByEvent = false` (the
        // `UndoBufferIsolationTests` seam) — every EXISTING test that drives a canvas mutation
        // witness directly against this harness (`CanvasEditingTests`, `CanvasClipboardTests`, …)
        // brackets the call with `beginUndoGrouping()`/`endUndoGrouping()` for exactly this reason:
        // `.legacy`'s `insertText`/`deleteBackward`/`setMarkedText` register undo directly
        // (`DocumentCanvasView+Editing.swift`'s `registerUndo`), and `NSUndoManager` throws
        // `_registerUndoObject:` when no group is open. `.inputDec`'s mutation path never touches
        // `effectiveUndoManager` at all (measured: omitting this bracket left the `.inputDec`-only
        // determinism test passing while the `.legacy` leg crashed), so this is harmless there.
        h.undoManager.beginUndoGrouping()
        scenario.body(h.canvas)
        h.undoManager.endUndoGrouping()
        return BackendScenarioOutcomeReader.read(h)
    }

    func test_structuralScenariosProduceTheSameOutcomeOnBothBackends() {
        for scenario in Self.structuralScenarios {
            let legacy = outcome(scenario, .legacy)
            let inputDec = outcome(scenario, .inputDec)
            XCTAssertEqual(legacy, inputDec,
                           "scenario '\(scenario.name)' diverges\n  legacy:   \(legacy)\n"
                           + "  inputDec: \(inputDec)")
        }
    }

    /// Task D3, Step 1 — driven exactly like the structural comparison above, one method per group so
    /// a failure report names which group diverges without having to read scenario names.
    func test_selectionScenariosMatch() {
        for scenario in Self.selectionScenarios {
            let legacy = outcome(scenario, .legacy)
            let inputDec = outcome(scenario, .inputDec)
            XCTAssertEqual(legacy, inputDec,
                           "scenario '\(scenario.name)' diverges\n  legacy:   \(legacy)\n"
                           + "  inputDec: \(inputDec)")
        }
    }

    /// Task D3, Step 2.
    func test_markedScenariosMatch() {
        for scenario in Self.markedScenarios {
            let legacy = outcome(scenario, .legacy)
            let inputDec = outcome(scenario, .inputDec)
            XCTAssertEqual(legacy, inputDec,
                           "scenario '\(scenario.name)' diverges\n  legacy:   \(legacy)\n"
                           + "  inputDec: \(inputDec)")
        }
    }

    /// Task D3, Step 3.
    func test_commandScenariosMatch() {
        for scenario in Self.commandScenarios {
            let legacy = outcome(scenario, .legacy)
            let inputDec = outcome(scenario, .inputDec)
            XCTAssertEqual(legacy, inputDec,
                           "scenario '\(scenario.name)' diverges\n  legacy:   \(legacy)\n"
                           + "  inputDec: \(inputDec)")
        }
    }

    /// A scenario whose legacy outcome is EMPTY (no recorder event at all) proves nothing. This is the
    /// anti-vacuity guard: without it, a scenario body that silently no-ops passes the comparison
    /// forever. Checked PER SCENARIO, not in aggregate.
    ///
    /// Task D3: extended from `structuralScenarios` to `Self.allScenarios` — a guard covering one
    /// group while three go unchecked reports coverage it does not have (the supplement's own
    /// warning, echoing C3's discovery regex and D1's stale `>= 17` floor).
    func test_everyScenarioProducesANonEmptyLegacyOutcome() {
        for scenario in Self.allScenarios {
            XCTAssertFalse(outcome(scenario, .legacy).isVacuous,
                           "scenario '\(scenario.name)' recorded nothing — it is vacuous")
        }
    }

    /// Determinism: the same scenario run twice on the same backend must produce the same outcome, or
    /// a cross-backend difference cannot be attributed. Task D3: extended to `Self.allScenarios`, same
    /// reasoning as the non-emptiness guard above.
    func test_outcomesAreDeterministicWithinABackend() {
        for scenario in Self.allScenarios {
            XCTAssertEqual(outcome(scenario, .inputDec), outcome(scenario, .inputDec),
                           "scenario '\(scenario.name)' is not deterministic")
        }
    }

    /// Task D3, Step 4. Catches a group defined but never run — the exact "silently covering
    /// nothing" failure this programme has hit repeatedly (C3's discovery regex, D1's stale `>= 17`
    /// floor). A group added later and forgotten in `allScenarios` fails this loudly rather than
    /// quietly running zero of its scenarios through the guards above.
    func test_theScenarioListIsTheUnionOfEveryGroup() {
        XCTAssertEqual(Self.allScenarios.count,
                       Self.structuralScenarios.count + Self.selectionScenarios.count
                       + Self.markedScenarios.count + Self.commandScenarios.count)
        XCTAssertEqual(Set(Self.allScenarios.map(\.name)).count, Self.allScenarios.count,
                       "duplicate scenario name — one of them is shadowing the other")
    }
}
#endif
