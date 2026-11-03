#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
final class DetailsBoxInsertTests: XCTestCase {
    func test_insertDetailsBlock_onEmptyParagraph_replacesIt_expanded_caretInTitle() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p")))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart)
        v.insertDetailsBlock()
        let blocks = v.currentBlocks()
        guard blocks.count == 1, case .details(let d) = blocks[0] else { return XCTFail("expected one details block") }
        XCTAssertTrue(d.expanded)
        XCTAssertEqual(d.title, [])
        XCTAssertEqual(d.children.count, 1)                          // one empty body paragraph
        guard case .paragraph(let bp) = d.children[0] else { return XCTFail() }
        XCTAssertTrue(bp.text.isEmpty)
        let box = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        XCTAssertEqual(v.head, box.leafRegions().first?.globalStart)   // caret at the title start
    }

    func test_insertDetailsBlock_recomputesBody_leafRegionsOrdered_navigationDoesNotCrash() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p")))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart, head: v.boxes[0].textStart)
        v.insertDetailsBlock()
        // The body child's nodeStart must be assigned (DetailsBox.recompute ran via recomputeSpans), so
        // leaf regions come out in ascending globalStart order — else nextTextPosition builds an inverted
        // `pos..<nextStart` range and crashes ("Range requires lowerBound <= upperBound").
        let starts = v.allLeafRegions().map { $0.globalStart }
        XCTAssertEqual(starts, starts.sorted(), "leaf regions must be ordered by globalStart")
        _ = v.nextTextPosition(after: v.head)   // must not crash
    }

    func test_insertDetailsBlock_splitsNonEmptyParagraph() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "abcd")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.setSelectionForTesting(anchor: v.boxes[0].textStart + 2, head: v.boxes[0].textStart + 2)   // caret mid-text ("ab|cd")
        v.insertDetailsBlock()
        let blocks = v.currentBlocks()
        XCTAssertEqual(blocks.count, 3)                               // upper "ab", details, lower "cd"
        guard case .paragraph(let upper) = blocks[0], case .details = blocks[1], case .paragraph(let lower) = blocks[2] else {
            return XCTFail("expected [paragraph, details, paragraph]")
        }
        XCTAssertEqual(upper.text, "ab")
        XCTAssertEqual(lower.text, "cd")
    }

    func test_typingInTitleAndBody_goesToDetails_notFollowingParagraph() {
        let v = DocumentCanvasView()
        let d = DetailsBlock(id: BlockID("d"), title: [],
                             children: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: []))], expanded: true)
        v.setBlocks([.details(d), .paragraph(ParagraphBlock(id: BlockID("after"), runs: [TextRun(text: "AFTER")]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.becomeFirstResponder()
        // Type into the title (leaf region 0).
        let box = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        let titleStart = box.leafRegions()[0].globalStart
        v.setSelectionForTesting(anchor: titleStart, head: titleStart)
        v.insertText("Hi")
        // Type into the body (leaf region 1) — re-fetch, the box/positions were rebuilt by the edit.
        let box2 = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        let bodyStart = box2.leafRegions()[1].globalStart
        v.setSelectionForTesting(anchor: bodyStart, head: bodyStart)
        v.insertText("Yo")
        guard case .details(let out) = v.currentBlocks()[0] else { return XCTFail("expected details first") }
        XCTAssertEqual(out.title.map(\.text).joined(), "Hi")        // title got the text
        let bodyText = out.children.first.flatMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
        XCTAssertEqual(bodyText, "Yo")                              // body got the text
        guard case .paragraph(let after) = v.currentBlocks()[1] else { return XCTFail("expected following paragraph") }
        XCTAssertEqual(after.text, "AFTER")                         // following paragraph untouched
    }

    func test_insertDetailsBlock_insideTable_isNoOp() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 90)],
            rows: [Row(id: BlockID("r0"), cells: [Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap")))])])]))],
            width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let table = v.boxes.first { $0 is TableBlockBox } as! TableBlockBox
        v.setSelectionForTesting(anchor: table.cellTextStart(row: 0, column: 0)!, head: table.cellTextStart(row: 0, column: 0)!)
        let before = v.currentBlocks()
        v.insertDetailsBlock()
        XCTAssertEqual(v.currentBlocks(), before)                    // no-op inside a table
        XCTAssertNil(v.boxes.first { $0 is DetailsBox })
    }
}
#endif
