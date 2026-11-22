import XCTest
import TelegramCore
import MediaEditor

final class ChatMediaEditorCanvasTests: XCTestCase {
    func testCanvasSizeForLandscapePhoto() {
        XCTAssertEqual(mediaEditorNonStoryCanvasSize(originalDimensions: PixelDimensions(width: 4032, height: 3024)), CGSize(width: 1920.0, height: 1440.0))
    }

    func testCanvasSizeForPortraitVideo() {
        XCTAssertEqual(mediaEditorNonStoryCanvasSize(originalDimensions: PixelDimensions(width: 1080, height: 1920)), CGSize(width: 1072.0, height: 1905.0))
    }

    func testChatValuesAreNotStory() {
        let values = chatMediaEditorValues(peerId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1)), originalDimensions: PixelDimensions(width: 400, height: 300), qualityPreset: .compressedVeryHigh)
        XCTAssertEqual(values.qualityPreset, .compressedVeryHigh)
        XCTAssertEqual(values.originalDimensions, PixelDimensions(width: 400, height: 300))
        XCTAssertNil(values.cropRect)
        XCTAssertNil(values.coverDimensions)
    }
}
