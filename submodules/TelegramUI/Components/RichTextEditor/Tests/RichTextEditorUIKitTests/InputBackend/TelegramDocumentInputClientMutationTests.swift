#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
@MainActor
final class TelegramDocumentInputClientMutationTests: XCTestCase {
    private func makeClient() -> (DocumentCanvasView, TelegramDocumentInputClient) {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")]),
                         ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        // NB: groupsByEvent = false. Every mutation this suite performs must be wrapped in
        // um.beginUndoGrouping() / um.endUndoGrouping(), or +Editing.swift's registerUndo throws
        // "must begin a group before registering undo". The suite's existing convention is
        // CanvasEditingTests.swift:25. Task 3 hit this as a fixture crash.
        return (v, TelegramDocumentInputClient(canvas: v))
    }
    private func caretSelection(_ v: DocumentCanvasView, _ offset: Int) -> RichTextCanonicalSelection {
        .caret(at: .downstream(offset))
    }

    func test_prepareAtTheCurrentRevisionIsReady() {
        let (v, c) = makeClient()
        let m = RichTextInputMutation.insertText(text: NSAttributedString(string: "x"),
                                                 replacing: caretSelection(v, v.boxes[0].textStart),
                                                 origin: .softwareKeyboard)
        guard case .ready(let prepared) = c.prepareMutation(m, expectedRevision: c.revision) else {
            return XCTFail("expected .ready")
        }
        XCTAssertEqual(prepared.expectedRevision, c.revision)
        XCTAssertTrue(prepared.contentWillChange)
        XCTAssertTrue(prepared.selectionWillChange)
        _ = c.commitPreparedMutation(prepared)
    }

    func test_prepareAtAStaleRevisionIsTerminalRevisionMismatch() {
        let (v, c) = makeClient()
        let stale = c.revision
        // NOTE: groupsByEvent = false (see makeClient's NB), so this direct canvas call needs its own
        // explicit undo-group bracket, exactly like CanvasEditingTests.swift:25 — otherwise
        // +Editing.swift's registerUndo throws "must begin a group before registering undo" and aborts
        // the whole test process (found running this suite: a bare `v.editing {}` here crashed).
        v.undoManagerOverride?.beginUndoGrouping()
        v.editing { .unchanged }
        v.undoManagerOverride?.endUndoGrouping()
        let m = RichTextInputMutation.insertText(text: NSAttributedString(string: "x"),
                                                 replacing: caretSelection(v, v.boxes[0].textStart),
                                                 origin: .softwareKeyboard)
        guard case .terminal(let result) = c.prepareMutation(m, expectedRevision: stale) else {
            return XCTFail("expected .terminal")
        }
        XCTAssertEqual(result.disposition, .rejected(.revisionMismatch))
        XCTAssertFalse(result.contentChanged)
    }

