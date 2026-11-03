import XCTest
@testable import RichTextEditorCore

final class BlockDocumentTests: XCTestCase {
    func test_block_taggedUnionRoundTripsEachCase() throws {
        let blocks: [Block] = [
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "hi")])),
            .media(MediaBlock(id: BlockID("i1"), mediaID: "a.png",
                              naturalSize: Size2D(width: 1, height: 1))),
            .table(TableBlock(id: BlockID("t1"),
                              columns: [ColumnSpec(width: 10)],
                              rows: [Row(id: BlockID("r1"), cells: [Cell(id: BlockID("c1"))])])),
        ]
        for b in blocks {
            let data = try JSONEncoder().encode(b)
            XCTAssertEqual(try JSONDecoder().decode(Block.self, from: data), b)
        }
    }

    func test_block_encodesTypeDiscriminator() throws {
        let b = Block.paragraph(ParagraphBlock(id: BlockID("p1")))
        let obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(b)) as! [String: Any]
        XCTAssertEqual(obj["type"] as? String, "paragraph")
        XCTAssertNotNil(obj["value"])
    }

    func test_block_idAccessorReturnsUnderlyingID() {
        XCTAssertEqual(Block.paragraph(ParagraphBlock(id: BlockID("p9"))).id, BlockID("p9"))
        XCTAssertEqual(Block.media(MediaBlock(id: BlockID("i9"), mediaID: "a",
                       naturalSize: Size2D(width: 1, height: 1))).id, BlockID("i9"))
    }

    func test_document_roundTrips() throws {
        let doc = Document(
            blocks: [.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "x")]))]
        )
        let data = try JSONEncoder().encode(doc)
        XCTAssertEqual(try JSONDecoder().decode(Document.self, from: data), doc)
    }

    func test_document_decodesWithMissingSchemaVersionAsOne() throws {
        let json = #"{"blocks":[]}"#
            .data(using: .utf8)!
        let doc = try JSONDecoder().decode(Document.self, from: json)
        XCTAssertEqual(doc.schemaVersion, 1)
    }
}
