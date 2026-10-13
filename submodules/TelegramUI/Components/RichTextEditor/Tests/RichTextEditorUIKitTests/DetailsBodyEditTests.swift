#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
final class DetailsBodyEditTests: XCTestCase {
    /// A canvas holding one expanded details block whose body is a single paragraph `bodyText`, with the
    /// caret placed in that body paragraph.
    private func seededWithCaretInBody(_ bodyText: String) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        let d = DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                             children: [.paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: bodyText)]))],
                             expanded: true)
        v.setBlocks([.details(d)], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.becomeFirstResponder()
        let box = v.boxes.first { $0 is DetailsBox } as! DetailsBox
        let bodyStart = box.leafRegions()[1].globalStart        // [0] = title, [1] = body
        v.setSelectionForTesting(anchor: bodyStart, head: bodyStart)
        return v
    }
    private func detailsBody(_ v: DocumentCanvasView) -> [Block] {
        guard case .details(let d) = v.currentBlocks()[0] else { return [] }
        return d.children
    }

    func test_setHeading_insideDetailsBody() {
        let v = seededWithCaretInBody("note")
        v.setParagraphStyle(.heading2)
        guard case .paragraph(let bp) = detailsBody(v).first else { return XCTFail("expected a body paragraph") }
        XCTAssertEqual(bp.style, .heading2)
        XCTAssertEqual(bp.text, "note")
    }

    func test_setList_insideDetailsBody() {
        let v = seededWithCaretInBody("item")
        v.setList(.bullet)
        guard case .paragraph(let bp) = detailsBody(v).first else { return XCTFail("expected a body paragraph") }
        XCTAssertEqual(bp.list?.marker, .bullet)
    }

    func test_insertTable_insideDetailsBody() {
        let v = seededWithCaretInBody("x")
        v.insertTable(rows: 2, columns: 2)
        let body = detailsBody(v)
        XCTAssertTrue(body.contains { if case .table = $0 { return true } else { return false } },
                      "a table should be inserted inside the details body, not at top level")
        // The details block stays the only TOP-LEVEL block (the table went into its body).
        XCTAssertEqual(v.currentBlocks().count, 1)
    }

    func test_insertNestedDetails_insideDetailsBody() {
        let v = seededWithCaretInBody("x")
        v.insertDetailsBlock()
        XCTAssertTrue(detailsBody(v).contains { if case .details = $0 { return true } else { return false } })
        XCTAssertEqual(v.currentBlocks().count, 1)   // nested inside the body, not a new top-level block
    }

    func test_insertMedia_insideDetailsBody() {
        let v = seededWithCaretInBody("x")
        v.insertMedia(mediaID: "m1", naturalSize: CGSize(width: 100, height: 100), kind: .image)
        XCTAssertTrue(detailsBody(v).contains { if case .media = $0 { return true } else { return false } })
        XCTAssertEqual(v.currentBlocks().count, 1)
    }

    func test_makeCode_insideDetailsBody() {
        let v = seededWithCaretInBody("code")
        v.makeCodeBlock()
        XCTAssertTrue(detailsBody(v).contains { if case .code = $0 { return true } else { return false } })
    }

    func test_makePullQuote_insideDetailsBody() {
        let v = seededWithCaretInBody("quote")
        v.makePullQuote()
        XCTAssertTrue(detailsBody(v).contains { if case .pullQuote = $0 { return true } else { return false } })
    }

    func test_wrapInBlockQuote_insideDetailsBody() {
        let v = seededWithCaretInBody("quoted")
        v.wrapInBlockQuote()
        XCTAssertTrue(detailsBody(v).contains { if case .blockQuote = $0 { return true } else { return false } })
        XCTAssertEqual(v.currentBlocks().count, 1)
    }
}
#endif
