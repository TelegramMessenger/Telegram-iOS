#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class DirectionalSelectionCharacterizationTests: XCTestCase {
    private func makeCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    /// The getter hands UIKit an UNORDERED range for a right-to-left drag (+UITextInput.swift:143),
    /// while textRange(from:to:) orders its arguments (:188-190). Both behaviors are load-bearing.
    func test_selectedTextRangeGetter_isUnorderedForAReversedSelection() {
        let v = makeCanvas()
        let s = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: s + 7, head: s + 2)
        let r = v.selectedTextRange as! DocumentTextRange
        XCTAssertEqual(r.from.offset, s + 7, "from must be the ANCHOR, not min()")
        XCTAssertEqual(r.to.offset, s + 2, "to must be the HEAD, not max()")
    }

    func test_reversedSelection_survivesAHandleDragToTheLeft() {
        let v = makeCanvas()
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 7)
        v.setSelectionHead(global: s + 2)
        XCTAssertEqual(v.anchor, s + 7)
        XCTAssertEqual(v.head, s + 2)
        XCTAssertEqual(v.selFrom, s + 2)
        XCTAssertEqual(v.selTo, s + 7)
    }

    /// D6: there is NO affinity model. This test records its absence so the seam does not invent one.
    func test_documentTextPosition_carriesOnlyAnOffset_noAffinity() {
        let p = DocumentTextPosition(4)
        XCTAssertEqual(p.offset, 4)
        XCTAssertEqual(Mirror(reflecting: p).children.compactMap { $0.label }, ["offset"],
                       "DocumentTextPosition must remain offset-only; affinity is invented in Phase 1 "
                       + "as a carried-but-inert field (deviation D6)")
    }
}
#endif
