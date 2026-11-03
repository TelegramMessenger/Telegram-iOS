#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasParagraphFormatTests: XCTestCase {
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "First")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Second")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        return v
    }
    func para(_ v: DocumentCanvasView, _ id: String) -> ParagraphBlock? {
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID(id) { return p } }
        return nil
    }
    func caret(_ v: DocumentCanvasView, _ id: String) {
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
        v.setSelectionForTesting(anchor: r.globalStart + 1, head: r.globalStart + 1)
    }

    func test_setParagraphStyle_collapsedCaret_setsStyle() {
        let v = canvas(); caret(v, "a")
        v.setParagraphStyle(.heading1)
        XCTAssertEqual(para(v, "a")?.style, .heading1)
        XCTAssertEqual(para(v, "b")?.style, .body, "other paragraph unchanged")
    }
    func test_headingParagraph_modelRunsAreNotBold() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("a"), style: .heading1, runs: [TextRun(text: "Title")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        // Headings are regular weight by default (StyleSheet.font no longer forces bold), so a plain
        // heading carries no bold emphasis in the model.
        XCTAssertEqual(para(v, "a")?.runs.filter { $0.attributes.bold }.count, 0,
                       "a plain heading is not bold")
    }
    func test_setParagraphStyle_headingDownToBody_isNotBold() {
        let v = canvas(); caret(v, "a")
        v.setParagraphStyle(.heading1)
        XCTAssertEqual(para(v, "a")?.style, .heading1)
        v.setParagraphStyle(.body)
        XCTAssertEqual(para(v, "a")?.style, .body)
        // Headings are regular weight, so there is no style-injected bold to leak when down-converting
        // to body. (Regression for the original "body stays bold after heading→body" report.)
        XCTAssertEqual(para(v, "a")?.runs.filter { $0.attributes.bold }.count, 0,
                       "heading→body is not bold")
    }
    func test_setParagraphStyle_multiParagraphSelection() {
        let v = canvas()
        let a = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("a")) }!
        let b = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("b")) }!
        v.setSelectionForTesting(anchor: a.globalStart + 1, head: b.globalStart + 2)
        v.setParagraphStyle(.heading2)
        XCTAssertEqual(para(v, "a")?.style, .heading2)
        XCTAssertEqual(para(v, "b")?.style, .heading2)
    }
    func test_setParagraphStyle_isUndoable() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        caret(v, "a")
        um.beginUndoGrouping(); v.setParagraphStyle(.heading1); um.endUndoGrouping()
        XCTAssertEqual(para(v, "a")?.style, .heading1)
        um.undo()
        XCTAssertEqual(para(v, "a")?.style, .body, "undo restores body")
    }
    func test_setAlignment_setsAlignment() {
        let v = canvas(); caret(v, "a")
        v.setAlignment(.center)
        XCTAssertEqual(para(v, "a")?.paragraph.alignment, .center)
    }
    func test_setAlignment_isUndoable() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        caret(v, "a")
        um.beginUndoGrouping(); v.setAlignment(.right); um.endUndoGrouping()
        XCTAssertEqual(para(v, "a")?.paragraph.alignment, .right)
        um.undo()
        XCTAssertEqual(para(v, "a")?.paragraph.alignment, .natural, "undo restores the default (natural)")
    }
}
#endif
