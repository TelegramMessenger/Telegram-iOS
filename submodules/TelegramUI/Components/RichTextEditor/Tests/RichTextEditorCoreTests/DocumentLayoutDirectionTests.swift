import XCTest
@testable import RichTextEditorCore

final class DocumentLayoutDirectionTests: XCTestCase {
    private func doc(_ dir: DocumentLayoutDirection) -> Document {
        Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "x")]))],
                 layoutDirection: dir)
    }

    func test_default_isAuto() {
        XCTAssertEqual(Document().layoutDirection, .auto)
    }

    func test_codec_roundTripsLayoutDirection() throws {
        for dir in DocumentLayoutDirection.allCases {
            let back = try DocumentCodec.decode(DocumentCodec.encode(doc(dir)))
            XCTAssertEqual(back.layoutDirection, dir)
        }
    }

    func test_decode_missingKey_defaultsToAuto() throws {
        // A legacy document with no layoutDirection key must load as .auto.
        let legacy = #"{"blocks":[],"schemaVersion":1}"#.data(using: .utf8)!
        XCTAssertEqual(try DocumentCodec.decode(legacy).layoutDirection, .auto)
    }
}
