#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Golden traces for the CURRENT delegate emission behavior. These are the oracle for the task
/// that moves emission into LegacyRichTextInputBackend. A diff here in a commit that claims "no
/// behavior change" is a review stop, not a re-record.
@available(iOS 16.0, *)
final class DelegateTraceCharacterizationTests: XCTestCase {
    private var recorder: RichTextInputEventRecorder!

    private func makeCanvas(_ texts: [String] = ["Alpha", "Beta"]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        recorder = RichTextInputEventRecorder(); recorder.attach(canvas: v)
        recorder.reset()
        return v
    }
    private func delegateKinds() -> [RichTextInputRecordedEventKind] {
        recorder.kinds.filter {
            $0 == .textWillChange || $0 == .selectionWillChange
                || $0 == .selectionDidChange || $0 == .textDidChange
        }
    }

    func test_editingWithAMutatingBody_emitsTheFullBracket() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1); recorder.reset()
        v.editing { v.applyReplaceOutcome(globalFrom: v.head, globalTo: v.head, text: "x") }
        XCTAssertEqual(delegateKinds(),
                       [.textWillChange, .selectionWillChange, .selectionDidChange, .textDidChange])
    }

    /// The spec would gate these on a preparation's flags. Today they are UNCONDITIONAL.
    func test_editingWithANoOpBody_stillEmitsAllFourNotifications() {
        let v = makeCanvas(); recorder.reset()
        v.editing { .unchanged }
        XCTAssertEqual(delegateKinds(),
                       [.textWillChange, .selectionWillChange, .selectionDidChange, .textDidChange])
    }

    /// A refused edit returns early INSIDE the body, after the will-notifications already fired.
    func test_refusedEdit_stillEmitsAllFourNotifications() {
        let v = makeCanvas(); recorder.reset()
        v.editing { v.applyReplaceOutcome(globalFrom: -5, globalTo: -3, text: "x") }   // out of range → early return
        XCTAssertEqual(delegateKinds(),
                       [.textWillChange, .selectionWillChange, .selectionDidChange, .textDidChange])
    }

    // NOTE: the brief's snippet called `v.insertText("x")` un-bracketed under `groupsByEvent = false`,
    // which crashes ("must begin a group before registering undo") — `editing {}`'s `registerUndo`
    // (+Editing.swift:65) requires an open group when the manager doesn't auto-group by runloop event.
    // Every other undo test in this suite (e.g. CanvasEditingTests.test_undoRedo_ofTyping_onCanvas)
    // wraps the SETUP mutation in `beginUndoGrouping()/endUndoGrouping()` and calls `undo()`/`redo()`
    // unwrapped; matched here.
    func test_undo_emitsItsOwnBracket() {
        let v = makeCanvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.setCaret(global: v.boxes[0].textStart + 1)
        um.beginUndoGrouping(); v.insertText("x"); um.endUndoGrouping()
        recorder.reset()
        um.undo()
        XCTAssertEqual(delegateKinds(),
                       [.textWillChange, .selectionWillChange, .selectionDidChange, .textDidChange])
    }

    func test_redo_emitsItsOwnBracket() {
        let v = makeCanvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        v.setCaret(global: v.boxes[0].textStart + 1)
        um.beginUndoGrouping(); v.insertText("x"); um.endUndoGrouping()
        um.undo()
        recorder.reset()
        um.redo()
        XCTAssertEqual(delegateKinds(),
                       [.textWillChange, .selectionWillChange, .selectionDidChange, .textDidChange])
    }

    func test_reload_emitsTheFullBracket() {
        let v = makeCanvas(); recorder.reset()
        v.reload([.paragraph(ParagraphBlock(id: BlockID("q"), runs: [TextRun(text: "Gamma")]))], width: 300)
        XCTAssertEqual(delegateKinds(),
                       [.textWillChange, .selectionWillChange, .selectionDidChange, .textDidChange])
    }

    func test_setBlocks_emitsNoDelegateNotifications() {
        let v = makeCanvas(); recorder.reset()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("q"), runs: [TextRun(text: "Gamma")]))], width: 300)
        XCTAssertEqual(delegateKinds(), [])
    }

    func test_setCaret_emitsOneSelectionBracket() {
        let v = makeCanvas(); recorder.reset()
        v.setCaret(global: v.boxes[1].textStart)
        XCTAssertEqual(delegateKinds(), [.selectionWillChange, .selectionDidChange])
    }

    func test_setSelectionHead_emitsOneSelectionBracket() {
        let v = makeCanvas(); recorder.reset()
        v.setSelectionHead(global: v.boxes[0].textStart + 3)
        XCTAssertEqual(delegateKinds(), [.selectionWillChange, .selectionDidChange])
    }

    func test_setSelectionAnchor_emitsOneSelectionBracket() {
        let v = makeCanvas(); recorder.reset()
        v.setSelectionAnchor(global: v.boxes[0].textStart + 2)
        XCTAssertEqual(delegateKinds(), [.selectionWillChange, .selectionDidChange])
    }

    func test_coalescedSelectionFrames_emitNothing() {
        let v = makeCanvas()
        v.beginCoalescedSelectionDrag(); recorder.reset()
        for i in 0..<5 { v.setSelectionHead(global: v.boxes[0].textStart + i) }
        XCTAssertEqual(delegateKinds(), [])
        v.endCoalescedSelectionDrag()
    }

    /// Uses `XCTAssertTraceStates` (Task 2, previously unexercised): the bracket's WILL and DID events
    /// must carry the IDENTICAL selection/revision state — there is no intermediate mutation between them.
    func test_endCoalescedSelectionDrag_emitsExactlyOneBracketWithNoStateChangeBetween() {
        let v = makeCanvas()
        v.beginCoalescedSelectionDrag()
        for i in 0..<5 { v.setSelectionHead(global: v.boxes[0].textStart + i) }
        recorder.reset()
        v.endCoalescedSelectionDrag()
        let a = v.anchor, h = v.head, rev = v.documentRevision
        XCTAssertTraceStates(recorder, [
            (.selectionWillChange, anchor: a, head: h, revision: rev),
            (.selectionDidChange, anchor: a, head: h, revision: rev),
        ])
    }

    func test_endCoalescedSelectionDrag_withNoOpenDrag_emitsNothing() {
        let v = makeCanvas(); recorder.reset()
        v.endCoalescedSelectionDrag()
        XCTAssertEqual(delegateKinds(), [])
    }

    /// The floating cursor deliberately does NOT honour coalescing.
    func test_moveFloatingCaret_emitsABracketEvenWhileCoalescing() {
        let v = makeCanvas()
        v.beginCoalescedSelectionDrag(); recorder.reset()
        v.moveFloatingCaret(toGlobal: v.boxes[0].textStart + 2)
        XCTAssertEqual(delegateKinds(), [.selectionWillChange, .selectionDidChange])
        v.endCoalescedSelectionDrag()
    }

    func test_beginFloatingCursor_bracketsOnlyWhenCollapsingARangedSelection() {
        let v = makeCanvas()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart + 3)
        recorder.reset()
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(delegateKinds(), [.selectionWillChange, .selectionDidChange])
        v.endFloatingCursor()
    }

    func test_beginFloatingCursor_withACollapsedCaret_emitsNothing() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1); recorder.reset()
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(delegateKinds(), [])
        v.endFloatingCursor()
    }

    func test_endFloatingCursor_emitsNoDelegateNotifications() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.beginFloatingCursor(at: CGPoint(x: 10, y: 10)); recorder.reset()
        v.endFloatingCursor()
        XCTAssertEqual(delegateKinds(), [])
    }

    /// The marked-commit path moves the caret but emits NO selection bracket.
    func test_insertTextWhileMarked_emitsATextOnlyBracket() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        recorder.reset()
        v.insertText("。")
        XCTAssertEqual(delegateKinds(), [.textWillChange, .textDidChange])
    }

    func test_setMarkedText_emitsATextBracketThenASeparateSelectionBracket() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1); recorder.reset()
        v.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertEqual(delegateKinds(),
                       [.textWillChange, .textDidChange, .selectionWillChange, .selectionDidChange])
    }

    func test_dismissPrediction_emitsATextOnlyBracket() {
        let v = makeCanvas()
        v.setCaret(global: v.boxes[0].textStart + 1)
        v.setMarkedText("ing", selectedRange: NSRange(location: 0, length: 0))
        recorder.reset()
        v.dismissPrediction()
        XCTAssertEqual(delegateKinds(), [.textWillChange, .textDidChange])
    }

    /// UIKit is the caller here, so the setter must stay silent.
    func test_selectedTextRangeSetter_emitsNoDelegateNotifications() {
        let v = makeCanvas(); recorder.reset()
        let p = DocumentTextPosition(v.boxes[0].textStart + 2)
        v.selectedTextRange = DocumentTextRange(p, p)
        XCTAssertEqual(delegateKinds(), [])
    }

    func test_applySelection_emitsOneSelectionBracket() {
        let v = makeCanvas(); recorder.reset()
        v.applySelection(from: v.boxes[0].textStart, to: v.boxes[0].textStart + 3)
        XCTAssertEqual(delegateKinds(), [.selectionWillChange, .selectionDidChange])
    }

    func test_composerSelectedRangeSetter_emitsOneSelectionBracket() {
        let v = makeCanvas(); recorder.reset()
        v.composerSelectedRange = NSRange(location: 1, length: 2)
        XCTAssertEqual(delegateKinds(), [.selectionWillChange, .selectionDidChange])
    }
}
#endif
