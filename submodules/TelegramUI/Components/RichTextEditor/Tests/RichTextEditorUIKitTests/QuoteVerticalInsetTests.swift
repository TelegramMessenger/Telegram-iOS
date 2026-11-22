#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class QuoteVerticalInsetTests: XCTestCase {
    func test_quoteStyle_verticalInsets_defaultNil() {
        XCTAssertNil(QuoteStyle.default.topInset)
        XCTAssertNil(QuoteStyle.default.bottomInset)
        XCTAssertNil(StyleSheet().quoteTopInset)
        XCTAssertNil(StyleSheet().quoteBottomInset)
    }

    func test_applyQuoteStyle_mapsVerticalInsetsIntoStylesheet() {
        let v = DocumentCanvasView()
        v.applyQuoteStyle(QuoteStyle(topInset: 5, bottomInset: 7))
        XCTAssertEqual(v.mapper.styleSheet.quoteTopInset, 5)
        XCTAssertEqual(v.mapper.styleSheet.quoteBottomInset, 7)
    }

    // MARK: BlockStack layout

    private func canvas(_ blocks: [Block], quoteStyle: QuoteStyle = .default,
                        width: CGFloat = 300) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.applyQuoteStyle(quoteStyle)               // set the mapper BEFORE seeding so boxes carry it
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600)
        v.layoutIfNeeded()
        return v
    }
    private func body(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .body, runs: [TextRun(text: t)]))
    }
    private func listItem(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: .body,
                                  list: ListMembership(marker: .bullet), runs: [TextRun(text: t)]))
    }
    private func code(_ id: String, _ t: String) -> Block {
        .code(CodeBlock(id: BlockID(id), language: nil, runs: [TextRun(text: t)]))
    }

    func test_sameListItems_takeTheInListGap() {
        // Two items of the SAME list are items of one InstantPage `.list` block, so they take V2's
        // in-list gap. (They used to stack at 0 under the editor's own pre-parity model.) The gap is
        // carried by the LOWER item, so the upper contributes nothing below it.
        let v = canvas([listItem("a", "one"), listItem("b", "two")])
        let a = v.boxes[0] as! BlockBox
        let b = v.boxes[1] as! BlockBox
        XCTAssertEqual(a.bottomInset, 0, accuracy: 0.01)
        XCTAssertEqual(b.topInset,
                       richTextSpacingBetweenBlocks(upper: .paragraph, lower: .paragraph,
                                                    kind: .list, metrics: .default),
                       accuracy: 0.01)
    }

    func test_twoAdjacentCodeBlocks_haveExternalSeparation() {
        // Two code blocks each fill their whole frame, so their internal padding can't separate the two
        // fills — the layout must insert an external gap (base 8 + framed 8) between them.
        let v = canvas([code("c1", "a"), code("c2", "b")])
        let c1 = v.boxes[0], c2 = v.boxes[1]
        XCTAssertEqual(c2.frame.minY - c1.frame.maxY, 16, accuracy: 0.01,
                       "two code-block fills must be separated by the framed neighbor margin")
    }

    func test_codeBlock_adjacentToBody_unchangedSeparation() {
        // A code block next to body text keeps its existing separation (the body reserves the
        // framed margin; no extra bare gap is inserted, since only the body–code pairing applies).
        let v = canvas([body("a", "x"), code("c", "code"), body("b", "y")])
        let a = v.boxes[0], c = v.boxes[1], b = v.boxes[2]
        XCTAssertEqual(c.frame.minY - a.frame.maxY, 0, accuracy: 0.01, "no bare gap between body and code")
        XCTAssertEqual(b.frame.minY - c.frame.maxY, 0, accuracy: 0.01, "no bare gap between code and body")
    }
}
#endif
