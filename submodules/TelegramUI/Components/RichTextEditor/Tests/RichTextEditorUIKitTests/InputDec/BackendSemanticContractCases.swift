#if canImport(UIKit)
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Assertions written ONCE and run against every backend, via one subclass per kind.
///
/// XCTest runs inherited `test_` methods in each concrete subclass, so this base class is the
/// parameterisation mechanism. The base class itself must contribute no runs: `defaultTestSuite`
/// is overridden to be empty when `Self == BackendSemanticContractCases`, otherwise the
/// abstract case runs with a nil kind and every test fails confusingly.
@MainActor
@available(iOS 16.0, *)
class BackendSemanticContractCases: XCTestCase {

    /// Overridden by each subclass. nil marks the abstract base.
    class var backendKind: RichTextInputBackendKind? { nil }

    override class var defaultTestSuite: XCTestSuite {
        backendKind == nil ? XCTestSuite(name: "abstract") : super.defaultTestSuite
    }

    /// R1: every witness this suite drives against `.inputDec` (`caretRect(for:)`,
    /// `setMarkedText(_:selectedRange:)`, …) can hit `IDTextEditorBackend.reportKernelFailure(_:witness:)`,
    /// which routes into `RichTextInputContractViolation.report(...)` — an `assertionFailure()` in
    /// DEBUG unless a reporter is installed first (`RichTextInputContractViolation.swift`'s own
    /// documented override point; `BackendContractCases.setUpWithError()` already does this for the
    /// eight stage-1 contract suites, but this SEPARATE shared-suite fixture — Task C3's
    /// `BackendSemanticContractCases`, parameterised over `LegacyBackendSemanticTests`/
    /// `IDBackendSemanticTests` — never did). Measured directly, not assumed: a real gate-open run
    /// on this worktree crashed the process 4 times through exactly this path — once via
    /// `test_caretRectForAnUnrenderablePositionIsZero` (a foreign `UITextPosition` reaching the
    /// kernel's `-utf16Offset`, `unrecognized selector`) and three times via the suite's
    /// `setMarkedText`-driving tests (`test_setMarkedTextPublishesAMarkedRange`,
    /// `test_markedTextIsReplacedNotAppendedOnASecondSetMarkedText`,
    /// `test_unmarkTextClearsTheMarkedRange`; the kernel's own `NSMutableRLEArray … Out of bounds`).
    /// Installing this here — mirroring `BackendContractCases`'s pattern exactly — converts all four
    /// into observable, measurable test failures (the underlying behavioral gaps are NOT fixed here;
    /// see the R1 clustering doc) instead of process crashes that destroy the whole run's summary.
    private(set) var reportedContractViolations: [String] = []

