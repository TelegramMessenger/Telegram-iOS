#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Undo coalesces consecutive same-kind edits into ONE undo step (whole typing / deleting run),
/// matching a native iOS composer. `undoRegistrationCount` counts the NEW undo steps `editing`
/// starts (a coalesced keystroke registers nothing), so it directly measures coalescing without
/// depending on NSUndoManager's run-loop/group semantics.
final class UndoCoalescingTests: XCTestCase {
    private func canvas(_ text: String = "") -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("a"), runs: text.isEmpty ? [] : [TextRun(text: text)]))],
                    width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        // groupsByEvent = true matches production (`ownUndoManager`): registerUndo lazily opens a group,
        // so a bare registration outside an explicit group is legal, and undo() auto-closes the open group.
        // The `undoRegistrationCount` seam measures coalescing independent of grouping, so we don't need
        // manual begin/endUndoGrouping around the keystroke bursts.
        let um = UndoManager(); um.groupsByEvent = true
        v.undoManagerOverride = um
        return v
    }
    private func caretAtEnd(_ v: DocumentCanvasView) { let e = v.boxes[0].textStart + v.boxes[0].textLength; v.setSelectionForTesting(anchor: e, head: e) }
    private func text(_ v: DocumentCanvasView) -> String { (v.boxes[0] as! BlockBox).currentParagraph().text }

    func test_contiguousTyping_registersOneUndoStep() {
        let v = canvas("Hi ")
        caretAtEnd(v)
        v.insertText("a"); v.insertText("b"); v.insertText("c")
        XCTAssertEqual(text(v), "Hi abc")
        XCTAssertEqual(v.undoRegistrationCount, 1, "a contiguous typing burst is ONE undo step")
    }

    func test_caretMoveBetweenTyping_registersTwoSteps() {
        let v = canvas("Hi")
        caretAtEnd(v)
        v.insertText("a")                        // step 1 (opens a run at the new caret)
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 1, head: v.boxes[0].textStart + 1)   // move the caret away → breaks the run
        v.insertText("z")                        // step 2 (non-contiguous)
        XCTAssertEqual(v.undoRegistrationCount, 2, "a caret move between typed chars starts a new step")
    }

    func test_typingOverSelection_isOwnStep_thenCoalesces() {
        let v = canvas("Hello")
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 0, head: v.boxes[0].textStart + 5)   // select "Hello"
        v.insertText("X")                        // replace-by-typing: step 1
        v.insertText("Y")                        // contiguous typing: coalesces
        XCTAssertEqual(text(v), "XY")
        XCTAssertEqual(v.undoRegistrationCount, 1, "replace + following typing coalesce into one step")
    }

    func test_wholeTypingRun_revertsInOneUndo() {
        let v = canvas("Hi ")
        caretAtEnd(v)
        v.insertText("a"); v.insertText("b"); v.insertText("c")   // one coalesced run (1 registration)
        XCTAssertEqual(text(v), "Hi abc")
        v.effectiveUndoManager!.undo()                            // groupsByEvent=true → undo() closes+undoes the open group
        XCTAssertEqual(text(v), "Hi ", "one undo reverts the whole coalesced run")
    }

    func test_undoThenType_startsFreshStep() {
        let v = canvas("Hi ")
        caretAtEnd(v)
        v.insertText("a")
        XCTAssertEqual(v.undoRegistrationCount, 1)
        v.effectiveUndoManager!.undo()           // restores "Hi " via setBlocks → breakUndoCoalescing()
        caretAtEnd(v)
        v.insertText("b")
        XCTAssertEqual(v.undoRegistrationCount, 2, "typing after an undo starts a fresh step (run was reset)")
    }

    func test_contiguousBackspace_registersOneStep() {
        let v = canvas("Hello")
        caretAtEnd(v)
        v.deleteBackward(); v.deleteBackward(); v.deleteBackward()   // delete "oll" within the paragraph
        XCTAssertEqual(text(v), "He")
        XCTAssertEqual(v.undoRegistrationCount, 1, "a contiguous backspace burst is ONE undo step")
    }

    func test_typingThenDeleting_registersTwoSteps() {
        let v = canvas("Hi")
        caretAtEnd(v)
        v.insertText("a")       // .typing → step 1
        v.deleteBackward()      // .deleting → kind switch → step 2
        XCTAssertEqual(v.undoRegistrationCount, 2, "switching from typing to deleting starts a new step")
    }

    func test_deletingThenTyping_registersTwoSteps() {
        let v = canvas("Hi")
        caretAtEnd(v)
        v.deleteBackward()      // .deleting → step 1
        v.insertText("z")       // .typing → kind switch → step 2
        XCTAssertEqual(v.undoRegistrationCount, 2, "switching from deleting to typing starts a new step")
    }

    func test_structuralEditBetweenTyping_separateSteps() {
        let v = canvas("Hi")
        caretAtEnd(v)
        v.insertText("a")        // .typing → step 1
        v.insertText("\n")       // paragraph break → editing default .none → step 2, and resets the run
        v.insertText("b")        // .typing again, but the run was reset → step 3
        XCTAssertEqual(v.undoRegistrationCount, 3, "a structural edit between typed chars breaks coalescing on both sides")
    }

    func test_imeCompositionCommit_breaksTypingRun() {
        let v = canvas("Hi")
        caretAtEnd(v)
        v.insertText("a")                                   // .typing → step 1, opens a run
        // Start + commit an IME composition (its own undo step); this must break the surrounding run.
        v.setMarkedText("は", selectedRange: NSRange(location: 1, length: 0))
        v.commitMarkedText()
        XCTAssertNil(v.openUndoRun, "committing a composition breaks any open typing run")
    }

    func test_wholeTypingRun_redoRestoresWholeRun() {
        let v = canvas("Hi ")
        caretAtEnd(v)
        v.insertText("a"); v.insertText("b"); v.insertText("c")   // one coalesced run
        let um = v.effectiveUndoManager!
        um.undo()
        XCTAssertEqual(text(v), "Hi ")
        um.redo()
        XCTAssertEqual(text(v), "Hi abc", "redo restores the WHOLE coalesced run, not one char")
    }

    func test_resignFirstResponder_breaksRun() {
        let v = canvas("Hi")
        v.openUndoRun = (.typing, 5)                 // simulate an open typing run
        _ = v.resignFirstResponder()
        XCTAssertNil(v.openUndoRun, "losing focus ends any open coalescing run")
    }

    func test_undoOfSelectionDeletion_restoresCaretNotSelection() {
        let v = canvas("Hello")
        let start = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: start + 1, head: start + 4)   // select "ell"
        v.deleteBackward()                          // -> "Ho"
        XCTAssertEqual(text(v), "Ho")
        v.effectiveUndoManager!.undo()
        XCTAssertEqual(text(v), "Hello")
        XCTAssertEqual(v.anchor, v.head, "undo of a deletion restores a caret, not a selection")
        XCTAssertEqual(v.head, start + 4, "caret lands at the end of the restored span (iOS-style)")
    }

    func test_undoOfFormatting_preservesSelection() {
        let v = canvas("Hello")
        let start = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: start + 0, head: start + 5)   // select "Hello"
        v.toggleBold()                              // attribute-only; selection stays a range
        v.effectiveUndoManager!.undo()              // un-bold
        XCTAssertEqual(text(v), "Hello", "un-bold must not alter the text")
        XCTAssertEqual(v.anchor, start + 0, "formatting undo keeps the selection anchor")
        XCTAssertEqual(v.head, start + 5, "formatting undo keeps the selection head")
    }
}
#endif
