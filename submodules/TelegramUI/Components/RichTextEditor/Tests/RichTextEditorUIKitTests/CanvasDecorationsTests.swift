#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasDecorationsTests: XCTestCase {
    private func canvas(_ blocks: [Block], width: CGFloat = 390) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        return v
    }

    /// A code block paints its OWN band and is deliberately absent from the quote underlay's feed.
    /// It used to be that feed's only producer — which is why a code block nested in a quote or a
    /// table cell had no fill at all: the feed walked top-level boxes only.
    func test_codeBlock_paintsItsOwnBandAndFeedsNoQuoteUnderlay() {
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Body")])),
            .code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "let x = 1")])),
        ])
        XCTAssertTrue(v.blockQuoteFillRects().isEmpty, "no quotes ⇒ nothing for the quote underlay")
    }

    /// The compact-composer shape: NO bleed (the band spans exactly the text column, so it cannot
    /// spill past the input field) and the code indented WITHIN it instead — the inward counterpart
    /// of the renderer's outward bleed.
    func test_codeBlock_compactHostIndentsTheTextInsteadOfBleedingTheBand() {
        let width: CGFloat = 300
        let v = DocumentCanvasView()
        v.applyCodeStyle(CodeStyle(horizontalBleed: 0, horizontalInset: 8, cornerRadius: 4))
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Body")])),
            .code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "let x = 1")])),
        ], width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()

        let code = v.boxes.first(where: { $0 is CodeBlockBox }) as! CodeBlockBox
        let body = v.boxes.first(where: { $0 is BlockBox })!

        XCTAssertEqual(code.blockViewFrame, code.frame, "no bleed ⇒ the band is exactly the text column")
        XCTAssertEqual(code.blockViewFrame.minX, body.frame.minX, accuracy: 0.5,
                       "band's leading edge aligns with the paragraph column")
        XCTAssertEqual(code.textOrigin.x, code.frame.minX + 8, accuracy: 0.5,
                       "code text is indented inside the band")
        XCTAssertEqual(v.mapper.styleSheet.codeCornerRadius, 4, accuracy: 0.01)
    }

    /// The indent narrows the text MEASURE too, not just its origin — otherwise the code would wrap
    /// at the band's full width and overrun its trailing edge.
    func test_codeBlock_horizontalInsetNarrowsTheTextMeasure() {
        let width: CGFloat = 300
        let plain = DocumentCanvasView()
        let indented = DocumentCanvasView()
        indented.applyCodeStyle(CodeStyle(horizontalInset: 8))
        for v in [plain, indented] {
            v.setBlocks([.code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "let x = 1")]))], width: width)
            v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        }
        let a = plain.boxes.first as! CodeBlockBox
        let b = indented.boxes.first as! CodeBlockBox

        XCTAssertEqual(b.layout.containerWidth, a.layout.containerWidth - 16, accuracy: 0.5,
                       "the measure loses the inset on BOTH sides")
    }

    /// The band runs edge to edge across the canvas while the code TEXT stays in the paragraph
    /// column — the whole point of the redesign, and the only place the root bleed wiring is
    /// exercised end to end.
    func test_codeBlock_bandSpansTheCanvasWhileTextKeepsTheParagraphColumn() {
        let width: CGFloat = 300
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Body")])),
            .code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "let x = 1")])),
        ], width: width)
        let code = v.boxes.first(where: { $0 is CodeBlockBox }) as! CodeBlockBox
        let body = v.boxes.first(where: { $0 is BlockBox })!

        XCTAssertEqual(code.blockViewFrame.minX, 0, accuracy: 0.5, "band reaches the canvas leading edge")
        XCTAssertEqual(code.blockViewFrame.maxX, width, accuracy: 0.5, "band reaches the canvas trailing edge")
        XCTAssertEqual(code.textOrigin.x, body.frame.minX, accuracy: 0.5, "code text sits in the paragraph column")
    }

    func test_typeSomethingPlaceholder_onlyWhenSoleBlock() {
        // A single empty body paragraph (an otherwise-empty document): the "Type something…" placeholder shows.
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("a"), style: .body, runs: []))])
        let draws = v.placeholderDraws()
        XCTAssertEqual(draws.map(\.text), ["Type something…"], "sole empty body block shows the placeholder")
        XCTAssertEqual(draws.first?.origin.y ?? -1, v.boxes[0].textOrigin.y, accuracy: 8.0)
    }

    func test_typeSomethingPlaceholder_notShown_whenOtherBlocksExist() {
        // As soon as a second block exists, no "Type something…" placeholder — regardless of where the empty
        // body sits or whether the other block has content.
        let twoEmptyBodies = canvas([
            .paragraph(ParagraphBlock(id: BlockID("a"), style: .body, runs: [])),
            .paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [])),
        ])
        XCTAssertTrue(twoEmptyBodies.placeholderDraws().isEmpty, "two blocks ⇒ no placeholder")

        let emptyBodyThenHeading = canvas([
            .paragraph(ParagraphBlock(id: BlockID("a"), style: .body, runs: [])),
            .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Hi")])),
        ])
        XCTAssertTrue(emptyBodyThenHeading.placeholderDraws().isEmpty,
                      "an empty body is not alone ⇒ no placeholder")
    }

    func test_typeSomethingPlaceholder_notShown_whenSoleBlockIsNotBody() {
        // The document's only block is an empty heading — the gate is sole-block + body, so no placeholder.
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: []))])
        XCTAssertTrue(v.placeholderDraws().isEmpty, "a non-body sole block shows no body placeholder")
    }

    func test_placeholder_baselineMatchesRealFirstLineBaseline() {
        // The placeholder must sit on the paragraph's real first-line baseline (where the first typed glyph
        // lands), not float above OR below it. Under the pinned-box model that baseline is the font's
        // ascender measured from the text origin, so the placeholder draws at `textOrigin` with NO shift.
        // (Under the previous `lineHeightMultiple` model this needed half the multiple's extra leading.)
        // Asserted against a REAL typed paragraph's baseline rather than a formula, so the two cannot drift.
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: []))])
        let box = v.boxes[0] as! BlockBox
        let draw = v.placeholderDraws().first!
        let font = StyleSheet.default.font(for: .body, attributes: .plain)
        XCTAssertEqual(draw.origin.y, box.textOrigin.y, accuracy: 0.5)
        XCTAssertEqual(draw.origin.x, box.textOrigin.x, accuracy: 0.5)            // horizontal unchanged

        // The ghost's baseline (origin + ascender) is where a typed glyph's baseline actually lands.
        let typed = canvas([.paragraph(ParagraphBlock(id: BlockID("t"), style: .body,
                                                     runs: [TextRun(text: "A")]))])
        let typedBox = typed.boxes[0] as! BlockBox
        let typedBaseline = typedBox.textOrigin.y + (typedBox.layout.firstLineBaselineFromTop ?? -1)
        XCTAssertEqual(draw.origin.y + font.ascender - box.textOrigin.y,
                       typedBaseline - typedBox.textOrigin.y, accuracy: 0.5,
                       "the ghost must share the baseline the first typed glyph gets")
    }

    func test_emptyParagraph_caretRectSpansTheLineHeight() {
        // An empty line's caret must span a REAL line, not the fixed 20pt fallback BlockLayout returns
        // when there's no laid-out fragment — so it aligns with the placeholder and with a typed line.
        // Pinned to V2's one-line height exactly: at body size that is 20.29pt, which a loose
        // "greater than 20.5" check could not distinguish from the 20pt fallback it is guarding against.
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: []))])
        let box = v.boxes[0] as! BlockBox
        let caret = v.caretRect(for: DocumentTextPosition(box.textStart))
        let font = StyleSheet.default.font(for: .body, attributes: .plain)
        let factor = StyleSheet.default.metrics.body.lineSpacingFactor
        XCTAssertEqual(caret.height,
                       RichTextRenderMetrics.textHeight(font, factor: factor, lineCount: 1),
                       accuracy: 0.01)
        XCTAssertNotEqual(caret.height, 20.0, accuracy: 0.05, "not the fixed-20 fallback")
    }

    func test_placeholder_listItem_isInsetByHeadIndent() {
        // An empty list item shows a list-specific hint; it must be inset to the list's text column
        // (aligned with where typed text appears, past the marker), not drawn at the page margin.
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("li"), style: .body,
                                                  list: ListMembership(marker: .bullet), runs: []))])
        let box = v.boxes[0] as! BlockBox
        let draw = v.placeholderDraws().first { $0.text == "Press return to end the list" }
        XCTAssertNotNil(draw)
        XCTAssertEqual(draw!.origin.x, box.textOrigin.x + StyleSheet.listMarkerSpacing, accuracy: 0.5)
    }

    func test_placeholder_emptyListItem_level0_saysEndTheList() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("li"), style: .body,
                                                  list: ListMembership(marker: .bullet), runs: []))])
        XCTAssertEqual(v.placeholderDraws().first?.text, "Press return to end the list")
    }

    func test_placeholder_emptyNestedListItem_saysOutdent() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("li"), style: .body,
                                                  list: ListMembership(marker: .bullet, level: 1), runs: []))])
        XCTAssertEqual(v.placeholderDraws().first?.text, "Press return to outdent")
    }

    func test_placeholder_emptyOrderedListItem_alsoSaysEndTheList() {
        // The hint is about the list, not the marker style — ordered items get it too.
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("li"), style: .body,
                                                  list: ListMembership(marker: .ordered), runs: []))])
        XCTAssertEqual(v.placeholderDraws().first?.text, "Press return to end the list")
    }

    func test_placeholders_noneWhenNonEmpty() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("b"), style: .body, runs: [TextRun(text: "Hi")]))])
        XCTAssertTrue(v.placeholderDraws().isEmpty)
    }

    func test_placeholder_isDrawnByBox_onlyForTopLevelEmptyParagraph() {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("t"), style: .body, runs: [])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200); v.layoutIfNeeded()
        let box = v.boxes[0] as! BlockBox
        XCTAssertTrue(box.isTopLevelBlock, "top-level boxes are flagged during layout")
        let d = box.placeholderDraw()!
        let seam = v.placeholderDraws().first!
        XCTAssertEqual(d.text, "Type something…")
        XCTAssertEqual(d.origin.x, seam.origin.x, accuracy: 0.01)
        XCTAssertEqual(d.origin.y, seam.origin.y, accuracy: 0.01)
    }

    func test_emptyCellParagraph_drawsNoPlaceholder() {
        // An empty BODY paragraph inside a table cell would show "Type something…" if it were top-level;
        // the isTopLevelBlock gate must keep cells placeholder-free (parity with pre-refactor behavior).
        let v = DocumentCanvasView()
        let cellPara = ParagraphBlock(id: BlockID("cp"), style: .body, runs: [])
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [Cell(id: BlockID("c0"), blocks: [.paragraph(cellPara)])])]))],
            width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 200); v.layoutIfNeeded()
        // Find the cell's BlockBox via the table's leaf regions / cell stacks.
        let table = v.boxes[0] as! TableBlockBox
        let cellBox = table.cellStack(containing: table.cellTextStart(row: 0, column: 0)!)!.box as! BlockBox
        XCTAssertFalse(cellBox.isTopLevelBlock, "cell paragraphs are never flagged top-level")
        XCTAssertNil(cellBox.placeholderDraw(), "cell empty paragraph draws no placeholder")
        XCTAssertTrue(v.placeholderDraws().isEmpty, "the canvas placeholder seam excludes cell paragraphs")
    }
}
#endif