    /// TASK 22c FIX ROUND 2 — relocated here from `BackendRevisionContractTests`
    /// (`test_realDocumentClient_rebaseAlwaysRejectsAStaleSelection_byD32Construction`). That suite is
    /// a `BackendContractCases` subclass, and this property — D32's identity-or-nil rebase, "a stale
    /// selection is always rejected, never remapped" — belongs to the LEGACY CLIENT specifically, not
    /// every conformer: an InputDec client may legitimately implement `rebase` differently (or not at
    /// all the same way), so pinning it against `any RichTextInputBackend` was already the wrong home,
    /// and the original test additionally constructed its own `DocumentCanvasView()` /
    /// `LegacyRichTextInputBackend` directly rather than through `makeBackend()` — exactly the defect
    /// the new R10 source-boundary rule
    /// (`InputBackendSourceBoundaryTests.test_noConcreteBackendNamedOutsideMakeBackend_R10`) now
    /// catches mechanically. This class is `final` and legacy-client-specific, so testing
    /// `TelegramDocumentInputClient.rebase` directly is exactly on-topic — no canvas edits beyond the
    /// shared `makeClient()` fixture, no inheritance to worry about.
    ///
    /// Preserves what the ORIGINAL test actually pinned (not weakened into a tautology): D32's full
    /// identity-or-nil contract, both directions — a position is returned UNCHANGED when
    /// `fromRevision` matches the client's current revision, and `nil` (never a remapped/guessed
    /// position) when it does not.
    ///
    /// FIX ROUND 3 correction: the ORIGINAL version of this test probed `fromRevision: c.revision &+ 1`
    /// — a revision the canvas NEVER HELD (a future one). That probe is direction-blind: a plausible
    /// FUTURE violation of D32 is a **history-based offset remap** (maintaining a log of past revisions
    /// and mapping a position forward when `fromRevision` is found in it) — and such a remap correctly
    /// returns `nil` for a never-held FUTURE revision too, since it isn't in the log either. So the red
    /// check only ever exercised the direction-blind "returns unconditionally" mutation, not the
    /// realistic one. Fixed to probe a GENUINELY STALE PRIOR revision — captured before a real edit,
    /// exactly like the neighboring `test_prepareAtAStaleRevisionIsTerminalRevisionMismatch` above —
    /// which a history-based remap WOULD map, making this the test that actually stands between D32
    /// and that "fix".
    ///
    /// RED IF: `rebase` ever started returning non-nil for a revision that is NOT the current one
    /// (whether a genuinely-stale prior revision, as probed here, or a never-held future one) — i.e.
    /// gained ANY offset-mapping algorithm, history-based or otherwise, which is the exact D32
    /// violation this test exists to catch — or ever started returning something other than the
    /// identical position at a MATCHING revision.
    func test_rebase_isIdentityAtTheCurrentRevision_andNilForAStalePriorRevision() {
        let (v, c) = makeClient()
        let position = RichTextInputPosition(utf16Offset: v.boxes[0].textStart)
        XCTAssertEqual(c.rebase(position, fromRevision: c.revision), position,
                       "rebase at the CURRENT revision must return the position unchanged (identity)")

        let stale = c.revision
        // A REAL edit the canvas genuinely went through — `stale` is a revision this client actually
        // held at one point, not a number it never saw. Mirrors `test_prepareAtAStaleRevisionIsTerminalRevisionMismatch`'s
        // `v.editing { .unchanged }` shape exactly (including its own undo-group bracket note).
        v.undoManagerOverride?.beginUndoGrouping()
        v.editing { .unchanged }
        v.undoManagerOverride?.endUndoGrouping()
        XCTAssertNotEqual(stale, c.revision,
                         "the edit above must actually bump the revision, or this probes nothing")

        XCTAssertNil(c.rebase(position, fromRevision: stale),
                    "rebase at a STALE (but real, previously-held) revision must be nil — never " +
                    "remapped, even from known history (deviation D32)")
    }

    func test_prepareWithAnOutOfBoundsRangeIsTerminalInvalidRange() {
        // NOTE: `c` holds the canvas `unowned` (by design), so the canvas must be bound to a name
        // (`v`), not `_` — a discard pattern releases it immediately, deallocating the canvas out
        // from under `c` before the assertion runs (the same footgun proven sharp in Task 12 review;
        // the brief's literal `let (_, c) = makeClient()` here crashed with "Attempted to read an
        // unowned reference but the object was already destroyed" when this suite was run).
        let (v, c) = makeClient()
        withExtendedLifetime(v) {
            let m = RichTextInputMutation.replaceText(range: NSRange(location: 9_999, length: 1),
                                                      text: NSAttributedString(string: "x"),
                                                      origin: .programmatic)
            guard case .terminal(let result) = c.prepareMutation(m, expectedRevision: c.revision) else {
                return XCTFail("expected .terminal")
            }
            XCTAssertEqual(result.disposition, .rejected(.invalidRange))
        }
    }

    func test_prepareUnderANonEditablePolicyIsTerminalNotEditable() {
        let (v, c) = makeClient()
        v.editPolicy = RichTextInputEditPolicy(isEditable: false, isSelectable: true,
                                               allowsRichText: true, allowsPaste: true,
                                               allowsDictation: true, allowsWritingTools: true)
        let m = RichTextInputMutation.insertText(text: NSAttributedString(string: "x"),
                                                 replacing: caretSelection(v, v.boxes[0].textStart),
                                                 origin: .softwareKeyboard)
        guard case .terminal(let result) = c.prepareMutation(m, expectedRevision: c.revision) else {
            return XCTFail("expected .terminal")
        }
        XCTAssertEqual(result.disposition, .rejected(.notEditable))
    }

