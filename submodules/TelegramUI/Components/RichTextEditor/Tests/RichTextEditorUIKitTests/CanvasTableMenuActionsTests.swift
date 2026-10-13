#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The attachment-screen table menu's "Copy Table" (`copyCurrentTable`) and "Convert to Text"
/// (`convertCurrentTableToText`) actions.
final class CanvasTableMenuActionsTests: XCTestCase {
    final class FakePasteboard: TextPasteboard {
        var items: [String: Any] = [:]
        var string: String? {
            get { items["public.utf8-plain-text"] as? String }
            set { if let v = newValue { items = ["public.utf8-plain-text": v] } else { items = [:] } }
        }
        var hasStrings: Bool { !((string ?? "").isEmpty) }
        func data(forPasteboardType type: String) -> Data? { items[type] as? Data }
        func setItems(_ newItems: [[String: Any]], options: [UIPasteboard.OptionsKey: Any]) { items = newItems.first ?? [:] }
        func contains(pasteboardTypes: [String]) -> Bool { pasteboardTypes.contains { items[$0] != nil } }
    }
    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: t.isEmpty ? [] : [TextRun(text: t)]))])
    }
    private func canvas() -> (DocumentCanvasView, FakePasteboard) {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 90), ColumnSpec(width: 90)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "a"), cell("b", "b")]),
                       Row(id: BlockID("r1"), cells: [cell("c", "c"), cell("d", "d")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let pb = FakePasteboard(); v.pasteboard = pb
        return (v, pb)
    }
    private func tableBox(_ v: DocumentCanvasView) -> TableBlockBox { v.boxes.first { $0 is TableBlockBox } as! TableBlockBox }
    private func putCaretInTable(_ v: DocumentCanvasView) { let p = tableBox(v).cellTextStart(row: 0, column: 0)!; v.setSelectionForTesting(anchor: p, head: p) }
    private func paraTexts(_ v: DocumentCanvasView) -> [String] {
        v.currentBlocks().compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
    }

    func test_copyCurrentTable_writesFragmentRtfAndFlattenedPlain() {
        let (v, pb) = canvas()
        putCaretInTable(v)
        v.copyCurrentTable()
        XCTAssertEqual(pb.string, "a b\nc d", "plain rep: one line per row, cells space-joined")
        XCTAssertNotNil(pb.data(forPasteboardType: "public.rtf"), "RTF rep present")
        let fragData = pb.data(forPasteboardType: DocumentCanvasView.richTextFragmentUTI)
        XCTAssertNotNil(fragData, "app fragment present")
        let frag = try! DocumentCodec.decode(fragData!)
        XCTAssertEqual(frag.blocks.count, 1, "the fragment is a document with ONLY the table")
        guard case .table = frag.blocks[0] else { return XCTFail("fragment carries the table (pastes back as a real table)") }
    }

    func test_copyCurrentTable_noopOutsideTable() {
        let (v, pb) = canvas()
        v.setSelectionForTesting(anchor: 0, head: 0)   // caret in "Top", not the table
        v.copyCurrentTable()
        XCTAssertTrue(pb.items.isEmpty, "no-op when the caret isn't in a table")
    }

    func test_convertCurrentTableToText_replacesTableWithRowParagraphs() {
        let (v, _) = canvas()
        putCaretInTable(v)
        v.convertCurrentTableToText()
        v.layoutIfNeeded()
        XCTAssertNil(v.boxes.first { $0 is TableBlockBox }, "the table is replaced")
        XCTAssertEqual(paraTexts(v), ["Top", "a b", "c d"], "one body paragraph per row, cells space-joined")
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret lands at the start of the first converted paragraph")
    }
}
#endif
