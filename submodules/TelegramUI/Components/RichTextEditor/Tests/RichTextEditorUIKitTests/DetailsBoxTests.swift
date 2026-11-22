#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
final class DetailsBoxTests: XCTestCase {
    private func mapper() -> AttributedStringMapper { AttributedStringMapper() }

    func test_detailsBox_nodeSize_matchesDocumentTree_expandedAndFolded() {
        let body = Block.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "ab")]))
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")], children: [body], expanded: true)
        let box = DetailsBox(details: d, mapper: mapper(), width: 320)
        XCTAssertEqual(box.nodeSize, DocumentTree.documentSize(Document(blocks: [.details(d)])))   // == 9
        var folded = d; folded.expanded = false
        let foldedBox = DetailsBox(details: folded, mapper: mapper(), width: 320)
        XCTAssertEqual(foldedBox.nodeSize, DocumentTree.documentSize(Document(blocks: [.details(folded)])))   // == 5
    }

    func test_detailsBox_leafRegions_titleFirst_bodyWhenExpanded() {
        let body = Block.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "ab")]))
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")], children: [body], expanded: true)
        let box = DetailsBox(details: d, mapper: mapper(), width: 320)
        box.nodeStart = 0
        box.recompute()
        let regions = box.leafRegions()
        // The title is the first child BlockBox with a DERIVED id (distinct from the details' own id, so the
        // two backing views don't collide in `blockViews`); its region reads back as that `.paragraph` ref.
        let titleID = DetailsBox.titleBlockID(BlockID("d"))
        XCTAssertEqual(regions.first?.ref, .paragraph(titleID))
        XCTAssertEqual(regions.first?.globalStart, 1)                 // first child of a container at nodeStart 0 → leaf at 1 (like BlockQuoteBox)
        XCTAssertEqual(regions.count, 2)                              // title + one body paragraph
        // Folded → only the title region
        var folded = d; folded.expanded = false
        let f = DetailsBox(details: folded, mapper: mapper(), width: 320); f.nodeStart = 0; f.recompute()
        XCTAssertEqual(f.leafRegions().map { $0.ref }, [.paragraph(titleID)])
    }

    func test_detailsBox_currentBlock_roundTrips() {
        let body = Block.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "ab")]))
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")], children: [body], expanded: true)
        let box = DetailsBox(details: d, mapper: mapper(), width: 320)
        guard case .details(let out) = box.currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.id, d.id)
        XCTAssertEqual(out.title.map(\.text).joined(), "T")
        XCTAssertEqual(out.expanded, true)
        XCTAssertEqual(out.children.count, 1)
    }

    func test_detailsBox_draw_doesNotCrash_andChevronInsideBounds() {
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "Summary")],
                             children: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "x")]))],
                             expanded: true)
        let box = DetailsBox(details: d, mapper: mapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height); box.nodeStart = 0; box.recompute()
        XCTAssertTrue(CGRect(x: 0, y: 0, width: 320, height: box.height).contains(box.chevronRect()))
        UIGraphicsBeginImageContext(CGSize(width: 320, height: max(1, box.height)))
        defer { UIGraphicsEndImageContext() }
        box.draw(in: UIGraphicsGetCurrentContext()!, imageProvider: { _ in nil })   // must not crash
    }

    func test_detailsBox_titleReadBack_stripsDisplayFontSize_keepsText() {
        // The title is always Body (implicit style); its read-back runs must NOT carry the pinned display font
        // size, so the model title stays style-clean (only inline text + real attributes).
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "Summary")],
                             children: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "x")]))],
                             expanded: true)
        let box = DetailsBox(details: d, mapper: mapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height); box.nodeStart = 0; box.recompute()
        guard case .details(let out) = box.currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.title.map(\.text).joined(), "Summary")
        XCTAssertTrue(out.title.allSatisfy { $0.attributes.fontSize == nil })   // no pinned H2 size
    }

    func test_detailsBox_body_isFlush_withTheBlockLeadingEdge() {
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                             children: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "body")]))],
                             expanded: true)
        let box = DetailsBox(details: d, mapper: mapper(), width: 300)
        box.frame = CGRect(x: 10, y: 0, width: 300, height: box.height); box.nodeStart = 0; box.recompute()
        // Both the title and body child FRAMES are full-width at the block's leading edge; only the title's
        // TEXT is indented (paragraph indent) to clear the chevron — the body sits at the normal body inset.
        XCTAssertEqual(box.children.boxes[0].frame.minX, box.frame.minX, accuracy: 0.5)   // title frame flush
        XCTAssertEqual(box.children.boxes[1].frame.minX, box.frame.minX, accuracy: 0.5)   // body flush
    }

    func test_detailsBox_draw_withChevronImage_doesNotCrash() {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 18, height: 18)).image { _ in }
        for expanded in [true, false] {
            let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                 children: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "x")]))],
                                 expanded: expanded)
            let box = DetailsBox(details: d, mapper: mapper(), width: 320)
            box.chevronImage = img
            box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height); box.nodeStart = 0; box.recompute()
            UIGraphicsBeginImageContext(CGSize(width: 320, height: max(1, box.height)))
            box.draw(in: UIGraphicsGetCurrentContext()!, imageProvider: { _ in nil })
            UIGraphicsEndImageContext()
        }
    }

    func test_detailsBox_titleBodyGap_isIndependentOfBodyBodySpacing() {
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                             children: [.paragraph(ParagraphBlock(id: BlockID("b1"), runs: [TextRun(text: "one")])),
                                        .paragraph(ParagraphBlock(id: BlockID("b2"), runs: [TextRun(text: "two")]))],
                             expanded: true)
        let box = DetailsBox(details: d, mapper: mapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height); box.nodeStart = 0; box.recompute()
        let frames = box.children.boxes.map { $0.frame }
        XCTAssertEqual(frames.count, 3)                                             // title + 2 body paragraphs
        XCTAssertEqual(frames[1].minY - frames[0].maxY, DetailsBox.titleBodyGap, accuracy: 0.5)   // title↔body gap
        XCTAssertEqual(frames[2].minY - frames[1].maxY, 0, accuracy: 0.5)                          // body↔body = 0
    }

    func test_detailsBox_titlePosition_sameCollapsedAndExpanded() {
        func made(_ expanded: Bool) -> DetailsBox {
            let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                 children: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "body")]))],
                                 expanded: expanded)
            let box = DetailsBox(details: d, mapper: mapper(), width: 320)
            box.frame = CGRect(x: 0, y: 0, width: 320, height: box.height); box.nodeStart = 0; box.recompute()
            return box
        }
        let exp = made(true), col = made(false)
        // Folding must NOT move the title/chevron — same top inset in both states.
        XCTAssertEqual(col.children.boxes[0].frame.minY, exp.children.boxes[0].frame.minY, accuracy: 0.5)
        XCTAssertEqual(col.chevronRect().minY, exp.chevronRect().minY, accuracy: 0.5)
    }

    func test_detailsBox_folded_preservesBodyForRoundTrip() {
        let body = Block.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "kept")]))
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")], children: [body], expanded: false)
        let box = DetailsBox(details: d, mapper: mapper(), width: 320)
        guard case .details(let out) = box.currentBlock() else { return XCTFail() }
        XCTAssertFalse(out.expanded)
        XCTAssertEqual(out.children.count, 1)                        // body preserved off-axis while folded
        guard case .paragraph(let p) = out.children[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "kept")
    }
}
#endif
