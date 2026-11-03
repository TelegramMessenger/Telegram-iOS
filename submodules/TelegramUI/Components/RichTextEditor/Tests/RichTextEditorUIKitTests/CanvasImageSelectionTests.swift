#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasImageSelectionTests: XCTestCase {
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 80, height: 50)).image { c in
            UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: 80, height: 50)) } }
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Above")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                              caption: [TextRun(text: "Caption")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Below")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }

    func test_selectionFlowsThroughCaption() {
        let v = canvas()
        let imgBox = v.boxes[1]
        // From inside "Above" through the caption into "Below" → rects in all three blocks.
        let rects = v.selectionRects(globalFrom: v.boxes[0].textStart + 2,
                                     globalTo: v.boxes[2].textStart + 2)
        func count(in box: CanvasBlock) -> Int { rects.filter { box.frame.intersects($0) }.count }
        XCTAssertGreaterThan(count(in: v.boxes[0]), 0)
        XCTAssertGreaterThan(count(in: imgBox), 0)        // caption rects
        XCTAssertGreaterThan(count(in: v.boxes[2]), 0)
    }

    func test_caretInCaption_isBelowImage() {
        let v = canvas()
        let imgBox = v.boxes[1] as! MediaBlockBox
        let caret = v.caretRect(for: DocumentTextPosition(imgBox.textStart))
        XCTAssertGreaterThan(caret.minY, imgBox.mediaRect().minY)   // caption caret sits below the image
    }

    func test_caretAtImageGap_isVerticalBarAtImageLeadingEdge() {
        let v = canvas()
        let imgBox = v.boxes[1] as! MediaBlockBox
        // The gap before the image atom is a real caret position; we must report a drawable rect so
        // UITextSelectionDisplayInteraction renders the native caret there (not .zero, which is invisible).
        let caret = v.caretRect(for: DocumentTextPosition(imgBox.nodeStart))
        let img = imgBox.mediaRect()
        XCTAssertFalse(caret.isEmpty, "gap caret must be a drawable rect, not .zero")
        XCTAssertEqual(caret.minX, img.minX, accuracy: 0.5, "vertical caret sits at the image's leading edge")
        XCTAssertEqual(caret.height, img.height, accuracy: 0.5, "caret spans the image height")
    }

    func test_typingInCaption_editsCaptionText() {
        let v = canvas()
        let imgBox = v.boxes[1] as! MediaBlockBox
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(imgBox.textStart + 7),
                                                DocumentTextPosition(imgBox.textStart + 7)) // end of "Caption"
        v.insertText("!")
        guard case .media(let out) = v.boxes[1].currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.caption.map(\.text).joined(), "Caption!")
    }
}
#endif
