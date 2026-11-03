import XCTest
@testable import RichTextEditorCore

final class TextRunSlicingTests: XCTestCase {
    private func runs() -> [TextRun] {
        [TextRun(text: "Hello", attributes: CharacterAttributes(bold: true)),
         TextRun(text: " world", attributes: .plain)]
    }

    func test_slice_withinFirstRun_keepsAttributes() {
        let r = sliceRuns(runs(), fromUTF16: 1, toUTF16: 4)   // "ell"
        XCTAssertEqual(r.map(\.text), ["ell"])
        XCTAssertTrue(r[0].attributes.bold)
    }

    func test_slice_acrossRunBoundary_splitsBoth() {
        let r = sliceRuns(runs(), fromUTF16: 3, toUTF16: 8)   // "lo wo"
        XCTAssertEqual(r.map(\.text), ["lo", " wo"])
        XCTAssertTrue(r[0].attributes.bold)
        XCTAssertFalse(r[1].attributes.bold)
    }

    func test_slice_emptyRange_returnsEmpty() {
        XCTAssertTrue(sliceRuns(runs(), fromUTF16: 4, toUTF16: 4).isEmpty)
    }

    func test_slice_clampsOutOfRange() {
        let r = sliceRuns(runs(), fromUTF16: -5, toUTF16: 999)
        XCTAssertEqual(r.map(\.text).joined(), "Hello world")
    }

    func test_insertingText_atRunBoundary_insertsPlainRun() {
        let r = insertingText("X", into: runs(), atUTF16: 5)   // between "Hello" and " world"
        XCTAssertEqual(r.map(\.text).joined(), "HelloX world")
    }

    func test_insertingText_midRun_splitsRunAndKeepsHalves() {
        let r = insertingText("X", into: runs(), atUTF16: 2)
        XCTAssertEqual(r.map(\.text).joined(), "HeXllo world")
    }
}
