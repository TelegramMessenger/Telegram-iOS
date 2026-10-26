#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
final class DetailsBoxReturnTests: XCTestCase {
    private func seeded(body: [Block]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")], children: body, expanded: true)
        v.setBlocks([.details(d)], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.becomeFirstResponder()
        return v
    }
    private func detailsBox(_ v: DocumentCanvasView) -> DetailsBox { v.boxes.first { $0 is DetailsBox } as! DetailsBox }

    func test_doubleReturnAtEndOfBodyContent_escapesToParagraphAfterDetails() {
        let v = seeded(body: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "note")]))])
        let bodyRegion = detailsBox(v).leafRegions()[1]                 // [0] = title, [1] = body
        let end = bodyRegion.globalStart + bodyRegion.length
        v.setSelectionForTesting(anchor: end, head: end)
        v.insertText("\n")                                             // 1st Return: adds an empty body line
        v.insertText("\n")                                             // 2nd Return: escapes
        let blocks = v.currentBlocks()
        XCTAssertEqual(blocks.count, 2)                                // details + a following body paragraph
        guard case .details(let out) = blocks[0] else { return XCTFail() }
        XCTAssertEqual(out.title.map(\.text).joined(), "T")
        XCTAssertEqual(out.children.count, 1)                          // body keeps "note"; the trailing empty is consumed
        guard case .paragraph(let after) = blocks[1] else { return XCTFail("expected trailing paragraph") }
        XCTAssertTrue(after.text.isEmpty)
        XCTAssertEqual(v.head, v.boxes[1].textStart)                   // caret in the following paragraph
    }

    func test_doubleReturnInEmptyBody_firstAddsLine_secondEscapes() {
        let v = seeded(body: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: []))])
        let bodyRegion = detailsBox(v).leafRegions()[1]
        v.setSelectionForTesting(anchor: bodyRegion.globalStart, head: bodyRegion.globalStart)
        v.insertText("\n")                                             // 1st Return: adds a line, NO escape
        XCTAssertEqual(v.currentBlocks().count, 1)                     // still only the details
        guard case .details(let mid) = v.currentBlocks()[0] else { return XCTFail() }
        XCTAssertEqual(mid.children.count, 2)                          // two empty body lines
        v.insertText("\n")                                             // 2nd Return: escapes
        let blocks = v.currentBlocks()
        XCTAssertEqual(blocks.count, 2)                                // details + a following body paragraph
        guard case .details(let out) = blocks[0] else { return XCTFail() }
        XCTAssertEqual(out.children.count, 0)                          // all-empty body cleared; title kept
        XCTAssertEqual(out.title.map(\.text).joined(), "T")
    }
}
#endif
