#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// R7-tables rung C — the structural menu.
///
/// The editor owns WHAT the menu offers, adapted to the table's state; the host owns HOW it is
/// presented (titles, icons, styling). Ported from legacy's `tableStructuralMenuRequest()` with its
/// adaptive rules intact — hiding an item is how the menu says "not possible here", and each of those
/// rules exists because the underlying edit would be a no-op or a data loss.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The menu for the live structural selection, or nil when there is none.
    internal func tableStructuralMenuRequest() -> TableStructuralMenuRequest? {
        guard let selection = tableStructuralSelection, let (table, _) = tableForEditing(),
              let chrome = tableStructuralChromeViews[selection.table] else { return nil }
        let map = TableMap(table)
        var actions: [TableStructuralMenuRequest.Action] = []

        switch selection.kind {
        case let .columns(range):
            actions.append(.init(kind: .addColumnLeft, perform: perform { $0.insertTableColumnLeft() }))
            actions.append(.init(kind: .addColumnRight, perform: perform { $0.insertTableColumnRight() }))
            // Hidden when the range covers every column: deleting them all would empty the table.
            if !(range.lowerBound == 0 && range.upperBound == map.columns - 1) {
                actions.append(.init(kind: .deleteColumn, perform: perform { $0.deleteTableColumn() }))
            }
        case let .rows(range):
            // Nothing goes above the header row.
            if !range.contains(where: { table.rows.indices.contains($0) && table.rows[$0].isHeader }) {
                actions.append(.init(kind: .addRowAbove, perform: perform { $0.insertTableRowAbove() }))
            }
            actions.append(.init(kind: .addRowBelow, perform: perform { $0.insertTableRowBelow() }))
            // Delete needs at least one NON-header row in range — Core refuses to remove a header
            // row, so offering it over a header-only range would be an item that does nothing.
            if range.contains(where: { table.rows.indices.contains($0) && !table.rows[$0].isHeader }) {
                actions.append(.init(kind: .deleteRow, perform: perform { $0.deleteTableRow() }))
            }
        case let .cells(rect):
            let anchors = map.cellsInRect(rect)
            if anchors.count >= 2 {
                actions.append(.init(kind: .mergeCells, perform: perform { $0.mergeSelectedCells() }))
            }
            if anchors.count == 1, let only = anchors.first, only.colspan > 1 || only.rowspan > 1 {
                actions.append(.init(kind: .splitCell, perform: perform { $0.splitSelectedCell() }))
            }
        }

        return TableStructuralMenuRequest(view: chrome, sourceRect: sourceRect(for: selection.kind, in: chrome),
                                          actions: actions,
                                          alignment: alignmentDescriptor(table: table, map: map),
                                          header: headerDescriptor(table: table, map: map))
    }

    /// Where the host anchors the menu: the tapped GRIP for a row or column range, and the OUTLINE for
    /// a cell rect — there is no grip for one, so a handle-based rect would be `.zero`.
    private func sourceRect(for kind: EngineTableStructuralSelection,
                            in chrome: TableStructuralChromeView) -> CGRect {
        guard let geometry = structuralChromeGeometry() else { return .zero }
        if case .cells = kind {
            return geometry.outlineRect().map { chrome.viewRect($0) } ?? .zero
        }
        // The first matching grip: for a row range that is the LEADING one, which is where the menu
        // anchored before the trailing grip existed. Every grip rides the scroll.
        for handle in geometry.handles() where handle.kind == kind {
            return chrome.viewRect(handle.rect)
        }
        return .zero
    }

    /// Every action runs its verb and then clears the structural selection, mirroring legacy's
    /// run-then-clear: the rows the menu acted on may not exist afterwards.
    private func perform(_ body: @escaping (RichTextEngineEditorView) -> Void) -> () -> Void {
        { [weak self] in
            guard let self else { return }
            body(self)
            self.clearTableStructuralSelection()
        }
    }

    private func coveredCells(table: TableBlock, map: TableMap) -> [Cell] {
        guard let rect = coveredRectForAttributes() else { return [] }
        let ids = Set(map.cellsInRect(rect).map(\.cellID))
        return table.rows.flatMap(\.cells).filter { ids.contains($0.id) }
    }

    /// The uniform value per axis, or nil when the covered cells disagree — which the host renders as
    /// "mixed" rather than picking one.
    private func alignmentDescriptor(table: TableBlock, map: TableMap) -> TableStructuralMenuRequest.Alignment? {
        let cells = coveredCells(table: table, map: map)
        guard !cells.isEmpty else { return nil }
        let horizontal = Set(cells.map(\.horizontalAlignment))
        let vertical = Set(cells.map(\.verticalAlignment))
        return .init(horizontal: horizontal.count == 1 ? horizontal.first : nil,
                     vertical: vertical.count == 1 ? vertical.first : nil,
                     apply: { [weak self] h, v in self?.setSelectionAlignment(horizontal: h, vertical: v) })
    }

    private func headerDescriptor(table: TableBlock, map: TableMap) -> TableStructuralMenuRequest.Header? {
        let cells = coveredCells(table: table, map: map)
        guard !cells.isEmpty else { return nil }
        let flags = Set(cells.map(\.isHeader))
        return .init(isHeader: flags.count == 1 ? flags.first : nil,
                     apply: { [weak self] in self?.toggleSelectionHeader() })
    }
}
#endif
