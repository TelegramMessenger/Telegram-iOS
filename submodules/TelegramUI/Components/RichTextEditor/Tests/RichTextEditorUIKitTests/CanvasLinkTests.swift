#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasLinkTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    /// [ paragraph "Hello", paragraph "World", table( "Alpha" | "Beta" ) ]
    func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello")])),
            .paragraph(ParagraphBlock(id: BlockID("w"), runs: [TextRun(text: "World")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    func runs(_ v: DocumentCanvasView, _ id: String) -> [TextRun] {
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID(id) { return p.runs } }
        return []
    }
    func cellRuns(_ v: DocumentCanvasView, _ row: Int, _ col: Int) -> [TextRun] {
        guard let t = v.boxes.first(where: { $0 is TableBlockBox }) as? TableBlockBox,
              case .table(let model) = t.currentBlock() else { return [] }
        if case .paragraph(let p) = model.rows[row].cells[col].blocks[0] { return p.runs }
        return []
    }
    func selectParagraph(_ v: DocumentCanvasView, _ id: String, _ lo: Int, _ hi: Int) {
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
        v.setSelectionForTesting(anchor: r.globalStart + lo, head: r.globalStart + hi)
    }

    func test_setLink_appliesToSelectionOnly() {
        let v = canvas()
        selectParagraph(v, "h", 1, 4)             // "ell" of "Hello"
        v.setLink("https://x.com")
        let linked = runs(v, "h").filter { $0.attributes.link != nil }
        XCTAssertEqual(linked.map { $0.text }.joined(), "ell")
        XCTAssertEqual(linked.first?.attributes.link, "https://x.com")
    }

    func test_setLink_doesNotContaminateModel() {
        let v = canvas()
        selectParagraph(v, "h", 1, 4)
        v.setLink("https://x.com")
        let linked = runs(v, "h").first { $0.attributes.link != nil }!
        XCTAssertFalse(linked.attributes.underline, "link underline must not leak into the model")
        XCTAssertNil(linked.attributes.foreground, "link blue must not leak into the model foreground")
    }

    func test_removeLink_clearsLinkAndStyling() {
        let v = canvas()
        selectParagraph(v, "h", 1, 4); v.setLink("https://x.com")
        selectParagraph(v, "h", 1, 4); v.removeLink()
        XCTAssertTrue(runs(v, "h").allSatisfy { $0.attributes.link == nil })
        XCTAssertTrue(runs(v, "h").allSatisfy { !$0.attributes.underline })
    }

    func test_currentLink_uniformReturnsValue_mixedReturnsNil() {
        let v = canvas()
        selectParagraph(v, "h", 1, 4); v.setLink("https://x.com")
        selectParagraph(v, "h", 1, 4)
        XCTAssertEqual(v.currentLink(), "https://x.com", "fully-linked selection returns the link")
        selectParagraph(v, "h", 0, 5)
        XCTAssertNil(v.currentLink(), "selection covering unlinked text returns nil")
    }

    func test_setLink_collapsedCaret_isNoOp() {
        let v = canvas()
        selectParagraph(v, "h", 2, 2); v.setLink("https://x.com")
        XCTAssertTrue(runs(v, "h").allSatisfy { $0.attributes.link == nil })
    }

    func test_setLink_crossCell() {
        let v = canvas()
        let a = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let b = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: a.globalStart + 1, head: b.globalStart + 3)   // "lpha" + "Bet"
        v.setLink("https://x.com")
        XCTAssertEqual(cellRuns(v, 0, 0).filter { $0.attributes.link != nil }.map { $0.text }.joined(), "lpha")
        XCTAssertEqual(cellRuns(v, 0, 1).filter { $0.attributes.link != nil }.map { $0.text }.joined(), "Bet")
    }

    func test_setLink_isUndoable() {
        let v = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        selectParagraph(v, "h", 0, 5)
        um.beginUndoGrouping(); v.setLink("https://x.com"); um.endUndoGrouping()
        XCTAssertEqual(runs(v, "h").filter { $0.attributes.link != nil }.map { $0.text }.joined(), "Hello")
        um.undo()
        XCTAssertTrue(runs(v, "h").allSatisfy { $0.attributes.link == nil })
    }

    func test_setLink_injectsVisibleStylingIntoLiveStorage() {
        // editing{} does NOT rebuild boxes, so the live storage IS what's drawn — setLink must inject
        // the blue directly (the model read-back suppresses it, so this is the only check of
        // immediate display). 6a: links are blue only, no underline.
        let v = canvas()
        selectParagraph(v, "h", 1, 4)
        v.setLink("https://x.com")
        let r = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("h")) }!
        let storage = r.layout.backingStorage!
        let attrs = storage.attributes(at: 2, effectiveRange: nil)   // within the linked "ell"
        XCTAssertEqual(attrs[.link] as? String, "https://x.com")
        XCTAssertNotNil(attrs[.foregroundColor], "live storage carries the link foreground color")
        // 6a: updated from single.rawValue assertion — links must not be underlined
        XCTAssertNil(attrs[.underlineStyle], "links must not be underlined in 6a")
    }

    func test_removeLink_overSupersetSelection_clearsLink() {
        let v = canvas()
        selectParagraph(v, "h", 1, 4); v.setLink("https://x.com")   // link "ell"
        selectParagraph(v, "h", 0, 5); v.removeLink()               // unlink the whole word
        XCTAssertTrue(runs(v, "h").allSatisfy { $0.attributes.link == nil })
        XCTAssertTrue(runs(v, "h").allSatisfy { !$0.attributes.underline })
    }

    func test_currentLink_uniformAcrossCells() {
        let v = canvas()
        let a = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let b = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        v.setSelectionForTesting(anchor: a.globalStart, head: b.globalStart + b.length)   // whole "Alpha" + "Beta" across cells
        v.setLink("https://x.com")
        v.setSelectionForTesting(anchor: a.globalStart, head: b.globalStart + b.length)   // re-select the same cross-cell range
        XCTAssertEqual(v.currentLink(), "https://x.com")
    }
}
#endif
