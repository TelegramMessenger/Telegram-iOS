#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasEditingTests: XCTestCase {
    private func canvas(_ texts: [String]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }
    private func caret(_ v: DocumentCanvasView, _ pos: Int) {
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }

    func test_undoRedo_ofTyping_onCanvas() {
        let v = canvas(["Alpha", "Beta"])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[0].textStart + 5)              // end of "Alpha"
        um.beginUndoGrouping(); v.insertText("!"); um.endUndoGrouping()
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha!")
        um.undo()
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha")
        XCTAssertEqual(v.head, v.boxes[0].textStart + 5)   // caret restored to end of "Alpha"
        um.redo()
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha!")
        XCTAssertEqual(v.head, v.boxes[0].textStart + 6)   // caret after "Alpha!"
    }

    func test_crossBlockSelectionDelete_mergesEndpoints() {
        let v = canvas(["Alpha", "Beta", "Gamma"])
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 2, head: v.boxes[1].textStart + 2)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alta")
        XCTAssertEqual(v.boxes[0].id, BlockID("p0"))
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "Gamma")
        XCTAssertEqual(v.head, v.boxes[0].textStart + 2)
    }

    func test_crossBlockDelete_removesFullyCoveredMiddleBlock() {
        let v = canvas(["Alpha", "Beta", "Gamma"])
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 2, head: v.boxes[2].textStart + 2)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Almma")
    }

    func test_typeOverCrossBlockSelection_insertsInMergedBlock() {
        let v = canvas(["Alpha", "Beta"])
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 2, head: v.boxes[1].textStart + 2)
        v.insertText("X")
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "AlXta")
        XCTAssertEqual(v.head, v.boxes[0].textStart + 3)
    }

    func test_undo_ofCrossBlockDelete_restoresAllBlocks() {
        let v = canvas(["Alpha", "Beta"])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 2, head: v.boxes[1].textStart + 2)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 1)
        um.undo()
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertEqual(v.boxes.map { ($0 as! BlockBox).currentParagraph().text }, ["Alpha", "Beta"])
        XCTAssertEqual(v.boxes.map { $0.id }, [BlockID("p0"), BlockID("p1")])
        // Undo of a deletion now restores a COLLAPSED caret at the END of the restored span (iOS-style),
        // not the pre-edit selection. max(before-anchor, before-head) = the head end = boxes[1].textStart + 2.
        XCTAssertEqual(v.anchor, v.boxes[1].textStart + 2)
        XCTAssertEqual(v.head, v.boxes[1].textStart + 2)
    }

    func test_deleteSelectionToEndOfDocument_viaSnapping() {
        let v = canvas(["Alpha", "Beta"])
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 2, head: v.documentSize)   // inside "Alpha" end-of-document (past last text → resolveBox snaps)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1)
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Al")   // "Al" + everything-after deleted
    }
}
#endif
