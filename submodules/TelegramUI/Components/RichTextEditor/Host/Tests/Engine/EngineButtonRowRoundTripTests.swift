import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-buttons Task 2 — a button row is a fifth engine block shape.
///
/// The first test here is the one that could not exist before this task: `Block.buttonRow` was a
/// `preconditionFailure` in the bridge, so a document holding one crashed the editor on a document
/// SET — not on an authoring verb.
@available(iOS 18.4, *)
final class EngineButtonRowRoundTripTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func button(_ label: String, _ url: String = "https://example.com") -> ButtonRef {
        ButtonRef(label: [TextRun(text: label)], action: .url(url))
    }
    private func row(_ id: String, _ buttons: [ButtonRef], _ alignment: ButtonRowAlignment = .justify) -> Block {
        .buttonRow(ButtonRowBlock(id: BlockID(id), buttons: buttons, alignment: alignment))
    }
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    func test_aDocumentHoldingAButtonRowCanBeSetAtAll() {
        editor.document = Document(blocks: [para("p", "before"), row("r", [button("Open")]), para("q", "after")])
        XCTAssertEqual(editor.currentRoles.count, 3)
        XCTAssertEqual(editor.document.blocks, [para("p", "before"), row("r", [button("Open")]), para("q", "after")])
    }

    func test_theRowIsOneEngineBlockHoldingOneAttachmentCharacter() {
        editor.document = Document(blocks: [row("r", [button("A"), button("B")])])
        let blocks = editor.engine.attributedBlocks
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].length, 1, "one atom for the whole row, whatever its pill count")
        XCTAssertTrue(blocks[0].attribute(.attachment, at: 0, effectiveRange: nil) is ButtonRowTextAttachment)
    }

    func test_theShapeCarriesTheWholeModelAndIgnoresRuns() {
        let model = ButtonRowBlock(id: BlockID("r"), buttons: [button("A")], alignment: .center)
        let shape = ButtonRowShape(model)
        XCTAssertEqual(shape.block, model)
        XCTAssertEqual(EngineBlockShape.buttonRow(shape).block(runs: [TextRun(text: "ignored")]),
                       .buttonRow(model), "a row has no text, so runs cannot reach it")
    }

    func test_aRowRoundTripsInsideAQuoteAndInsideADetails() {
        let quoted = Block.blockQuote(BlockQuote(id: BlockID("q"),
                                                 children: [row("r1", [button("Q")])], author: []))
        let detailed = Block.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                                  children: [row("r2", [button("D")])], expanded: true))
        editor.document = Document(blocks: [quoted, detailed])
        XCTAssertEqual(editor.document.blocks, [quoted, detailed])
    }

    func test_anEmptyRowSurvivesTheRoundTrip() {
        editor.document = Document(blocks: [row("r", [])])
        XCTAssertEqual(editor.document.blocks, [row("r", [])])
        XCTAssertEqual(editor.engine.attributedBlocks[0].length, 1)
    }

    func test_anUnsupportedActionIsPreservedThroughTheEditRoundTrip() {
        let opaque = ButtonRef(label: [TextRun(text: "Pay")],
                               action: .unsupported(kind: "payment", payload: "blob"))
        editor.document = Document(blocks: [row("r", [opaque])])
        XCTAssertEqual(editor.document.blocks, [row("r", [opaque])],
                       "the opaque carrier belongs to the message it arrived in; only a PASTE downgrades it")
    }

    func test_aRowInsideATableCellIsDroppedAsItIsOnTheWire() {
        let cell = Cell(id: BlockID("c"), blocks: [row("r", [button("X")])])
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                               rows: [Row(id: BlockID("row"), cells: [cell])])
        editor.document = Document(blocks: [.table(table)])
        guard case let .table(back) = editor.document.blocks[0] else { return XCTFail("not a table") }
        XCTAssertTrue(back.rows[0].cells[0].blocks.allSatisfy { if case .buttonRow = $0 { return false }; return true },
                      "a cell is ONE inline text on the wire; documented, not a regression")
    }
}
