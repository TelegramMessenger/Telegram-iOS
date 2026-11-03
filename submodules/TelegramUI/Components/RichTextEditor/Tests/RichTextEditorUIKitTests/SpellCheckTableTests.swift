#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SpellCheckTableTests: XCTestCase {
    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    func test_cellMisspelling_isFlaggedAndHitTestable() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "wrold"), cell("b", "fine")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let box = v.boxes.first { $0 is TableBlockBox } as! TableBlockBox
        let start = box.cellTextStart(row: 0, column: 0)!
        v.applyNativeAnnotations(global: NSRange(location: start, length: 5), style: .spelling)   // "wrold"
        // Cell "a"'s paragraph block id is "ap"; the whole word "wrold" is flagged (region-local 0..5).
        XCTAssertEqual(v.spellResults[BlockID("ap")]?.ranges.map { $0.range }, [NSRange(location: 0, length: 5)])
        // The flagged word is hit-testable in canvas coordinates (selectionRects folds table offset).
        let r = v.spellingWordRanges().first { v.spellCheckableRef($0.region.ref) == BlockID("ap") }!
        let rects = v.selectionRects(globalFrom: r.global.location, globalTo: r.global.location + r.global.length)
        XCTAssertFalse(rects.isEmpty)
        XCTAssertNotNil(v.misspelledWord(atCanvasPoint: CGPoint(x: rects[0].midX, y: rects[0].midY)))
    }
}
#endif
