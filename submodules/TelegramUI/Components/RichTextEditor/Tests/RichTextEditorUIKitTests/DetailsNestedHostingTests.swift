#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
final class DetailsNestedHostingTests: XCTestCase {
    /// A canvas with a details block whose body contains a 2×2 table.
    private func canvasWithNestedTable() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        let table = Block.table(TableBlock.empty(rows: 2, columns: 2))
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                             children: [table], expanded: true)
        v.setBlocks([.details(d)], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        return v
    }
    private func nestedTableBox(_ v: DocumentCanvasView) -> TableBlockBox {
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        return details.children.boxes.first { $0 is TableBlockBox } as! TableBlockBox
    }

    func test_owningTable_findsTableNestedInDetailsBody() {
        let v = canvasWithNestedTable()
        let table = nestedTableBox(v)
        let cellStart = table.cellTextStart(row: 0, column: 0)!
        XCTAssertTrue(v.owningTable(cellStart) === table)
        XCTAssertTrue(v.tableBox(containingGlobal: cellStart) === table)
    }

    func test_nestedTable_activeTableResolvesAndHandlesAndInsertRowWork() {
        // The table control handles + structural ops all derive from activeTable(); it must resolve a table
        // nested in a details body (was top-level only → no handles, dead menu).
        let v = canvasWithNestedTable()
        let table = nestedTableBox(v)
        let cellStart = table.cellTextStart(row: 0, column: 0)!
        v.setSelectionForTesting(anchor: cellStart, head: cellStart)
        guard let a = v.activeTable() else { return XCTFail("activeTable must resolve a nested table") }
        XCTAssertTrue(a.box === table)
        XCTAssertFalse(v.tableHandles().isEmpty, "control handles must be present for a nested table")
        let before = table.rowCount
        v.insertTableRowBelow()
        XCTAssertEqual(nestedTableBox(v).rowCount, before + 1, "insert-row must work on a nested table")
    }

    func test_nestedTable_convertToText_replacesInDetailsBody() {
        let v = canvasWithNestedTable()
        let table = nestedTableBox(v)
        v.setSelectionForTesting(anchor: table.cellTextStart(row: 0, column: 0)!, head: table.cellTextStart(row: 0, column: 0)!)
        v.convertCurrentTableToText()
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        XCTAssertFalse(details.children.boxes.contains { $0 is TableBlockBox }, "the nested table must be converted to text in place")
        XCTAssertTrue(details.children.boxes.allSatisfy { $0 is BlockBox }, "only paragraphs remain (title + one per row)")
    }

    func test_nestedTable_realizesTableBackingView() {
        let v = canvasWithNestedTable()
        let table = nestedTableBox(v)
        v.syncBlockViews()
        XCTAssertTrue(v.isBlockViewRealizedForTesting(table.id), "nested table must get its own backing view")
    }

    func test_nestedTable_realizedViewIsATableBackingView() {
        let v = canvasWithNestedTable()
        let table = nestedTableBox(v)
        v.syncBlockViews()
        XCTAssertTrue(v.blockViewForTesting(table.id) is TableBackingView)
    }

    func test_reconcile_isIdempotent_forNestedViews() {
        let v = canvasWithNestedTable()
        v.syncBlockViews(); let n1 = v.realizedBlockViewCountForTesting
        v.syncBlockViews(); let n2 = v.realizedBlockViewCountForTesting
        XCTAssertEqual(n1, n2)   // no duplicate creation on a second reconcile
    }

    func test_detailsChromeView_distinctFromTitleView() {
        // The DetailsBox chrome view and its title child view must be SEPARATE backing views — they must not
        // collide on the same BlockID in `blockViews` (else the title overwrites the chrome → no chevron/
        // separator/placeholder). The title box uses a derived id.
        let v = canvasWithNestedTable()
        v.syncBlockViews()
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        let titleID = DetailsBox.titleBlockID(details.id)
        XCTAssertNotEqual(titleID, details.id)
        XCTAssertNotNil(v.blockViewForTesting(details.id))
        XCTAssertNotNil(v.blockViewForTesting(titleID))
        XCTAssertFalse(v.blockViewForTesting(details.id) === v.blockViewForTesting(titleID))
    }

    func test_caretInNestedTableCell_hostsIntoThatTable() {
        let v = canvasWithNestedTable()
        v.syncBlockViews()
        let table = nestedTableBox(v)
        let cellStart = table.cellTextStart(row: 0, column: 0)!
        let placement = v.caretHostPlacement(forGlobal: cellStart)
        XCTAssertNotNil(placement)
        XCTAssertTrue(placement?.container === v.blockViewForTesting(table.id))   // hosts into the nested table's view
    }

    func test_detailsDraw_isChromeOnly_noCrash() {
        let v = canvasWithNestedTable()
        v.syncBlockViews()
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        UIGraphicsBeginImageContext(CGSize(width: 320, height: max(1, details.frame.height)))
        defer { UIGraphicsEndImageContext() }
        details.draw(in: UIGraphicsGetCurrentContext()!, imageProvider: { _ in nil })   // chrome only; must not crash
    }

    func test_nestedList_markerIsResolved() {
        let v = DocumentCanvasView()
        let bullet = Block.paragraph(ParagraphBlock(id: BlockID("li"), list: ListMembership(marker: .bullet), runs: [TextRun(text: "item")]))
        v.setBlocks([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")], children: [bullet], expanded: true))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        let li = details.children.boxes.first { ($0 as? BlockBox)?.listMembership?.marker == .bullet } as! BlockBox
        XCTAssertNotNil(li.resolvedListMarker, "a nested list item must get a marker label so BlockBox.draw draws it")
    }

    func test_nestedChecklist_hostsCheckboxView() {
        final class StubCheckbox: UIView, RichTextChecklistMarkerView { func setChecked(_ checked: Bool, animated: Bool) {} }
        let v = DocumentCanvasView()
        v.checklistMarkerViewProvider = { _, _ in StubCheckbox() }
        let item = Block.paragraph(ParagraphBlock(id: BlockID("ck"), list: ListMembership(marker: .checklist, level: 0, checked: false), runs: [TextRun(text: "todo")]))
        v.setBlocks([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")], children: [item], expanded: true))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        let ck = details.children.boxes.first { ($0 as? BlockBox)?.listMembership?.marker == .checklist } as! BlockBox
        XCTAssertTrue(ck.hostsChecklistCheckbox, "a nested checklist item must be flagged to host a checkbox")
        XCTAssertNotNil(v.checklistMarkerViewForTesting(ck.id), "a nested checklist item must host a checkbox view")
    }

    func test_nestedMedia_realizesBackingView() {
        let v = DocumentCanvasView()
        let media = Block.media(MediaBlock(id: BlockID("nm"), mediaID: "x",
                                           naturalSize: Size2D(width: 100, height: 100), caption: []))
        v.setBlocks([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")], children: [media], expanded: true))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        v.syncBlockViews()
        XCTAssertTrue(v.isBlockViewRealizedForTesting(BlockID("nm")))
    }

    func test_nestedMedia_gapResolvesToTheMediaBox() {
        // Every image action (tap-select, edit-menu geometry, delete, spoiler) routes through
        // `mediaBox(atGap:)` — it must find a media block nested in a details body, not just top-level.
        let v = DocumentCanvasView()
        let media = Block.media(MediaBlock(id: BlockID("nm"), mediaID: "x",
                                           naturalSize: Size2D(width: 100, height: 100), caption: []))
        v.setBlocks([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")], children: [media], expanded: true))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        let mediaBox = details.children.boxes.first { $0 is MediaBlockBox } as! MediaBlockBox
        XCTAssertTrue(v.mediaBox(atGap: mediaBox.nodeStart) === mediaBox, "a nested media block's gap must resolve to it")
        XCTAssertTrue(v.isGapPosition(mediaBox.nodeStart), "a nested media block's leading gap must be a gap position")
    }

    func test_nestedMedia_deleteMediaBlock_removesFromDetailsBody() {
        let v = DocumentCanvasView()
        let media = Block.media(MediaBlock(id: BlockID("nm"), mediaID: "x",
                                           naturalSize: Size2D(width: 100, height: 100), caption: []))
        let para = Block.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "after")]))
        v.setBlocks([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                           children: [media, para], expanded: true))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        v.deleteMediaBlock(id: BlockID("nm"))
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        XCTAssertFalse(details.children.boxes.contains { $0 is MediaBlockBox }, "the nested media block must be removed from the details body")
        XCTAssertTrue(details.children.boxes.contains { ($0 as? BlockBox)?.id == BlockID("p") }, "the sibling paragraph survives")
    }

    func test_nestedMedia_toggleSpoiler_flipsNestedItem() {
        let v = DocumentCanvasView()
        let media = Block.media(MediaBlock(id: BlockID("nm"), mediaID: "x",
                                           naturalSize: Size2D(width: 100, height: 100), caption: []))
        v.setBlocks([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                           children: [media], expanded: true))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        v.toggleMediaSpoiler(blockID: BlockID("nm"), itemIndex: nil)
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        let box = details.children.boxes.first { $0 is MediaBlockBox } as! MediaBlockBox
        guard case .media(let m) = box.currentBlock() else { return XCTFail("expected a media block") }
        XCTAssertTrue(m.items.first?.isSpoiler == true, "toggling spoiler on a nested media block must flip its item")
    }

    func test_nestedMedia_backspaceOnSelected_replacesWithEmptyParagraph() {
        // Backspace on a tap-selected media block replaces it with an empty body paragraph IN PLACE —
        // it must NOT remove the block completely, even when the media is nested in a details body.
        let v = DocumentCanvasView()
        let media = Block.media(MediaBlock(id: BlockID("nm"), mediaID: "x",
                                           naturalSize: Size2D(width: 100, height: 100), caption: []))
        v.setBlocks([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                           children: [media], expanded: true))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        let mb = (v.boxes.first { $0 is DetailsBox } as! DetailsBox).children.boxes.first { $0 is MediaBlockBox } as! MediaBlockBox
        v.selectImage(mb)
        v.deleteBackward()
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        XCTAssertFalse(details.children.boxes.contains { $0 is MediaBlockBox }, "the media must be replaced, not removed")
        XCTAssertTrue(details.children.boxes.contains { ($0 as? BlockBox)?.style == .body && $0.textLength == 0 },
                      "an empty body paragraph must take the media's place in the details body")
    }

    func test_nestedEmptyParagraphAfterImage_backspaceRemovesTheParagraph() {
        // Backspace at the start of an empty paragraph inside a details body, whose previous sibling is an
        // image, must DELETE the empty paragraph — not cross-delete into the image's caption.
        let v = DocumentCanvasView()
        let media = Block.media(MediaBlock(id: BlockID("nm"), mediaID: "x",
                                           naturalSize: Size2D(width: 100, height: 100), caption: []))
        let empty = Block.paragraph(ParagraphBlock(id: BlockID("e"), runs: []))
        v.setBlocks([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                           children: [media, empty], expanded: true))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 800); v.layoutIfNeeded()
        let emptyBox = (v.boxes.first { $0 is DetailsBox } as! DetailsBox).children.boxes.first { ($0 as? BlockBox)?.id == BlockID("e") } as! BlockBox
        v.setSelectionForTesting(anchor: emptyBox.textStart, head: emptyBox.textStart)
        v.deleteBackward()
        let details = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        XCTAssertFalse(details.children.boxes.contains { ($0 as? BlockBox)?.id == BlockID("e") }, "the empty paragraph must be removed")
        XCTAssertTrue(details.children.boxes.contains { $0 is MediaBlockBox }, "the image must be kept")
    }
}
#endif
