import XCTest
@testable import RichTextEditorCore

final class MediaBlockTests: XCTestCase {
    func test_media_defaultsAndCaptionLength() {
        let img = MediaBlock(
            id: BlockID("img1"),
            mediaID: "img1.png",
            naturalSize: Size2D(width: 100, height: 50),
            caption: [TextRun(text: "Fig 1")]
        )
        XCTAssertEqual(img.alignment, .center)
        XCTAssertNil(img.displayWidth)
        XCTAssertEqual(img.kind, .image)
        XCTAssertEqual(img.captionUTF16Count, 5)
    }

    func test_media_roundTrips() throws {
        let img = MediaBlock(
            id: BlockID("img1"),
            mediaID: "img1.png",
            kind: .image,
            naturalSize: Size2D(width: 100, height: 50),
            displayWidth: 80,
            alignment: .left,
            caption: [TextRun(text: "c")]
        )
        let data = try JSONEncoder().encode(img)
        XCTAssertEqual(try JSONDecoder().decode(MediaBlock.self, from: data), img)
    }

    func testMediaKindAudioCodableRoundTrip() throws {
        let block = MediaBlock(
            id: BlockID("audio1"),
            mediaID: "doc:42",
            kind: .audio,
            naturalSize: Size2D(width: 1, height: 1),
            displayWidth: nil,
            alignment: .center,
            caption: [TextRun(text: "song")]
        )
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(MediaBlock.self, from: data)
        XCTAssertEqual(decoded.kind, .audio)
        XCTAssertEqual(MediaKind.audio.rawValue, "audio")
    }

    func testAudioMediaBlockIsCaptionLessAtom() {
        let audio = MediaBlock(id: BlockID("a"), mediaID: "doc:1", kind: .audio,
                               naturalSize: Size2D(width: 1, height: 1), displayWidth: nil,
                               alignment: .center, caption: [])
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.media(audio)])), 3) // mediaBlock([mediaAtom]) = 1 + 2
    }

    func testCaptionedMediaNodeSizeUnchanged() {
        let img = MediaBlock(id: BlockID("i"), mediaID: "doc:2", kind: .image,
                             naturalSize: Size2D(width: 1, height: 1), displayWidth: nil,
                             alignment: .center, caption: [TextRun(text: "hi")]) // captionUTF16Count == 2
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.media(img)])), 7) // caption 2 + 5
    }
}
