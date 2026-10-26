#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class BlockStackTests: XCTestCase {
    func test_recompute_assignsNodeStartsAndReturnsTokenSize() {
        let mapper = AttributedStringMapper()
        let stack = BlockStack(boxes: [
            BlockBox(paragraph: ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "One")]), mapper: mapper, width: 300),
            BlockBox(paragraph: ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Two")]), mapper: mapper, width: 300),
        ])
        let size = stack.recompute(baseOffset: 0)
        // "One"(3)+2 + "Two"(3)+2 = 10; globalStarts 1 and 6
        XCTAssertEqual(size, 10)
        XCTAssertEqual(stack.boxes[0].nodeStart, 1)
        XCTAssertEqual(stack.boxes[1].nodeStart, 6)
    }

    func test_recompute_withBaseOffset_shiftsGlobalStarts() {
        let mapper = AttributedStringMapper()
        let stack = BlockStack(boxes: [
            BlockBox(paragraph: ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "One")]), mapper: mapper, width: 300),
        ])
        _ = stack.recompute(baseOffset: 100)
        XCTAssertEqual(stack.boxes[0].nodeStart, 101)     // baseOffset + 1
        XCTAssertEqual(stack.boxes[0].leafRegions()[0].globalStart, 101)
    }

    func test_layout_stacksVerticallyAndReturnsHeight() {
        let mapper = AttributedStringMapper()
        let stack = BlockStack(boxes: [
            BlockBox(paragraph: ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "One")]), mapper: mapper, width: 300),
            BlockBox(paragraph: ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Two")]), mapper: mapper, width: 300),
        ])
        let h = stack.layout(origin: CGPoint(x: 10, y: 20), width: 300)
        XCTAssertEqual(stack.boxes[0].frame.minX, 10, accuracy: 0.5)
        XCTAssertEqual(stack.boxes[0].frame.minY, 20, accuracy: 0.5)
        XCTAssertEqual(stack.boxes[1].frame.minY, stack.boxes[0].frame.maxY, accuracy: 0.5)
        XCTAssertGreaterThan(h, 0)
    }

    /// The intra-paragraph advance between two adjacent lines of a single body paragraph — the target
    /// spacing for consecutive list items.
    private func intraParagraphLineAdvance() -> CGFloat {
        let ref = BlockBox(paragraph: ParagraphBlock(id: BlockID("ref"), runs: [TextRun(text: "AAAA\nBBBB")]),
                           mapper: AttributedStringMapper(), width: 300)
        ref.setWidth(300)
        return ref.layout.caretRect(atOffset: 5).minY - ref.layout.caretRect(atOffset: 0).minY
    }

    private func listBox(_ id: String) -> BlockBox {
        BlockBox(paragraph: ParagraphBlock(id: BlockID(id), list: ListMembership(marker: .bullet),
                                           runs: [TextRun(text: "Item")]),
                 mapper: AttributedStringMapper(), width: 300)
    }

    /// Two adjacent list items are ITEMS of one InstantPage `.list` block, so they take V2's in-list
    /// gap — not the paragraph-to-paragraph 1pt rule, and not the old "tight as intra-paragraph lines".
    func test_consecutiveListItems_takeTheInListGap() {
        let stack = BlockStack(boxes: [listBox("a"), listBox("b")])
        stack.layout(origin: .zero, width: 300)
        let expected = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .paragraph,
                                                    kind: .list, metrics: .default)
        XCTAssertEqual((stack.boxes[1] as! BlockBox).topInset, expected, accuracy: 0.01)
        // Frames stay contiguous (no overlap) on both engines — the core stacking invariant.
        XCTAssertEqual(stack.boxes[1].frame.minY, stack.boxes[0].frame.maxY, accuracy: 0.5)
    }

    /// Two body paragraphs take V2's minimum separation (1pt) — they are held apart by their own line
    /// boxes, so the rhythm adds only a hairline. (Was 0 under the editor's own pre-parity model.)
    func test_consecutiveBodyBlocks_takeTheMinimumSeparation() {
        let mapper = AttributedStringMapper()
        let stack = BlockStack(boxes: [
            BlockBox(paragraph: ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "One")]), mapper: mapper, width: 300),
            BlockBox(paragraph: ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Two")]), mapper: mapper, width: 300),
        ])
        stack.layout(origin: .zero, width: 300)
        let a = stack.boxes[0] as! BlockBox, b = stack.boxes[1] as! BlockBox
        // The whitespace between A's last glyph row and B's first: the gap is carried by B's topInset, and
        // A's own height is the V2-corrected text height, so the two agree.
        let gap = b.textOrigin.y - (a.textOrigin.y + a.layout.correctedBoundingHeight)
        XCTAssertEqual(gap, 1.0, accuracy: 0.01)
        XCTAssertEqual(b.topInset, 1.0, accuracy: 0.01)
    }

    /// A code block (`.preformatted`) takes V2's fall-through rule against a paragraph:
    /// padding + base + padding. A framed block cannot own an external inset, so the gap above it is
    /// carried by the paragraph ABOVE (its `bottomInset`) — which is also what keeps the canvas
    /// contiguous for hit-testing and arrow-key escape.
    func test_codeBlockNeighbors_takeTheV2FallThroughGap() {
        let mapper = AttributedStringMapper()
        func body(_ id: String) -> BlockBox {
            BlockBox(paragraph: ParagraphBlock(id: BlockID(id), runs: [TextRun(text: "x")]), mapper: mapper, width: 300)
        }
        let code = CodeBlockBox(code: CodeBlock(id: BlockID("c"), runs: [TextRun(text: "let x = 1")]), mapper: mapper, width: 300)
        let above = body("above"), below = body("below")
        BlockStack(boxes: [above, code, below]).layout(origin: .zero, width: 300)
        let expected = richTextSpacingBetweenBlocks(upper: .paragraph, lower: .preformatted,
                                                    kind: .topLevel, metrics: .default)
        XCTAssertEqual(above.bottomInset, expected, accuracy: 0.01, "the paragraph above owns the gap")
        XCTAssertEqual(below.topInset,
                       richTextSpacingBetweenBlocks(upper: .preformatted, lower: .paragraph,
                                                    kind: .topLevel, metrics: .default),
                       accuracy: 0.01)
        // Far side: the sequence's leading edge.
        XCTAssertEqual(above.topInset,
                       richTextSpacingBetweenBlocks(upper: nil, lower: .paragraph, kind: .topLevel, metrics: .default),
                       accuracy: 0.01, "far side is the document edge gap")
    }

    /// Same shape for a table, whose bounded grid takes the same fall-through rule.
    func test_tableNeighbors_takeTheV2FallThroughGap() {
        let mapper = AttributedStringMapper()
        func body(_ id: String) -> BlockBox {
            BlockBox(paragraph: ParagraphBlock(id: BlockID(id), runs: [TextRun(text: "x")]), mapper: mapper, width: 300)
        }
        let table = TableBlockBox(table: TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [
                Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap")))]),
                Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp")))])])]),
            mapper: mapper, width: 300)
        let above = body("above"), below = body("below")
        BlockStack(boxes: [above, table, below]).layout(origin: .zero, width: 300)
        XCTAssertEqual(above.bottomInset,
                       richTextSpacingBetweenBlocks(upper: .paragraph, lower: .table, kind: .topLevel, metrics: .default),
                       accuracy: 0.01, "the paragraph above owns the gap")
        XCTAssertEqual(below.topInset,
                       richTextSpacingBetweenBlocks(upper: .table, lower: .paragraph, kind: .topLevel, metrics: .default),
                       accuracy: 0.01)
    }

    /// Media takes V2's own rules rather than the editor's former dedicated 6pt media inset. A bare
    /// image next to text gets `max(1, paddings + 1)`; the far sides get the document edge gaps.
    /// (`verticalInsetBase` is not consulted at all in the V2 model — the old test proved the media
    /// inset was decoupled from that base, a distinction the rule table no longer has.)
    func test_blockToMediaBoundary_usesTheV2MediaRules() {
        let mapper = AttributedStringMapper()
        func body(_ id: String) -> BlockBox {
            BlockBox(paragraph: ParagraphBlock(id: BlockID(id), runs: [TextRun(text: "x")]), mapper: mapper, width: 300)
        }
        let media = MediaBlockBox(media: MediaBlock(id: BlockID("m"), mediaID: "x",
                                                    naturalSize: Size2D(width: 100, height: 50), caption: []),
                                  mapper: mapper, width: 300)
        let heading = BlockBox(paragraph: ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "H")]),
                               mapper: mapper, width: 300)
        let below = body("below")
        let stack = BlockStack(boxes: [heading, media, below])
        stack.layout(origin: .zero, width: 300)
        let image = RichTextBlockSpacingKind.media(hasCredit: false, isRawMedia: true)
        XCTAssertEqual(heading.bottomInset,
                       richTextSpacingBetweenBlocks(upper: .heading, lower: image, kind: .topLevel, metrics: .default),
                       accuracy: 0.01, "the heading above owns the gap to the image")
        XCTAssertEqual(below.topInset,
                       richTextSpacingBetweenBlocks(upper: image, lower: .paragraph, kind: .topLevel, metrics: .default),
                       accuracy: 0.01)
        XCTAssertEqual(heading.topInset,
                       richTextSpacingBetweenBlocks(upper: nil, lower: .heading, kind: .topLevel, metrics: .default),
                       accuracy: 0.01, "far side is the document edge gap")
        XCTAssertEqual(below.bottomInset,
                       richTextSpacingBetweenBlocks(upper: .paragraph, lower: nil, kind: .topLevel, metrics: .default),
                       accuracy: 0.01, "far side is the document edge gap")
    }

    /// The list-run -> body boundary takes V2's list/paragraph rule (the sum of both paddings), not the
    /// editor's former "collapses to nothing".
    func test_listItemToParagraphBoundary_takesTheListToParagraphGap() {
        let mapper = AttributedStringMapper()
        let stack = BlockStack(boxes: [
            listBox("a"),
            BlockBox(paragraph: ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Plain")]), mapper: mapper, width: 300),
        ])
        stack.layout(origin: .zero, width: 300)
        let b = stack.boxes[1] as! BlockBox
        XCTAssertEqual(b.topInset,
                       richTextSpacingBetweenBlocks(upper: .list, lower: .paragraph, kind: .topLevel, metrics: .default),
                       accuracy: 0.01)
    }
}
#endif
