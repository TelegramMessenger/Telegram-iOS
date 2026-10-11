#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// `MediaSlotGeometry` is the ONE copy of the slot numbers both editors reserve. It is pinned
/// against `MediaBlockBox`'s own answers — the box is the reference — before the box starts calling
/// it, so the extraction cannot move a pixel.
final class MediaSlotGeometryParityTests: XCTestCase {
    private func box(_ block: MediaBlock, width: CGFloat = 300) -> MediaBlockBox {
        MediaBlockBox(media: block, mapper: AttributedStringMapper(), width: width, horizontalBleed: 0)
    }
    private func item(_ w: Double, _ h: Double, kind: MediaKind = .image) -> MediaItem {
        MediaItem(mediaID: "m\(w)x\(h)", kind: kind, naturalSize: Size2D(width: w, height: h))
    }

    func test_aLandscapeImageFillsTheWidthAtItsAspect() {
        let block = MediaBlock(id: BlockID("a"), items: [item(1000, 500)])
        XCTAssertEqual(MediaSlotGeometry.slotSize(items: block.items, displayMode: .mosaic, displayWidth: nil, maxWidth: 300).height,
                       box(block).imageAreaHeight, accuracy: 0.01)
        XCTAssertEqual(MediaSlotGeometry.slotSize(items: block.items, displayMode: .mosaic, displayWidth: nil, maxWidth: 300).height, 150, accuracy: 0.01)
    }

    func test_aPortraitImageIsCappedAtTheWidth() {
        let block = MediaBlock(id: BlockID("a"), items: [item(500, 1000)])
        XCTAssertEqual(MediaSlotGeometry.slotSize(items: block.items, displayMode: .mosaic, displayWidth: nil, maxWidth: 300).height,
                       box(block).imageAreaHeight, accuracy: 0.01)
        XCTAssertEqual(box(block).imageAreaHeight, 300, accuracy: 0.01, "min(1000, maxWidth)")
    }

    func test_aDisplayWidthNarrowsTheSlot() {
        let block = MediaBlock(id: BlockID("a"), items: [item(1000, 500)], displayWidth: 150)
        let size = MediaSlotGeometry.slotSize(items: block.items, displayMode: .mosaic, displayWidth: 150, maxWidth: 300)
        XCTAssertEqual(size.width, 150, accuracy: 0.01)
        XCTAssertEqual(size.height, box(block).imageAreaHeight, accuracy: 0.01)
    }

    func test_anAlbumPacksAsAMosaic() {
        let block = MediaBlock(id: BlockID("a"), items: [item(1000, 500), item(500, 500), item(800, 600)])
        XCTAssertEqual(MediaSlotGeometry.slotSize(items: block.items, displayMode: .mosaic, displayWidth: nil, maxWidth: 300).height,
                       box(block).imageAreaHeight, accuracy: 0.01)
    }

    func test_aSlideshowIsTheTallestPageFitted() {
        let block = MediaBlock(id: BlockID("a"), items: [item(1000, 500), item(500, 500)], displayMode: .slideshow)
        XCTAssertEqual(MediaSlotGeometry.slotSize(items: block.items, displayMode: .slideshow, displayWidth: nil, maxWidth: 300).height,
                       box(block).imageAreaHeight, accuracy: 0.01)
    }

    func test_audioAndDocumentAreFixedRows() {
        let audio = MediaBlock(id: BlockID("a"), items: [item(0, 0, kind: .audio)])
        let document = MediaBlock(id: BlockID("d"), items: [item(0, 0, kind: .document)])
        XCTAssertEqual(MediaSlotGeometry.slotSize(items: audio.items, displayMode: .mosaic, displayWidth: nil, maxWidth: 300).height, box(audio).imageAreaHeight)
        XCTAssertEqual(MediaSlotGeometry.slotSize(items: document.items, displayMode: .mosaic, displayWidth: nil, maxWidth: 300).height, box(document).imageAreaHeight)
        XCTAssertEqual(MediaSlotGeometry.audioRowHeight, 44)
        XCTAssertEqual(MediaSlotGeometry.documentRowHeight, 52)
    }

    func test_theInteriorConstantsAreTheBoxes() {
        let block = MediaBlock(id: BlockID("a"), items: [item(1000, 500)])
        XCTAssertEqual(MediaSlotGeometry.verticalInset, box(block).verticalInset)
        XCTAssertEqual(MediaSlotGeometry.captionGap, box(block).captionGap)
    }
}
#endif
