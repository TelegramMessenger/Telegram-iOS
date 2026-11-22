import XCTest
@testable import RichTextEditorCore

final class DocumentCodecTests: XCTestCase {
    private func sampleDoc() -> Document {
        Document(
            blocks: [.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "x")]))]
        )
    }

    func test_codec_roundTrips() throws {
        let doc = sampleDoc()
        XCTAssertEqual(try DocumentCodec.decode(DocumentCodec.encode(doc)), doc)
    }

    func test_codec_emitsNoMetadataKey() throws {
        // A Document is just { schemaVersion, blocks } — there is no metadata wrapper, so the encoded
        // JSON must not carry a "metadata" key.
        let json = String(data: try DocumentCodec.encode(sampleDoc()), encoding: .utf8)!
        XCTAssertFalse(json.contains("metadata"), json)
    }

    func test_codec_keysAreSortedForStableDiffs() throws {
        let json = String(data: try DocumentCodec.encode(sampleDoc()), encoding: .utf8)!
        // "blocks" sorts before "schemaVersion"
        let iBlocks = json.range(of: "\"blocks\"")!.lowerBound
        let iSchema = json.range(of: "\"schemaVersion\"")!.lowerBound
        XCTAssertTrue(iBlocks < iSchema, json)
    }

    // MARK: - Lenient decode (backward-compat with removed kinds)

    func test_lenientDecode_oldQuoteStyle_becomesBody() throws {
        // A paragraph with the old "quote" style (now removed) must decode with style == .body.
        // Build valid JSON via the encoder then patch the style field to the old rawValue.
        let para = Block.paragraph(ParagraphBlock(id: BlockID("p"), style: .body,
                                                  runs: [TextRun(text: "hi")]))
        var jsonStr = try String(data: DocumentCodec.encode(Document(blocks: [para])), encoding: .utf8)!
        // Replace the first "body" rawValue occurrence (the style field) with the old "quote" value.
        jsonStr = jsonStr.replacingOccurrences(of: "\"body\"", with: "\"quote\"",
                                               range: jsonStr.range(of: "\"body\""))
        let doc = try DocumentCodec.decode(Data(jsonStr.utf8))
        guard case .paragraph(let p) = doc.blocks.first else { return XCTFail("expected .paragraph") }
        XCTAssertEqual(p.style, .body, "old quote style falls back to body")
    }

    func test_lenientDecode_oldCollapsedQuoteBlock_isSkipped() throws {
        // A document whose blocks array contains one removed-kind block + one good paragraph
        // → only the paragraph survives (the unknown kind is skipped, not fatal).
        // Build valid JSON via the encoder, then splice in a fake unknown block type.
        let para = Block.paragraph(ParagraphBlock(id: BlockID("p"), style: .body,
                                                  runs: [TextRun(text: "ok")]))
        var jsonStr = try String(data: DocumentCodec.encode(Document(blocks: [para])), encoding: .utf8)!
        // Insert a removed kind before the known paragraph block.
        let fakeBlock = #"{"type":"collapsedQuote","value":{}}"#
        jsonStr = jsonStr.replacingOccurrences(of: "\"blocks\":[", with: "\"blocks\":[\(fakeBlock),")
        let doc = try DocumentCodec.decode(Data(jsonStr.utf8))
        XCTAssertEqual(doc.blocks.count, 1, "the old collapsedQuote block is skipped")
        guard case .paragraph = doc.blocks[0] else { return XCTFail("expected .paragraph") }
    }
}
