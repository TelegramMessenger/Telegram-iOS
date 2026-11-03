import XCTest
@testable import RichTextEditorCore

final class ParagraphEditingTests: XCTestCase {
    private func bold(_ s: String) -> TextRun { TextRun(text: s, attributes: CharacterAttributes(bold: true)) }
    private func plain(_ s: String) -> TextRun { TextRun(text: s) }

    func test_split_inMiddleOfSingleRun_keepsTextOnBothSides() {
        let p = ParagraphBlock(id: BlockID("a"), style: .heading2, runs: [plain("Alpha")])
        let (upper, lower) = p.split(at: 2, newID: BlockID("b"))
        XCTAssertEqual(upper.id, BlockID("a"))      // upper keeps the parent id
        XCTAssertEqual(lower.id, BlockID("b"))      // lower gets the new id
        XCTAssertEqual(upper.text, "Al")
        XCTAssertEqual(lower.text, "pha")
        XCTAssertEqual(upper.style, .heading2)      // both inherit style
        XCTAssertEqual(lower.style, .heading2)
    }

    func test_split_insideBoldRun_preservesAttributesOnBothSides() {
        let p = ParagraphBlock(id: BlockID("a"), runs: [plain("Hi "), bold("there")])
        let (upper, lower) = p.split(at: 5, newID: BlockID("b"))   // "Hi th" | "ere"
        XCTAssertEqual(upper.text, "Hi th")
        XCTAssertEqual(lower.text, "ere")
        XCTAssertTrue(upper.runs.last?.attributes.bold ?? false)   // "th" stays bold
        XCTAssertTrue(lower.runs.first?.attributes.bold ?? false)  // "ere" stays bold
    }

    func test_split_atStart_givesEmptyUpper() {
        let p = ParagraphBlock(id: BlockID("a"), runs: [plain("Alpha")])
        let (upper, lower) = p.split(at: 0, newID: BlockID("b"))
        XCTAssertEqual(upper.text, "")
        XCTAssertEqual(lower.text, "Alpha")
        XCTAssertTrue(upper.runs.isEmpty)
    }

    func test_split_exactlyAtRunBoundary_producesNoSplitRun() {
        let p = ParagraphBlock(id: BlockID("a"), runs: [plain("Hi "), bold("there")])
        let (upper, lower) = p.split(at: 3, newID: BlockID("b"))   // cut == end of "Hi "
        XCTAssertEqual(upper.runs.count, 1)
        XCTAssertEqual(upper.runs[0].text, "Hi ")
        XCTAssertFalse(upper.runs[0].attributes.bold)
        XCTAssertEqual(lower.runs.count, 1)
        XCTAssertEqual(lower.runs[0].text, "there")
        XCTAssertTrue(lower.runs[0].attributes.bold)
    }

    func test_split_atEnd_givesEmptyLower_andInheritsList() {
        let p = ParagraphBlock(id: BlockID("a"), list: ListMembership(marker: .bullet, level: 1),
                               runs: [plain("Alpha")])
        let (upper, lower) = p.split(at: 5, newID: BlockID("b"))
        XCTAssertEqual(upper.text, "Alpha")
        XCTAssertEqual(lower.text, "")
        XCTAssertEqual(lower.list, ListMembership(marker: .bullet, level: 1))  // list inherited
    }

    func test_merging_concatenatesRuns_keepingReceiverIdentity() {
        let a = ParagraphBlock(id: BlockID("a"), style: .heading1, runs: [plain("Alpha")])
        let b = ParagraphBlock(id: BlockID("b"), style: .body, runs: [plain("Beta")])
        let merged = a.merging(b)
        XCTAssertEqual(merged.id, BlockID("a"))     // survivor identity
        XCTAssertEqual(merged.style, .heading1)     // survivor style wins
        XCTAssertEqual(merged.text, "AlphaBeta")
    }

    func test_merging_preservesEachSidesAttributes() {
        let a = ParagraphBlock(id: BlockID("a"), runs: [plain("Hi ")])
        let b = ParagraphBlock(id: BlockID("b"), runs: [bold("there")])
        let merged = a.merging(b)
        XCTAssertEqual(merged.runs.count, 2)
        XCTAssertFalse(merged.runs[0].attributes.bold)
        XCTAssertTrue(merged.runs[1].attributes.bold)
    }

    func test_splitThenMerge_roundTrips() {
        let p = ParagraphBlock(id: BlockID("a"), runs: [plain("Hello world")])
        let (u, l) = p.split(at: 5, newID: BlockID("b"))
        XCTAssertEqual(u.merging(l).text, "Hello world")
    }
}
