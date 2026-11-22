import XCTest
@testable import RichTextEditorCore

final class MediaBlockDisplayModeTests: XCTestCase {
    private func item() -> MediaItem { MediaItem(mediaID: "m1", kind: .image, naturalSize: Size2D(width: 100, height: 80)) }

    func test_defaultDisplayModeIsMosaic() {
        let block = MediaBlock(id: BlockID.generate(), items: [item(), item()])
        XCTAssertEqual(block.displayMode, .mosaic)
    }

    func test_displayModeRoundTripsThroughCodable() throws {
        var block = MediaBlock(id: BlockID.generate(), items: [item(), item()])
        block.displayMode = .slideshow
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(MediaBlock.self, from: data)
        XCTAssertEqual(decoded.displayMode, .slideshow)
    }

    func test_missingDisplayModeKeyDecodesAsMosaic() throws {
        // A pre-feature payload has items but no `displayMode` key.
        let json = """
        {"id":"\(BlockID.generate().rawValue)","items":[{"mediaID":"m1","kind":"image","naturalSize":{"width":100,"height":80}}],"alignment":"center","caption":[]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MediaBlock.self, from: json)
        XCTAssertEqual(decoded.displayMode, .mosaic)
        XCTAssertEqual(decoded.items.count, 1)
    }
}
