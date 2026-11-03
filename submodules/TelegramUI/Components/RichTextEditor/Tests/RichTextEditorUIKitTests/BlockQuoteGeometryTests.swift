#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class BlockQuoteGeometryTests: XCTestCase {
    // Follow the QuoteVerticalInsetTests helper pattern: setBlocks then set frame + layoutIfNeeded so
    // BlockStack.layout has run and all box.frame values are populated.
    private func canvas(_ blocks: [Block], width: CGFloat = 320) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: width)
        c.frame = CGRect(x: 0, y: 0, width: width, height: 600)
        c.layoutIfNeeded()
        return c
    }

    /// Two adjacent top-level block quotes must NOT sit flush — there must be a vertical gap between
    /// their frames (separation gap via `isFramedAtom` + external-gap insertion in `BlockStack.layout`).
    func test_twoAdjacentBlockQuotes_haveSeparationGap() {
        let a = BlockQuote(id: BlockID("a"), children: [.paragraph(ParagraphBlock(id: BlockID("pa"), runs: [TextRun(text:"a")]))], collapsed:false)
        let b = BlockQuote(id: BlockID("b"), children: [.paragraph(ParagraphBlock(id: BlockID("pb"), runs: [TextRun(text:"b")]))], collapsed:false)
        let c = canvas([.blockQuote(a), .blockQuote(b)])
        let boxA = c.boxes[0], boxB = c.boxes[1]
        XCTAssertGreaterThan(boxB.frame.minY - boxA.frame.maxY, 0,
                             "Two adjacent BlockQuoteBoxes must have a positive separation gap, not sit flush")
    }

    /// Bug 2 regression: the expanded quote's first child's content-top must equal `box.frame.minY +
    /// box.topInset` — the same Y the collapsed preview starts at. Before the fix,
    /// `stack.verticalInsetBase == 8` added an extra 8pt top gap to the first child (via
    /// `facingInset(toward: nil) == base`), so expanded content sat 8pt lower than the collapsed preview.
    func test_expandedFirstChild_contentTop_equalsTopInset() {
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "content")]))
        ], collapsed: false)
        let c = canvas([.blockQuote(bq)])
        let box = c.boxes[0] as! BlockQuoteBox
        let childBox = box.children.boxes[0]
        // The child's frame.minY is its top relative to the canvas; box.frame.minY + box.topInset
        // is where the collapsed preview text would start.
        let expectedContentTop = box.frame.minY + box.topInset
        XCTAssertEqual(childBox.frame.minY, expectedContentTop, accuracy: 0.5,
                       "Expanded first child's top must align with topInset (== collapsed preview top). " +
                       "Extra gap means verticalInsetBase is non-zero.")
    }

    /// Collapsed vs expanded height parity for a single-line body-paragraph quote.
    /// Before the original fix, `previewAttributes` used a plain NSMutableParagraphStyle (no
    /// lineHeightMultiple), making the collapsed box ~2pt shorter than the expanded one for the same content.
    ///
    /// Task 4 update: the expanded box now ALSO reserves an always-present author-line region below its
    /// child stack (bold caption, showing an "Add author" placeholder when empty) — the collapsed folded
    /// preview never shows one (`DocumentTree` maps a collapsed quote to a caption-less atom, entirely off
    /// the position axis; collapsing the quote loses the author's ON-CANVAS rendering, not the underlying
    /// model field). So the two TOTAL heights are no longer expected to be equal. The original invariant
    /// this test guarded — the child stack's CONTENT height (topInset + children + bottomInset) matches the
    /// collapsed preview's height for identical single-line body content — still holds; verify it directly,
    /// independent of the (now additive) author-line reservation, and separately assert the new inequality.
    func test_collapsedVsExpanded_singleLineBodyChild_heightParity() {
        let text = "Hello world"
        let paraBlock = ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: text)])
        let expandedBQ = BlockQuote(id: BlockID("bq-e"), children: [.paragraph(paraBlock)], collapsed: false)
        let collapsedBQ = BlockQuote(id: BlockID("bq-c"), children: [.paragraph(paraBlock)], collapsed: true)
        let width: CGFloat = 320
        let expandedCanvas = canvas([.blockQuote(expandedBQ)], width: width)
        let collapsedCanvas = canvas([.blockQuote(collapsedBQ)], width: width)
        let expandedBox = expandedCanvas.boxes[0] as! BlockQuoteBox
        let collapsedHeight = collapsedCanvas.boxes[0].height
        let innerWidth = max(width - expandedBox.quoteStyle.leadingInset - expandedBox.quoteStyle.trailingInset, 1)
        let contentHeight = expandedBox.topInset + expandedBox.children.measuredHeight(forWidth: innerWidth) + expandedBox.bottomInset
        XCTAssertEqual(contentHeight, collapsedHeight, accuracy: 0.5,
                       "Collapsed and expanded BlockQuoteBox must have equal CONTENT height (excluding the " +
                       "author-line reservation) for identical single-line body content. " +
                       "Content: \(contentHeight), Collapsed: \(collapsedHeight)")
        XCTAssertGreaterThan(expandedBox.height, collapsedHeight,
                             "Expanded is now taller than collapsed by the always-reserved (placeholder) author-line region")
    }

    /// A nested block quote must receive its OWN fill rect from the recursive `blockQuoteFillRects()`
    /// collector, not just the outer fill.
    func test_nestedBlockQuote_fillIsEmitted() {
        let inner = BlockQuote(id: BlockID("in"), children: [.paragraph(ParagraphBlock(id: BlockID("ip"), runs:[TextRun(text:"z")]))], collapsed:false)
        let outer = BlockQuote(id: BlockID("out"), children: [.blockQuote(inner)], collapsed:false)
        let c = canvas([.blockQuote(outer)])
        let fills = c.blockQuoteFillRects()
        XCTAssertGreaterThanOrEqual(fills.count, 2,
                                    "blockQuoteFillRects() must emit at least one fill per BlockQuoteBox level (outer + inner)")
        // The outer fill must be larger than the inner fill (the inner is nested inside).
        if fills.count >= 2 {
            let outerFill = fills[0], innerFill = fills[1]
            XCTAssertGreaterThan(outerFill.height, innerFill.height,
                                 "Outer fill should be taller than the nested inner fill")
        }
    }
}
#endif
