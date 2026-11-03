#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class MediaSpoilerToggleTests: XCTestCase {
    /// A canvas seeded with a single-image media block (`BlockID("b1")`), mirroring `MediaControlTests`' setup.
    private func canvasWithSingleImageBlock() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.mediaViewProvider = { _, _, _, _ in nil }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("b1"), mediaID: "m1", kind: .image,
                              naturalSize: Size2D(width: 100, height: 100))),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }

    /// A canvas seeded with a 2-item (album) media block.
    private func canvasWithAlbumBlock() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.mediaViewProvider = { _, _, _, _ in nil }
        v.setBlocks([
            .media(MediaBlock(id: BlockID("b1"), items: [
                MediaItem(mediaID: "m1", kind: .image, naturalSize: Size2D(width: 100, height: 100)),
                MediaItem(mediaID: "m2", kind: .image, naturalSize: Size2D(width: 100, height: 100)),
            ])),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }

    private func firstMediaBlock(_ v: DocumentCanvasView) -> MediaBlock? {
        guard case let .media(block)? = v.currentBlocks().first else { return nil }
        return block
    }

    func test_toggleMediaSpoiler_singleImage_flipsItemAndIsOneUndoStep() {
        let v = canvasWithSingleImageBlock()
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um

        XCTAssertEqual(firstMediaBlock(v)?.items.first?.isSpoiler, false, "precondition: spoiler defaults off")

        let before = v.undoRegistrationCount
        um.beginUndoGrouping()
        v.toggleMediaSpoiler(blockID: BlockID("b1"), itemIndex: nil)
        um.endUndoGrouping()

        XCTAssertEqual(firstMediaBlock(v)?.items.first?.isSpoiler, true, "spoiler flips on")
        XCTAssertEqual(v.undoRegistrationCount, before + 1, "exactly one undo step registered")

        um.undo()
        XCTAssertEqual(firstMediaBlock(v)?.items.first?.isSpoiler, false, "undo restores the un-spoilered state")
    }

    func test_toggleMediaSpoiler_albumCellByIndex_flipsOnlyThatCell() {
        let v = canvasWithAlbumBlock()

        v.toggleMediaSpoiler(blockID: BlockID("b1"), itemIndex: 1)

        let block = firstMediaBlock(v)
        XCTAssertEqual(block?.items.count, 2, "the album keeps both items")
        XCTAssertEqual(block?.items[0].isSpoiler, false, "cell 0 is unaffected")
        XCTAssertEqual(block?.items[1].isSpoiler, true, "only the indexed cell flips")
    }
}
#endif
