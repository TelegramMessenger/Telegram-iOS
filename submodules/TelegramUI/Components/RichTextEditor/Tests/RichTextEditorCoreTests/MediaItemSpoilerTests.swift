import XCTest
@testable import RichTextEditorCore

final class MediaItemSpoilerTests: XCTestCase {
    func test_isSpoiler_defaultsFalse() {
        let item = MediaItem(mediaID: "m1", kind: .image, naturalSize: Size2D(width: 4, height: 3))
        XCTAssertFalse(item.isSpoiler)
    }

    func test_isSpoiler_roundTripsThroughCodable() throws {
        var item = MediaItem(mediaID: "m1", kind: .video, naturalSize: Size2D(width: 16, height: 9))
        item.isSpoiler = true
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MediaItem.self, from: data)
        XCTAssertTrue(decoded.isSpoiler)
    }

    func test_legacyPayloadWithoutSpoiler_decodesFalse() throws {
        // A pre-spoiler payload has no "isSpoiler" key. `MediaKind` is a String-raw enum and `Size2D` is a
        // flat {width,height} object, so build the fixture by encoding a known non-spoiler MediaItem on the
        // CURRENT model and stripping the "isSpoiler" key from the resulting JSON dictionary.
        let current = MediaItem(mediaID: "m1", kind: .image, naturalSize: Size2D(width: 4, height: 3))
        let data = try JSONEncoder().encode(current)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "isSpoiler")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(MediaItem.self, from: legacyData)
        XCTAssertFalse(decoded.isSpoiler)
    }
}
