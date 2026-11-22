#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Re-runs `T/MarkedTextTests.swift`'s composition/prediction scenarios through the Task-2 recorder to
/// pin `(trace, revision, anchor/head, markedRange)` tuples — the one thing the existing 27-test suite
/// never records as a SEQUENCE. This is characterization: every assertion below records what the code
/// does today, not what it "should" do.
@available(iOS 16.0, *)
final class MarkedTextTraceCharacterizationTests: XCTestCase {
    private var recorder: RichTextInputEventRecorder!

    private func makeCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha")]),
                         ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        // NB: groupsByEvent = false. Every mutation this suite performs that can reach `registerUndo`
        // (directly via `commitMarkedText`, or via `editing{}`'s own registration) must be wrapped in
        // `grouped(v) { ... }` below, or +Editing.swift's registerUndo throws "must begin a group before
        // registering undo". The suite's existing convention is CanvasEditingTests.swift:25. Task 3 hit
        // this as a fixture crash. `setMarkedText` itself never calls `registerUndo` (composition edits
        // are provisional — see +MarkedText.swift), so only the COMMIT/DISMISS-adjacent calls need it:
        // `unmarkText`, `insertText` while marked (the committing-keystroke branch), `setCaret`/
        // `insertParagraphBreak` while an ACTUAL COMPOSITION (not a prediction) is live, and
        // `resignFirstResponder`.
        recorder = RichTextInputEventRecorder(); recorder.attach(canvas: v); recorder.reset()
        return v
    }
    private func delegateKinds() -> [RichTextInputRecordedEventKind] {
        recorder.kinds.filter {
            $0 == .textWillChange || $0 == .selectionWillChange
                || $0 == .selectionDidChange || $0 == .textDidChange
        }
    }
    /// Wraps a mutation in an explicit undo group (see the fixture's NB above). Safe to use even when
    /// the wrapped call turns out not to reach `registerUndo` — an empty group is a harmless no-op.
    private func grouped(_ v: DocumentCanvasView, _ body: () -> Void) {
        let um = v.undoManagerOverride!
        um.beginUndoGrouping()
        body()
        um.endUndoGrouping()
    }

    // MARK: - Composition begin / update / commit

    func test_compositionBeginUpdateCommit_traceAndRevisions() {
        let v = makeCanvas()
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 5); recorder.reset()
        let revBeforeMark = v.documentRevision

        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertEqual(v.markedRange.map { $0.to - $0.from }, 1, "composition begin established")
        let afterBegin = v.documentRevision
        XCTAssertEqual(afterBegin, revBeforeMark + 1, "setMarkedText's applyReplaceOutcome bumps the revision outside editing{}")

        // Pin the begin-composition trace: SIX events, not the four one might expect from "a text
        // bracket then a selection bracket" — `setMarkedText`'s tail unconditionally also fires
        // `notifyContentSizeChanged()` (→ `.canvasContentSizeChanged`) and `onSelectionChange?()`
        // (→ `.canvasSelectionChanged`), even though this composition update didn't change content
        // HEIGHT. Two further non-obvious facts pinned here:
        // (1) `applyReplaceOutcome`'s same-block path RETURNS a caret at the post-insert position, and
        //     `legacySetMarkedText` applies it on the next instruction (`applyCaretOutcome`, inside the
        //     TEXT bracket — Task 36c; before that a transitional wrapper did the same thing). So by
        //     `textDidChange` — BEFORE the selection bracket even starts — the model's `head` has
        //     ALREADY moved to s+6, and an input-delegate observer reading `head` inside the TEXT
        //     bracket sees the NEW selection, not the old one.
        // (2) `markedRange` is NOT yet visible at `textDidChange` — the model sets it only afterward,
        //     right before the selection bracket — even though the text mutation it describes has
        //     already landed.
        let m1 = NSRange(location: s + 5, length: 1)
        typealias E = (kind: RichTextInputRecordedEventKind, anchor: Int, head: Int, revision: UInt64, markedRange: NSRange?)
        let expected: [E] = [
            (kind: .textWillChange,          anchor: s + 5, head: s + 5, revision: revBeforeMark, markedRange: nil),
            (kind: .textDidChange,           anchor: s + 6, head: s + 6, revision: afterBegin,     markedRange: nil),
            (kind: .selectionWillChange,     anchor: s + 6, head: s + 6, revision: afterBegin,     markedRange: m1),
            (kind: .selectionDidChange,      anchor: s + 6, head: s + 6, revision: afterBegin,     markedRange: m1),
            (kind: .canvasContentSizeChanged,anchor: s + 6, head: s + 6, revision: afterBegin,     markedRange: m1),
            (kind: .canvasSelectionChanged,  anchor: s + 6, head: s + 6, revision: afterBegin,     markedRange: m1),
        ]
        XCTAssertTraceStates(recorder, expected)

        recorder.reset()
        v.setMarkedText("かん", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertEqual(v.documentRevision, afterBegin + 1)
        XCTAssertEqual(v.markedRange.map { $0.to - $0.from }, 2)

        recorder.reset()
        let revBeforeCommit = v.documentRevision
        grouped(v) { v.unmarkText() }
        XCTAssertNil(v.markedRange)   // preceded by the length==2 presence check just above
        XCTAssertEqual(delegateKinds(), [], "commit itself mutates nothing and emits nothing")
        // Strengthen to the FULL (unfiltered) trace: commitMarkedText also fires no canvas-hook event
        // (no notifyContentSizeChanged / onSelectionChange call in its body).
        XCTAssertEqual(recorder.kinds, [], "commit registers undo directly but calls no delegate/canvas hook")
        XCTAssertEqual(v.documentRevision, revBeforeCommit, "commitMarkedText does not bump the revision")
    }

    func test_composition_isOneUndoStep_andRegistersOnCommit() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 5)
        let before = v.undoRegistrationCount
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        v.setMarkedText("かん", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertEqual(v.undoRegistrationCount, before, "provisional edits register no undo")
        XCTAssertNotNil(v.markedRange, "composition established before the commit this test measures")
        grouped(v) { v.unmarkText() }
        XCTAssertEqual(v.undoRegistrationCount, before, "commitMarkedText registers directly, not via editing")
        XCTAssertTrue(v.undoManagerOverride!.canUndo)
    }

    func test_cancelledComposition_registersNoUndo() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 5)
        let before = v.undoRegistrationCount
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(v.markedRange, "composition established before cancelling")
        v.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
        XCTAssertNil(v.markedRange)
        XCTAssertEqual(v.undoRegistrationCount, before, "a cancelled composition registers no undo step")
        XCTAssertFalse(v.undoManagerOverride!.canUndo)
    }

    // MARK: - Interruptions: selection change, structural edit

    func test_commitOnSelectionChange_traceAndMarkedState() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 5)
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(v.markedRange, "composition established before the selection-change commit")
        recorder.reset()
        let revBefore = v.documentRevision
        grouped(v) { v.setCaret(global: v.boxes[1].textStart) }
        XCTAssertNil(v.markedRange)
        XCTAssertEqual(delegateKinds(), [.selectionWillChange, .selectionDidChange])
        XCTAssertEqual(v.documentRevision, revBefore, "a composition COMMIT (not a text edit) does not bump the revision")
        // Full trace: the commit itself is silent (as pinned above); setCaret's own selection bracket +
        // its onSelectionChange→canvas hook are what's actually visible.
        XCTAssertEqual(recorder.kinds, [.selectionWillChange, .selectionDidChange, .canvasSelectionChanged])
    }

    func test_commitOnStructuralEdit_commitsThenEdits() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 5)
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(v.markedRange, "composition established before the structural edit")
        recorder.reset()
        let revBefore = v.documentRevision
        grouped(v) { v.insertParagraphBreak() }
        XCTAssertNil(v.markedRange)
        // The composition commit (inside finalizeMarkedText, called at editing{}'s very first line) is
        // invisible on the trace — editing{} still bumps the revision exactly ONCE for its own body,
        // not twice, and the trace is the plain six-event editing{} bracket (established fact from
        // Task 3/6), unaffected by the silent prior commit.
        XCTAssertEqual(v.documentRevision, revBefore + 1, "editing{} bumps once; the prior composition commit does not bump separately")
        XCTAssertEqual(recorder.kinds, [.textWillChange, .selectionWillChange, .selectionDidChange,
                                         .textDidChange, .canvasContentSizeChanged, .canvasSelectionChanged])
    }

    // MARK: - Prediction vs. composition

    /// A prediction is distinguished from a composition ONLY by the selected range (+MarkedText.swift:74-76).
    func test_predictionVsComposition_isDistinguishedBySelectedRange() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 5)
        v.setMarkedText("ing", selectedRange: NSRange(location: 0, length: 0))
        XCTAssertNotNil(v.markedRange, "prediction ghost established")
        XCTAssertTrue(v.markedTextIsPrediction)
        v.dismissPrediction()
        XCTAssertNil(v.markedRange)   // preceded by the presence check above
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(v.markedRange, "composition established")
        XCTAssertFalse(v.markedTextIsPrediction)
    }

    func test_predictionIsDismissedNotCommittedByAGestureCaretMove() {
        let v = makeCanvas()
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 5)
        v.setMarkedText("ing", selectedRange: NSRange(location: 0, length: 0))
        XCTAssertNotNil(v.markedRange, "prediction ghost established before the caret move dismisses it")
        let lengthWithGhost = v.boxes[0].textLength
        v.setCaret(global: s + 1)
        XCTAssertNil(v.markedRange)
        XCTAssertLessThan(v.boxes[0].textLength, lengthWithGhost, "the ghost text is removed, not committed")
    }

    /// finalizeMarkedText returns the dismissed span so setCaret can shift later positions left
    /// (DCV:1478-1480). That shift is load-bearing and easy to lose in a routing refactor.
    func test_dismissedPredictionShiftsALaterCaretTargetLeft() {
        let v = makeCanvas()
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 2)
        v.setMarkedText("XYZ", selectedRange: NSRange(location: 0, length: 0))
        XCTAssertNotNil(v.markedRange, "prediction ghost established before the shifted caret move")
        v.setCaret(global: s + 5)   // a target BEYOND the ghost
        XCTAssertEqual(v.head, s + 2, "the target is shifted back by the removed ghost length")
    }

    // MARK: - Committing keystroke via insertText

    /// The brief predicted `insertText` "advances the caret" for a committing keystroke. That's only
    /// true when the committing text is LONGER than the marked range it replaces — `insertText`'s
    /// marked-commit branch REPLACES the whole marked range with `text` (+UITextInput.swift:307,
    /// matching `MarkedTextTests.test_insertText_whileMarked_replacesMarkedRange_andCommits`'s existing
    /// "confirming keystroke replaces the composition" characterization), so a same-length commit (e.g.
    /// composing "か" then committing with a single-char "。") leaves the caret UNCHANGED, not advanced.
    /// This test therefore commits with a two-character string to make the advance genuine and
    /// verifiable, rather than asserting a fact that happened not to hold for the brief's original
    /// single-char example.
    func test_markedCommitViaInsertText_advancesTheCaretWithoutASelectionBracket() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 5)
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(v.markedRange, "composition established before the committing keystroke")
        let headBefore = v.head
        let revBeforeCommit = v.documentRevision
        recorder.reset()
        grouped(v) { v.insertText("AB") }
        XCTAssertGreaterThan(v.head, headBefore)
        XCTAssertEqual(v.head, headBefore + 1, "committing text (len 2) replaces the marked range (len 1): net +1")
        XCTAssertNil(v.markedRange, "the committing keystroke clears the composition")
        XCTAssertEqual(delegateKinds(), [.textWillChange, .textDidChange])
        XCTAssertEqual(v.documentRevision, revBeforeCommit + 1, "one bump for the committing applyReplaceOutcome; commitMarkedText itself does not bump")
    }

    // MARK: - Resign first responder while composing

    func test_resignFirstResponderWhileMarked_commits() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let v = makeCanvas()
        window.addSubview(v)
        XCTAssertTrue(v.becomeFirstResponder())
        v.setCaret(global: v.boxes[0].textStart + 5)
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(v.markedRange, "composition established before resigning first responder")
        grouped(v) { _ = v.resignFirstResponder() }
        XCTAssertNil(v.markedRange)
    }
}
#endif
