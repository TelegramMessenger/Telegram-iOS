#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class GapCursorTests: XCTestCase {
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 80, height: 50)).image { c in
            UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: 80, height: 50)) } }
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Above")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                              caption: [TextRun(text: "Cap")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    func test_gapPositionIsImageNodeStart_andHasNoTextBox() {
        let v = canvas()
        let img = v.boxes[1]
        XCTAssertNil(v.box(containingGlobal: img.nodeStart))   // gap: not in any text region
        XCTAssertTrue(v.isGapPosition(img.nodeStart))
    }

    func test_tapOnImageArea_landsOnGap() {
        let v = canvas()
        let img = v.boxes[1] as! MediaBlockBox
        let p = CGPoint(x: img.mediaRect().midX, y: img.mediaRect().midY)
        XCTAssertEqual(v.closestGlobalPosition(to: p), img.nodeStart)
    }

    func test_rightFromEndOfParagraph_landsOnGapBeforeImage() {
        let v = canvas()
        let endOfAbove = v.boxes[0].textStart + v.boxes[0].textLength
        let next = (v.position(from: DocumentTextPosition(endOfAbove), in: .right, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(next, v.boxes[1].nodeStart)             // gap before the image
    }

    func test_rightFromGap_landsInCaption() {
        let v = canvas()
        let gap = v.boxes[1].nodeStart
        let next = (v.position(from: DocumentTextPosition(gap), in: .right, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(next, v.boxes[1].textStart)             // into the caption
    }

    func test_leftFromCaptionStart_landsOnGap() {
        let v = canvas()
        let prev = (v.position(from: DocumentTextPosition(v.boxes[1].textStart), in: .left, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(prev, v.boxes[1].nodeStart)        // caption start → gap before the image
    }

    func test_rightFromLastImageCaptionEnd_staysPut() {
        let v = canvas()
        let end = v.boxes[1].textStart + v.boxes[1].textLength
        let next = (v.position(from: DocumentTextPosition(end), in: .right, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(next, end)                         // last block → no overshoot
    }

    func test_leftFromGapBeforeFirstImage_returnsDocStart() {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 80, height: 50)).image { c in
            UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: 80, height: 50)) } }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                              caption: [TextRun(text: "Cap")])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "After")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        let prev = (v.position(from: DocumentTextPosition(v.boxes[0].nodeStart), in: .left, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(prev, 0)                           // image-first: gap → document start, no underflow
    }
}
#endif
