#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// `contentMargins` is interior padding that's PART of the content (distinct from the host's scroll
/// insets): the text lays out inset by it (offset + wrapping narrower), the content height grows by
/// top+bottom, and the margin area still hit-tests to a text position (it is interactable).
final class CanvasContentMarginsTests: XCTestCase {
    private func canvas(_ texts: [String]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(texts.map { .paragraph(ParagraphBlock(id: BlockID($0), runs: [TextRun(text: $0)])) }, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 600)
        v.layoutIfNeeded()
        return v
    }

    func test_default_isZero() {
        XCTAssertEqual(canvas(["Hello"]).contentMargins, .zero)
    }

    func test_leftMargin_offsetsFirstBlock() {
        let v = canvas(["Hello"])
        let baseMinX = v.boxes[0].frame.minX
        v.contentMargins = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 0)
        v.layoutContent()
        XCTAssertEqual(v.boxes[0].frame.minX, baseMinX + 24, accuracy: 0.5,
                       "a left margin offsets the content rightward (on top of the built-in page margin)")
    }

    func test_horizontalMargins_narrowContentWidth() {
        let v = canvas(["Hello"])
        let baseWidth = v.boxes[0].frame.width
        v.contentMargins = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 16)
        v.layoutContent()
        XCTAssertEqual(v.boxes[0].frame.width, baseWidth - 24 - 16, accuracy: 0.5,
                       "left+right margins narrow the text content width")
    }

    func test_topMargin_offsetsFirstBlockDown() {
        let v = canvas(["Hello"])
        let baseMinY = v.boxes[0].frame.minY
        v.contentMargins = UIEdgeInsets(top: 30, left: 0, bottom: 0, right: 0)
        v.layoutContent()
        XCTAssertEqual(v.boxes[0].frame.minY, baseMinY + 30, accuracy: 0.5,
                       "a top margin pushes the content down")
    }

    func test_verticalMargins_increaseIntrinsicHeight() {
        let v = canvas(["Hello"])
        let baseH = v.intrinsicContentSize.height
        v.contentMargins = UIEdgeInsets(top: 30, left: 0, bottom: 20, right: 0)
        XCTAssertEqual(v.intrinsicContentSize.height, baseH + 50, accuracy: 0.5,
                       "top+bottom margins grow the content height")
    }

    func test_tapInTopMargin_placesCaret_isInteractable() {
        let v = canvas(["Hello"])
        v.contentMargins = UIEdgeInsets(top: 40, left: 0, bottom: 0, right: 0)
        v.layoutContent()
        v.performSingleTap(at: CGPoint(x: 20, y: 10))   // inside the 40pt top margin, above the text
        XCTAssertEqual(v.head, v.boxes[0].textStart,
                       "a tap in the margin maps to the nearest text position (margins are interactable)")
    }

    // MARK: Façade

    func test_facade_marginsIncreaseMeasuredContentHeight() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Line A")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Line B")])),
            .paragraph(ParagraphBlock(id: BlockID("c"), runs: [TextRun(text: "Line C")])),
        ])
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)   // settle the re-flow first
        let base = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        XCTAssertGreaterThan(base, 44, "precondition: content is already taller than the 44pt floor")
        let withMargins = editor.update(size: CGSize(width: 320, height: 400), insets: .zero,
                                        contentMargins: UIEdgeInsets(top: 30, left: 0, bottom: 20, right: 0))
        XCTAssertEqual(withMargins, base + 50, accuracy: 0.5,
                       "top+bottom margins passed to update() add to the measured content height")
    }

    /// The reason margins go through `update` (not a side-effecting property): applying a layout input must
    /// not synchronously fire `onChange`, or a host that re-layouts in `onChange` would recurse.
    func test_facade_updateWithMargins_doesNotSynchronouslyFireOnChange() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")]))])
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        var fired = false
        editor.onChange = { fired = true }
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: .zero,
                          contentMargins: UIEdgeInsets(top: 20, left: 10, bottom: 20, right: 10))
        XCTAssertFalse(fired, "update() applying margins must not synchronously fire onChange (else the host recurses)")
    }
}
#endif
