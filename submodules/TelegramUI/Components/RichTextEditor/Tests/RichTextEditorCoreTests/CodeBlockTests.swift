import XCTest
@testable import RichTextEditorCore

final class CodeBlockTests: XCTestCase {
    func test_codeBlock_textAndCountJoinRuns() {
        let cb = CodeBlock(id: BlockID("c1"), language: "swift",
                           runs: [TextRun(text: "let x = 1\n"), TextRun(text: "let y = 2")])
        XCTAssertEqual(cb.text, "let x = 1\nlet y = 2")
        XCTAssertEqual(cb.utf16Count, 19)
    }

    func test_codeBlock_codableRoundTrip() throws {
        let cb = CodeBlock(id: BlockID("c1"), language: "python",
                           runs: [TextRun(text: "print(1)\nprint(2)")])
        let data = try JSONEncoder().encode(cb)
        let back = try JSONDecoder().decode(CodeBlock.self, from: data)
        XCTAssertEqual(cb, back)
    }

    func test_codeBlock_nilLanguageRoundTrips() throws {
        let cb = CodeBlock(id: BlockID("c1"), language: nil, runs: [TextRun(text: "x")])
        let back = try JSONDecoder().decode(CodeBlock.self, from: JSONEncoder().encode(cb))
        XCTAssertNil(back.language)
        XCTAssertEqual(cb, back)
    }

    func test_codeBlock_emptyRunsGiveZeroCount() {
        let cb = CodeBlock(id: BlockID("c1"))
        XCTAssertEqual(cb.text, "")
        XCTAssertEqual(cb.utf16Count, 0)
    }

    func test_blockCode_idAndCodableRoundTrip() throws {
        let block = Block.code(CodeBlock(id: BlockID("c1"), language: "swift",
                                         runs: [TextRun(text: "a\nb")]))
        XCTAssertEqual(block.id, BlockID("c1"))
        let back = try JSONDecoder().decode(Block.self, from: JSONEncoder().encode(block))
        XCTAssertEqual(block, back)
    }

    // The language line's UTF-16 length — the axis the position model counts in. Mirrors
    // `PullQuote.authorUTF16Count`. A nil AND an empty language are both zero-length: "no language"
    // and "an empty language line" are the same state, and `currentCode()` normalizes "" back to nil.
    func test_languageUTF16Count_isZeroForNilAndEmpty() {
        XCTAssertEqual(CodeBlock(id: BlockID("c"), language: nil).languageUTF16Count, 0)
        XCTAssertEqual(CodeBlock(id: BlockID("c"), language: "").languageUTF16Count, 0)
    }

    func test_languageUTF16Count_countsUTF16UnitsNotCharacters() {
        XCTAssertEqual(CodeBlock(id: BlockID("c"), language: "swift").languageUTF16Count, 5)
        // A non-BMP scalar is TWO UTF-16 units; the position axis counts units, so this must be 2.
        XCTAssertEqual(CodeBlock(id: BlockID("c"), language: "\u{1F600}").languageUTF16Count, 2)
    }

    func test_textNodeRef_codeLanguageIsDistinctFromCode() {
        XCTAssertNotEqual(TextNodeRef.codeLanguage(BlockID("c")), TextNodeRef.code(BlockID("c")))
        XCTAssertEqual(TextNodeRef.codeLanguage(BlockID("c")), TextNodeRef.codeLanguage(BlockID("c")))
    }
}
