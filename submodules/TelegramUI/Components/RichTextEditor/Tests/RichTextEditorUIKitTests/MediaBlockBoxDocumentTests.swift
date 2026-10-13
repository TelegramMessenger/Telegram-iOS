#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class MediaBlockBoxDocumentTests: XCTestCase {
    private func documentBlock() -> MediaBlock {
        MediaBlock(id: BlockID("doc"), mediaID: "f1", kind: .document,
                   naturalSize: Size2D(width: 1, height: 1))
    }

    func test_documentBox_isCaptionlessAtom() {
        let box: CanvasBlock = MediaBlockBox(media: documentBlock(), mapper: AttributedStringMapper(), width: 300)
        box.nodeStart = 5
        XCTAssertEqual(box.textLength, 0)
        XCTAssertEqual(box.nodeSize, 3)
        XCTAssertEqual(box.textStart, box.nodeStart)
        XCTAssertTrue(box.leafRegions().isEmpty)
        XCTAssertEqual(box.closestPosition(toCanvasPoint: CGPoint(x: 150, y: 20)), box.nodeStart)
    }

    func test_documentBox_rowHeightIs52_notAudios44() {
        let box = MediaBlockBox(media: documentBlock(), mapper: AttributedStringMapper(), width: 300)
        XCTAssertEqual(MediaBlockBox.documentRowHeight, 52.0,
                       "must equal InstantPageV2Layout's documentFrame height so the preview matches the bubble")
        XCTAssertEqual(box.imageAreaHeight, 52.0)
        XCTAssertEqual(box.height, box.verticalInset + 52.0 + box.verticalInset)
        XCTAssertEqual(box.measuredHeight(forWidth: 300), box.height)

        let audio = MediaBlockBox(media: MediaBlock(id: BlockID("a"), mediaID: "f2", kind: .audio,
                                                    naturalSize: Size2D(width: 1, height: 1)),
                                  mapper: AttributedStringMapper(), width: 300)
        XCTAssertEqual(audio.imageAreaHeight, 44.0, "audio keeps its own 44pt row")
    }

    func test_documentBox_dropsAnyIncomingCaption() {
        let withCaption = MediaBlock(id: BlockID("doc"), mediaID: "f1", kind: .document,
                                     naturalSize: Size2D(width: 1, height: 1),
                                     caption: [TextRun(text: "ignored")])
        let box = MediaBlockBox(media: withCaption, mapper: AttributedStringMapper(), width: 300)
        guard case .media(let out) = box.currentBlock() else { return XCTFail("expected media") }
        XCTAssertTrue(out.caption.isEmpty)
        XCTAssertNil(box.captionPlaceholder(), "a caption-less row shows no \"Add caption\" placeholder")
    }

    func test_documentBox_mediaRectIsFullBleedFixedHeightRow() {
        let box = MediaBlockBox(media: documentBlock(), mapper: AttributedStringMapper(), width: 300,
                                horizontalBleed: 16)
        box.frame = CGRect(x: 16, y: 100, width: 300, height: box.height)
        let rect = box.mediaRect()
        XCTAssertEqual(rect.minX, 0.0)                     // frame.minX - bleed
        XCTAssertEqual(rect.width, 332.0)                  // width + bleed * 2
        XCTAssertEqual(rect.height, 52.0)
        XCTAssertEqual(rect.minY, 100.0 + box.verticalInset)
    }

    func test_insertDocument_landsCaretInAFollowingParagraph() {
        // A caption-less block has nowhere to put the caret, so insertMedia appends/uses a body paragraph.
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        v.layoutIfNeeded()
        v.setCaret(global: v.boxes[0].textStart + 5)
        v.insertMedia(mediaID: "f1", naturalSize: CGSize(width: 1, height: 1), kind: .document, caption: [])

        let blocks = v.currentBlocks()
        guard case .media(let m) = blocks[1] else { return XCTFail("expected the document block at index 1") }
        XCTAssertEqual(m.kind, .document)
        guard let trailing = v.boxes.last as? BlockBox else { return XCTFail("expected a trailing paragraph") }
        XCTAssertEqual(v.head, trailing.textStart)
    }
}
#endif
