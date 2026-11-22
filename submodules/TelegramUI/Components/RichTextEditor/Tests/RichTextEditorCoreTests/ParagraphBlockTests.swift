import XCTest
@testable import RichTextEditorCore

final class ParagraphBlockTests: XCTestCase {
    func test_blockID_encodesAsBareString() throws {
        let id = BlockID("p1")
        let data = try JSONEncoder().encode(id)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"p1\"")
    }

    func test_paragraph_textConcatenatesRuns_andUTF16CountSumsRuns() {
        let p = ParagraphBlock(id: BlockID("p1"), runs: [
            TextRun(text: "Hello "),
            TextRun(text: "world"),
        ])
        XCTAssertEqual(p.text, "Hello world")
        XCTAssertEqual(p.utf16Count, 11)
    }

    func test_paragraph_defaultsToBodyStyleNoList() {
        let p = ParagraphBlock(id: BlockID("p1"))
        XCTAssertEqual(p.style, .body)
        XCTAssertNil(p.list)
        XCTAssertEqual(p.utf16Count, 0)
    }
}
