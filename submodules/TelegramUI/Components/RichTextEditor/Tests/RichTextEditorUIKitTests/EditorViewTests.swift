#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class EditorViewTests: XCTestCase {
    private func singleBlockDoc(_ p: ParagraphBlock) -> Document {
        Document(blocks: [.paragraph(p)])
    }

    func test_documentRoundTrips() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let p = ParagraphBlock(id: BlockID("p1"), style: .heading2, runs: [
            TextRun(text: "A "),
            TextRun(text: "B", attributes: CharacterAttributes(bold: true)),
        ])
        editor.document = singleBlockDoc(p)
        editor.layoutIfNeeded()
        let out = editor.document
        guard case .paragraph(let outP) = out.blocks.first else { return XCTFail("expected paragraph") }
        XCTAssertEqual(outP.style, .heading2)
        XCTAssertEqual(outP.runs.map(\.text).joined(), "A B")
        XCTAssertTrue(outP.runs.last?.attributes.bold ?? false)
    }

    func test_toggleBoldThroughFacade() {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        editor.document = singleBlockDoc(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "hi")]))
        editor.layoutIfNeeded()
        editor.selectAll()
        editor.toggleBold()
        guard case .paragraph(let p) = editor.document.blocks.first else { return XCTFail() }
        XCTAssertTrue(p.runs.allSatisfy { $0.attributes.bold })
    }
}
#endif
