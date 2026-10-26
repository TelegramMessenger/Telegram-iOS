#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// `composerParagraphs()` must RECURSE a `BlockQuoteBox` so that:
///   - an expanded block quote's children are inlined into the flat string (joined by "\n"),
///   - a collapsed block quote contributes exactly ONE flat placeholder char (like `CollapsedQuoteBox`).
///
/// Without the recursion `composerSelectedRange` mis-maps a caret inside a block quote's child
/// (the pull-quote bug class generalised to BlockQuoteBox), and a collapsed block quote contributes
/// zero chars (making `composerSelectedRange` read short).
final class ComposerBlockQuoteSelectionTests: XCTestCase {
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.setBlocks(blocks, width: 320)
        c.simulateParentLayout()
        return c
    }
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }
    private func blockQuote(_ id: String, children: [Block], collapsed: Bool = false) -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children, collapsed: collapsed))
    }

    // MARK: - Expanded block quote — children inlined on the flat axis

    /// [para "ab", blockQuote([child "cd"]), para "ef"]  →  flat "ab\ncd\nef" (total flat length 8).
    /// A caret at the end of the block-quote child ("cd") must map to flat offset 5.
    func test_composerSelectedRange_countsExpandedBlockQuoteInterior() {
        let c = canvas([
            para("a", "ab"),
            blockQuote("q", children: [para("c", "cd")]),
            para("e", "ef")
        ])
        let box = c.boxes[1] as! BlockQuoteBox
        let endOfChild = box.children.boxes[0].leafRegions().first!.globalStart + 2
        c.setSelectionForTesting(anchor: endOfChild, head: endOfChild)
        XCTAssertEqual(c.composerSelectedRange.location, 5,
                       "caret after 'cd' in the quote child should be flat offset 5 (ab=2, \\n=1, cd=2)")
    }

    /// The whole document has flat length 8: "ab"(2) + "\\n"(1) + "cd"(2) + "\\n"(1) + "ef"(2).
    func test_composerSelectedRange_expandedQuote_totalFlatLength() {
        let c = canvas([
            para("a", "ab"),
            blockQuote("q", children: [para("c", "cd")]),
            para("e", "ef")
        ])
        c.selectAllText()
        XCTAssertEqual(c.composerSelectedRange.length, 8,
                       "ab(2)+\\n(1)+cd(2)+\\n(1)+ef(2) = 8 total flat chars")
    }

    /// Caret at the start of the para AFTER the quote maps to flat 6 ("ab\\ncd\\n").
    func test_composerSelectedRange_afterExpandedQuote_paraStartOffset() {
        let c = canvas([
            para("a", "ab"),
            blockQuote("q", children: [para("c", "cd")]),
            para("e", "ef")
        ])
        let afterBox = c.boxes[2]
        c.setSelectionForTesting(anchor: afterBox.textStart, head: afterBox.textStart)
        XCTAssertEqual(c.composerSelectedRange.location, 6,
                       "start of 'ef' (after the block quote) is flat offset 6")
    }

    // MARK: - Collapsed block quote — contributes exactly ONE flat char

    /// A single collapsed block quote must occupy exactly 1 flat char.
    func test_composerSelectedRange_collapsedBlockQuote_oneFlatChar() {
        let c = canvas([blockQuote("q", children: [para("c", "cd")], collapsed: true)])
        c.setSelectionForTesting(anchor: c.documentSizeValue, head: c.documentSizeValue)
        XCTAssertEqual(c.composerSelectedRange.location, 1,
                       "collapsed block quote contributes exactly 1 flat char (like CollapsedQuoteBox)")
    }

    /// [para "ab", collapsed-bq, para "ef"]  →  flat "ab\\n \\nef" = 7 chars.
    func test_composerSelectedRange_collapsedBlockQuote_contributesOneFlatChar_withNeighbors() {
        let c = canvas([
            para("a", "ab"),
            blockQuote("q", children: [para("c", "cd")], collapsed: true),
            para("e", "ef")
        ])
        c.selectAllText()
        XCTAssertEqual(c.composerSelectedRange.length, 7,
                       "ab(2)+\\n(1)+collapsed(1)+\\n(1)+ef(2) = 7 flat chars")
    }

    // MARK: - Author region is excluded from the flat composer axis (Task 5)

    /// A block quote WITH an author line must contribute only its body to the composer flat axis
    /// ("ab\ncd\nef" = 8) — the author ("Ada") is off-axis, exactly like a media caption.
    func test_composerFlatRange_excludesBlockQuoteAuthor() {
        let c = canvas([
            para("a", "ab"),
            .blockQuote(BlockQuote(id: BlockID("q"), children: [para("c", "cd")],
                                   collapsed: false, author: [TextRun(text: "Ada")])),
            para("e", "ef")
        ])
        c.selectAllText()
        XCTAssertEqual(c.composerSelectedRange.length, 8,
                       "the block-quote author must contribute nothing to the composer flat axis")
    }

    /// A pull quote WITH an author line likewise contributes only its pull text ("ab\ncd\nef" = 8).
    func test_composerFlatRange_excludesPullQuoteAuthor() {
        let c = canvas([
            para("a", "ab"),
            .pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "cd")], author: [TextRun(text: "Ada")])),
            para("e", "ef")
        ])
        c.selectAllText()
        XCTAssertEqual(c.composerSelectedRange.length, 8,
                       "the pull-quote author must contribute nothing to the composer flat axis")
    }

    // MARK: - Nested (expanded inside expanded)

    /// outer[para "a", inner[para "b"]] → flat "a\\nb" (total 3).
    func test_composerSelectedRange_nestedExpandedQuotes_inlined() {
        let c = canvas([
            blockQuote("outer", children: [
                para("a", "a"),
                blockQuote("inner", children: [para("b", "b")])
            ])
        ])
        c.selectAllText()
        XCTAssertEqual(c.composerSelectedRange.length, 3,
                       "a(1)+\\n(1)+b(1) = 3 flat chars for nested expanded quotes")
    }
}
#endif
