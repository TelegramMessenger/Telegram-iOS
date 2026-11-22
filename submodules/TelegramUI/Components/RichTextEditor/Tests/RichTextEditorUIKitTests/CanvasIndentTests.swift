#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasIndentTests: XCTestCase {
    /// [ bullet "Item" (level 0), plain "Plain" ]
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("li"), list: ListMembership(marker: .bullet, level: 0),
                                      runs: [TextRun(text: "Item")])),
            .paragraph(ParagraphBlock(id: BlockID("pl"), runs: [TextRun(text: "Plain")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    func level(_ v: DocumentCanvasView, _ id: String) -> Int? {
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID(id) { return p.list?.level } }
        return nil
    }
    func caretIn(_ v: DocumentCanvasView, _ id: String) {
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart)
    }

    func test_indent_bumpsListLevel() {
        let v = canvas(); caretIn(v, "li")
        v.indent()
        XCTAssertEqual(level(v, "li"), 1)
    }

    func test_outdent_decrementsAndClampsAtZero() {
        let v = canvas()
        caretIn(v, "li"); v.indent()
        caretIn(v, "li"); v.indent()
        XCTAssertEqual(level(v, "li"), 2)
        caretIn(v, "li"); v.outdent()
        XCTAssertEqual(level(v, "li"), 1)
        caretIn(v, "li"); v.outdent()
        caretIn(v, "li"); v.outdent()
        XCTAssertEqual(level(v, "li"), 0, "outdent clamps at 0 (does not remove the list)")
    }

    func test_indent_clampsAtMaxLevel() {
        let v = canvas()
        for _ in 0..<12 { caretIn(v, "li"); v.indent() }
        XCTAssertEqual(level(v, "li"), 8, "indent clamps at maxLevel 8")
    }

    func test_indent_nonListParagraph_isNoOp() {
        let v = canvas(); caretIn(v, "pl")
        v.indent()
        XCTAssertNil(level(v, "pl"), "a non-list paragraph stays non-list")
    }

    func test_indent_isUndoable() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        caretIn(v, "li")
        um.beginUndoGrouping(); v.indent(); um.endUndoGrouping()
        XCTAssertEqual(level(v, "li"), 1)
        um.undo()
        XCTAssertEqual(level(v, "li"), 0)
    }

    func test_indent_multiParagraphSelection_bumpsAllTouchedListItems() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "One")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "Two")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let a = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("a")) }!
        let b = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("b")) }!
        v.setSelectionForTesting(anchor: a.globalStart, head: b.globalStart + b.length)   // span both list items
        v.indent()
        XCTAssertEqual(level(v, "a"), 1)
        XCTAssertEqual(level(v, "b"), 1)
    }

    func test_indent_changesRenderedMarkerGlyph() {
        let v = canvas(); caretIn(v, "li")
        let before = v.listMarkerLabels()[BlockID("li")]
        v.indent()
        let after = v.listMarkerLabels()[BlockID("li")]
        XCTAssertNotNil(before)
        XCTAssertNotEqual(before, after, "indenting cycles the rendered bullet glyph (level 0 → 1)")
    }

    func test_outdent_nonListParagraph_isNoOp() {
        let v = canvas(); caretIn(v, "pl")
        v.outdent()
        XCTAssertNil(level(v, "pl"), "outdent on a non-list paragraph stays non-list")
    }
}
#endif
