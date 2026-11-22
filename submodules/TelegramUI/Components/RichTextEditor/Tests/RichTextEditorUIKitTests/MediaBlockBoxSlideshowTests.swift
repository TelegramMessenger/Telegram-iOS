#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

@available(iOS 13.0, *)
final class MediaBlockBoxSlideshowTests: XCTestCase {
    private func makeBlock(mode: MediaDisplayMode) -> MediaBlock {
        // Two portrait items (100×200) and one landscape (100×50). Tallest-fitted-to-width drives slideshow height.
        MediaBlock(id: BlockID.generate(),
                   items: [MediaItem(mediaID: "a", kind: .image, naturalSize: Size2D(width: 100, height: 200)),
                           MediaItem(mediaID: "b", kind: .image, naturalSize: Size2D(width: 100, height: 50))],
                   displayMode: mode)
    }
    private func mapper() -> AttributedStringMapper { AttributedStringMapper() }

    func test_slideshowHeight_isTallestItemFittedToWidth() {
        let width: CGFloat = 300
        let box = MediaBlockBox(media: makeBlock(mode: .slideshow), mapper: mapper(), width: width, horizontalBleed: 0)
        // Tallest item 100×200 fitted to width 300 → 600, capped at min(1000, 300) = 300.
        XCTAssertEqual(box.imageAreaHeight, 300, accuracy: 0.5)
    }

    func test_currentBlock_carriesDisplayMode() {
        let box = MediaBlockBox(media: makeBlock(mode: .slideshow), mapper: mapper(), width: 300, horizontalBleed: 0)
        guard case .media(let m) = box.currentBlock() else { return XCTFail("expected media") }
        XCTAssertEqual(m.displayMode, .slideshow)
    }
}
#endif