    override func setUpWithError() throws {
        if Self.backendKind == .inputDec {
            guard #available(iOS 17.0, *), IDTextEditorBackend.isSupported() else {
                throw XCTSkip("the InputDec kernel is not supported on this runtime")
            }
        }
        reportedContractViolations = []
        RichTextInputContractViolation.reporter = { [weak self] message in
            self?.reportedContractViolations.append(message)
        }
    }

    override func tearDown() {
        RichTextInputContractViolation.reporter = nil
        super.tearDown()
    }

    func harness(_ paragraphs: [String] = ["Alpha", "Beta"]) -> RichTextInputBackendHarness {
        makeBackendHarness(backend: Self.backendKind!, paragraphs: paragraphs)
    }

    // MARK: - Family 1: document reads and position/range conversion

    func test_textInWholeDocumentRange_isTheDocumentProjection() {
        let h = harness(); defer { h.tearDown() }
        let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument,
                                       to: h.canvas.endOfDocument)!
        XCTAssertEqual(h.canvas.text(in: whole), "Alpha\nBeta")
    }

    /// CORRECTED BY TASK C3 (empirically, against a real K1 simulator run — Step 3 of the task
    /// brief failed with the brief's literal `offset: -1` until this was fixed; see
    /// `task-C3-report.md`). `beginningOfDocument` is NOT the position axis's raw `0` — the
    /// package `CLAUDE.md`'s "verification traps" entry documents that the axis is sparse and
    /// `beginningOfDocument`/`endOfDocument` deliberately SNAP to the nearest RENDERABLE slot,
    /// never the document's structural open/close-token slot (a caret must never hide on a
    /// non-renderable position). Measured on this harness's default two-paragraph fixture:
    /// `beginningOfDocument` sits at raw offset 1 (raw 0 is the structural open token), and
    /// `position(from:offset:-1)` computes raw offset 0 — which is IN BOUNDS of the underlying
    /// axis (`0...document.utf16Length`) and snaps back to the same renderable position, so it
    /// returns a position equal to `start`, NOT nil. A genuinely out-of-bounds offset (`-1000`,
    /// far below the axis floor) does return nil, and is the offset this test now uses to state
    /// "before the start" without depending on the exact one-slot structural overhape at the edge.
    func test_positionBeforeTheStartIsNil_andAfterTheStartIsNot() {
        let h = harness(); defer { h.tearDown() }
        let start = h.canvas.beginningOfDocument
        XCTAssertNil(h.canvas.position(from: start, offset: -1000))
        XCTAssertNotNil(h.canvas.position(from: start, offset: 1))
    }

    func test_compareAndOffsetUseUTF16OffsetsOnly() {
        let h = harness(); defer { h.tearDown() }
        let a = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 2)!
        let b = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 5)!
        XCTAssertEqual(h.canvas.compare(a, to: b), .orderedAscending)
        XCTAssertEqual(h.canvas.offset(from: a, to: b), 3)
    }

    /// CORRECTED BY TASK C3 (empirically — the brief's literal `, 10)` failed Step 3 with
    /// `("11") is not equal to ("10")`). The position axis is SPARSE exactly at a top-level
    /// paragraph boundary: it carries TWO structural slots there while `text(in:)`'s document
    /// projection emits only ONE `"\n"` character (package `CLAUDE.md`, same verification-traps
    /// entry as above). The harness's default two-paragraph fixture ("Alpha", "Beta") has exactly
    /// one such boundary, so `offset(from:to:)` across the whole document is the UTF-16 text
    /// length PLUS one extra unit for that boundary — 11, not 10 — even though `text(in:)` itself
    /// still reports the plain 10-unit string. This is the documented, load-bearing design (not a
    /// legacy-backend bug): fixing the base-class assertion, not the backend, per this task's own
    /// Step 3 instruction ("a failure here means the base-class assertions are wrong").
    func test_endOfDocumentOffsetEqualsUTF16LengthPlusBoundarySlots() {
        let h = harness(); defer { h.tearDown() }
        let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument, to: h.canvas.endOfDocument)!
        let textLength = h.canvas.text(in: whole)?.utf16.count ?? -1
        XCTAssertEqual(textLength, 10)
        XCTAssertEqual(h.canvas.offset(from: h.canvas.beginningOfDocument, to: h.canvas.endOfDocument),
                       textLength + 1)
    }

    // MARK: - Family 2: geometry

    func test_caretRectAtDocumentStartIsNonEmpty() {
        let h = harness(); defer { h.tearDown() }
        let rect = h.canvas.caretRect(for: h.canvas.beginningOfDocument)
        XCTAssertFalse(rect.isEmpty, "a real document position must report real caret geometry")
    }

    func test_selectionRectsForAWholeParagraphCoverItsHeight() {
        let h = harness(); defer { h.tearDown() }
        let start = h.canvas.beginningOfDocument
        // "Alpha" is the first paragraph — five characters in from the start.
        let end = h.canvas.position(from: start, offset: 5)!
        let range = h.canvas.textRange(from: start, to: end)!
        let rects = h.canvas.selectionRects(for: range)
        XCTAssertFalse(rects.isEmpty)
        let unionRect = rects.dropFirst().reduce(rects[0].rect) { $0.union($1.rect) }
        let caretHeight = h.canvas.caretRect(for: start).height
        XCTAssertGreaterThanOrEqual(unionRect.height, caretHeight * 0.5,
                                    "the selection geometry must cover at least the paragraph's own line height")
    }

    func test_closestPositionToAPointInsideTheFirstLineIsInTheFirstParagraph() {
        let h = harness(); defer { h.tearDown() }
        let start = h.canvas.beginningOfDocument
        let startRect = h.canvas.caretRect(for: start)
        let point = CGPoint(x: startRect.midX + 1, y: startRect.midY)
        guard let resolved = h.canvas.closestPosition(to: point) else {
            XCTFail("closestPosition(to:) must resolve a point inside the rendered first line")
            return
        }
        let offset = h.canvas.offset(from: start, to: resolved)
        // "Alpha" is 5 UTF-16 units; a point on its own first line must resolve within (or at the
        // very boundary of) that span, never into the second paragraph ("Beta").
        XCTAssertGreaterThanOrEqual(offset, 0)
        XCTAssertLessThanOrEqual(offset, 5)
    }

    /// Deviation D9. `caretRect(for:)` is non-optional UIKit surface — a position this backend did
    /// not itself mint (a foreign `UITextPosition` conformer) must degrade to `.zero`, never a
    /// fabricated non-zero rect. `OpaqueForeignTextPosition` mirrors the existing dummy-position
    /// precedent in `NativeTextCheckingResolverTests.swift`.
    func test_caretRectForAnUnrenderablePositionIsZero() {
        let h = harness(); defer { h.tearDown() }
        final class OpaqueForeignTextPosition: UITextPosition {}
        XCTAssertEqual(h.canvas.caretRect(for: OpaqueForeignTextPosition()), .zero)
    }

    // MARK: - Family 3: selection and delegate order

    /// Mirrors `BackendSelectionContractTests.test_selectedTextRangeGetter_handsUIKitAnUnorderedRange_forAReversedSelection`,
    /// now over the CANVAS witness both backends share. `.start`/`.end` must report anchor/head, not
    /// `min`/`max`.
    func test_settingASelectionMovesAnchorAndHead() {
        let h = harness(); defer { h.tearDown() }
        let start = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 2)!
        let end = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 5)!
        h.canvas.selectedTextRange = h.canvas.textRange(from: start, to: end)
        guard let range = h.canvas.selectedTextRange else {
            XCTFail("expected a non-nil selectedTextRange after a write"); return
        }
        XCTAssertEqual(h.canvas.offset(from: h.canvas.beginningOfDocument, to: range.start), 2)
        XCTAssertEqual(h.canvas.offset(from: h.canvas.beginningOfDocument, to: range.end), 5)
    }

    /// `RichTextCanonicalSelection.normalizedRange`'s own doc comment: "the canvas hands UIKit an
    /// unordered range for a reversed drag and that is load-bearing." A reversed drag (anchor at
    /// the HIGHER offset, head at the lower) must round-trip through the `selectedTextRange`
    /// GETTER without ever being reordered to `min`/`max`.
    ///
    /// Seats the reversed selection via `setSelectionForTesting(anchor:head:)` (the harness's raw
    /// selection seam, `h.select(_:_:)`), NOT `textRange(from:to:)` — measured, not assumed:
    /// `textRange(from:to:)` is a DIFFERENT `UITextInput` witness ("give me a range spanning two
    /// positions") and orders its result regardless of argument order, which is the correct
    /// behavior for that witness and would make this test assert against a normalized range
    /// instead of the raw, unordered selection this test exists to pin (caught by a real red run
    /// against `LegacyBackendSemanticTests` — see `task-C6-report.md`).
    ///
    /// Asserts via `offset(from: range.start, to: range.end)` rather than against
    /// `beginningOfDocument`-relative offsets, so this needs no assumption about the fixture's raw
    /// axis start: with anchor(5) as `start` and head(2) as `end` the relative offset is
    /// `head - anchor == -3`; a normalized range (`min`/`max`) would report `+3` regardless of
    /// which endpoint anchor/head actually were, so `-3` uniquely confirms the unordered read.
    func test_aReversedSelectionRoundTripsThroughSelectedTextRange() {
        let h = harness(); defer { h.tearDown() }
        h.select(5, 2)
        guard let range = h.canvas.selectedTextRange else {
            XCTFail("expected a non-nil selectedTextRange after a reversed write"); return
        }
        XCTAssertEqual(h.canvas.compare(range.start, to: range.end), .orderedDescending,
                       "start (the anchor) must sit AFTER end (the head) for a reversed selection")
        XCTAssertEqual(h.canvas.offset(from: range.start, to: range.end), -3,
                       "start must be the ANCHOR (5) and end the HEAD (2), unordered — a normalized " +
                       "range would report +3 here regardless of which endpoint anchor/head were")
    }

    /// Select All (`beginningOfDocument`...`endOfDocument`) must select the whole document
    /// projection — the same two-paragraph fixture `test_textInWholeDocumentRange_isTheDocumentProjection`
    /// (Family 1) already pins for a plain read; this drives it through `selectedTextRange` instead.
    func test_selectAllSelectsTheWholeDocument() {
        let h = harness(); defer { h.tearDown() }
        h.canvas.selectedTextRange = h.canvas.textRange(from: h.canvas.beginningOfDocument,
                                                        to: h.canvas.endOfDocument)
        guard let range = h.canvas.selectedTextRange else {
            XCTFail("expected a non-nil selectedTextRange after Select All"); return
        }
        XCTAssertEqual(h.canvas.text(in: range), "Alpha\nBeta")
    }

    // MARK: - Family 4: insertion

    func test_insertTextAtTheCaretAppearsInTheDocument() {
        let h = harness(); defer { h.tearDown() }
        // End of "Alpha" — offset 5, well inside the first paragraph's own span (never crosses the
        // sparse paragraph-boundary slot the axis carries between "Alpha" and "Beta"; see Family 1's
        // own note on `beginningOfDocument`/offsets).
        let caret = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 5)!
        h.canvas.selectedTextRange = h.canvas.textRange(from: caret, to: caret)
        // `groupsByEvent = false` on the harness's undo manager (deliberate — see the factory's own
        // comment and `RichTextInputBackendHarnessTests`'s pin) means every mutation needs its OWN
        // explicit bracket, exactly like that file's own `insertText` calls.
        h.undoManager.beginUndoGrouping(); h.canvas.insertText("!"); h.undoManager.endUndoGrouping()
        let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument, to: h.canvas.endOfDocument)!
        XCTAssertEqual(h.canvas.text(in: whole), "Alpha!\nBeta")
    }

    /// THE assertion the intent latch exists for. UIKit's real entry point for a software-keyboard
    /// Return key is a RAW range replace with the string `"\n"` — indistinguishable, without the
    /// latch, from any other inserted character. If this passes for `.legacy` and fails for
    /// `.inputDec`, the latch is wrong, and the test must not be weakened.
    func test_insertNewlineSplitsTheParagraph() {
        let h = harness(); defer { h.tearDown() }
        // Between 'A' and 'l' of "Alpha" (offset 2) — interior to the first paragraph.
        let caret = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 2)!
        h.canvas.selectedTextRange = h.canvas.textRange(from: caret, to: caret)
        h.undoManager.beginUndoGrouping(); h.canvas.insertText("\n"); h.undoManager.endUndoGrouping()
        let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument, to: h.canvas.endOfDocument)!
        XCTAssertEqual(h.canvas.text(in: whole), "Al\npha\nBeta",
                       "a newline inside a paragraph must SPLIT it, not just insert a literal '\\n' glyph")
    }

    func test_insertOverASelectionReplacesIt() {
        let h = harness(); defer { h.tearDown() }
        let from = h.canvas.beginningOfDocument
        let to = h.canvas.position(from: from, offset: 5)!   // the whole of "Alpha"
        h.canvas.selectedTextRange = h.canvas.textRange(from: from, to: to)
        h.undoManager.beginUndoGrouping(); h.canvas.insertText("Zzz"); h.undoManager.endUndoGrouping()
        let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument, to: h.canvas.endOfDocument)!
        XCTAssertEqual(h.canvas.text(in: whole), "Zzz\nBeta")
    }

    func test_insertTextIsOneUndoStepPerContiguousRun() {
        let h = harness(); defer { h.tearDown() }
        let caret = h.canvas.endOfDocument
        h.canvas.selectedTextRange = h.canvas.textRange(from: caret, to: caret)
        // ONE bracket around all three keystrokes — they coalesce into a single `editing`
        // registration (the assertion below), so a single group is the correct shape; `groupsByEvent`
        // only needs SOME open group around each `registerUndo` call, not one bracket per keystroke.
        h.undoManager.beginUndoGrouping()
        h.canvas.insertText("x")
        h.canvas.insertText("y")
        h.canvas.insertText("z")
        h.undoManager.endUndoGrouping()
        XCTAssertEqual(h.canvas.undoRegistrationCount, 1,
                       "a contiguous typing burst must coalesce into ONE undo step")
    }

    // MARK: - Family 6: marked text

    /// Composing text at the caret must be reported back through `h.canvas.markedTextRange` — the
    /// backend-agnostic `UITextInput` witness both conformers route (Legacy through
    /// `legacyCanvas.markedRange`; `.inputDec` through `IDTextEditorBackend`'s own
    /// `state.markedRange`, fixed by Task C9 from an always-nil stub — see `+TextBackend.swift`).
    /// "!" lands right after "Alpha" — offset 5, the same interior-of-the-first-paragraph position
    /// Family 4's own insertion cases already use.
    ///
    /// Asserted via `offset(from:to:)`, NOT a raw `NSRange` literal — mirroring Family 1's own
    /// established idiom (`test_aReversedSelectionRoundTripsThroughSelectedTextRange`'s doc
    /// comment): the position axis is SPARSE, so `beginningOfDocument` is not raw offset 0 and a
    /// hardcoded absolute location would silently assume a specific structural-slot count. Caught
    /// by a real red run: the first draft asserted `NSRange(location: 5, length: 1)` and failed
    /// with `("Optional({6, 1})") is not equal to ("Optional({5, 1})")` — `beginningOfDocument`
    /// itself sits at raw offset 1 on this fixture, so `caret` (offset 5 from it) is raw 6, not 5.
    func test_setMarkedTextPublishesAMarkedRange() {
        let h = harness(); defer { h.tearDown() }
        let caret = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 5)!
        h.canvas.selectedTextRange = h.canvas.textRange(from: caret, to: caret)
        h.canvas.setMarkedText("!", selectedRange: NSRange(location: 1, length: 0))
        guard let markedUITextRange = h.canvas.markedTextRange else {
            return XCTFail("expected an open composition after setMarkedText")
        }
        XCTAssertEqual(h.canvas.offset(from: caret, to: markedUITextRange.start), 0,
                       "the marked range must start exactly at the caret")
        XCTAssertEqual(h.canvas.offset(from: markedUITextRange.start, to: markedUITextRange.end), 1)
    }

    /// `unmarkText()` (the keyboard-driven accept) must retire the composition — bracketed like
    /// every other canvas mutation this suite drives, since the harness's undo manager is
    /// deliberately `groupsByEvent = false` (Family 4's own established convention) and a commit
    /// registers its own undo step.
    func test_unmarkTextClearsTheMarkedRange() {
        let h = harness(); defer { h.tearDown() }
        let caret = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 5)!
        h.canvas.selectedTextRange = h.canvas.textRange(from: caret, to: caret)
        h.canvas.setMarkedText("!", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(h.markedRange, "composition established before the commit")
        h.undoManager.beginUndoGrouping(); h.canvas.unmarkText(); h.undoManager.endUndoGrouping()
        XCTAssertNil(h.markedRange)
    }

    /// A SECOND `setMarkedText` while a composition is already open must REPLACE it — the still-open
    /// run's own range, not append past it — the same "is a run already open" branch every IME
    /// composition (CJK, predictive text) depends on for every keystroke after the first.
    func test_markedTextIsReplacedNotAppendedOnASecondSetMarkedText() {
        let h = harness(); defer { h.tearDown() }
        let caret = h.canvas.position(from: h.canvas.beginningOfDocument, offset: 5)!
        h.canvas.selectedTextRange = h.canvas.textRange(from: caret, to: caret)
        h.canvas.setMarkedText("a", selectedRange: NSRange(location: 1, length: 0))
        h.canvas.setMarkedText("bb", selectedRange: NSRange(location: 2, length: 0))
        guard let markedUITextRange = h.canvas.markedTextRange else {
            return XCTFail("expected an open composition after the second setMarkedText")
        }
        // Same offset-based idiom as `test_setMarkedTextPublishesAMarkedRange` above — see that
        // test's own doc comment on why a raw `NSRange` literal is the wrong tool here.
        XCTAssertEqual(h.canvas.offset(from: caret, to: markedUITextRange.start), 0,
                       "the second call must REPLACE the still-open composition, starting at the " +
                       "same caret — not append past it")
        XCTAssertEqual(h.canvas.offset(from: markedUITextRange.start, to: markedUITextRange.end), 2)
        let whole = h.canvas.textRange(from: h.canvas.beginningOfDocument, to: h.canvas.endOfDocument)!
        XCTAssertEqual(h.canvas.text(in: whole), "Alphabb\nBeta")
    }

    // MARK: - Family 8: responder lifecycle

    /// `UIResponder.becomeFirstResponder()` fails outright for a windowless view, so this needs the
    /// harness's own `hostInWindow()`/`makeFirstResponder()` pair — mirrors
    /// `ResponderRouterTests`' own real-window fixture, one level up (backend-agnostic here).
    func test_becomeFirstResponderSucceedsOnAnEditableCanvas() {
        let h = harness(); defer { h.tearDown() }
        h.hostInWindow()
        XCTAssertTrue(h.makeFirstResponder())
        XCTAssertTrue(h.canvas.isFirstResponder)
    }

    func test_resignFirstResponderEndsEditing() {
        let h = harness(); defer { h.tearDown() }
        h.hostInWindow()
        XCTAssertTrue(h.makeFirstResponder())
        XCTAssertTrue(h.canvas.resignFirstResponder())
        XCTAssertFalse(h.canvas.isFirstResponder)
    }

    // `test_notEditableRejectsInsertText` — the brief's third Step-5 case — is DELIBERATELY NOT
    // added here. `canvas.editPolicy` IS settable directly and both backends' production
    // `lifecycleClient` reads it (`TelegramLifecycleInputClient.editPolicy { canvas.editPolicy }`,
    // constructed once in `DocumentCanvasView.init` regardless of which backend attaches), which
    // made it look like a genuine, backend-agnostic gate — but a real red run against
    // `LegacyBackendSemanticTests` disproved that: `LegacyRichTextInputBackend.insertText(_:)` is,
    // since deviation D35, a PLAIN forward to `legacyCanvas?.legacyInsertText(text)`
    // (`LegacyRichTextInputBackend+Insertion.swift`) that consults `editPolicy`/`isEditable`
    // NOWHERE in its reachable body (grepped: zero hits in `DocumentCanvasView+UITextInput.swift`).
    // `TelegramDocumentInputClient.prepareMutation`'s own `guard canvas.editPolicy.isEditable`
    // gate — where the assertion's author expected the check to live — is reached only by the ID
    // backend's two-phase mutation transactions (`deleteBackward`/`setMarkedText`), never by
    // Legacy's structural `insertText`; `BackendEditPolicyTests`' OWN pre-existing
    // `test_notEditable_rejectsInsertText_…` passes only because it substitutes the TEST-ONLY
    // `ReferenceMutationBackend` (its own doc comment: "stage 1's legacy conformer no longer owns
    // that mutation"), not the real `LegacyRichTextInputBackend` this shared suite's `.legacy` arm
    // actually attaches. So the assertion is FALSE for Legacy's real, current production behavior —
    // adding it here would either fail honestly (unacceptable: the brief asks for a passing shared
    // case) or require retrofitting an editPolicy gate onto Legacy's `insertText`, which is
    // unscoped production-behavior-changing work well outside Family 8. The ID-side half of this
    // exact assertion still exists, unweakened, in `IDBackendFamily8Tests
    // .test_notEditablePolicy_rejectsInsertText_withNoDelegateNotifications`; see this task's
    // report and `DIVERGENCES.md` entry 11 for the full finding.
}
#endif
