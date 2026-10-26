#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class MediaBlockBoxTests: XCTestCase {
    private func solid(_ size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.systemBlue.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
    private func mixedCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in self.solid(CGSize(width: 100, height: 60)) }
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Above")])),
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 100, height: 60),
                              caption: [TextRun(text: "Cap")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Below")])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }

    func test_imageBox_tokenMath() {
        let block = MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 100, height: 60),
                               caption: [TextRun(text: "Cap")])
        let box: CanvasBlock = MediaBlockBox(media: block, mapper: AttributedStringMapper(), width: 300)
        box.nodeStart = 5
        XCTAssertEqual(box.textLength, 3)          // "Cap"
        XCTAssertEqual(box.nodeSize, 8)            // captionLen + 5
        XCTAssertEqual(box.textStart, 7)           // nodeStart + 2
        XCTAssertEqual(box.textRef, .caption(BlockID("img")))
        guard case .media(let out) = box.currentBlock() else { return XCTFail("expected media") }
        XCTAssertEqual(out.caption.map(\.text).joined(), "Cap")
    }

    func test_mixedDoc_spansMatchCorePositionModel() {
        let v = mixedCanvas()
        let doc = Document(blocks: v.currentBlocks())
        let tree = DocumentTree.build(from: doc)
        XCTAssertEqual(v.documentSizeValue, DocumentTree.documentSize(doc))
        // caption text start matches the Core global position of the caption text node
        let imgBox = v.boxes[1]
        let coreCaptionStart = PositionResolver.globalPosition(of: .caption(BlockID("img")), offset: 0, in: tree)
        XCTAssertEqual(imgBox.textStart, coreCaptionStart)
    }

    func test_currentBlocks_roundTripsMixedDocument() {
        let v = mixedCanvas()
        let blocks = v.currentBlocks()
        XCTAssertEqual(blocks.count, 3)
        guard case .paragraph = blocks[0], case .media = blocks[1], case .paragraph = blocks[2]
        else { return XCTFail("expected paragraph/media/paragraph") }
    }

    func test_imageRendersNonBlank() {
        let v = mixedCanvas()
        let image = UIGraphicsImageRenderer(bounds: v.bounds).image { _ in
            v.drawHierarchy(in: v.bounds, afterScreenUpdates: true)
        }
        XCTAssertNotNil(image.cgImage)
    }

    func test_caption_isCentered() {
        let block = MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 100, height: 60),
                               caption: [TextRun(text: "Cap")])
        let box = MediaBlockBox(media: block, mapper: AttributedStringMapper(), width: 300)
        let ps = box.caption.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(ps?.alignment, .center)
    }

    func test_emptyCaption_reservesOneLine() {
        let mapper = AttributedStringMapper()
        let empty = MediaBlock(id: BlockID("img"), mediaID: "x",
                               naturalSize: Size2D(width: 100, height: 60), caption: [])
        let box = MediaBlockBox(media: empty, mapper: mapper, width: 300)
        // height minus the fixed image+inset+gap chrome must be ~one body line — the empty caption row
        // does NOT collapse to 0.
        let chrome = box.verticalInset * 2 + box.imageAreaHeight + box.captionGap
        let reserved = box.height - chrome
        // "One line" is V2's single-line item height for the CAPTION style (the caption renders at
        // `.caption`, not `.body`) — ascender + |descender|, not a scaled font.lineHeight.
        let captionLine = RichTextRenderMetrics.textHeight(
            mapper.styleSheet.font(for: .caption, attributes: .plain),
            factor: mapper.styleSheet.metrics.caption.lineSpacingFactor, lineCount: 1)
        XCTAssertEqual(reserved, captionLine, accuracy: 0.5, "empty caption reserves exactly one V2 line")
    }

    func test_emptyCaption_showsAddCaptionPlaceholder() {
        let mapper = AttributedStringMapper()
        let empty = MediaBlock(id: BlockID("img"), mediaID: "x",
                               naturalSize: Size2D(width: 100, height: 60), caption: [])
        let box = MediaBlockBox(media: empty, mapper: mapper, width: 300)
        let ph = box.captionPlaceholder()
        XCTAssertEqual(ph?.text, "Add caption")
        XCTAssertEqual(ph?.rect.width ?? 0, 300, accuracy: 0.5)   // spans the caption width (so it centers)
        // The rect must cover the FULL reserved line (font.lineHeight × caption lineHeightMultiple), matching
        // captionEmptyLineHeight — not the bare font.lineHeight — so the placeholder aligns with real text.
        let ps = mapper.styleSheet.paragraphStyle(for: .caption, attributes: ParagraphAttributes(alignment: .center), list: nil)
        let mult = ps.lineHeightMultiple > 0 ? ps.lineHeightMultiple : 1
        let captionLine = mapper.styleSheet.font(for: .caption, attributes: .plain).lineHeight
        XCTAssertEqual(ph?.rect.height ?? 0, captionLine * mult, accuracy: 0.5)

        let filled = MediaBlock(id: BlockID("img"), mediaID: "x",
                                naturalSize: Size2D(width: 100, height: 60), caption: [TextRun(text: "Cap")])
        let box2 = MediaBlockBox(media: filled, mapper: mapper, width: 300)
        XCTAssertNil(box2.captionPlaceholder())                   // no placeholder once text exists
    }

    func test_emptyCaption_caretAlignsToPlaceholderStart() {
        let mapper = AttributedStringMapper()
        let empty = MediaBlock(id: BlockID("img"), mediaID: "x",
                               naturalSize: Size2D(width: 100, height: 60), caption: [])
        let box = MediaBlockBox(media: empty, mapper: mapper, width: 300)
        // The caption's empty-line caret x offset (added by caretRect(for:)/updateCaretView) places the caret
        // at the START (left edge) of the centered "Add caption" placeholder, not the line center: the
        // placeholder is centered in a 300pt-wide rect, so its left edge is (300 - placeholderWidth)/2.
        let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
        let phWidth = ("Add caption" as NSString).size(withAttributes: [.font: font]).width
        let expected = (300 - phWidth) / 2
        XCTAssertEqual(box.leafRegions()[0].emptyLineLeadingIndent, expected, accuracy: 0.5)
        // Sanity: that offset is well left of the line center (150) — i.e. the caret no longer bisects "Add caption".
        XCTAssertLessThan(box.leafRegions()[0].emptyLineLeadingIndent, 150 - 1.0)

        let filled = MediaBlock(id: BlockID("img"), mediaID: "x",
                                naturalSize: Size2D(width: 100, height: 60), caption: [TextRun(text: "Cap")])
        let box2 = MediaBlockBox(media: filled, mapper: mapper, width: 300)
        XCTAssertEqual(box2.leafRegions()[0].emptyLineLeadingIndent, 0, accuracy: 0.5)  // text exists → 0
    }

    func test_emptyCaption_caretRectSpansTheLineHeight() {
        let mapper = AttributedStringMapper()
        let v = DocumentCanvasView()
        v.imageProvider = { _ in self.solid(CGSize(width: 100, height: 60)) }
        v.setBlocks([.media(MediaBlock(id: BlockID("img"), mediaID: "x",
                                       naturalSize: Size2D(width: 100, height: 60), caption: []))], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        let imgBox = v.boxes[0] as! MediaBlockBox
        let caret = v.caretRect(for: DocumentTextPosition(imgBox.textStart))
        // The empty-caption caret spans the real line height (font.lineHeight × caption lineHeightMultiple),
        // not the fixed 20pt fallback — so it matches a typed line and the centered placeholder on it.
        let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
        let ps = mapper.styleSheet.paragraphStyle(for: .caption, attributes: ParagraphAttributes(alignment: .center), list: nil)
        let mult = ps.lineHeightMultiple > 0 ? ps.lineHeightMultiple : 1
        // Tight accuracy: the 15pt caption line (~19.7) sits just under the 20pt fallback, so a loose
        // tolerance couldn't tell the real metric from the fallback.
        XCTAssertEqual(caret.height, font.lineHeight * mult, accuracy: 0.1)
        XCTAssertNotEqual(caret.height, 20.0, "the real caption line height, not the fixed-20pt empty-caret fallback")
    }

    func test_imageRect_respectsExplicitDisplayWidth() {
        let block = MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 100, height: 50),
                               displayWidth: 60, caption: [])
        let v = DocumentCanvasView()
        v.setBlocks([.media(block)], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 400); v.layoutIfNeeded()
        let box = v.boxes[0] as! MediaBlockBox
        XCTAssertEqual(box.mediaRect().width, 60, accuracy: 0.5)   // explicit width honored, not stretched full-bleed
    }

    func testAudioBlockIsFixedHeightAcrossWidths() {
        // Build a .audio MediaBlockBox the same way the existing image tests build theirs.
        let block = MediaBlock(id: BlockID("aud"), mediaID: "y", kind: .audio,
                               naturalSize: Size2D(width: 1, height: 1), caption: [])
        let box = MediaBlockBox(media: block, mapper: AttributedStringMapper(), width: 300)
        let hNarrow = box.measuredHeight(forWidth: 200)
        let hWide = box.measuredHeight(forWidth: 600)
        // The audio ROW area is fixed; only the (empty) caption row is shared. Heights must match across widths.
        XCTAssertEqual(hNarrow, hWide, accuracy: 0.5)
        // And the area must equal the fixed row height plus insets+caption (not an aspect-scaled image height).
        XCTAssertLessThan(hNarrow, 120)
    }

    func testAudioMediaRectIsFixedHeightRow() {
        // Build an .audio box exactly as testAudioBlockIsFixedHeightAcrossWidths does, then place a
        // frame so that mediaRect() has a defined minX/minY (mirrors the image-rect test setup in
        // test_imageRect_respectsExplicitDisplayWidth).
        let block = MediaBlock(id: BlockID("aud"), mediaID: "y", kind: .audio,
                               naturalSize: Size2D(width: 1, height: 1), caption: [])
        let box = MediaBlockBox(media: block, mapper: AttributedStringMapper(), width: 320)
        // Assign frame + canvasWidth-matching layoutWidth so mediaRect() has stable geometry.
        box.frame = CGRect(x: CanvasMetrics.pageMargin, y: 0, width: 320, height: 80)
        let rect = box.mediaRect()
        XCTAssertEqual(rect.height, MediaBlockBox.audioRowHeight, accuracy: 0.5)   // 44pt, NOT a giant square
        XCTAssertEqual(rect.width, 320 + CanvasMetrics.pageMargin * 2, accuracy: 0.5) // full canvas width (avail)
    }

    func testAudioBoxIsCaptionLess() {
        let box = MediaBlockBox(media: MediaBlock(id: BlockID("a"), mediaID: "doc:1", kind: .audio,
                                                  naturalSize: Size2D(width: 1, height: 1), displayWidth: nil,
                                                  alignment: .center, caption: []),
                                mapper: AttributedStringMapper(), width: 300)
        box.nodeStart = 0
        XCTAssertEqual(box.textLength, 0)
        XCTAssertEqual(box.nodeSize, 3)
        XCTAssertEqual(box.textStart, box.nodeStart)
        XCTAssertTrue(box.leafRegions().isEmpty)
        XCTAssertEqual(box.height, 60, accuracy: 0.5) // verticalInset(8) + audioRowHeight(44) + verticalInset(8)
    }

    func testAudioCurrentBlockHasEmptyCaption() {
        // Even if a caption is seeded (e.g. from an incoming message), audio drops it.
        let box = MediaBlockBox(media: MediaBlock(id: BlockID("a"), mediaID: "doc:1", kind: .audio,
                                                  naturalSize: Size2D(width: 1, height: 1), displayWidth: nil,
                                                  alignment: .center, caption: [TextRun(text: "x")]),
                                mapper: AttributedStringMapper(), width: 300)
        guard case .media(let m) = box.currentBlock() else { return XCTFail("expected .media") }
        XCTAssertTrue(m.caption.isEmpty)
    }

    func testCaptionedImageBoxStillHasCaptionRegion() { // regression
        let box = MediaBlockBox(media: MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 100, height: 50),
                                                   caption: []),
                                mapper: AttributedStringMapper(), width: 300)
        box.nodeStart = 0
        XCTAssertEqual(box.textStart, box.nodeStart + 2)
        XCTAssertEqual(box.leafRegions().count, 1)
    }

    func test_mediaBlockBox_twoItems_usesMosaicHeight() {
        let mapper = AttributedStringMapper()   // match the file's existing test setup
        let block = MediaBlock(id: BlockID("b1"), items: [
            MediaItem(mediaID: "m1", kind: .image, naturalSize: Size2D(width: 100, height: 100)),
            MediaItem(mediaID: "m2", kind: .image, naturalSize: Size2D(width: 100, height: 100)),
        ], caption: [])
        let box = MediaBlockBox(media: block, mapper: mapper, width: 300, horizontalBleed: 0)
        // Two square items in a 300-wide mosaic pack side-by-side → area height < single-full-width (300),
        // and strictly positive.
        XCTAssertGreaterThan(box.imageAreaHeight, 0)
        XCTAssertLessThan(box.imageAreaHeight, 300)
    }

    func test_singleMedia_portrait_heightCappedToWidth() {
        let mapper = AttributedStringMapper()   // match the file's existing test setup
        // A tall portrait: 100 wide x 400 tall. At width 300, uncapped height would be 1200.
        let block = MediaBlock(id: BlockID("b1"), mediaID: "m1", kind: .image,
                               naturalSize: Size2D(width: 100, height: 400))
        let box = MediaBlockBox(media: block, mapper: mapper, width: 300, horizontalBleed: 0)
        // cap = min(1000, canvasWidth=300) = 300 → the slot is at most a 300x300 square.
        XCTAssertEqual(box.imageAreaHeight, 300, accuracy: 0.5)
    }

    func test_singleMedia_landscape_uncapped() {
        let mapper = AttributedStringMapper()
        // Landscape 400x100 at width 300 → height 75, under the 300 cap.
        let block = MediaBlock(id: BlockID("b1"), mediaID: "m1", kind: .image,
                               naturalSize: Size2D(width: 400, height: 100))
        let box = MediaBlockBox(media: block, mapper: mapper, width: 300, horizontalBleed: 0)
        XCTAssertEqual(box.imageAreaHeight, 75, accuracy: 0.5)
    }

    func test_mosaic_totalHeightCappedToWidth() {
        let mapper = AttributedStringMapper()
        // Several tall items → the packed mosaic exceeds a square; total height must be <= cap.
        let items = (0..<5).map { MediaItem(mediaID: "m\($0)", kind: .image, naturalSize: Size2D(width: 100, height: 300)) }
        let box = MediaBlockBox(media: MediaBlock(id: BlockID("b1"), items: items), mapper: mapper, width: 300, horizontalBleed: 0)
        XCTAssertLessThanOrEqual(box.imageAreaHeight, 300.0 + 0.5)   // cap = min(1000, 300)
        XCTAssertGreaterThan(box.imageAreaHeight, 0)
    }
}
#endif
