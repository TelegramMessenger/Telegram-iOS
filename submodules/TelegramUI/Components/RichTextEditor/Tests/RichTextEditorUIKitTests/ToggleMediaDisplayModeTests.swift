#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Mirrors `MediaSpoilerToggleTests`' setup/idiom exactly (verified sibling test — same file this new op
/// lives beside): `DocumentCanvasView()` + `setBlocks` + `currentBlocks()` read-back, `undoManagerOverride`
/// + explicit `beginUndoGrouping`/`endUndoGrouping` + `undoRegistrationCount` for the one-undo-step check.
final class ToggleMediaDisplayModeTests: XCTestCase {
    /// A canvas seeded with a 2-item (album) media block — `toggleMediaDisplayMode` requires `items.count >= 2`.
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

    /// A canvas seeded with a single-image media block (only 1 item — the no-op case).
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

    private func firstMediaBlock(_ v: DocumentCanvasView) -> MediaBlock? {
        guard case let .media(block)? = v.currentBlocks().first else { return nil }
        return block
    }

    func test_toggleFlipsMosaicToSlideshowAndBack() {
        let v = canvasWithAlbumBlock()
        XCTAssertEqual(firstMediaBlock(v)?.displayMode, .mosaic, "precondition: mosaic by default")

        v.toggleMediaDisplayMode(blockID: BlockID("b1"))
        XCTAssertEqual(firstMediaBlock(v)?.displayMode, .slideshow)

        v.toggleMediaDisplayMode(blockID: BlockID("b1"))
        XCTAssertEqual(firstMediaBlock(v)?.displayMode, .mosaic)
    }

    func test_toggleIsOneUndoStep() {
        let v = canvasWithAlbumBlock()
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um

        let before = v.undoRegistrationCount
        um.beginUndoGrouping()
        v.toggleMediaDisplayMode(blockID: BlockID("b1"))
        um.endUndoGrouping()

        XCTAssertEqual(firstMediaBlock(v)?.displayMode, .slideshow)
        XCTAssertEqual(v.undoRegistrationCount, before + 1, "exactly one undo step registered")

        um.undo()
        XCTAssertEqual(firstMediaBlock(v)?.displayMode, .mosaic, "undo restores mosaic")
    }

    func test_toggleIsNoOpForFewerThanTwoItems() {
        let v = canvasWithSingleImageBlock()
        XCTAssertEqual(firstMediaBlock(v)?.items.count, 1)
        v.toggleMediaDisplayMode(blockID: BlockID("b1"))
        XCTAssertEqual(firstMediaBlock(v)?.displayMode, .mosaic, "single-item block: toggle is a no-op")
    }

    func test_toggleIsNoOpForUnknownBlockID() {
        let v = canvasWithAlbumBlock()
        v.toggleMediaDisplayMode(blockID: BlockID("nonexistent"))
        XCTAssertEqual(firstMediaBlock(v)?.displayMode, .mosaic, "unknown blockID: toggle is a no-op")
    }
}
#endif
