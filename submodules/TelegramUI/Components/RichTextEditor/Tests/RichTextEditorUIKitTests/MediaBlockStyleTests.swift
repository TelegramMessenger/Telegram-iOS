#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class MediaBlockStyleTests: XCTestCase {
    func test_default_isPageMarginBleed() {
        XCTAssertEqual(MediaBlockStyle.default.horizontalBleed, 16, accuracy: 0.0)
        XCTAssertEqual(MediaBlockStyle.default, MediaBlockStyle())
        // The default literal equals the document page margin.
        XCTAssertEqual(MediaBlockStyle.default.horizontalBleed, CanvasMetrics.pageMargin, accuracy: 0.0)
    }

    func test_customBleed_andEquatable() {
        XCTAssertEqual(MediaBlockStyle(horizontalBleed: 0).horizontalBleed, 0, accuracy: 0.0)
        XCTAssertNotEqual(MediaBlockStyle(horizontalBleed: 0), MediaBlockStyle.default)
    }
}

extension MediaBlockStyleTests {
    private func imageBlock() -> MediaBlock {
        MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 100, height: 50), caption: [])
    }

    func test_mediaRect_bleedZero_alignsToFrame() {
        let box = MediaBlockBox(media: imageBlock(), mapper: AttributedStringMapper(), width: 200, horizontalBleed: 0)
        box.frame = CGRect(x: 40, y: 0, width: 200, height: 200)
        let rect = box.mediaRect()
        XCTAssertEqual(rect.minX, 40, accuracy: 0.5)    // no bleed: aligns to the text strip
        XCTAssertEqual(rect.width, 200, accuracy: 0.5)  // == layoutWidth (no displayWidth → fills text width)
    }

    func test_mediaRect_bleed16_bleedsPastFrame() {
        let box = MediaBlockBox(media: imageBlock(), mapper: AttributedStringMapper(), width: 200, horizontalBleed: 16)
        box.frame = CGRect(x: 40, y: 0, width: 200, height: 200)
        let rect = box.mediaRect()
        XCTAssertEqual(rect.minX, 24, accuracy: 0.5)    // 40 - 16
        XCTAssertEqual(rect.width, 232, accuracy: 0.5)  // 200 + 32
    }

    func test_mediaRect_defaultBleed_matchesPageMargin() {
        // The init default keeps the legacy static-pageMargin bleed (document edge-to-edge look).
        let box = MediaBlockBox(media: imageBlock(), mapper: AttributedStringMapper(), width: 200)
        box.frame = CGRect(x: CanvasMetrics.pageMargin, y: 0, width: 200, height: 200)
        XCTAssertEqual(box.horizontalBleed, CanvasMetrics.pageMargin, accuracy: 0.0)
        XCTAssertEqual(box.mediaRect().minX, 0, accuracy: 0.5)                                  // to canvas edge
        XCTAssertEqual(box.mediaRect().width, 200 + CanvasMetrics.pageMargin * 2, accuracy: 0.5)
    }

    func test_measuredHeight_tracksBleed() {
        let zero = MediaBlockBox(media: imageBlock(), mapper: AttributedStringMapper(), width: 200, horizontalBleed: 0)
        let bled = MediaBlockBox(media: imageBlock(), mapper: AttributedStringMapper(), width: 200, horizontalBleed: 16)
        // Wider bleed → wider image area → taller aspect-scaled image (no displayWidth).
        XCTAssertGreaterThan(bled.measuredHeight(forWidth: 200), zero.measuredHeight(forWidth: 200))
    }
}

extension MediaBlockStyleTests {
    private func mediaDocCanvas(bleedZero: Bool) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        if bleedZero { v.applyMediaBlockStyle(MediaBlockStyle(horizontalBleed: 0)) }
        v.setBlocks([.media(MediaBlock(id: BlockID("img"), mediaID: "x",
                                       naturalSize: Size2D(width: 100, height: 60), caption: []))], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }

    func test_canvas_defaultMediaBlockStyle_bleeds() {
        let v = mediaDocCanvas(bleedZero: false)
        let box = v.boxes[0] as! MediaBlockBox
        XCTAssertEqual(box.horizontalBleed, CanvasMetrics.pageMargin, accuracy: 0.0)
    }

    func test_canvas_applyMediaBlockStyleZero_insetsToTextStrip() {
        let v = mediaDocCanvas(bleedZero: true)
        let box = v.boxes[0] as! MediaBlockBox
        XCTAssertEqual(box.horizontalBleed, 0, accuracy: 0.0)
        XCTAssertEqual(box.mediaRect().minX, box.frame.minX, accuracy: 0.5)   // aligned to the text strip
    }
}

extension MediaBlockStyleTests {
    func test_insertMedia_usesCanvasMediaBlockStyle() {
        let v = DocumentCanvasView()
        v.applyMediaBlockStyle(MediaBlockStyle(horizontalBleed: 0))
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hi")]))], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        v.insertMedia(mediaID: "x", naturalSize: CGSize(width: 100, height: 60), kind: .image)
        let mediaBox = v.boxes.compactMap { $0 as? MediaBlockBox }.first!
        XCTAssertEqual(mediaBox.horizontalBleed, 0, accuracy: 0.0)   // inherits the canvas's inset style
    }

    func test_tableCellMedia_skipsBleed() {
        let cell = Cell(id: BlockID("c"),
                        blocks: [.media(MediaBlock(id: BlockID("m"), mediaID: "x",
                                                   naturalSize: Size2D(width: 100, height: 60), caption: []))])
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140)],
                               rows: [Row(id: BlockID("r0"), cells: [cell])])
        let box = TableBlockBox(table: table, mapper: AttributedStringMapper(), width: 300)
        let cellMedia = box.cells[0][0].boxes[0] as! MediaBlockBox
        XCTAssertEqual(cellMedia.horizontalBleed, 0, accuracy: 0.0)  // nested media never bleeds
    }
}

extension MediaBlockStyleTests {
    func test_facade_mediaBlockStyle_appliesToMediaBoxes() {
        let editor = RichTextEditorView()
        editor.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        editor.document = Document(blocks: [.media(MediaBlock(id: BlockID("img"), mediaID: "x",
                                                              naturalSize: Size2D(width: 100, height: 60), caption: []))])
        _ = editor.update(size: editor.frame.size, insets: .zero)
        // Default: document edge-to-edge look.
        let before = editor.canvasForTesting.boxes.compactMap { $0 as? MediaBlockBox }.first!
        XCTAssertEqual(before.horizontalBleed, CanvasMetrics.pageMargin, accuracy: 0.0)
        // Assigning the inset style reloads (the view is sized) so boxes rebuild with bleed 0.
        editor.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 0)
        let after = editor.canvasForTesting.boxes.compactMap { $0 as? MediaBlockBox }.first!
        XCTAssertEqual(after.horizontalBleed, 0, accuracy: 0.0)
    }
}
#endif
