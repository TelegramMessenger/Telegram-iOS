#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasSpanTests: XCTestCase {
    private func canvas(_ texts: [String]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs(texts.enumerated().map {
            ParagraphBlock(id: BlockID("p\($0.offset)"), runs: [TextRun(text: $0.element)])
        }, width: 300)
        return v
    }

    func test_spansMatchCorePositionModel() {
        let v = canvas(["One", "Two", "Three"])
        let doc = Document(blocks: v.currentParagraphs().map { .paragraph($0) })
        let tree = DocumentTree.build(from: doc)
        XCTAssertEqual(v.documentSize, DocumentTree.documentSize(doc))
        for box in v.boxes {
            let expected = PositionResolver.globalPosition(of: .paragraph(box.id), offset: 0, in: tree)
            XCTAssertEqual(box.textStart, expected)
        }
    }

    func test_boxContainingGlobal_roundTrips() {
        let v = canvas(["One", "Two"])
        // "One" occupies globals 1...4; "Two" occupies 6...9 (0 <p>1 O2 n3 e4</p>5 <p>6 T7 w8 o9</p>10)
        let (box, local) = v.box(containingGlobal: 7)!
        XCTAssertEqual(box.id, BlockID("p1"))
        XCTAssertEqual(local, 1)
        XCTAssertNil(v.box(containingGlobal: 5))   // structural boundary between paragraphs
    }
}
#endif
