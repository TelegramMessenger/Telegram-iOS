import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

@available(iOS 18.4, *)
final class EngineTableDecorationTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func cell(_ id: String, _ text: String, header: Bool = false, background: RGBAColor? = nil) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID("\(id)p"), runs: [TextRun(text: text)]))],
             background: background, isHeader: header)
    }
    private func table(bordered: Bool = true) -> TableBlock {
        TableBlock(id: BlockID("t0"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                   rows: [Row(id: BlockID("r0"), cells: [cell("a", "A", header: true), cell("b", "B", header: true)]),
                          Row(id: BlockID("r1"), cells: [cell("c", "C", background: RGBAColor(red: 0, green: 1, blue: 0, alpha: 1)), cell("d", "D")])],
                   bordered: bordered)
    }

    func test_aTableGetsOneChromeViewBehindItsCellsCoveringTheWholeGrid() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")])),
            .table(table()),
        ])
        editor.layoutIfNeeded()
        guard let chrome = editor.tableChromeViews[BlockID("t0")] else { return XCTFail("no chrome view") }
        let grid = editor.tableGrids[BlockID("t0")]!
        XCTAssertEqual(chrome.frame.size.width, grid.size.width, accuracy: 0.5)
        XCTAssertEqual(chrome.frame.size.height, grid.size.height, accuracy: 0.5)
        let a = editor.engine.id_frameForBlock(at: 1)
        // The chrome lives in the run's scrolling content, at its origin; the first cell's text sits
        // inside its top border + padding, measured in the content view's own coordinates.
        guard let content = editor.engine.id_placedRunContentViewForBlock(at: 1) else { return XCTFail("no run content") }
        XCTAssertEqual(chrome.superview, content)
        XCTAssertEqual(chrome.frame.origin.x, 0)
        // Asserted against the ONE place the number lives, not re-derived here. This used to call
        // `tableGapAbove` for itself — the same duplication that let a grid draw on top of the table
        // above it once adjacent tables gained a run offset.
        XCTAssertEqual(chrome.frame.origin.y, editor.tablePlacements[BlockID("t0")]?.dy ?? -1,
                       accuracy: 0.5, "the chrome sits at the offset the cells were placed with")
        XCTAssertEqual(content.subviews.firstIndex(of: chrome), 0, "behind the cells")
        let aInContent = editor.engine.convert(a, to: content)
        XCTAssertEqual(aInContent.minY, chrome.frame.minY + grid.borderWidth + 14, accuracy: 0.5, "the first cell's text sits inside the chrome's top border + padding")
        XCTAssertFalse(chrome.isUserInteractionEnabled)
    }

    func test_chromeDrawsTheGridOnlyWhenBorderedAndPaintsHeaderAndCellBackgrounds() {
        editor.document = Document(blocks: [.table(table())])
        editor.layoutIfNeeded()
        let chrome = editor.tableChromeViews[BlockID("t0")]!
        chrome.layer.displayIfNeeded()
        XCTAssertEqual(chrome.gridLineRects.count, 3, "the outer path, one interior vertical, one interior horizontal")
        XCTAssertEqual(chrome.fillRects.count, 3, "two header cells + one cell background")
        editor.document = Document(blocks: [.table(table(bordered: false))])
        editor.layoutIfNeeded()
        let unbordered = editor.tableChromeViews[BlockID("t0")]!
        unbordered.layer.displayIfNeeded()
        XCTAssertEqual(unbordered.gridLineRects.count, 0, "unbordered: no grid at all")
    }

    func test_removingTheTableRemovesItsChrome() {
        editor.document = Document(blocks: [.table(table())])
        editor.layoutIfNeeded()
        XCTAssertNotNil(editor.tableChromeViews[BlockID("t0")])
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "x")]))])
        editor.layoutIfNeeded()
        XCTAssertNil(editor.tableChromeViews[BlockID("t0")])
    }

    func test_theRunIsTallEnoughForTheBottomBorderWhenAParagraphFollows() {
        // The chrome is one border taller than the cells; with a paragraph below (no trailing gap
        // on the run) the scroll view clipped that last point of the bottom border.
        editor.document = Document(blocks: [
            .table(table()),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "after")])),
        ])
        editor.layoutIfNeeded()
        guard let chrome = editor.tableChromeViews[BlockID("t0")], let content = chrome.superview,
              let scroll = content.superview as? UIScrollView else { return XCTFail("chrome not in a run") }
        XCTAssertGreaterThanOrEqual(scroll.bounds.height, chrome.frame.maxY - 0.01,
                                    "the run must contain the whole chrome, bottom border included")
        XCTAssertGreaterThanOrEqual(content.bounds.height, chrome.frame.maxY - 0.01)
    }
}
