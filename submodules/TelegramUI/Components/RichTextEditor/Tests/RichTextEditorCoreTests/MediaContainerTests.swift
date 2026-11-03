import XCTest
@testable import RichTextEditorCore

final class MediaContainerTests: XCTestCase {
    func test_mediaItem_codableRoundTrip() throws {
        let item = MediaItem(mediaID: "abc", kind: .video, naturalSize: Size2D(width: 640, height: 480))
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MediaItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }

    func test_mediaBlock_conveniceInit_wrapsSingleItem() {
        let block = MediaBlock(id: BlockID("b1"), mediaID: "m1", kind: .image,
                               naturalSize: Size2D(width: 100, height: 50))
        XCTAssertEqual(block.items.count, 1)
        XCTAssertEqual(block.mediaID, "m1")          // computed accessor -> first item
        XCTAssertEqual(block.kind, .image)
        XCTAssertEqual(block.naturalSize, Size2D(width: 100, height: 50))
        XCTAssertFalse(block.isAudio)
    }

    func test_mediaBlock_container_holdsMultipleItems() {
        let block = MediaBlock(id: BlockID("b1"), items: [
            MediaItem(mediaID: "m1", kind: .image, naturalSize: Size2D(width: 100, height: 50)),
            MediaItem(mediaID: "m2", kind: .video, naturalSize: Size2D(width: 60, height: 90)),
        ], caption: [])
        XCTAssertEqual(block.items.count, 2)
        XCTAssertEqual(block.mediaID, "m1")          // first item
    }

    func test_mediaBlock_codable_newContainerRoundTrips() throws {
        let block = MediaBlock(id: BlockID("b1"), items: [
            MediaItem(mediaID: "m1", kind: .image, naturalSize: Size2D(width: 100, height: 50)),
            MediaItem(mediaID: "m2", kind: .video, naturalSize: Size2D(width: 60, height: 90)),
        ], displayWidth: nil, alignment: .center, caption: [])
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(MediaBlock.self, from: data)
        XCTAssertEqual(decoded, block)
    }

    func test_mediaBlock_codable_decodesLegacyFlatShapeIntoOneItem() throws {
        // A pre-container persisted block has mediaID/kind/naturalSize at the block level, no `items`.
        let legacyJSON = """
        {"id":"b1","mediaID":"m1","kind":"image","naturalSize":{"width":100,"height":50},"alignment":"center","caption":[]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MediaBlock.self, from: legacyJSON)
        XCTAssertEqual(decoded.items, [MediaItem(mediaID: "m1", kind: .image, naturalSize: Size2D(width: 100, height: 50))])
        XCTAssertEqual(decoded.id, BlockID("b1"))
    }
}
