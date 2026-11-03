import XCTest
@testable import RichTextEditorCore

final class ResolveTests: XCTestCase {
    // Reuse the Task-11 fixture map:
    // 0 <p> 1 O 2 n 3 e 4 </p> 5 <mediaBlock> 6 <mediaAtom> 7 <capP> 8 H 9 i 10 </capP> 11 </mediaBlock> 12
    private func tree() -> DocNode {
        DocumentTree.build(from: Document(
            blocks: [
                .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "One")])),
                .media(MediaBlock(id: BlockID("i1"), mediaID: "a",
                                  naturalSize: Size2D(width: 1, height: 1),
                                  caption: [TextRun(text: "Hi")])),
            ]))
    }

    func test_resolve_insideParagraphText_hasParagraphParentAndDepth1() {
        let r = PositionResolver.resolve(2, in: tree())   // between 'O' and 'n'
        XCTAssertEqual(r.depth, 1)
        XCTAssertEqual(r.parentOffset, 1)
        if case .paragraph(let id, _) = r.parent { XCTAssertEqual(id, BlockID("p1")) }
        else { XCTFail("parent should be paragraph p1") }
    }

    func test_resolve_topLevelBoundaryBetweenBlocks_hasDocParentDepth0() {
        let r = PositionResolver.resolve(5, in: tree())   // boundary after paragraph, before image
        XCTAssertEqual(r.depth, 0)
        if case .doc = r.parent {} else { XCTFail("parent should be doc") }
    }

    func test_resolve_insideCaptionText_isDepth2UnderMediaBlock() {
        let r = PositionResolver.resolve(9, in: tree())   // inside caption text (after 'H')
        XCTAssertEqual(r.depth, 2)
        if case .paragraph(let id, _) = r.parent { XCTAssertEqual(id, BlockID("i1")) }
        else { XCTFail("parent should be caption paragraph (image id)") }
    }

    func test_resolve_start_and_end_helpers() {
        let r = PositionResolver.resolve(2, in: tree())
        XCTAssertEqual(r.start(1), 1)   // first content position inside the paragraph
        XCTAssertEqual(r.end(1), 4)     // last content position inside the paragraph
    }

    func test_resolve_beforeAfterGiveNodeBoundaries() {
        let r = PositionResolver.resolve(2, in: tree())  // inside paragraph (depth 1)
        XCTAssertEqual(r.before(1), 0)   // position before the paragraph
        XCTAssertEqual(r.after(1), 5)    // position after the paragraph
    }

    func test_resolve_nodeBeforeAndAfterAtBlockBoundary() {
        let r = PositionResolver.resolve(5, in: tree())  // boundary between paragraph and image
        if case .paragraph(let id, _) = r.nodeBefore { XCTAssertEqual(id, BlockID("p1")) }
        else { XCTFail("nodeBefore should be paragraph p1") }
        if case .mediaBlock(let id, _) = r.nodeAfter { XCTAssertEqual(id, BlockID("i1")) }
        else { XCTFail("nodeAfter should be the media block i1") }
    }

    func test_resolve_nodeBeforeAfterAreNilInsideText() {
        let r = PositionResolver.resolve(2, in: tree())  // strictly inside "One"
        XCTAssertNil(r.nodeBefore)
        XCTAssertNil(r.nodeAfter)
    }
}
