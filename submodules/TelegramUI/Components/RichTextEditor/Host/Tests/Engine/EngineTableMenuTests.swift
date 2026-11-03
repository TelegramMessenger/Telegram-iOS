import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-tables rung C — the structural menu, with legacy's adaptive rules.
///
/// The engine owns WHAT the menu offers; the host owns how it is presented. Both the alignment
/// control and the header toggle are really rendered by the host today, so neither descriptor is
/// dead weight — the request type's own "deferred" comment is stale.
@available(iOS 18.4, *)
final class EngineTableMenuTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 800))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }

    private func load(rows: Int = 3, columns: Int = 2) {
        var built = TableBlock.empty(rows: rows, columns: columns)
        built.id = BlockID("t")
        for r in 0..<rows {
            for c in 0..<columns { built.rows[r].cells[c].blocks = [para("t-\(r)\(c)", "x")] }
        }
        editor.document = Document(blocks: [.table(built)])
        window.layoutIfNeeded()
    }

    private func kinds(_ request: TableStructuralMenuRequest?) -> [TableStructuralMenuRequest.Kind] {
        (request?.actions ?? []).map(\.kind)
    }

    // MARK: Column ranges

    func test_aColumnRangeOffersAddLeftRightAndDelete() {
        load(columns: 3)
        editor.selectTableColumns(1...1)
        XCTAssertEqual(kinds(editor.tableStructuralMenuRequest()),
                       [.addColumnLeft, .addColumnRight, .deleteColumn])
    }

    /// Deleting every column would empty the table, so the item is not offered at all.
    func test_aColumnRangeCoveringEverythingHidesDelete() {
        load(columns: 2)
        editor.selectTableColumns(0...1)
        XCTAssertEqual(kinds(editor.tableStructuralMenuRequest()), [.addColumnLeft, .addColumnRight])
    }

    // MARK: Row ranges

    /// Row 0 is the header (`TableBlock.empty` makes it one), and you cannot insert above it.
    func test_aRowRangeIncludingTheHeaderHidesAddAbove() {
        load()
        editor.selectTableRows(0...0)
        XCTAssertFalse(kinds(editor.tableStructuralMenuRequest()).contains(.addRowAbove))
        XCTAssertTrue(kinds(editor.tableStructuralMenuRequest()).contains(.addRowBelow))
    }

    func test_aRowRangeExcludingTheHeaderOffersAddAbove() {
        load()
        editor.selectTableRows(1...1)
        XCTAssertEqual(kinds(editor.tableStructuralMenuRequest()),
                       [.addRowAbove, .addRowBelow, .deleteRow])
    }

    /// Delete Row needs at least one NON-header row in range, since Core would refuse to remove a
    /// header row anyway.
    func test_aHeaderOnlyRowRangeHidesDelete() {
        load()
        editor.selectTableRows(0...0)
        XCTAssertFalse(kinds(editor.tableStructuralMenuRequest()).contains(.deleteRow))
    }

    // MARK: Cell rects

    func test_aMultiCellRectOffersMerge() {
        load()
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        XCTAssertEqual(kinds(editor.tableStructuralMenuRequest()), [.mergeCells])
    }

    func test_aMergedCellOffersSplit() {
        load()
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        editor.mergeSelectedCells()
        editor.selectTableCells(TableRect(top: 0, left: 0, bottom: 0, right: 0))
        XCTAssertEqual(kinds(editor.tableStructuralMenuRequest()), [.splitCell])
    }

    func test_aSingleUnmergedCellOffersNeither() {
        load()
        editor.selectTableCells(TableRect(top: 1, left: 0, bottom: 1, right: 0))
        XCTAssertTrue(kinds(editor.tableStructuralMenuRequest()).isEmpty)
    }

    // MARK: The descriptors

    func test_theAlignmentDescriptorReportsAUniformValueAndNilWhenMixed() {
        load()
        editor.selectTableRows(1...1)
        XCTAssertEqual(editor.tableStructuralMenuRequest()?.alignment?.horizontal, .center)
        editor.selectTableCells(TableRect(top: 1, left: 0, bottom: 1, right: 0))
        editor.setSelectionAlignment(horizontal: .right, vertical: nil)
        editor.selectTableRows(1...1)
        XCTAssertNil(editor.tableStructuralMenuRequest()?.alignment?.horizontal, "the cells disagree")
    }

    func test_theHeaderDescriptorReportsAUniformValueAndNilWhenMixed() {
        load()
        editor.selectTableRows(0...0)
        XCTAssertEqual(editor.tableStructuralMenuRequest()?.header?.isHeader, true)
        editor.selectTableRows(0...1)
        XCTAssertNil(editor.tableStructuralMenuRequest()?.header?.isHeader, "header row and body row")
    }

    func test_thereIsNoRequestWithoutASelection() {
        load()
        XCTAssertNil(editor.tableStructuralMenuRequest())
    }

    // MARK: The gesture — first tap selects, second opens

    private func rowGripPoint() -> CGPoint? {
        guard let chrome = editor.tableStructuralChromeViews[BlockID("t")] else { return nil }
        UIGraphicsBeginImageContextWithOptions(chrome.bounds.size, false, 1)
        chrome.draw(chrome.bounds)
        UIGraphicsEndImageContext()
        guard let grip = chrome.drawnHandleRects
            .first(where: { $0.minX < chrome.currentTableOrigin.x }) else { return nil }
        return CGPoint(x: grip.midX, y: grip.midY)
    }

    func test_theFirstTapSelectsAndTheSecondRequestsTheMenu() {
        load()
        var requests = 0
        editor.onRequestTableStructuralMenu = { _ in requests += 1 }
        guard let point = rowGripPoint() else { return XCTFail("no row grip") }

        editor.handleTableStructuralTap(atPointInChrome: point)
        XCTAssertNotNil(editor.structuralRowRange(), "the first tap selects")
        XCTAssertEqual(requests, 0, "and does not open the menu")

        window.layoutIfNeeded()
        guard let second = rowGripPoint() else { return XCTFail("no row grip after selecting") }
        editor.handleTableStructuralTap(atPointInChrome: second)
        XCTAssertEqual(requests, 1, "the second tap on the same grip opens it")
    }
}
