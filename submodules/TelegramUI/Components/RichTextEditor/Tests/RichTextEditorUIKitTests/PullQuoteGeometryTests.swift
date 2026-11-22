#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class PullQuoteGeometryTests: XCTestCase {
    func test_pullQuotePill_isCenteredAndHugsContent() {
        let canvas = DocumentCanvasView()
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Hi")]))], width: 320)
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        canvas.layoutIfNeeded()
        let pills = canvas.pullQuotePillRects()
        XCTAssertEqual(pills.count, 1)
        XCTAssertGreaterThan(pills[0].width, 0)
        XCTAssertLessThan(pills[0].width, 320)                                 // hugs content, not full width
        XCTAssertEqual(pills[0].midX, canvas.bounds.width / 2, accuracy: 1.0)  // centered in the content column
    }

    func test_pullQuoteMarks_topLeftAndBottomRight() {
        let canvas = DocumentCanvasView()
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        canvas.simulateParentLayout()
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Hi")]))], width: 320)
        guard let box = canvas.boxes.first as? PullQuoteBox else { return XCTFail("expected a PullQuoteBox") }
        let pill = canvas.pullQuotePillRects()[0]
        let marks = canvas.pullQuoteMarkRects()
        XCTAssertEqual(marks.count, 1)
        XCTAssertEqual(marks[0].open.minX, pill.minX + 6, accuracy: 0.5)          // top-left, inset 6
        XCTAssertEqual(marks[0].open.minY, pill.minY + 6, accuracy: 0.5)
        XCTAssertEqual(marks[0].close.maxX, pill.maxX - 6, accuracy: 0.5)         // bottom-right (x/width unaffected)
        // The close mark's Y now brackets the quote TEXT only (excludes the always-present author region,
        // even the empty "Add author" placeholder) — the pill itself still spans the full box height.
        XCTAssertEqual(marks[0].close.maxY, box.frame.minY + box.quoteOnlyHeight - 6, accuracy: 0.5)
    }

    func test_pullQuoteMarkRects_deriveFrames_fromNonSquareImageSizes() {
        // The RichText/QuoteOpen & QuoteClose assets are 12×10 (non-square). Each mark rect must use its
        // image's own size (not a square), anchored open→top-left / close→bottom-right, inset from the corner.
        let pill = CGRect(x: 100, y: 50, width: 160, height: 90)
        let size = CGSize(width: 12, height: 10)
        let rects = DocumentCanvasView.pullQuoteMarkRects(pills: [pill], inset: 6, openSize: size, closeSize: size)
        XCTAssertEqual(rects.count, 1)
        XCTAssertEqual(rects[0].open, CGRect(x: 106, y: 56, width: 12, height: 10))   // top-left, natural size
        XCTAssertEqual(rects[0].close.width, 12, accuracy: 0.001)                     // image width, not a forced square
        XCTAssertEqual(rects[0].close.height, 10, accuracy: 0.001)                    // image height (non-square)
        XCTAssertEqual(rects[0].close.maxX, pill.maxX - 6, accuracy: 0.001)           // bottom-right anchored
        XCTAssertEqual(rects[0].close.maxY, pill.maxY - 6, accuracy: 0.001)
    }

    func test_pullQuoteStyle_minWidthFloor_andMarkFromImageSize() {
        let canvas = DocumentCanvasView()
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        var style = PullQuoteStyle.default; style.minWidth = 200
        canvas.applyPullQuoteStyle(style)
        canvas.simulateParentLayout()   // install callback before setBlocks so layout fires on content-size notify
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "x")]))], width: 320)
        XCTAssertGreaterThanOrEqual(canvas.pullQuotePillRects()[0].width, 200)   // minWidth floor
        // mark frame size comes from the image's natural size (the generated stub under SwiftPM), not a config knob
        XCTAssertEqual(canvas.pullQuoteMarkRects()[0].open.width,
                       PullQuoteMarksView.openImageNaturalSize.width, accuracy: 0.5)
    }

    func test_pullQuoteCloseMark_excludesAuthorLine() {
        // The close (bottom-right) corner mark must bracket the QUOTE TEXT only — sitting at the last text
        // line's bottom, ABOVE the author line — even though the tinted pill background still spans the
        // full box height (text + author).
        let canvas = DocumentCanvasView()
        canvas.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        canvas.simulateParentLayout()
        canvas.setBlocks([.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Hi")], author: [TextRun(text: "Ada")]))], width: 320)
        guard let box = canvas.boxes.first as? PullQuoteBox else { return XCTFail("expected a PullQuoteBox") }
        XCTAssertGreaterThan(box.frame.maxY, box.frame.minY + box.quoteOnlyHeight,
                             "sanity: the author line adds height beyond the quote-only height")
        let marks = canvas.pullQuoteMarkRects()
        XCTAssertEqual(marks.count, 1)
        let close = marks[0].close
        XCTAssertEqual(close.maxY, box.frame.minY + box.quoteOnlyHeight - canvas.pullQuoteStyle.markInset, accuracy: 0.5)
        XCTAssertLessThan(close.maxY, box.frame.maxY, "close mark sits above the author line, not at the box bottom")
        // The OPEN (top-left) mark is unaffected — still anchored off the box's top edge.
        let open = marks[0].open
        XCTAssertEqual(open.minY, box.frame.minY + canvas.pullQuoteStyle.markInset, accuracy: 0.5)
    }

    func test_pullQuoteUnderlay_cornerRadius_comesFromPullQuoteStyleDefault() {
        // Regression: the pull-quote pill underlay must take its corner radius from PullQuoteStyle (the
        // pull-quote's own look), NOT borrow the block-quote underlay's radius at init — otherwise changing
        // PullQuoteStyle.cornerRadius has no effect in hosts that don't assign a custom pullQuoteStyle (the composer).
        let canvas = DocumentCanvasView()
        XCTAssertEqual(canvas.pullQuoteUnderlay.cornerRadius, PullQuoteStyle.default.cornerRadius, accuracy: 0.001)
    }
}
#endif