    func test_commitAppliesTheInsertionAndReportsTheNewRevisionAndSelection() {
        let (v, c) = makeClient()
        let start = v.boxes[0].textStart
        let before = c.revision
        let m = RichTextInputMutation.insertText(text: NSAttributedString(string: "Z"),
                                                 replacing: caretSelection(v, start),
                                                 origin: .softwareKeyboard)
        guard case .ready(let prepared) = c.prepareMutation(m, expectedRevision: before) else {
            return XCTFail("expected .ready")
        }
        let result = c.commitPreparedMutation(prepared)
        XCTAssertEqual(result.disposition, .applied)
        XCTAssertEqual(result.revision, before + 1)
        XCTAssertEqual(result.selection.head.utf16Offset, v.head)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "ZAlpha")
        XCTAssertTrue(result.legacyConservativePreparation, "deviation D10")
    }

    /// Fix round 1: the 14-test suite exercised `.replaceText` only in its terminal/invalid forms
    /// (`test_prepareWithAnOutOfBoundsRangeIsTerminalInvalidRange`, `test_rejectionMutatesNothing`) —
    /// never a VALID `.replaceText` committed through the full seam. That matters because
    /// `applySelectionReplaceOutcome` (the primitive the `.replaceText` case in `legacyApplyMutation`
    /// dispatches to) is "the chokepoint for every selection-replacing edit" per this task's own
    /// brief, so the wiring from the switch arm through prepare→commit is exactly the path most
    /// production traffic (delete/type-over/paste/replace) takes. Red if: the disposition were
    /// anything but `.applied` (e.g. `.noChange`, meaning the dispatcher's `editing { }` call never
    /// actually replaced the range); the resulting paragraph text were not exactly "XYZ" (e.g. stale
    /// "Alpha" if the range/text were swapped or dropped, or "XYZAlpha"/"XYZha" if the replaced range
    /// were wrong); the reported revision were not `before + 1`; or the reported/actual selection were
    /// not collapsed at `start + 3` (end of the inserted "XYZ") — `applyReplaceOutcome`'s same-paragraph
    /// branch (`start.index == end.index`) places the caret at
    /// `b.textStart + start.local + (text as NSString).length`, so a wrong caret here would mean the
    /// `.replaceText` case's range plumbing in `legacyApplyMutation` disagrees with that primitive.
    func test_commitOfAValidReplaceTextAppliesAndReportsTheNewRevisionAndSelection() {
        let (v, c) = makeClient()
        let start = v.boxes[0].textStart   // "Alpha" — replace the whole word
        let before = c.revision
        let m = RichTextInputMutation.replaceText(range: NSRange(location: start, length: 5),
                                                  text: NSAttributedString(string: "XYZ"),
                                                  origin: .programmatic)
        guard case .ready(let prepared) = c.prepareMutation(m, expectedRevision: before) else {
            return XCTFail("expected .ready")
        }
        let result = c.commitPreparedMutation(prepared)
        XCTAssertEqual(result.disposition, .applied)
        XCTAssertEqual(result.revision, before + 1)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "XYZ")
        XCTAssertEqual(result.selection.anchor.utf16Offset, start + 3)
        XCTAssertEqual(result.selection.head.utf16Offset, start + 3)
        XCTAssertEqual(v.head, start + 3)
        XCTAssertTrue(result.legacyConservativePreparation, "deviation D10")
    }

    func test_commitOfADeleteBackwardRemovesOneCharacter() {
        let (v, c) = makeClient()
        let start = v.boxes[0].textStart
        let m = RichTextInputMutation.deleteBackward(selection: caretSelection(v, start + 2),
                                                     proposedRange: nil)
        guard case .ready(let prepared) = c.prepareMutation(m, expectedRevision: c.revision) else {
            return XCTFail("expected .ready")
        }
        _ = c.commitPreparedMutation(prepared)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Apha")
    }

    func test_commitOfAParagraphBreakSplitsTheBlock() {
        let (v, c) = makeClient()
        let blocksBefore = v.boxes.count
        let m = RichTextInputMutation.insertParagraphBreak(
            replacing: caretSelection(v, v.boxes[0].textStart + 2), origin: .softwareKeyboard)
        guard case .ready(let prepared) = c.prepareMutation(m, expectedRevision: c.revision) else {
            return XCTFail("expected .ready")
        }
        _ = c.commitPreparedMutation(prepared)
        XCTAssertEqual(v.boxes.count, blocksBefore + 1)
    }

    /// TASK 27b — **the one thing that can see the Step-4 dispatcher repoint.** `legacyApplyMutation`'s
    /// own rule is "every case dispatches to the LEGACY BODY, never to the UIKit witness of the same
    /// name"; Task 27b routed `insertText(_:)` and repointed the case at `legacyInsertText(_:)` in the
    /// same commit. With the backend ATTACHED the two spellings are indistinguishable (the witness just
    /// bounces out through the backend and straight back), which is why every other test in the tree
    /// stays green either way — measured, not assumed.
    ///
    /// DETACHING is what separates them: a witness dispatch goes canvas → `inputBackend.insertText` →
    /// `legacyCanvas`, which is nil once detached, so the mutation is silently DROPPED and the document
    /// client reports a change it did not make. A body dispatch does not consult the backend's
    /// attachment at all. The scenario is a probe rather than a user flow — but the DROP it detects is
    /// the real cost of leaving the case pointed at the witness, and nothing else in the tree detects
    /// it.
    ///
    /// RED IF: the case is pointed back at `insertText(text.string)` — verified red against exactly
    /// that (see the task report's red-check section): the paragraph stays "Alpha".
    func test_insertTextMutation_dispatchesToTheLegacyBody_notBackThroughTheRoutedWitness() {
        let (v, c) = makeClient()
        let start = v.boxes[0].textStart
        (v.inputBackend as! LegacyRichTextInputBackend).detach()

        let m = RichTextInputMutation.insertText(text: NSAttributedString(string: "x"),
                                                 replacing: caretSelection(v, start),
                                                 origin: .softwareKeyboard)
        guard case .ready(let prepared) = c.prepareMutation(m, expectedRevision: c.revision) else {
            return XCTFail("expected .ready")
        }
        let result = c.commitPreparedMutation(prepared)

        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "xAlpha",
                       "the dispatcher must reach the legacy BODY, which does not consult the backend")
        XCTAssertTrue(result.contentChanged)
    }

    /// TASK 28 — the `deleteBackward` sibling of the test above, and it is here for the same measured
    /// reason: **before it existed, NOTHING in the tree could see Task 28's Step-4 repoint.** Measured,
    /// not assumed — with the case reverted to `deleteBackward()` (the witness) this suite (17),
    /// `BackendMutationContractTests` (9), `BackendAttachmentTests` (32) and `DeletionRouterTests` (4)
    /// were all green. `test_commitOfADeleteBackwardRemovesOneCharacter` above cannot see it: with the
    /// backend ATTACHED the witness just bounces out through it and straight back to the same body.
    ///
    /// DETACHING separates them: a witness dispatch goes canvas → `inputBackend.deleteBackward` →
    /// `legacyCanvas`, which is nil once detached, so the mutation is silently DROPPED and the document
    /// client reports a change it did not make. A body dispatch does not consult the backend's
    /// attachment at all. The scenario is a probe rather than a user flow — but the DROP it detects is
    /// the real cost of leaving the case pointed at the witness.
    ///
    /// RED IF: the case is pointed back at `deleteBackward()` — verified red against exactly that (see
    /// the task report's red-check section): the paragraph stays "Alpha".
    func test_deleteBackwardMutation_dispatchesToTheLegacyBody_notBackThroughTheRoutedWitness() {
        let (v, c) = makeClient()
        let start = v.boxes[0].textStart
        (v.inputBackend as! LegacyRichTextInputBackend).detach()

        let m = RichTextInputMutation.deleteBackward(selection: caretSelection(v, start + 1),
                                                     proposedRange: nil)
        guard case .ready(let prepared) = c.prepareMutation(m, expectedRevision: c.revision) else {
            return XCTFail("expected .ready")
        }
        let result = c.commitPreparedMutation(prepared)

        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "lpha",
                       "the dispatcher must reach the legacy BODY, which does not consult the backend")
        XCTAssertTrue(result.contentChanged)
    }

    func test_aTokenCanOnlyBeCommittedOnce() {
        let (v, c) = makeClient()
        var violations: [String] = []
        RichTextInputContractViolation.reporter = { violations.append($0) }
        defer { RichTextInputContractViolation.reporter = nil }
        let m = RichTextInputMutation.insertText(text: NSAttributedString(string: "x"),
                                                 replacing: caretSelection(v, v.boxes[0].textStart),
                                                 origin: .softwareKeyboard)
        guard case .ready(let prepared) = c.prepareMutation(m, expectedRevision: c.revision) else {
            return XCTFail("expected .ready")
        }
        _ = c.commitPreparedMutation(prepared)
        let second = c.commitPreparedMutation(prepared)
        XCTAssertEqual(second.disposition, .rejected(.unsupportedOperation))
        XCTAssertFalse(violations.isEmpty)
    }

    func test_aForeignTokenIsRejected() {
        let (v, c) = makeClient()
        RichTextInputContractViolation.reporter = { _ in }
        defer { RichTextInputContractViolation.reporter = nil }
        let foreign = RichTextInputPreparedMutation(token: UUID(), expectedRevision: c.revision,
                                                    contentWillChange: true, selectionWillChange: true)
        XCTAssertEqual(c.commitPreparedMutation(foreign).disposition, .rejected(.unsupportedOperation))
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha")
    }

    func test_onlyOneOutstandingPreparationIsRetained() {
        let (v, c) = makeClient()
        RichTextInputContractViolation.reporter = { _ in }
        defer { RichTextInputContractViolation.reporter = nil }
        let m = RichTextInputMutation.insertText(text: NSAttributedString(string: "x"),
                                                 replacing: caretSelection(v, v.boxes[0].textStart),
                                                 origin: .softwareKeyboard)
        guard case .ready(let first) = c.prepareMutation(m, expectedRevision: c.revision),
              case .ready(let second) = c.prepareMutation(m, expectedRevision: c.revision) else {
            return XCTFail("expected two .ready preparations")
        }
        XCTAssertEqual(c.commitPreparedMutation(first).disposition, .rejected(.unsupportedOperation))
        XCTAssertEqual(c.commitPreparedMutation(second).disposition, .applied)
    }

    func test_rejectionMutatesNothing() {
        let (v, c) = makeClient()
        let textBefore = (v.boxes[0] as! BlockBox).currentParagraph().text
        let revisionBefore = c.revision
        let undoBefore = v.undoRegistrationCount
        let m = RichTextInputMutation.replaceText(range: NSRange(location: 9_999, length: 1),
                                                  text: NSAttributedString(string: "x"),
                                                  origin: .programmatic)
        _ = c.prepareMutation(m, expectedRevision: c.revision)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, textBefore)
        XCTAssertEqual(c.revision, revisionBefore)
        XCTAssertEqual(v.undoRegistrationCount, undoBefore)
    }

    func test_preparationItselfMutatesNothing() {
        let (v, c) = makeClient()
        let revisionBefore = c.revision
        let m = RichTextInputMutation.insertText(text: NSAttributedString(string: "x"),
                                                 replacing: caretSelection(v, v.boxes[0].textStart),
                                                 origin: .softwareKeyboard)
        guard case .ready(let prepared) = c.prepareMutation(m, expectedRevision: c.revision) else {
            return XCTFail("expected .ready")
        }
        XCTAssertEqual(c.revision, revisionBefore, "preparation must not touch the document")
        _ = c.commitPreparedMutation(prepared)
    }

    func test_setMarkedTextMutationIntentDrivesTheCompositionPath() {
        let (v, c) = makeClient()
        let start = v.boxes[0].textStart
        let m = RichTextInputMutation.setMarkedText(text: NSAttributedString(string: "か"),
                                                     replacing: NSRange(location: start, length: 0),
                                                     selectedRangeInMarkedText: NSRange(location: 1, length: 0))
        guard case .ready(let prepared) = c.prepareMutation(m, expectedRevision: c.revision) else {
            return XCTFail("expected .ready")
        }
        let result = c.commitPreparedMutation(prepared)
        XCTAssertNotNil(result.markedRange)
        XCTAssertNotNil(v.markedRange)
    }

    func test_unmarkTextMutationIntentCommitsTheComposition() {
        let (v, c) = makeClient()
        v.setCaret(global: v.boxes[0].textStart)
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        guard case .ready(let prepared) = c.prepareMutation(.unmarkText, expectedRevision: c.revision) else {
            return XCTFail("expected .ready")
        }
        let result = c.commitPreparedMutation(prepared)
        XCTAssertNil(result.markedRange)
        XCTAssertNil(v.markedRange)
    }
}
#endif
